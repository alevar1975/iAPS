import Combine
import Foundation
import Swinject

final class IAPSKIServerManager {
    static let shared = IAPSKIServerManager()

    func uploadCurrentSettings(resolver: Resolver) {
        // 1. iAPS FileStorage über den Resolver auflösen
        guard let storage = resolver.resolve(FileStorage.self) else {
            print("❌ Fehler: iAPS FileStorage konnte nicht geladen werden.")
            return
        }

        // 2. Zugangsdaten aus den UserDefaults und dem Keychain laden
        guard let serverURLStr = UserDefaults.standard.string(forKey: "iaps_ki_server_url"),
              let url = URL(string: "\(serverURLStr)/api/v1/upload_settings.php"),
              let keyData = KeychainHelper.shared.read(service: "iaps-ki-api", account: "iAPS"),
              let apiKey = String(data: keyData, encoding: .utf8)
        else {
            print("❌ Upload abgebrochen: URL oder API-Key fehlen in iAPS.")
            return
        }

        Task {
            // 3. Relevante JSON-Dateien aus dem iAPS Speicher abrufen
            let profileRaw = storage.retrieveRaw(OpenAPS.Settings.profile) ?? "{}"
            let prefRaw = storage.retrieveRaw(OpenAPS.Settings.preferences) ?? "{}"
            let freeapsRaw = storage.retrieveRaw(OpenAPS.FreeAPS.settings) ?? "{}"

            // Bevorzugt enacted.json, ansonsten Fallback auf suggested.json
            let enactedRaw = storage.retrieveRaw(OpenAPS.Enact.enacted) ?? "{}"
            let suggestedRaw = storage.retrieveRaw(OpenAPS.Enact.suggested) ?? "{}"

            let profile = self.parseRawJSON(profileRaw)
            let preferences = self.parseRawJSON(prefRaw)
            let freeapsSettings = self.parseRawJSON(freeapsRaw)

            // Wenn enacted Werte hat, nehmen wir die, sonst suggested
            let enactedData = self.parseRawJSON(enactedRaw)
            let suggestedData = self.parseRawJSON(suggestedRaw)
            let loopData = enactedData.isEmpty == false ? enactedData : suggestedData

            // 4. Statische Werte extrahieren
            let currentIC = (profile["carb_ratio"] as? NSNumber)?.doubleValue ?? (profile["carbratio"] as? NSNumber)?
                .doubleValue ?? 0.0
            let staticBasal = (profile["current_basal"] as? NSNumber)?.doubleValue ?? (profile["basal"] as? NSNumber)?
                .doubleValue ?? 0.0
            let currentMaxIOB = (profile["max_iob"] as? NSNumber)?.doubleValue ?? (profile["maxIOB"] as? NSNumber)?
                .doubleValue ?? 0.0
            let staticProfileISF = (profile["sens"] as? NSNumber)?.doubleValue ?? (profile["isf"] as? NSNumber)?
                .doubleValue ?? 0.0

            // 🟢 5. WERTE DIREKT AUS DEM "REASON" FELD EXTRAHIEREN
            var dynamicISF = staticProfileISF
            var dynamicBasal = staticBasal

            if let reasonText = loopData["reason"] as? String {
                // Den dynamischen ISF aus dem Reason-Feld holen (z.B. "ISF: 29 → 33")
                let parsedISF = self.extractValueAfterArrow(from: reasonText, forKeyword: "ISF:")
                if let parsedISF = parsedISF {
                    dynamicISF = parsedISF
                }

                // Die dynamische Basalrate aus dem Reason-Feld holen (z.B. "Basal: 2.6 → 2.25")
                let parsedBasal = self.extractValueAfterArrow(from: reasonText, forKeyword: "Basal:")
                if let parsedBasal = parsedBasal {
                    dynamicBasal = parsedBasal
                }
            }

            var payload: [String: Any] = [
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "openaps": [
                    "isf": dynamicISF, // 🟢 Dynamischer ISF (direkt aus dem iAPS Log)
                    "basal": dynamicBasal, // 🟢 Dynamische Basalrate (direkt aus dem iAPS Log)
                    "profile_isf": staticProfileISF, // 🟢 Profil-Referenzwert
                    "ic": currentIC,
                    "maxIOB": currentMaxIOB
                ]
            ]

            var activeAlgorithm = "openaps_only"
            var algorithmSettings: [String: Any] = [:]

            // 6. Mappen der AutoISF Werte für das Python-Skript
            algorithmSettings["bgAccelISFweight"] = self.extractDouble(
                key1: "bgAccelISFweight",
                key2: "bgAccel_ISF_weight",
                defaultVal: 0.17,
                dict1: freeapsSettings,
                dict2: preferences
            )
            algorithmSettings["bgBrakeISFweight"] = self.extractDouble(
                key1: "bgBrakeISFweight",
                key2: "bgBrake_ISF_weight",
                defaultVal: 0.23,
                dict1: freeapsSettings,
                dict2: preferences
            )
            algorithmSettings["higherISFrangeWeight"] = self.extractDouble(
                key1: "higherISFrangeWeight",
                key2: "higher_ISFrange_weight",
                defaultVal: 2.0,
                dict1: freeapsSettings,
                dict2: preferences
            )
            algorithmSettings["lowerISFrangeWeight"] = self.extractDouble(
                key1: "lowerISFrangeWeight",
                key2: "lower_ISFrange_weight",
                defaultVal: 3.0,
                dict1: freeapsSettings,
                dict2: preferences
            )
            algorithmSettings["autoISFhourlyChange"] = self.extractDouble(
                key1: "autoISFhourlyChange",
                defaultVal: 1.0,
                dict1: freeapsSettings,
                dict2: preferences
            )
            algorithmSettings["postMealISFweight"] = self.extractDouble(
                key1: "postMealISFweight",
                key2: "pp_ISF_weight",
                defaultVal: 0.05,
                dict1: freeapsSettings,
                dict2: preferences
            )
            algorithmSettings["autoisf_max"] = self.extractDouble(
                key1: "autoISFmax",
                key2: "autoisf_max",
                defaultVal: 1.2,
                dict1: freeapsSettings,
                dict2: preferences
            )
            algorithmSettings["autoisf_min"] = self.extractDouble(
                key1: "autoISFmin",
                key2: "autoisf_min",
                defaultVal: 0.8,
                dict1: freeapsSettings,
                dict2: preferences
            )
            algorithmSettings["dura_ISF_weight"] = self.extractDouble(
                key1: "dura_ISF_weight",
                defaultVal: 1.8,
                dict1: freeapsSettings,
                dict2: preferences
            )
            algorithmSettings["iob_threshold_percent"] = self.extractDouble(
                key1: "iob_threshold_percent",
                defaultVal: 50.0,
                dict1: freeapsSettings,
                dict2: preferences
            )

            // 7. Algorithmus-Logik: Welches System ist aktiv?
            let useNewFormula = freeapsSettings["useNewFormula"] as? Bool ?? false
            let isAutoISFEnabled = (preferences["autoisf"] as? Bool) == true ||
                (preferences["autoisf"] as? Int) == 1 ||
                (freeapsSettings["autoisf"] as? Bool) == true

            if useNewFormula {
                activeAlgorithm = "dynisf"
                algorithmSettings["adjustment_factor"] = freeapsSettings["adjustmentFactor"] ?? 1.0
                algorithmSettings["use_smb"] = freeapsSettings["allowSMB"] ?? false
            } else if isAutoISFEnabled {
                activeAlgorithm = "autoisf"
            }

            payload["active_algorithm"] = activeAlgorithm
            payload["algorithm_settings"] = algorithmSettings

            // 8. Daten an den Netcup Server senden
            self.sendData(url: url, apiKey: apiKey, payload: payload)
        }
    }

    // 🟢 HILFSFUNKTION: Sucht nach "ISF: 29 → 33" und gibt die 33.0 zurück
    private func extractValueAfterArrow(from text: String, forKeyword keyword: String) -> Double? {
        // Sucht den Start des Keywords (z.B. "ISF:")
        guard let keywordRange = text.range(of: keyword) else { return nil }

        // Schneidet den Text ab dem Keyword ab (z.B. " 29 → 33, CR: 15...")
        let textAfterKeyword = text[keywordRange.upperBound...]

        // Findet das nächste Komma, da iAPS die Werte im Reason-Feld mit Kommata trennt
        let relevantPart: String
        if let commaRange = textAfterKeyword.range(of: ",") {
            relevantPart = String(textAfterKeyword[..<commaRange.lowerBound])
        } else {
            // Falls es der letzte Wert im String ist und kein Komma mehr kommt
            relevantPart = String(textAfterKeyword)
        }

        // iAPS nutzt oft verschiedene Pfeil-Symbole (→ oder ->), wir prüfen auf beides
        let arrowSymbols = ["→", "->"]
        for arrow in arrowSymbols {
            if let arrowRange = relevantPart.range(of: arrow) {
                // Schneidet den Text ab dem Pfeil ab und entfernt Leerzeichen
                let valueString = relevantPart[arrowRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                return Double(valueString)
            }
        }

        return nil
    }

    private func extractDouble(
        key1: String,
        key2: String? = nil,
        defaultVal: Double,
        dict1: [String: Any],
        dict2: [String: Any]
    ) -> Double {
        if let v = (dict1[key1] as? NSNumber)?.doubleValue { return v }
        if let v = (dict2[key1] as? NSNumber)?.doubleValue { return v }
        if let k2 = key2 {
            if let v = (dict1[k2] as? NSNumber)?.doubleValue { return v }
            if let v = (dict2[k2] as? NSNumber)?.doubleValue { return v }
        }
        return defaultVal
    }

    private func parseRawJSON(_ jsonString: String) -> [String: Any] {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else {
            return [:]
        }
        return dict
    }

    private func sendData(url: URL, apiKey: String, payload: [String: Any]) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            URLSession.shared.dataTask(with: request) { _, response, error in
                if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                    print("✅ iAPS-Einstellungen erfolgreich an KI-Server gesendet!")
                } else if let error = error {
                    print("❌ Fehler beim Upload: \(error.localizedDescription)")
                }
            }.resume()
        } catch {
            print("❌ Fehler beim Serialisieren der Upload-Daten.")
        }
    }
}
