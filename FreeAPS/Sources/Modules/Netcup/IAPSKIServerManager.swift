
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

            let profile = self.parseRawJSON(profileRaw)
            let preferences = self.parseRawJSON(prefRaw)
            let freeapsSettings = self.parseRawJSON(freeapsRaw)

            // 4. OpenAPS Basiswerte extrahieren
            let currentISF = profile["sens"] as? Double ?? profile["isf"] as? Double ?? 0.0
            let currentIC = profile["carb_ratio"] as? Double ?? profile["carbratio"] as? Double ?? 0.0
            let currentBasal = profile["current_basal"] as? Double ?? profile["basal"] as? Double ?? 0.0
            let currentMaxIOB = profile["max_iob"] as? Double ?? profile["maxIOB"] as? Double ?? 0.0

            var payload: [String: Any] = [
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "openaps": [
                    "isf": currentISF,
                    "ic": currentIC,
                    "basal": currentBasal,
                    "maxIOB": currentMaxIOB
                ]
            ]

            var activeAlgorithm = "openaps_only"
            var algorithmSettings: [String: Any] = [:]

            // 5. Mappen der AutoISF Werte für das Python-Skript
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
                defaultVal: 2.0,
                dict1: freeapsSettings,
                dict2: preferences
            )
            algorithmSettings["lowerISFrangeWeight"] = self.extractDouble(
                key1: "lowerISFrangeWeight",
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

            // 6. Algorithmus-Logik: Welches System ist aktiv?
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
                algorithmSettings["iob_threshold_percent"] = preferences["iob_threshold_percent"] ?? 100
            }

            payload["active_algorithm"] = activeAlgorithm
            payload["algorithm_settings"] = algorithmSettings

            // 7. Daten an den Netcup Server senden
            self.sendData(url: url, apiKey: apiKey, payload: payload)
        }
    }

    // 🟢 Helfer-Funktion sicher auf Klassen-Ebene ausgelagert
    private func extractDouble(
        key1: String,
        key2: String? = nil,
        defaultVal: Double,
        dict1: [String: Any],
        dict2: [String: Any]
    ) -> Double {
        if let v = dict1[key1] as? Double { return v }
        if let v = dict2[key1] as? Double { return v }
        if let k2 = key2 {
            if let v = dict1[k2] as? Double { return v }
            if let v = dict2[k2] as? Double { return v }
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
