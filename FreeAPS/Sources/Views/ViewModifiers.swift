import Combine
import SwiftUI

struct RoundedBackground: ViewModifier {
    private let color: Color

    init(color: Color = Color("CapsuleColor")) {
        self.color = color
    }

    func body(content: Content) -> some View {
        content
            .padding()
            // 🟢 NEU: Spatial UI Glassmorphism statt flacher Farbe
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .clear, .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct BoolTag: ViewModifier {
    let bool: Bool
    @Environment(\.colorScheme) var colorScheme
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 4).padding(.horizontal, 8)
            // 🟢 NEU: Organische Gradienten für Status-Tags
            .background(
                LinearGradient(
                    colors: bool
                        ? [Color.green.opacity(0.8), Color.green.opacity(0.6)]
                        : [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule()) // Capsule sieht viel moderner aus als RoundedRectangle(6)
            .shadow(color: (bool ? Color.green : Color.red).opacity(0.3), radius: 3, x: 0, y: 2)
            .padding(.vertical, 3).padding(.trailing, 3)
    }
}

struct CompactSectionSpacing: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listSectionSpacing(.compact)
    }
}

struct ActiveOverride: ViewModifier {
    var override: Bool = false
    func body(content: Content) -> some View {
        content
            .overlay {
                override ?
                    Image(systemName: "person.2.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.purple.opacity(0.5), Color.green.opacity(0.5)) // Etwas kräftiger
                    .font(.system(size: 11, weight: .bold))
                    .offset(x: 20)
                    .frame(maxHeight: .infinity, alignment: .leading)
                    : nil
            }
    }
}

struct CarveOrDrop: ViewModifier {
    let carve: Bool
    func body(content: Content) -> some View {
        if carve {
            return content
                .foregroundStyle(.shadow(.inner(color: .black, radius: 0.01, y: 1)))
        } else {
            return content
                .foregroundStyle(.shadow(.drop(color: .black, radius: 0.02, y: 1)))
        }
    }
}

struct InfoPanelBackground: View {
    let colorScheme: ColorScheme
    var body: some View {
        RoundedRectangle(cornerRadius: 8) // Harte Kanten vermieden
            .fill(colorScheme == .light ? .white.opacity(0.8) : .black.opacity(0.6))
            .background(.ultraThinMaterial)
            .frame(height: 24)
    }
}

struct AddShadow: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    func body(content: Content) -> some View {
        content
            // 🟢 NEU: Ein zweischichtiger, moderner Schatten (Weich + Tief)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 8, x: 0, y: 4)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 2, x: 0, y: 1)
    }
}

struct RaisedRectangle: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        Rectangle().fill(colorScheme == .dark ? .black : .white)
            .frame(height: 1)
            .addShadows()
    }
}

struct TestTube: View {
    let opacity: CGFloat
    let amount: CGFloat
    let colourOfSubstance: Color
    let materialOpacity: CGFloat
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        UnevenRoundedRectangle.testTube
            .fill(
                LinearGradient(
                    gradient: Gradient(stops: [
                        Gradient.Stop(color: .white.opacity(opacity), location: amount),
                        Gradient.Stop(color: colourOfSubstance, location: amount)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                FrostedGlass(opacity: materialOpacity)
            }
            .overlay(
                // 🟢 NEU: Ein feiner Glas-Highlight-Strich am linken Rand
                UnevenRoundedRectangle.testTube
                    .stroke(
                        LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.2), radius: 4, x: 0, y: 2)
    }
}

struct FrostedGlass: View {
    let opacity: CGFloat
    var body: some View {
        UnevenRoundedRectangle.testTube
            .fill(.ultraThinMaterial.opacity(max(opacity, 0.1))) // Sicherstellen, dass Material greift
    }
}

struct ColouredRoundedBackground: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                colorScheme == .dark ? IAPSconfig.previewBackgroundDark :
                    IAPSconfig.previewBackgroundLight
            )
            .background(.ultraThinMaterial)
    }
}

struct ColouredBackground: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        Rectangle()
            .fill(
                colorScheme == .dark ? IAPSconfig.chartBackgroundDark :
                    IAPSconfig.chartBackgroundLight
            )
    }
}

struct LoopEllipse: View {
    @Environment(\.colorScheme) var colorScheme
    let stroke: Color
    var body: some View {
        Capsule() // Capsule ist runder als RoundedRectangle(15)
            .stroke(stroke.opacity(0.8), lineWidth: 1.5)
            .background(
                Capsule()
                    .fill(colorScheme == .light ? .white : .black)
                    .shadow(color: stroke.opacity(0.3), radius: 4, x: 0, y: 0) // Sanfter Glow
            )
    }
}

struct Sage: View {
    @Environment(\.colorScheme) var colorScheme
    let amount: Double
    let expiration: Double
    let lineColour: Color
    let sensordays: TimeInterval
    var body: some View {
        let fill = max(expiration / amount, 0.15)
        let colour: Color = (expiration < 0.5 * 8.64E4) ? .red
            .opacity(0.9) : (expiration < 2 * 8.64E4) ? .orange.opacity(0.8) : colorScheme == .light ? Color.white : Color
            .black
            .opacity(0.9)
        let scheme = colorScheme == .light ? Color(.systemGray5) : Color(.systemGray2)

        Circle()
            .stroke(scheme, lineWidth: 5)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                Gradient.Stop(color: colour, location: fill),
                                Gradient.Stop(color: colorScheme == .light ? Color.white : Color.black, location: fill)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
    }
}

struct TimeEllipse: View {
    let characters: Int
    var body: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(Capsule().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            .frame(width: CGFloat(characters * 7 + 10), height: 25)
    }
}

struct HeaderBackground: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial) // Headers sehen mit Glas immer besser aus
            .background(
                colorScheme == .light ? IAPSconfig.headerBackgroundLight.opacity(0.5) : IAPSconfig.headerBackgroundDark
                    .opacity(0.5)
            )
    }
}

struct ClockOffset: View {
    let mdtPump: Bool
    var body: some View {
        ZStack {
            Image(systemName: "clock.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 20)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color(.warning))
                .shadow(color: Color(.warning).opacity(0.4), radius: 3, x: 0, y: 0) // Glow
                .offset(x: !mdtPump ? 10 : 12, y: !mdtPump ? -20 : -22)
        }
    }
}

struct NonStandardInsulin: View {
    let concentration: Double
    let pump: HeaderPump

    private var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }

    var body: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(colors: [.red, .red.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 35, height: 16)
                .shadow(color: .red.opacity(0.5), radius: 3, x: 0, y: 2)
                .overlay {
                    Text("U" + (formatter.string(from: concentration * 100 as NSNumber) ?? ""))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
        }
        .offset(x: pump == .pod ? -15 : pump == .medtrum ? 25 : -5, y: pump == .pod ? -24 : pump == .medtrum ? -20 : 7)
    }
}

struct TooOldValue: View {
    var body: some View {
        ZStack {
            Image(systemName: "circle.fill")
                .resizable()
                .frame(maxHeight: 20)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color(.warning).opacity(0.5))
                .offset(x: 5, y: -13)
                .overlay {
                    Text("Old").font(.caption.bold()).offset(x: 5, y: -13)
                }
        }
    }
}

struct ChartBackground: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(colorScheme == .light ? .gray.opacity(0.05) : .black).brightness(colorScheme == .dark ? 0.05 : 0)
    }
}

private let navigationCache = LRUCache<Screen.ID, AnyView>(capacity: 10)

struct NavigationLazyView: View {
    let build: () -> AnyView
    let screen: Screen

    init(_ build: @autoclosure @escaping () -> AnyView, screen: Screen) {
        self.build = build
        self.screen = screen
    }

    var body: AnyView {
        if navigationCache[screen.id] == nil {
            navigationCache[screen.id] = build()
        }
        return navigationCache[screen.id]!
            .onDisappear {
                navigationCache[screen.id] = nil
            }.asAny()
    }
}

struct Link<T>: ViewModifier where T: View {
    private let destination: () -> T
    let screen: Screen

    init(destination: @autoclosure @escaping () -> T, screen: Screen) {
        self.destination = destination
        self.screen = screen
    }

    func body(content: Content) -> some View {
        NavigationLink(destination: NavigationLazyView(destination().asAny(), screen: screen)) {
            content
        }
    }
}

struct ClearButton: ViewModifier {
    @Binding var text: String
    func body(content: Content) -> some View {
        HStack {
            content
            if !text.isEmpty {
                Button { self.text = "" }
                label: {
                    Image(systemName: "xmark.circle.fill") // Schöneres Icon
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
        }
    }
}

extension View {
    func roundedBackground() -> some View { modifier(RoundedBackground()) }
    func addShadows() -> some View { modifier(AddShadow()) }
    func carvingOrRelief(carve: Bool) -> some View { modifier(CarveOrDrop(carve: carve)) }
    func boolTag(_ bool: Bool) -> some View { modifier(BoolTag(bool: bool)) }
    func addBackground() -> some View { ColouredRoundedBackground() }
    func addColouredBackground() -> some View { ColouredBackground() }
    func addHeaderBackground() -> some View { HeaderBackground() }
    func chartBackground() -> some View { modifier(ChartBackground()) }
    func frostedGlassLayer(_ opacity: CGFloat) -> some View { FrostedGlass(opacity: opacity) }
    func navigationLink<V: BaseView>(
        to screen: Screen,
        from view: V
    ) -> some View { modifier(Link(destination: view.state.view(for: screen), screen: screen)) }
    func modal<V: BaseView>(for screen: Screen?, from view: V) -> some View { onTapGesture { view.state.showModal(for: screen) } }
    func compactSectionSpacing() -> some View { modifier(CompactSectionSpacing()) }
    func activeOverride(_ override: Bool) -> some View { modifier(ActiveOverride(override: override)) }
    func asAny() -> AnyView { .init(self) }
}

extension UnevenRoundedRectangle {
    static let testTube =
        UnevenRoundedRectangle(
            topLeadingRadius: 1.5,
            bottomLeadingRadius: 50,
            bottomTrailingRadius: 50,
            topTrailingRadius: 1.5
        )
}

extension UIImage {
    func fillImageUpToPortion(color: Color, portion: Double) -> Image {
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            draw(in: rect)
            let height: CGFloat = 1 - portion
            let rectToFill = CGRect(x: 0, y: size.height * portion, width: size.width, height: size.height * height)
            UIColor(color).setFill()
            context.fill(rectToFill, blendMode: .sourceIn)
        }
        return Image(uiImage: image)
    }
}

enum HeaderPump {
    case medtrum
    case pod
    case dana
    case medtronic
    case other
}
