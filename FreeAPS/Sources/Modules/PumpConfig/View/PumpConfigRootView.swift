import SwiftUI
import Swinject

struct SmoothiOSButtonStyle: ButtonStyle {
    var backgroundColor: Color

    func makeBody(configuration: ButtonStyle.Configuration) -> some View {
        configuration.label
            .padding()
            .foregroundColor(Color.white)
            .background(backgroundColor)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(Animation.easeOut(duration: 0.15), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

extension PumpConfig {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state: StateModel

        init(resolver: Resolver) {
            self.resolver = resolver
            _state = StateObject(wrappedValue: StateModel(resolver: resolver))
        }

        var body: some View {
            NavigationView {
                Form {
                    if let pumpManager = state.deviceManager.pumpManager, pumpManager.isOnboarded {
                        Section(header: Text("Model")) {
                            Button {
                                state.setupPump(pumpManager.pluginIdentifier)
                            } label: {
                                HStack {
                                    Image(uiImage: pumpManager.smallImage ?? UIImage())
                                        .resizable()
                                        .scaledToFit()
                                        .padding()
                                        .frame(maxWidth: 100)
                                    Text(pumpManager.localizedTitle)
                                }
                            }
                        }

                        Section {
                            if let status = pumpManager.pumpStatusHighlight?.localizedMessage {
                                HStack {
                                    Text(status.replacingOccurrences(of: "\n", with: " "))
                                }
                            }
                            if state.pumpManagerStatus?.deliveryIsUncertain ?? false {
                                HStack {
                                    Text("Pump delivery uncertain").foregroundColor(.red)
                                }
                            }
                            if state.alertNotAck {
                                Spacer()
                                Button("Acknowledge all alerts") { state.ack() }
                            }
                        }

                        if pumpManager.pluginIdentifier == "Dana" {
                            Section(
                                header: Text("Site, Reservoir & Battery"),
                                footer: Text(
                                    "Der alte Eintrag wird automatisch gelöscht, bevor das neue Datum sicher mit Nightscout synchronisiert wird."
                                )
                            ) {
                                DatePicker(
                                    "Geändert am",
                                    selection: $state.changedAt,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .padding(.vertical, 4)

                                // Site Change Button
                                Button(action: {
                                    state.confirmation = .siteChange
                                }) {
                                    HStack {
                                        Image(systemName: "drop.fill")
                                            .font(.title3)
                                        Text("Log Site Change")
                                            .fontWeight(.semibold)
                                            .font(.body)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(SmoothiOSButtonStyle(backgroundColor: .blue))
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear)

                                // Reservoir Change Button
                                Button(action: {
                                    state.confirmation = .reservoirChange
                                }) {
                                    HStack {
                                        Image(systemName: "syringe.fill")
                                            .font(.title3)
                                        Text("Log Reservoir Change")
                                            .fontWeight(.semibold)
                                            .font(.body)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(SmoothiOSButtonStyle(backgroundColor: .orange))
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear)

                                // Battery Change Button
                                Button(action: {
                                    state.confirmation = .batteryChange
                                }) {
                                    HStack {
                                        Image(systemName: "battery.100")
                                            .font(.title3)
                                        Text("Log Battery Change")
                                            .fontWeight(.semibold)
                                            .font(.body)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(SmoothiOSButtonStyle(backgroundColor: .green))
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                                .listRowBackground(Color.clear)
                            }
                        }

                    } else {
                        Section {
                            ForEach(state.deviceManager.availablePumpManagers, id: \.identifier) { pump in
                                VStack(alignment: .leading) {
                                    Button("Add " + pump.localizedTitle) {
                                        state.setupPump(pump.identifier)
                                    }
                                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Pump config")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $state.pumpSetupPresented) {
                    if let pumpIdentifier = state.pumpIdentifierToSetUp {
                        if let pumpManager = state.deviceManager.pumpManager, pumpManager.isOnboarded {
                            PumpSettingsView(
                                pumpManager: pumpManager,
                                deviceManager: state.deviceManager,
                                completionDelegate: state
                            )
                        } else {
                            PumpSetupView(
                                pumpIdentifier: pumpIdentifier,
                                pumpInitialSettings: state.initialSettings,
                                deviceManager: state.deviceManager,
                                completionDelegate: state
                            )
                        }
                    }
                }
                .alert(item: $state.confirmation) { confirmationType in
                    switch confirmationType {
                    case .siteChange:
                        return Alert(
                            title: Text("Log Site Change?"),
                            message: Text(
                                "Möchtest du den Katheterwechsel auf\n\(state.formattedChangedAt) setzen?\n\nDer alte Eintrag wird automatisch aus Nightscout gelöscht."
                            ),
                            primaryButton: .default(Text("Speichern"), action: { state.logSiteChange() }),
                            secondaryButton: .cancel(Text("Abbrechen"))
                        )
                    case .reservoirChange:
                        return Alert(
                            title: Text("Log Reservoir Change?"),
                            message: Text(
                                "Möchtest du den Reservoirwechsel auf\n\(state.formattedChangedAt) setzen?\n\nDer alte Eintrag wird automatisch aus Nightscout gelöscht."
                            ),
                            primaryButton: .default(Text("Speichern"), action: { state.logReservoirChange() }),
                            secondaryButton: .cancel(Text("Abbrechen"))
                        )
                    case .batteryChange:
                        return Alert(
                            title: Text("Log Battery Change?"),
                            message: Text(
                                "Möchtest du den Batteriewechsel auf\n\(state.formattedChangedAt) setzen?\n\nDer alte Eintrag wird automatisch aus Nightscout gelöscht."
                            ),
                            primaryButton: .default(Text("Speichern"), action: { state.logBatteryChange() }),
                            secondaryButton: .cancel(Text("Abbrechen"))
                        )
                    }
                }
            }
        }
    }
}
