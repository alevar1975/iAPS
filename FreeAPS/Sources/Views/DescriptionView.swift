import SwiftUI

struct DescriptionView<T: View>: ViewModifier {
    let description: T
    let isPresented: Bool
    let alignment: Alignment

    init(isPresented: Bool, alignment: Alignment, @ViewBuilder content: () -> T) {
        self.isPresented = isPresented
        self.alignment = alignment
        description = content()
    }

    func body(content: Content) -> some View {
        content
            .overlay(popupContent())
    }

    @ViewBuilder private func popupContent() -> some View {
        GeometryReader { geometry in
            if isPresented {
                description
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: alignment)
                    // 🟢 NEU: Weiches Einblenden wie beim Apple "Dynamic Island"
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPresented)
            }
        }
    }
}

extension View {
    func description<T: View>(
        isPresented: Bool,
        alignment: Alignment = .center,
        @ViewBuilder content: () -> T
    ) -> some View {
        modifier(DescriptionView(isPresented: isPresented, alignment: alignment, content: content))
    }

    func formatDescription() -> some View {
        modifier(DescriptionLayout())
    }
}

struct DescriptionLayout: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(.all, 20)
            .foregroundStyle(Color.primary) // Passt sich Hell/Dunkel an
            // 🟢 NEU: Apple Glassmorphism
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 10)
    }
}
