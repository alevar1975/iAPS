import SwiftUI

struct CurrentGlucoseView: View {
    @Binding var recentGlucose: BloodGlucose?
    @Binding var delta: Int?
    @Binding var units: GlucoseUnits
    @Binding var alarm: GlucoseAlarm?
    @Binding var lowGlucose: Decimal
    @Binding var highGlucose: Decimal
    @Binding var alwaysUseColors: Bool
    @Binding var displayDelta: Bool
    @Binding var scrolling: Bool
    @Binding var displaySAGE: Bool
    @Binding var displayExpiration: Bool
    @Binding var sensordays: Double
    @Binding var timerDate: Date

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.sizeCategory) private var fontSize

    private var glucoseFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        if units == .mmolL {
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 1
            formatter.roundingMode = .halfUp
        }
        return formatter
    }

    private var manualGlucoseFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        if units == .mmolL {
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 1
            formatter.roundingMode = .ceiling
        }
        return formatter
    }

    private var decimalString: String {
        let formatter = NumberFormatter()
        return formatter.decimalSeparator
    }

    private var deltaFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if units == .mmolL {
            formatter.decimalSeparator = "."
        }
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "+ "
        formatter.negativePrefix = "- "
        return formatter
    }

    private var timaAgoFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.negativePrefix = ""
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    private var remainingTimeFormatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour]
        formatter.unitsStyle = .abbreviated
        return formatter
    }

    private var remainingTimeFormatterDays: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day]
        formatter.unitsStyle = .abbreviated
        return formatter
    }

    var body: some View {
        glucoseView
            .dynamicTypeSize(DynamicTypeSize.medium ... DynamicTypeSize.xLarge)
    }

    var glucoseView: some View {
        ZStack {
            if let recent = recentGlucose {
                // 🟢 Der integrierte Apple-Style Pod für Glukose und Trend
                VStack(spacing: 0) {
                    GlucoseValuePod(recentGlucose: recent, scrolling: scrolling)

                    if !scrolling {
                        let minutesAgo = timerDate.timeIntervalSince(recent.dateString) / 60
                        let text = timaAgoFormatter.string(for: Double(minutesAgo)) ?? ""
                        Text(
                            minutesAgo <= 1 ? NSLocalizedString("Now", comment: "") :
                                (text + " " + NSLocalizedString("min", comment: "Short form for minutes") + " ")
                        )
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .offset(x: 1, y: fontSize >= .extraLarge ? -1 : 4) // Optisch vom Kreis abgesetzt
                    }
                }

                if displayExpiration || displaySAGE {
                    sageView
                }

                if displayDelta, !scrolling, let deltaInt = delta,
                   !(units == .mmolL && abs(deltaInt) <= 1) { deltaView(deltaInt) }
            }
        }
    }

    private func deltaView(_ deltaInt: Int) -> some View {
        ZStack {
            let deltaConverted = units == .mmolL ? deltaInt.asMmolL : Decimal(deltaInt)
            let string = deltaFormatter.string(from: deltaConverted as NSNumber) ?? ""
            let offset: CGFloat = -7

            Text(string)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: string)
                .offset(x: offset, y: 10)
        }
        .dynamicTypeSize(DynamicTypeSize.medium ... DynamicTypeSize.large)
        .frame(maxHeight: .infinity, alignment: .center).offset(x: 110.5, y: -9)
    }

    private var sageView: some View {
        ZStack {
            if let date = recentGlucose?.sessionStartDate {
                let sensorAge: TimeInterval = (-1 * date.timeIntervalSinceNow)
                let expiration = sensordays - sensorAge
                let secondsOfDay = 8.64E4
                let colour = colorScheme == .light ? Color.black : Color.white
                let lineColour: Color = sensorAge >= sensordays - secondsOfDay * 1 ? Color.red
                    .opacity(0.9) : sensorAge >= sensordays - secondsOfDay * 2 ? Color
                    .orange : Color.white
                let minutesAndHours = (displayExpiration && expiration < 1 * 8.64E4) || (displaySAGE && sensorAge < 1 * 8.64E4)

                Sage(amount: sensorAge, expiration: expiration, lineColour: lineColour, sensordays: sensordays)
                    .frame(width: 36, height: 36)
                    .overlay {
                        HStack {
                            Text(
                                !minutesAndHours ?
                                    (remainingTimeFormatterDays.string(from: displayExpiration ? expiration : sensorAge) ?? "")
                                    .replacingOccurrences(of: ",", with: " ") :
                                    (remainingTimeFormatter.string(from: displayExpiration ? expiration : sensorAge) ?? "")
                                    .replacingOccurrences(of: ",", with: " ")
                            ).foregroundStyle(colour).fontWeight(colorScheme == .dark ? .semibold : .regular)
                        }
                    }
            }
        }
        .font(.footnote)
        .dynamicTypeSize(DynamicTypeSize.medium ... DynamicTypeSize.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(20)
        .offset(x: -5)
    }

    // 🟢 Basis-Winkel des Pfeils (Das Offset übernimmt jetzt AnimatedTrendRing)
    private var adjustments: (degree: Double, x: CGFloat, y: CGFloat) {
        guard let direction = recentGlucose?.direction else {
            return (90, 0, 0)
        }
        switch direction {
        case .doubleUp,
             .singleUp,
             .tripleUp:
            return (0, 0, 0) // 12 Uhr
        case .fortyFiveUp:
            return (45, 0, 0) // 1:30 Uhr
        case .flat:
            return (90, 0, 0) // 3 Uhr
        case .fortyFiveDown:
            return (135, 0, 0) // 4:30 Uhr
        case .doubleDown,
             .singleDown,
             .tripleDown:
            return (180, 0, 0) // 6 Uhr
        case .none,
             .notComputable,
             .rateOutOfRange:
            return (90, 0, 0)
        }
    }

    // 🟢 NEU: Die komplette Glukose-Kapsel samt animiertem Ring
    private func GlucoseValuePod(recentGlucose: BloodGlucose, scrolling: Bool) -> some View {
        ZStack {
            // 1. Hintergrund-Glas (Milchglas-Pod)
            ZStack {
                RoundedRectangle(cornerRadius: 100, style: .continuous)
                    .fill(colorScheme == .dark ? Color(white: 0.05).opacity(0.85) : Color.white.opacity(0.7))
                    .background(colorScheme == .dark ? Material.ultraThin : Material.thin)

                RoundedRectangle(cornerRadius: 100, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.25 : 0.8),
                                .clear,
                                .white.opacity(colorScheme == .dark ? 0.08 : 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blendMode(colorScheme == .dark ? .plusLighter : .normal)
            }
            .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
            .shadow(color: colorOfGlucose.opacity(0.4), radius: 8, x: 0, y: 4)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.1), radius: 25, x: 0, y: 12)

            // 2. Zentrierter Glukosewert
            let formatter = recentGlucose.type == GlucoseType.manual.rawValue ? manualGlucoseFormatter : glucoseFormatter
            if let string = recentGlucose.unfiltered.map({
                formatter.string(from: Double(units == .mmolL ? $0.asMmolL : $0) as NSNumber) ?? ""
            }) {
                glucoseText(string)
            }

            // 3. Der performante Apple Watch Style Kometen-Ring
            AnimatedTrendRing(
                degree: adjustments.degree,
                direction: recentGlucose.direction,
                color: alwaysUseColors ? colorOfGlucose : (alarm == nil ? .primary : .loopRed),
                scrolling: scrolling,
                dateString: recentGlucose.dateString
            )
        }
        .frame(width: !scrolling ? 140 : 80, height: !scrolling ? 140 : 80)
    }

    private func glucoseText(_ string: String) -> some View {
        ZStack {
            let decimal = string.components(separatedBy: decimalString)
            let baseColor = alwaysUseColors ? colorOfGlucose : (alarm == nil ? .primary : .loopRed)

            if decimal.count > 1 {
                HStack(spacing: 0) {
                    Text(decimal[0])
                        .font(.system(size: !scrolling ? 48 : 24, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText())
                    Text(decimalString)
                        .font(.system(size: !scrolling ? 24 : 12, weight: .heavy, design: .rounded))
                        .baselineOffset(-10)
                    Text(decimal[1])
                        .font(.system(size: !scrolling ? 30 : 16, weight: .heavy, design: .rounded))
                        .baselineOffset(!scrolling ? -8 : -4)
                        .contentTransition(.numericText())
                }
                .tracking(-1.5)
                .offset(x: 0, y: 4) // Perfekt in der Kapsel zentriert
                .foregroundColor(baseColor)
                .shadow(color: baseColor.opacity(0.4), radius: 8, x: 0, y: 4)

            } else {
                Text(string)
                    .font(.system(size: !scrolling ? 54 : 28, weight: .heavy, design: .rounded))
                    .tracking(-2)
                    .foregroundColor(baseColor)
                    .contentTransition(.numericText())
                    .shadow(color: baseColor.opacity(0.4), radius: 8, x: 0, y: 4)
                    .offset(x: 0, y: 4) // Perfekt in der Kapsel zentriert
            }
        }
        .offset(y: scrolling ? 3 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: string)
    }

    private var colorOfGlucose: Color {
        let whichGlucose = recentGlucose?.glucose ?? 0
        guard lowGlucose < highGlucose else { return .primary }

        switch whichGlucose {
        case 0 ..< Int(lowGlucose):
            return .loopRed
        case Int(lowGlucose) ..< Int(highGlucose):
            return .loopGreen
        case Int(highGlucose)...:
            return .loopYellow
        default:
            return .loopYellow
        }
    }
}

// 🟢 NEU: Hochperformanter 15s Kometenschweif & Zentripetal-Pfeil (Main-Thread Save!)
struct AnimatedTrendRing: View {
    let degree: Double
    let direction: BloodGlucose.Direction?
    let color: Color
    let scrolling: Bool
    let dateString: Date?

    // Animations-Zustände (Main-Thread entlastet durch .repeatCount)
    @State private var spinDegree: Double = 0
    @State private var flatOffset: CGFloat = 0

    var isFlat: Bool {
        direction == .flat || direction == .none || direction == .notComputable || direction == .rateOutOfRange
    }

    var isRising: Bool {
        direction == .singleUp || direction == .doubleUp || direction == .tripleUp || direction == .fortyFiveUp
    }

    var isFalling: Bool {
        direction == .singleDown || direction == .doubleDown || direction == .tripleDown || direction == .fortyFiveDown
    }

    var body: some View {
        let size: CGFloat = !scrolling ? 140 : 80
        let radius = size / 2
        let arrowSize: CGFloat = !scrolling ? 20 : 14 // Prominenter für die Schweif-Spitze

        ZStack {
            // 🟢 1. ULTIMATIVER KOMETENSCHWEIF (Raumfüllend, sprayig, glitzig, Farbabgestimmt)
            if isRising || isFalling {
                ZStack {
                    // Hauptschweif-Körper
                    Circle()
                        .trim(from: 0.0, to: 0.35) // Längerer Schweif (raumfüllender)
                        .stroke(
                            AngularGradient(
                                colors: [color.opacity(0.8), color.opacity(0)], // Verblasst sanft
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(120)
                            ),
                            style: StrokeStyle(lineWidth: !scrolling ? 8 : 5, lineCap: .round)
                        )
                        .blur(radius: 4) // Spray-Effekt (weicher Körper)

                    // Glitzer-Glow-Kern
                    Circle()
                        .trim(from: 0.0, to: 0.35)
                        .stroke(
                            AngularGradient(
                                colors: [color, color.opacity(0.1)],
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(120)
                            ),
                            style: StrokeStyle(lineWidth: !scrolling ? 4 : 2, lineCap: .round)
                        )

                    // Glitzer-Spots (für den "glitzigen, sprayigen" Look)
                    ForEach(0 ..< 12) { i in
                        Circle()
                            .fill(color)
                            .frame(width: CGFloat.random(in: 3 ... 6), height: CGFloat.random(in: 3 ... 6))
                            .offset(y: -radius + CGFloat.random(in: -3 ... 3))
                            // Dreht jeden Punkt um den Ring, aber nur im Schweif-Bereich
                            .rotationEffect(.degrees(Double(i) * 10.0))
                            .opacity(1.0 - (Double(i) * 0.08)) // Verblasst
                            .shadow(color: color, radius: 2) // Jeder Punkt glowt
                    }
                }
                .rotationEffect(.degrees(-90)) // Startpunkt auf 12 Uhr
                // Spiegelt den Schweif auf die linke Seite, wenn der Pfeil im Uhrzeigersinn (fallend) fliegt
                .scaleEffect(x: isFalling ? -1 : 1, y: 1)
            }

            // 🟢 2. ZENTRIPETAL-PFEILKOPF (zeigt in die Mitte, Spitze auf dem Ring)
            Path { path in
                path.move(to: CGPoint(x: arrowSize / 2, y: 0)) // Spitze
                path.addLine(to: CGPoint(x: arrowSize, y: arrowSize))
                path.addLine(to: CGPoint(x: arrowSize / 2, y: arrowSize * 0.65)) // Einkerbung hinten
                path.addLine(to: CGPoint(x: 0, y: arrowSize))
                path.closeSubpath()
            }
            .fill(color)
            .shadow(color: color.opacity(0.8), radius: 6, x: 0, y: 0)
            .frame(width: arrowSize, height: arrowSize)
            // 🟢 HIER: Spitze 90 Grad im Uhrzeigersinn gedreht (Pfeil zeigt radial in die Mitte)
            .rotationEffect(.degrees(isFlat ? 0 : 180))
            // Setzt den Pfeil auf den Rand. Wenn Flat, gleitet er nach außen und innen (flatOffset)
            .offset(y: -radius + flatOffset)
        }
        .frame(width: size, height: size)
        // 1. Basis-Rotation für den echten Trend-Winkel
        .rotationEffect(.degrees(degree))
        // 2. Orbit-Animation, die sich dazu addiert
        .rotationEffect(.degrees(spinDegree))

        // Trigger für die Animation, sobald ein neuer Glukosewert reinkommt
        .onChange(of: dateString) { _ in startHardwareAnimation() }
        .onAppear { startHardwareAnimation() }
    }

    func startHardwareAnimation() {
        // 1. Hard-Reset ohne Animation (Setzt Pfeil sofort zurück)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            spinDegree = 0
            // Start-Position für den Left-to-Right Effekt (Pfeil gleitet von links rein)
            flatOffset = isFlat ? 8 : 0
        }

        // 2. 🟢 Hardware-beschleunigte Animation (CoreAnimation) - Main-Thread entlastet!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if isRising {
                // Langsamer: 10 Runden à 1.5s = Exakt 15 Sekunden. Bleibt am Ende perfekt auf der Position stehen!
                withAnimation(.linear(duration: 1.5).repeatCount(10, autoreverses: false)) {
                    spinDegree = -360 // Gegen den Uhrzeigersinn
                }
            } else if isFalling {
                // Langsamer: Uhrzeigersinn
                withAnimation(.linear(duration: 1.5).repeatCount(10, autoreverses: false)) {
                    spinDegree = 360
                }
            } else if isFlat {
                // 🟢 NEU: Gleitet für 15 Sekunden von links nach rechts (15 Durchläufe à 1s)
                withAnimation(.easeInOut(duration: 1.0).repeatCount(15, autoreverses: true)) {
                    // Gleitet nach außen (rechts), dann wieder zurück nach links
                    flatOffset = -12
                }
            }
        }
    }
}
