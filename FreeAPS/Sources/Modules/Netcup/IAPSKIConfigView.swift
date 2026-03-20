import SwiftUI
import Swinject // WICHTIG FÜR iAPS!

struct IAPSKIConfigView: View {
    let resolver: Resolver // NEU: Wir nehmen den Resolver entgegen

    @AppStorage("iaps_ki_server_url") var serverURL: String = ""
    @State private var apiKey: String = ""
    @State private var isSaved: Bool = false
    @State private var isUploading: Bool = false

    var body: some View {
        Form {
            Section(
                header: Text("KI Server-Verbindung"),
                footer: Text("Die Basis-URL deines Netcup-Servers für das iAPS Machine-Learning (z.B. https://dein-server.de).")
            ) {
                TextField("Server URL", text: $serverURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            Section(
                header: Text("Authentifizierung"),
                footer: Text("Der Token wird sicher im verschlüsselten iOS-Keychain abgelegt.")
            ) {
                SecureField("API Token", text: $apiKey)
            }

            Section {
                Button(action: saveSettings) {
                    HStack {
                        Text("Zugangsdaten speichern")
                        Spacer()
                        if isSaved {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .transition(.scale)
                        }
                    }
                }
            }

            Section(
                header: Text("Manueller Sync"),
                footer: Text(
                    "Liest das aktuelle Profil (inkl. AutoISF/DynISF Status) aus der iAPS-Memory und sendet es sofort an den Server."
                )
            ) {
                Button(action: triggerManualUpload) {
                    HStack {
                        Text("Einstellungen jetzt hochladen")
                        Spacer()
                        if isUploading { ProgressView() }
                    }
                }
                .disabled(serverURL.isEmpty || apiKey.isEmpty || isUploading)
            }
        }
        .navigationTitle("KI & Netcup (Modul)")
        .onAppear {
            if let data = KeychainHelper.shared.read(service: "iaps-ki-api", account: "iAPS"),
               let savedKey = String(data: data, encoding: .utf8)
            {
                self.apiKey = savedKey
            }
        }
    }

    private func saveSettings() {
        if let data = apiKey.data(using: .utf8) {
            KeychainHelper.shared.save(data, service: "iaps-ki-api", account: "iAPS")
            withAnimation { isSaved = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { isSaved = false }
            }
        }
    }

    private func triggerManualUpload() {
        isUploading = true
        // NEU: Wir reichen den Resolver an den Manager durch
        IAPSKIServerManager.shared.uploadCurrentSettings(resolver: resolver)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isUploading = false
        }
    }
}
