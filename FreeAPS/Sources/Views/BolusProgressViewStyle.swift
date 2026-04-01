import SwiftUI

public struct BolusProgressViewStyle: ProgressViewStyle {
    @Environment(\.colorScheme) var colorScheme

    public func makeBody(configuration: LinearProgressViewStyle.Configuration) -> some View {
        let progress = CGFloat(configuration.fractionCompleted ?? 0)

        ZStack {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 1. Der gläserne Hintergrund (Track)
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )

                    // 2. Die fließende "Insulin"-Flüssigkeit
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.insulin.opacity(0.7), Color.insulin],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geometry.size.width * progress, 0))
                        // 🟢 NEU: Das Insulin "leuchtet" auf dem Glas
                        .shadow(color: Color.insulin.opacity(0.6), radius: 6, x: 0, y: 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
                }
            }
        }
        .frame(width: 250, height: 14) // Elegantere, flachere Höhe
    }
}
