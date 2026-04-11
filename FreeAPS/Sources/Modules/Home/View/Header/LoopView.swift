import SwiftDate
import SwiftUI
import UIKit

struct LoopView: View {
    private enum Config {
        static let lag: TimeInterval = 30
    }

    @Binding var suggestion: Suggestion?
    @Binding var enactedSuggestion: Suggestion?
    @Binding var closedLoop: Bool
    @Binding var timerDate: Date
    @Binding var isLooping: Bool
    @Binding var lastLoopDate: Date
    @Binding var manualTempBasal: Bool

    // 🟢 NEU: States für unser visuelles Feedback
    @State private var feedbackState: FeedbackState = .none

    enum FeedbackState {
        case none
        case success
        case failure
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.sizeCategory) private var fontSize

    var body: some View {
        VStack(spacing: 6) {
            let multiplyForLargeFonts = fontSize > .extraLarge ? 1.15 : 1.0

            // iAPS Logo modernisiert
            HStack(spacing: 0) {
                Text("i").font(.system(size: 11, weight: .bold, design: .rounded))
                Text("APS").font(.system(size: 13, weight: .black, design: .rounded))
            }
            .foregroundStyle(
                LinearGradient(colors: [.primary.opacity(0.9), .primary.opacity(0.5)], startPoint: .top, endPoint: .bottom)
            )

            // 🟢 NEU: iPhone 17 "Dynamic Island" Pill-Design
            ZStack {
                // Hintergrundglas
                Capsule()
                    .fill(.ultraThinMaterial)
                    // Weiches Leuchten, wenn der Loop arbeitet
                    .shadow(color: color.opacity(isLooping ? 0.6 : 0.2), radius: isLooping ? 8 : 4, x: 0, y: 2)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .clear, .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    // Dynamischer Farbrand
                    .overlay(
                        Capsule().strokeBorder(color.opacity(0.6), lineWidth: 1.5)
                    )

                // Innerer Inhalt der Pille
                HStack(spacing: 0) {
                    if feedbackState == .success {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 18, weight: .bold))
                            .transition(.scale.combined(with: .opacity))
                    } else if feedbackState == .failure {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 18, weight: .bold))
                            .transition(.scale.combined(with: .opacity))
                    } else if isLooping {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(color)
                            .font(.system(size: 15, weight: .bold))
                            .rotatingForever() // 🟢 NEU: Sanfte Endlos-Rotation
                            .transition(.opacity)
                    } else if closedLoop {
                        if minutesAgo > 999 {
                            Text("--")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        } else {
                            HStack(spacing: 1) {
                                Text("\(minutesAgo)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("m")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .offset(y: 1)
                            }
                        }
                    } else {
                        Text("Open")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: minutesAgo > 9 ? 65 * multiplyForLargeFonts : 55 * multiplyForLargeFonts, height: 32)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: feedbackState)
            .animation(.easeInOut(duration: 0.3), value: isLooping)
        }
        // 🟢 NEU: Sobald das Loopen aufhört, werten wir das Ergebnis aus!
        .onChange(of: isLooping) { looping in
            if !looping {
                evaluateLoopResult()
            }
        }
    }

    // 🟢 NEU: Prüft, ob der Loop erfolgreich war oder abgestürzt/abgebrochen ist
    private func evaluateLoopResult() {
        let delta = Date().timeIntervalSince(lastLoopDate)

        // Wenn der letzte erfolgreiche Loop vor weniger als 15 Sekunden gespeichert wurde, war es ein Erfolg!
        if delta < 15 {
            showFeedback(.success)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            // Die Zeit hat sich nicht aktualisiert -> Fehler im Loop
            showFeedback(.failure)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // 🟢 NEU: Zeigt das Icon für 2,5 Sekunden und blendet es dann wieder aus
    private func showFeedback(_ state: FeedbackState) {
        withAnimation {
            feedbackState = state
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                feedbackState = .none
            }
        }
    }

    private var minutesAgo: Int {
        let minAgo = Int((timerDate.timeIntervalSince(lastLoopDate) - Config.lag) / 60) + 1
        return minAgo
    }

    private var color: Color {
        guard actualSuggestion?.timestamp != nil else { return .loopGray }
        guard manualTempBasal == false else { return .loopManualTemp }

        let delta = timerDate.timeIntervalSince(lastLoopDate) - Config.lag

        if delta <= 8.minutes.timeInterval {
            guard actualSuggestion?.deliverAt != nil else { return .loopYellow }
            return .loopGreen
        } else if delta <= 12.minutes.timeInterval {
            return .loopYellow
        } else {
            return .loopRed
        }
    }

    private var actualSuggestion: Suggestion? {
        if closedLoop, enactedSuggestion?.recieved == true {
            return enactedSuggestion ?? suggestion
        } else {
            return suggestion
        }
    }
}

// 🟢 NEU: Moderner iOS Rotations-Modifier, der flüssiger läuft als das alte 'animateForever'
struct RotationAnimationModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .animation(Animation.linear(duration: 1.0).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    func rotatingForever() -> some View {
        modifier(RotationAnimationModifier())
    }
}
