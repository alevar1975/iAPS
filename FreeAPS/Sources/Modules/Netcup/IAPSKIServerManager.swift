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
            let autoisfRaw = storage.retrieveRaw(OpenAPS.Settings.autoisf) ?? "{}"
            let settingsRaw = storage.retrieveRaw(OpenAPS.Settings.settings) ?? "{}"

            let enactedRaw = storage.retrieveRaw(OpenAPS.Enact.enacted) ?? "{}"
            let suggestedRaw = storage.retrieveRaw(OpenAPS.Enact.suggested) ?? "{}"

            let profile = self.parseRawJSON(profileRaw)
            let preferences = self.parseRawJSON(prefRaw)
            let freeapsSettings = self.parseRawJSON(freeapsRaw)
            let autoisfData = self.parseRawJSON(autoisfRaw)
            let pumpSettings = self.parseRawJSON(settingsRaw)

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

            // 5. WERTE DIREKT AUS DEM "REASON" FELD EXTRAHIEREN (Regex-Präzision)
            var dynamicISF = staticProfileISF
            var dynamicBasal = staticBasal

            if let reasonText = loopData["reason"] as? String {
                if let parsedISF = self.extractValueFromReason(from: reasonText, forKeyword: "ISF:") {
                    dynamicISF = parsedISF
                }

                if let parsedBasal = self.extractValueFromReason(from: reasonText, forKeyword: "Basal:") {
                    dynamicBasal = parsedBasal
                }
            }

            var payload: [String: Any] = [
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "openaps": [
                    "isf": dynamicISF,
                    "basal": dynamicBasal,
                    "profile_isf": staticProfileISF,
                    "ic": currentIC,
                    "maxIOB": currentMaxIOB
                ]
            ]

            var activeAlgorithm = "openaps_only"
            var algorithmSettings: [String: Any] = [:]

            let dictsToSearch = [freeapsSettings, preferences, autoisfData, profile, pumpSettings]

            // 6. Mappen der Settings
            algorithmSettings["bgAccelISFweight"] = self.extractDouble(
                keys: ["bgAccelISFweight", "bgAccel_ISF_weight"],
                defaultVal: 0.17,
                dicts: dictsToSearch
            )
            algorithmSettings["bgBrakeISFweight"] = self.extractDouble(
                keys: ["bgBrakeISFweight", "bgBrake_ISF_weight"],
                defaultVal: 0.23,
                dicts: dictsToSearch
            )
            algorithmSettings["higherISFrangeWeight"] = self.extractDouble(
                keys: ["higherISFrangeWeight", "higher_ISFrange_weight"],
                defaultVal: 2.0,
                dicts: dictsToSearch
            )
            algorithmSettings["lowerISFrangeWeight"] = self.extractDouble(
                keys: ["lowerISFrangeWeight", "lower_ISFrange_weight"],
                defaultVal: 3.0,
                dicts: dictsToSearch
            )
            algorithmSettings["postMealISFweight"] = self.extractDouble(
                keys: ["postMealISFweight", "pp_ISF_weight"],
                defaultVal: 0.05,
                dicts: dictsToSearch
            )
            algorithmSettings["autoisf_max"] = self.extractDouble(
                keys: ["autoISFmax", "autoisf_max"],
                defaultVal: 1.2,
                dicts: dictsToSearch
            )
            algorithmSettings["autoisf_min"] = self.extractDouble(
                keys: ["autoISFmin", "autoisf_min"],
                defaultVal: 0.8,
                dicts: dictsToSearch
            )

            // 🟢 HIER IST DIE LÖSUNG FÜR DAS RÄTSEL!
            // Wir lesen autoISFhourlyChange aus (was in der iAPS UI "Dauer (dura)" heißt)
            let duraValue = self.extractDouble(
                keys: ["autoISFhourlyChange"],
                defaultVal: 1.0,
                dicts: dictsToSearch
            )
            // Und übergeben es an die KI einmal unter dem Original-Namen und einmal als dura_ISF_weight
            algorithmSettings["autoISFhourlyChange"] = duraValue
            algorithmSettings["dura_ISF_weight"] = duraValue

            algorithmSettings["iob_threshold_percent"] = self.extractDouble(
                keys: ["iobThresholdPercent", "iob_threshold_percent"],
                defaultVal: 50.0,
                dicts: dictsToSearch
            )

            // 7. Algorithmus-Logik
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

    // 🟢 HILFSFUNKTION 1: Extraktion mit Regex
    private func extractValueFromReason(from text: String, forKeyword keyword: String) -> Double? {
        guard let keywordRange = text.range(of: keyword) else { return nil }
        let textAfterKeyword = text[keywordRange.upperBound...]

        let relevantPart: String
        if let commaRange = textAfterKeyword.range(of: ",") {
            relevantPart = String(textAfterKeyword[..<commaRange.lowerBound])
        } else {
            relevantPart = String(textAfterKeyword)
        }

        var targetString = relevantPart
        let arrowSymbols = ["→", "->"]
        for arrow in arrowSymbols {
            if let arrowRange = relevantPart.range(of: arrow) {
                targetString = String(relevantPart[arrowRange.upperBound...])
                break
            }
        }

        let numberRegex = "[0-9]+([.][0-9]+)?"
        if let range = targetString.range(of: numberRegex, options: .regularExpression) {
            return Double(targetString[range])
        }

        return nil
    }

    // 🟢 HILFSFUNKTION 2: Der rekursive Extractor
    private func extractDoubleRecursive(keys: [String], dict: [String: Any]) -> Double? {
        for (dictKey, dictVal) in dict {
            let normalizedDictKey = dictKey.lowercased().replacingOccurrences(of: "_", with: "")
            for key in keys {
                let normalizedKey = key.lowercased().replacingOccurrences(of: "_", with: "")
                if normalizedDictKey == normalizedKey {
                    if let num = dictVal as? NSNumber { return num.doubleValue }
                    if let str = dictVal as? String, let num = Double(str) { return num }
                }
            }

            if let subDict = dictVal as? [String: Any] {
                if let found = extractDoubleRecursive(keys: keys, dict: subDict) {
                    return found
                }
            }
        }
        return nil
    }

    private func extractDouble(
        keys: [String],
        defaultVal: Double,
        dicts: [[String: Any]]
    ) -> Double {
        for dict in dicts {
            if let found = extractDoubleRecursive(keys: keys, dict: dict) {
                return found
            }
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
