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
                // 🟢 Der 100px Apple-Style Pod
                VStack(spacing: 0) {
                    GlucoseValuePod(recentGlucose: recent, scrolling: scrolling)

                    if !scrolling {
                        let minutesAgo = timerDate.timeIntervalSince(recent.dateString) / 60
                        let text = timaAgoFormatter.string(for: Double(minutesAgo)) ?? ""
                        Text(
                            minutesAgo <= 1 ? NSLocalizedString("Now", comment: "") :
                                (text + " " + NSLocalizedString("min", comment: "Short form for minutes") + " ")
                        )
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        // 🟢 Minimal abgesetzt, damit es nicht in den Pod ragt
                        .offset(y: 8)
                    }
                }

                if displayExpiration || displaySAGE {
                    sageView
                }

                if displayDelta, !scrolling, let deltaInt = delta, !(units == .mmolL && abs(deltaInt) <= 1) {
                    deltaView(deltaInt)
                }
            }
        }
    }

    private func deltaView(_ deltaInt: Int) -> some View {
        ZStack {
            let deltaConverted = units == .mmolL ? deltaInt.asMmolL : Decimal(deltaInt)
            let string = deltaFormatter.string(from: deltaConverted as NSNumber) ?? ""

            Text(string)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: string)
                // 🟢 Näher an den 100px Pod herangezogen
                .offset(x: 75, y: -5)
        }
        .frame(maxHeight: .infinity, alignment: .center)
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
                    .frame(width: 28, height: 28)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(20)
    }

    // 🟢 Basis-Winkel des Pfeils aus dem iAPS Backend
    // 🟢 Basis-Winkel des Pfeils aus dem iAPS Backend
    private var adjustments: (degree: Double, x: CGFloat, y: CGFloat) {
        if let direction = recentGlucose?.direction {
            switch direction {
            case .doubleUp,
                 .tripleUp: return (0, 0, 0) // 12 Uhr
            case .fortyFiveUp,
                 .singleUp: return (45, 0, 0) // 1:30 Uhr
            case .flat: return (90, 0, 0) // 3 Uhr
            case .fortyFiveDown,
                 .singleDown: return (135, 0, 0) // 4:30 Uhr
            case .doubleDown,
                 .tripleDown: return (180, 0, 0) // 6 Uhr
            case .none,
                 .notComputable,
                 .rateOutOfRange: break
            }
        }

        if let deltaInt = delta {
            if deltaInt > 10 { return (0, 0, 0) }
            else if deltaInt > 5 { return (45, 0, 0) }
            else if deltaInt < -10 { return (180, 0, 0) }
            else if deltaInt < -5 { return (135, 0, 0) }
            else { return (90, 0, 0) }
        }

        return (90, 0, 0)
    }

    private func GlucoseValuePod(recentGlucose: BloodGlucose, scrolling: Bool) -> some View {
        ZStack {
            // Glas-Hintergrund
            RoundedRectangle(cornerRadius: 100, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.05).opacity(0.85) : Color.white.opacity(0.7))
                .background(colorScheme == .dark ? Material.ultraThin : Material.thin)
                .overlay(
                    RoundedRectangle(cornerRadius: 100, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: colorOfGlucose.opacity(0.3), radius: 6, x: 0, y: 3)

            // Zentrierter Glukosewert
            let formatter = recentGlucose.type == GlucoseType.manual.rawValue ? manualGlucoseFormatter : glucoseFormatter
            if let string = recentGlucose.unfiltered
                .map({ formatter.string(from: Double(units == .mmolL ? $0.asMmolL : $0) as NSNumber) ?? "" })
            {
                glucoseText(string)
            }

            // 🟢 Getrennter Komet und stationärer Pfeil
            AnimatedTrendRing(
                degree: adjustments.degree,
                color: alwaysUseColors ? colorOfGlucose : (alarm == nil ? .primary : .loopRed),
                scrolling: scrolling,
                dateString: recentGlucose.dateString
            )
        }
        // 🟢 100px exakte Größe
        .frame(width: !scrolling ? 100 : 65, height: !scrolling ? 100 : 65)
    }

    private func glucoseText(_ string: String) -> some View {
        let decimal = string.components(separatedBy: decimalString)
        let baseColor = alwaysUseColors ? colorOfGlucose : (alarm == nil ? .primary : .loopRed)

        return Group {
            if decimal.count > 1 {
                HStack(spacing: 0) {
                    Text(decimal[0])
                        // 🟢 Angepasst für 100px Pod
                        .font(.system(size: !scrolling ? 34 : 18, weight: .heavy, design: .rounded))
                    Text(decimalString)
                        .font(.system(size: !scrolling ? 18 : 10, weight: .heavy, design: .rounded))
                        .baselineOffset(-6)
                    Text(decimal[1])
                        .font(.system(size: !scrolling ? 22 : 12, weight: .heavy, design: .rounded))
                        .baselineOffset(-4)
                }
            } else {
                Text(string)
                    // 🟢 Angepasst für 100px Pod
                    .font(.system(size: !scrolling ? 40 : 22, weight: .heavy, design: .rounded))
            }
        }
        .foregroundColor(baseColor)
        .shadow(color: baseColor.opacity(0.3), radius: 4, x: 0, y: 2)
        .contentTransition(.numericText())
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: string)
    }

    private var colorOfGlucose: Color {
        let whichGlucose = recentGlucose?.glucose ?? 0
        guard lowGlucose < highGlucose else { return .primary }

        if whichGlucose < Int(lowGlucose) { return .loopRed }
        if whichGlucose < Int(highGlucose) { return .loopGreen }
        return .loopYellow
    }
}

// 🟢 GETRENNTE ANIMATION: Unabhängiger Schweif & Atmender Pfeil
struct AnimatedTrendRing: View {
    let degree: Double
    let color: Color
    let scrolling: Bool
    let dateString: Date?

    @State private var breatheOffset: CGFloat = 0
    @State private var tailRotation: Double = 0
    @State private var sparkleOpacity: Double = 0.2

    var body: some View {
        let size: CGFloat = !scrolling ? 100 : 65
        let radius = size / 2
        let arrowSize: CGFloat = !scrolling ? 18 : 12
        let angleFromThree = degree - 90 // Berechnet die Position auf dem Ziffernblatt

        let isFlat = angleFromThree == 0
        let isRising = angleFromThree < 0
        let isFalling = angleFromThree > 0

        ZStack {
            // 🟢 1. DER SCHWEIF / SPARKLE (Völlig losgelöst vom Pfeil)
            if isFlat {
                // Flat: Der gesamte Ring funkelt für 15 Sekunden
                ZStack {
                    Circle()
                        .stroke(color.opacity(sparkleOpacity), lineWidth: !scrolling ? 4 : 2)
                        .blur(radius: 2)

                    Circle()
                        .stroke(color.opacity(sparkleOpacity * 0.5), lineWidth: !scrolling ? 2 : 1)

                    // Glitzer Partikel rund um den Ring (Deterministisch, ohne Springen)
                    ForEach(0 ..< 12, id: \.self) { i in
                        let pSize = CGFloat(2 + (i % 3)) // Größen: 2, 3 oder 4
                        let pOffset = CGFloat((i * 5) % 7 - 3) // Offset: Zwischen -3 und +3

                        Circle()
                            .fill(color)
                            .frame(width: pSize, height: pSize)
                            .offset(y: -radius + pOffset)
                            .rotationEffect(.degrees(Double(i) * 30))
                            .opacity(sparkleOpacity * (0.4 + (Double((i * 7) % 12) / 12.0) * 0.6))
                            .shadow(color: color, radius: 2)
                    }
                }
            } else {
                // Steigend/Fallend: Rasanter Kometenschweif, der endlos kreist
                ZStack {
                    Circle()
                        .trim(from: 0.0, to: 0.25) // Ein Viertel des Rings lang
                        .stroke(
                            AngularGradient(
                                colors: [color.opacity(0.8), color.opacity(0)],
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(90)
                            ),
                            style: StrokeStyle(lineWidth: !scrolling ? 6 : 4, lineCap: .round)
                        )
                        .blur(radius: 2)

                    Circle()
                        .trim(from: 0.0, to: 0.25)
                        .stroke(
                            AngularGradient(
                                colors: [color, color.opacity(0.1)],
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(90)
                            ),
                            style: StrokeStyle(lineWidth: !scrolling ? 3 : 2, lineCap: .round)
                        )
                }
                // Dreht den Gradienten um, wenn er im Uhrzeigersinn kreist
                .scaleEffect(y: isFalling ? -1 : 1)
                // Dies ist die dynamische Orbit-Rotation
                .rotationEffect(.degrees(tailRotation))
            }

            // 🟢 2. DIE STATISCHE PFEILSPITZE
            Path { path in
                path.move(to: CGPoint(x: arrowSize, y: arrowSize / 2)) // Spitze rechts
                path.addLine(to: CGPoint(x: 0, y: 0)) // Oben links
                path.addLine(to: CGPoint(x: arrowSize * 0.4, y: arrowSize / 2)) // Einkerbung hinten
                path.addLine(to: CGPoint(x: 0, y: arrowSize)) // Unten links
                path.closeSubpath()
            }
            .fill(color)
            .shadow(color: color.opacity(0.8), radius: 4)
            .frame(width: arrowSize, height: arrowSize)
            // Die Atmungs-Animation drückt den Pfeil sanft nach außen und innen
            .offset(x: radius + breatheOffset)
            // Rotiert den Pfeil auf seine feste Uhrzeit (z.B. -90 für 12 Uhr)
            .rotationEffect(.degrees(angleFromThree))
        }
        .frame(width: size, height: size)
        .onChange(of: dateString) { _ in startHardwareAnimation(isRising: isRising, isFlat: isFlat) }
        .onAppear { startHardwareAnimation(isRising: isRising, isFlat: isFlat) }
    }

    func startHardwareAnimation(isRising: Bool, isFlat: Bool) {
        // Reset states to prevent glitches
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            tailRotation = 0
            breatheOffset = -1
            sparkleOpacity = 0.2
        }

        // Hardware beschleunigte Animationen ausführen (15 Sekunden lang)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // 1. Die Atmung des Pfeils (Für alle Richtungen)
            withAnimation(.easeInOut(duration: 1.0).repeatCount(15, autoreverses: true)) {
                breatheOffset = 3 // Atmet um 4px nach außen
            }

            // 2. Der Orbit oder das Funkeln
            if isFlat {
                // Funkeln: 15 Sekunden lang
                withAnimation(.easeInOut(duration: 0.5).repeatCount(30, autoreverses: true)) {
                    sparkleOpacity = 0.9
                }
            } else {
                // Orbit: Macht 10 volle Umdrehungen in 15 Sekunden
                withAnimation(.linear(duration: 1.5).repeatCount(10, autoreverses: false)) {
                    // Steigend: Gegen den Uhrzeigersinn (-360). Fallend: Im Uhrzeigersinn (360)
                    tailRotation = isRising ? -360 : 360
                }
            }
        }
    }
}
