import SwiftUI
import Swinject

extension ManualTempBasal {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state: StateModel

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }

        init(resolver: Resolver) {
            self.resolver = resolver
            _state = StateObject(wrappedValue: StateModel(resolver: resolver))
        }

        var body: some View {
            Form {
                Section {
                    HStack {
                        Text("Amount")
                        Spacer()
                        DecimalTextField("0", value: $state.rate, formatter: formatter, autofocus: true, liveEditing: true)
                        Text("U/hr").foregroundColor(.secondary)
                    }
                    Picker(selection: $state.durationIndex, label: Text("Duration")) {
                        ForEach(0 ..< state.durationValues.count, id: \.self) { index in
                            Text(
                                String(
                                    format: "%.0f h %02.0f min",
                                    state.durationValues[index] / 60 - 0.1,
                                    state.durationValues[index].truncatingRemainder(dividingBy: 60)
                                )
                            ).tag(index)
                        }
                    }
                }

                // 🟢 NEU: Prominente, große Action-Buttons mit Haptik
                Section {
                    VStack(spacing: 12) {
                        Button {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            state.enact()
                        } label: {
                            Text("Enact")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .buttonStyle(BorderlessButtonStyle())

                        Button {
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            state.cancel()
                        } label: {
                            Text("Cancel Temp Basal")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 10)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .navigationTitle("Manual Temp Basal")
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(trailing: Button("Close", action: state.hideModal))
        }
    }
}
