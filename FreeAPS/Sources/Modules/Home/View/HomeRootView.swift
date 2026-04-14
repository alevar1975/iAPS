import Charts
import CoreData
import SpriteKit
import SwiftDate
import SwiftUI
import Swinject

// 🟢 NEU: Ultra-Runde Karten (Corner Radius 40)
struct ModerniPhone17CardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @State private var isBreathing = false

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(colorScheme == .dark ? Color(red: 0.05, green: 0.08, blue: 0.16) : Color.white.opacity(0.8))
                        .background(colorScheme == .dark ? Material.regular : Material.ultraThin)

                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(colorScheme == .dark ? (isBreathing ? 0.18 : 0.05) : 0.05),
                                    Color.purple.opacity(colorScheme == .dark ? (isBreathing ? 0.10 : 0.02) : 0.02),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: isBreathing)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 40, style: .continuous)
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
                        lineWidth: 1.5
                    )
                    .blendMode(colorScheme == .dark ? .plusLighter : .normal)
            )
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: 8, x: 0, y: 4)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.1), radius: 30, x: 0, y: 15)
            .onAppear { isBreathing = true }
    }
}

// 🟢 NEU: Ultra-Runde Full-Width-Karte
struct ModerniPhone17FullWidthStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @State private var isBreathing = false

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(colorScheme == .dark ? Color(red: 0.05, green: 0.08, blue: 0.16) : Color.white.opacity(0.8))
                        .background(colorScheme == .dark ? Material.regular : Material.ultraThin)

                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(colorScheme == .dark ? (isBreathing ? 0.15 : 0.05) : 0.05),
                                    Color.indigo.opacity(colorScheme == .dark ? (isBreathing ? 0.10 : 0.02) : 0.02),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .animation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: isBreathing)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.15 : 0.5),
                                .clear,
                                .white.opacity(colorScheme == .dark ? 0.05 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .blendMode(colorScheme == .dark ? .plusLighter : .normal)
            )
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: 8, x: 0, y: 4)
            .onAppear { isBreathing = true }
    }
}

extension View {
    func modernCard() -> some View { modifier(ModerniPhone17CardStyle()) }
    func modernFullWidth() -> some View { modifier(ModerniPhone17FullWidthStyle()) }
}

extension Home {
    struct RootView: BaseView {
        let resolver: Resolver

        @StateObject var state: StateModel
        @State var isStatusPopupPresented = false
        @State var showCancelAlert = false
        @State var showCancelTTAlert = false
        @State var triggerUpdate = false
        @State var display = false
        @State var displayGlucose = false
        @State var animateLoop = Date.distantPast
        @State var animateTIR = Date.distantPast
        @State var showBolusActiveAlert = false
        @State var displayAutoHistory = false
        @State var displayDynamicHistory = false
        @State private var isMealsHistoryPresented = false

        @State private var animateUI = false
        @State private var floatDock = false

        let buttonFont = Font.system(size: 14, weight: .medium, design: .rounded)
        let viewPadding: CGFloat = 5

        @Environment(\.managedObjectContext) var moc
        @Environment(\.sizeCategory) private var fontSize
        @Environment(\.colorScheme) var colorScheme

        @FetchRequest(
            entity: Override.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var fetchedPercent: FetchedResults<Override>

        @FetchRequest(
            entity: OverridePresets.entity(),
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)], predicate: NSPredicate(
                format: "name != %@", "" as String
            )
        ) var fetchedProfiles: FetchedResults<OverridePresets>

        @FetchRequest(
            entity: Auto_ISF.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var fetchedAISF: FetchedResults<Auto_ISF>

        @FetchRequest(
            entity: TempTargets.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var sliderTTpresets: FetchedResults<TempTargets>

        @FetchRequest(
            entity: TempTargetsSlider.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var enactedSliderTT: FetchedResults<TempTargetsSlider>

        @FetchRequest(
            entity: Onboarding.entity(),
            sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)]
        ) var onboarded: FetchedResults<Onboarding>

        private let numberFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }()

        private let fetchedTargetFormatterMmol: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }()

        private let fetchedTargetFormatterMgdl: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter
        }()

        private var fetchedTargetFormatter: NumberFormatter {
            state.data.units == .mmolL ? fetchedTargetFormatterMmol : fetchedTargetFormatterMgdl
        }

        private let targetFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }()

        private let tirFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter
        }()

        private let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            return dateFormatter
        }()

        private var spriteScene: SKScene {
            let scene = SnowScene()
            scene.scaleMode = .resizeFill
            scene.backgroundColor = .clear
            return scene
        }

        init(resolver: Resolver) {
            self.resolver = resolver
            _state = StateObject(wrappedValue: StateModel(resolver: resolver))
        }

        var glucoseView: some View {
            CurrentGlucoseView(
                recentGlucose: $state.recentGlucose,
                delta: $state.glucoseDelta,
                units: $state.data.units,
                alarm: $state.alarm,
                lowGlucose: $state.data.lowGlucose,
                highGlucose: $state.data.highGlucose,
                alwaysUseColors: $state.alwaysUseColors,
                displayDelta: $state.displayDelta,
                scrolling: $displayGlucose, displaySAGE: $state.displaySAGE,
                displayExpiration: $state.displayExpiration,
                sensordays: $state.sensorDays,
                timerDate: $state.data.timerDate
            )
            .onTapGesture {
                if state.alarm == nil {
                    state.openCGM()
                } else {
                    state.showModal(for: .snooze)
                }
            }
            .onLongPressGesture {
                let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                impactHeavy.impactOccurred()
                if state.alarm == nil {
                    state.showModal(for: .snooze)
                } else {
                    state.openCGM()
                }
            }
        }

        var pumpView: some View {
            PumpView(
                reservoir: $state.reservoir,
                battery: $state.battery,
                name: $state.pumpName,
                expiresAtDate: $state.pumpExpiresAtDate,
                timerDate: $state.data.timerDate, timeZone: $state.timeZone,
                state: state
            )
            .onTapGesture {
                if state.pumpDisplayState != nil {
                    state.setupPump = true
                }
            }
            .offset(y: 1)
        }

        var loopView: some View {
            LoopView(
                suggestion: $state.data.suggestion,
                enactedSuggestion: $state.enactedSuggestion,
                closedLoop: $state.closedLoop,
                timerDate: $state.data.timerDate,
                isLooping: $state.isLooping,
                lastLoopDate: $state.lastLoopDate,
                manualTempBasal: $state.manualTempBasal
            )
            .onTapGesture {
                state.isStatusPopupPresented.toggle()
            }.onLongPressGesture {
                let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                impactHeavy.impactOccurred()
                state.runLoop()
            }
        }

        var tempBasalString: String {
            guard let tempRate = state.tempRate else {
                return "?" + NSLocalizedString(" U/hr", comment: "Unit per hour with space")
            }
            let rateString = numberFormatter.string(from: tempRate as NSNumber) ?? "0"
            var manualBasalString = ""

            if state.apsManager.isManualTempBasal {
                manualBasalString = NSLocalizedString(
                    " Manual",
                    comment: "Manual Temp basal"
                )
            }
            return rateString + " " + NSLocalizedString(" U/hr", comment: "Unit per hour with space") + manualBasalString
        }

        var tempTargetString: String? {
            guard let tempTarget = state.tempTarget else {
                return nil
            }
            return tempTarget.displayName
        }

        var info: some View {
            HStack(spacing: 10) {
                ZStack {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if state.pumpSuspended {
                            Text("Pump suspended")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.loopGray)
                        } else {
                            Text(tempBasalString)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.insulin)

                            if let currentRate = state.tempRate,
                               let lastTemp = state.data.tempBasals.reversed().first(where: { ($0.rate ?? 0) != currentRate }),
                               let oldRate = lastTemp.rate
                            {
                                let oldRateString = numberFormatter.string(from: oldRate as NSNumber) ?? "0"
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("\(oldRateString)")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5))
                                .padding(.leading, 2)
                            }
                        }
                    }
                }
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let tempTargetString = tempTargetString, !(fetchedPercent.first?.enabled ?? false) {
                    Text(tempTargetString)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    profileView
                }

                ZStack {
                    HStack {
                        Text("⇢").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.secondary)

                        if let eventualBG = state.eventualBG {
                            Text(
                                fetchedTargetFormatter.string(
                                    from: (state.data.units == .mmolL ? eventualBG.asMmolL : Decimal(eventualBG)) as NSNumber
                                ) ?? ""
                            ).font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        } else {
                            Text("?").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                        }
                        Text(state.data.units.rawValue).font(.system(size: 12, design: .rounded)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 8)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }

        var infoPanelView: some View {
            HStack { info }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .modernCard()
        }

        var mainChart: some View {
            ZStack {
                if state.animatedBackground {
                    SpriteView(scene: spriteScene, options: [.allowsTransparency])
                        .ignoresSafeArea()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                }
                MainChartView(data: state.data, triggerUpdate: $triggerUpdate)
            }
            .padding(.bottom, 5)
            .modal(for: .dataTable, from: self)
        }

        @ViewBuilder private func buttonPanel(_ geo: GeometryProxy) -> some View {
            let isOverride = fetchedPercent.first?.enabled ?? false
            let isTarget = (state.tempTarget != nil)

            HStack(spacing: 0) {
                if state.carbButton {
                    Button { state.showModal(for: .addCarbs(editMode: false, override: false, mode: .meal)) }
                    label: {
                        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .bottom)) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundStyle(colorScheme == .dark ? .loopYellow : .orange)
                                .padding(12)

                            if let carbsReq = state.carbsRequired {
                                Text(numberFormatter.string(from: carbsReq as NSNumber)!)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.red))
                                    .offset(x: -4, y: -4)
                            }
                        }
                    }
                    .contextMenu {
                        Button { state.showModal(for: .addCarbs(editMode: false, override: false, mode: .presets)) } label: {
                            Label("Meal Presets", systemImage: "menucard") }
                        Button { state.showModal(for: .addCarbs(editMode: false, override: false, mode: .search)) } label: {
                            Label("Search", systemImage: "network") }
                        Button { state.showModal(for: .addCarbs(editMode: false, override: false, mode: .barcode)) } label: {
                            Label("Barcode", systemImage: "barcode.viewfinder") }
                        Button { state.showModal(for: .addCarbs(editMode: false, override: false, mode: .image)) } label: {
                            Label("AI Image Analysis", systemImage: "photo.badge.magnifyingglass") }
                        Button { state.showModal(for: .addCarbs(editMode: false, override: false, mode: .meal)) } label: {
                            Label("Add Meal", systemImage: "birthday.cake") }
                    }
                    Spacer()
                }

                Button {
                    (state.bolusProgress != nil) ? showBolusActiveAlert = true :
                        state.showModal(for: .bolus(waitForSuggestion: state.useCalc ? true : false, fetch: false))
                }
                label: {
                    Image(systemName: "syringe")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.insulin)
                        .padding(12)
                }
                Spacer()

                if state.allowManualTemp {
                    Button { state.showModal(for: .manualTempBasal) }
                    label: {
                        Image("bolus1")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .padding(12)
                    }
                    .foregroundStyle(.insulin)
                    Spacer()
                }

                if state.profileButton {
                    Button {
                        if isOverride { showCancelAlert.toggle() }
                        else { state.showModal(for: .overrideProfilesConfig) }
                    } label: {
                        Image(systemName: isOverride ? "person.fill" : "person")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(isOverride ? .white : .purple)
                            .padding(12)
                            .background(isOverride ? Color.purple : Color.clear)
                            .clipShape(Circle())
                    }
                    .onLongPressGesture {
                        state.showModal(for: .overrideProfilesConfig)
                    }
                    Spacer()
                }

                if state.useTargetButton {
                    Button {
                        if isTarget { showCancelTTAlert.toggle() }
                        else { state.showModal(for: .addTempTarget) }
                    } label: {
                        Image(systemName: "target")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(isTarget ? .white : .loopGreen)
                            .padding(12)
                            .background(isTarget ? Color.loopGreen : Color.clear)
                            .clipShape(Circle())
                    }
                    .onLongPressGesture {
                        state.showModal(for: .addTempTarget)
                    }
                    Spacer()
                }

                Button { state.showModal(for: .settings) }
                label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.gray)
                        .padding(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(
                        colorScheme == .dark ? Color(red: 0.08, green: 0.12, blue: 0.22).opacity(0.8) : Color.white
                            .opacity(0.7)
                    )
                    .background(.ultraThinMaterial)
            )
            .overlay(
                Capsule().strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.6 : 0.15), radius: 15, x: 0, y: 8)
            .padding(.horizontal, 24)
            .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? geo.safeAreaInsets.bottom / 2 : 16)
            .offset(y: floatDock ? -3 : 3)
            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: floatDock)
            .onAppear { floatDock = true }

            .confirmationDialog("Cancel Profile Override", isPresented: $showCancelAlert) {
                Button("Cancel Profile Override", role: .destructive) {
                    state.cancelProfile()
                    triggerUpdate.toggle()
                }
            }
            .confirmationDialog("Cancel Temporary Target", isPresented: $showCancelTTAlert) {
                Button("Cancel Temporary Target", role: .destructive) {
                    state.cancelTempTarget()
                }
            }
            .confirmationDialog("Bolus already in Progress", isPresented: $showBolusActiveAlert) {
                Button("Bolus already in Progress!", role: .destructive) {
                    showBolusActiveAlert = false
                }
            }
        }

        var chart: some View {
            let ratio = 1.96
            let ratio2 = 2.0

            return mainChart
                .frame(minHeight: UIScreen.main.bounds.height / (fontSize < .extraExtraLarge ? ratio : ratio2))
                .padding(.horizontal, 16)
                .modernCard()
        }

        var carbsAndInsulinView: some View {
            HStack {
                let opacity: CGFloat = colorScheme == .dark ? 0.2 : 0.65
                let materialOpacity: CGFloat = colorScheme == .dark ? 0.25 : 0.10

                // Carbs on Board
                HStack {
                    let substance = Double(state.data.suggestion?.cob ?? 0)
                    let max = max(Double(state.maxCOB), 1)
                    let fraction: Double = 1 - (substance / max)
                    let fill = CGFloat(min(Swift.max(fraction, 0.05), substance > 0 ? 0.92 : 1))
                    TestTube(
                        opacity: opacity,
                        amount: fill,
                        colourOfSubstance: .loopYellow,
                        materialOpacity: materialOpacity
                    )
                    .frame(width: 12, height: 38)
                    .offset(y: -5)
                    HStack(spacing: 0) {
                        if let loop = state.data.suggestion, let cob = loop.cob {
                            Text(numberFormatter.string(from: cob as NSNumber) ?? "0")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        } else {
                            Text("?").font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        Text(NSLocalizedString(" g", comment: "gram of carbs"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }.offset(y: 5)
                }

                Text(" ")

                // Insulin on Board
                HStack {
                    let substance = Double(state.data.iob ?? 0)
                    let max = max(Double(state.maxIOB), 1)
                    let fraction: Double = 1 - abs(substance) / max
                    let fill = CGFloat(min(Swift.max(fraction, 0.05), 1))
                    TestTube(
                        opacity: opacity,
                        amount: fill,
                        colourOfSubstance: substance < 0 ? .red : .insulin,
                        materialOpacity: materialOpacity
                    )
                    .frame(width: 12, height: 38)
                    .offset(y: -5)
                    HStack(spacing: 0) {
                        if let iob = state.data.iob {
                            Text(targetFormatter.string(from: iob as NSNumber) ?? "0")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        } else {
                            Text("?").font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        Text(NSLocalizedString(" U", comment: "Insulin unit"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }.offset(y: 5)
                }
            }.offset(x: 5, y: 5)
        }

        var preview: some View {
            ZStack {
                PreviewChart(
                    readings: $state.readings,
                    lowLimit: $state.data.lowGlucose,
                    highLimit: $state.data.highGlucose
                )
            }
            .frame(minHeight: 200)
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            .padding(.horizontal, 16)
            .modernCard()
            .blur(radius: animateTIRView ? 2 : 0)
            .onTapGesture {
                timeIsNowTIR()
                state.showModal(for: .statistics)
            }
            .overlay {
                if animateTIRView {
                    animation.asAny()
                }
            }
        }

        var activeIOBView: some View {
            ActiveIOBView(data: $state.iobData)
                .frame(minHeight: 190)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .padding(.horizontal, 16)
                .modernCard()
        }

        var activeCOBView: some View {
            ActiveCOBView(data: $state.iobData)
                .frame(minHeight: 190)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .padding(.horizontal, 16)
                .modernCard()
        }

        var insulinView: some View {
            VStack(alignment: .leading, spacing: 10) {
                InsulinSummaryView(
                    neg: $state.neg,
                    tddChange: $state.tddChange,
                    tddAverage: $state.tddAverage,
                    tddYesterday: $state.tddYesterday,
                    tdd2DaysAgo: $state.tdd2DaysAgo,
                    tdd3DaysAgo: $state.tdd3DaysAgo,
                    tddActualAverage: $state.tddActualAverage
                )

                if state.tddYesterday > 0 || state.tddAverage > 0 {
                    Chart {
                        if state.tdd3DaysAgo > 0 {
                            BarMark(x: .value("Tag", "Vor 3"), y: .value("IE", state.tdd3DaysAgo))
                                .foregroundStyle(LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .cornerRadius(100)
                        }
                        if state.tdd2DaysAgo > 0 {
                            BarMark(x: .value("Tag", "Vor 2"), y: .value("IE", state.tdd2DaysAgo))
                                .foregroundStyle(LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .cornerRadius(100)
                        }
                        if state.tddYesterday > 0 {
                            BarMark(x: .value("Tag", "Gestern"), y: .value("IE", state.tddYesterday))
                                .foregroundStyle(LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .cornerRadius(100)
                        }

                        let avg = state.tddActualAverage > 0 ? state.tddActualAverage : state.tddAverage
                        if avg > 0 {
                            RuleMark(y: .value("Ø", avg))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4]))
                                .foregroundStyle(Color.green)
                                .annotation(position: .top, alignment: .trailing) {
                                    Text("Ø").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(.green)
                                }
                        }
                    }
                    .frame(height: 120)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    .chartYAxis { AxisMarks(position: .leading) }
                }
            }
            .frame(minHeight: 280)
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            .padding(.horizontal, 16)
            .modernCard()
        }

        var mealsView: some View {
            MealsCardContainerView(todayData: $state.mealData)
                .frame(minHeight: 190)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .padding(.horizontal, 16)
                .modernCard()
                .onTapGesture {
                    isMealsHistoryPresented = true
                }
                .sheet(isPresented: $isMealsHistoryPresented) {
                    MealsHistorySheet()
                }
        }

        // 🟢 NEU: Korrigierte Tupel-Werte & Knallige Apple Fitness Neon-Farben!
        var loopPreview: some View {
            // In iAPS Tupel: Index 0 = Erfolgreiche Loops, Index 1 = Gesamte Lesungen
            let successLoops = state.loopStatistics.0
            let totalReadings = state.loopStatistics.1

            // Index 2 ist die Kommazahl (Percentage) und Index 3 ist das Intervall als String!
            let successRate = state.loopStatistics.2
            let avgIntervalString = state.loopStatistics.3

            let fillFraction = totalReadings > 0 ? CGFloat(successLoops) / CGFloat(totalReadings) : 0.0

            // 🟢 NEU: Richtig kräftige, vibrierende Farben
            let (ringGradient, iconColor) = {
                if successRate >= 85 {
                    return (
                        LinearGradient(
                            colors: [Color(red: 0.3, green: 1.0, blue: 0.4), Color(red: 0.0, green: 0.8, blue: 0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        Color(red: 0.1, green: 0.9, blue: 0.3)
                    )
                }
                if successRate >= 70 {
                    return (
                        LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                        Color.orange
                    )
                }
                return (
                    LinearGradient(colors: [Color.pink, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing),
                    Color.red
                )
            }()

            return HStack(spacing: 24) {
                // Das Apple-Fitness-Style Ringdiagramm
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 14)

                    Circle()
                        .trim(from: 0.0, to: fillFraction)
                        .stroke(
                            ringGradient,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(color: iconColor.opacity(0.6), radius: 8, x: 0, y: 0) // Stärkerer Glow

                    VStack(spacing: -2) {
                        Text(String(format: "%.0f", successRate))
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        Text("%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 85, height: 85)

                // Statistiken rechts daneben
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                            .foregroundColor(iconColor)
                            .font(.system(size: 16, weight: .bold))
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Intervall (Ø)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                            Text("\(avgIntervalString)") // 🟢 Zieht nun den fertigen String aus dem Tupel!
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                    }

                    Divider().background(Color.gray.opacity(0.3))

                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Loops")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                            Text("\(successLoops)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            Text("Lesungen")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                            Text("\(totalReadings)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(minHeight: 160)
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            .modernFullWidth()
            .blur(radius: animateLoopView ? 2.5 : 0)
            .onTapGesture {
                timeIsNowLoop()
                state.showModal(for: .statistics)
            }
            .overlay {
                if animateLoopView {
                    animation.asAny()
                }
            }
        }

        var profileView: some View {
            HStack(spacing: 0) {
                if let override = fetchedPercent.first {
                    if override.enabled {
                        if override.isPreset {
                            let profile = fetchedProfiles.first(where: { $0.id == override.id })
                            if let currentProfile = profile {
                                if let name = currentProfile.name, name != "EMPTY", name.nonEmpty != nil, name != "",
                                   name != "\u{0022}\u{0022}"
                                {
                                    if name.count > 15 {
                                        let shortened = name.prefix(15)
                                        Text(shortened).font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text(name).font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else { Text("📉") }
                        } else if override.percentage != 100 {
                            Text((tirFormatter.string(from: override.percentage as NSNumber) ?? "") + " %")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        } else if override.smbIsOff, !override.smbIsAlwaysOff {
                            Text("No ").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                            Image(systemName: "syringe")
                                .font(.system(size: 14)).foregroundStyle(.secondary)
                        } else if override.smbIsOff {
                            Image(systemName: "clock").font(.system(size: 14)).foregroundStyle(.secondary)
                            Image(systemName: "syringe")
                                .font(.system(size: 14)).foregroundStyle(.secondary)
                        } else {
                            Text("Override").font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }

        func bolusProgressView(progress: Decimal, amount: Decimal) -> some View {
            ZStack {
                VStack {
                    HStack {
                        let bolused = targetFormatter.string(from: (amount * progress) as NSNumber) ?? ""
                        Text("Bolusing")
                        Text(
                            bolused + " " + NSLocalizedString("of", comment: "") + " " + amount
                                .formatted() + NSLocalizedString(" U", comment: "")
                        )
                    }.frame(width: 250, height: 25).font(.system(size: 14, weight: .semibold, design: .rounded))
                    HStack(alignment: .bottom, spacing: 5) {
                        ProgressView(value: Double(progress)).progressViewStyle(BolusProgressViewStyle())
                            .overlay {
                                Image(systemName: "pause.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .blue)
                                    .font(.system(size: 18))
                            }
                    }
                    .onTapGesture { state.cancelBolus() }
                }
                .dynamicTypeSize(...DynamicTypeSize.large)
                .padding(.bottom, 8)
            }
        }

        @ViewBuilder private func headerView(_ geo: GeometryProxy) -> some View {
            let height: CGFloat = displayGlucose ? 140 : 210

            ZStack {
                if colorScheme == .dark {
                    Color(red: 0.04, green: 0.06, blue: 0.12).opacity(0.85)
                        .background(Material.ultraThin)
                } else {
                    addHeaderBackground()
                }
            }
            .frame(
                height: fontSize < .extraExtraLarge ? height + geo.safeAreaInsets.top : height + 10 + geo
                    .safeAreaInsets.top
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.1), radius: 20, x: 0, y: 10)
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            .overlay {
                VStack {
                    ZStack {
                        if !displayGlucose {
                            glucoseView.frame(maxHeight: .infinity, alignment: .center).offset(y: -5)
                            loopView
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .topLeading
                                )
                                .padding(20)
                                .offset(x: 5, y: -10)
                        }
                        if displayGlucose {
                            glucoseView.frame(maxHeight: .infinity, alignment: .center).offset(y: -10)
                        } else {
                            HStack {
                                carbsAndInsulinView
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                                Spacer()
                                pumpView
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                            }
                            .dynamicTypeSize(...DynamicTypeSize.xLarge)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 5)
                        }
                    }

                    if displayGlucose {
                        glucosePreview
                            .padding(.bottom, 10)
                    } else {
                        infoPanelView
                            .padding(.bottom, 10)
                    }
                }
                .padding(.top, geo.safeAreaInsets.top)
            }
        }

        var glucosePreview: some View {
            let data = state.data.glucose
            let minimum = data.compactMap(\.glucose).min() ?? 0
            let minimumRange = Double(minimum) * 0.8
            let maximum = Double(data.compactMap(\.glucose).max() ?? 0) * 1.1

            let high = state.data.highGlucose
            let low = state.data.lowGlucose
            let veryHigh = 198

            return Chart(data) {
                PointMark(
                    x: .value("Time", $0.dateString),
                    y: .value("Glucose", Double($0.glucose ?? 0) * (state.data.units == .mmolL ? 0.0555 : 1.0))
                )
                .foregroundStyle(
                    (($0.glucose ?? 0) > veryHigh || Decimal($0.glucose ?? 0) < low) ? Color(.red) : Decimal($0.glucose ?? 0) >
                        high ? Color(.yellow) : Color(.darkGreen)
                )
                .symbolSize(5)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3))
            }
            .chartYScale(
                domain: minimumRange * (state.data.units == .mmolL ? 0.0555 : 1.0) ... maximum *
                    (state.data.units == .mmolL ? 0.0555 : 1.0)
            )
            .chartXScale(
                domain: Date.now.addingTimeInterval(-1.days.timeInterval) ... Date.now
            )
            .frame(height: 50)
            .padding(.leading, 30)
            .padding(.trailing, 32)
            .padding(.top, 15)
            .dynamicTypeSize(DynamicTypeSize.medium ... DynamicTypeSize.large)
        }

        var timeSetting: some View {
            let hourLabel = NSLocalizedString("\(state.hours) hours", comment: "") + "   "

            return Menu(hourLabel) {
                ForEach([3, 6, 9, 12, 24], id: \.self) { value in
                    let label = NSLocalizedString("\(value) hours", comment: "")
                    Button(label, action: { state.hours = value })
                }

                Button("UI/UX Settings", action: {
                    state.showModal(for: .uiConfig)
                })
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.5))
                    .background(.ultraThinMaterial)
            )
            .padding(.top, 10)
        }

        private var isfView: some View {
            ZStack {
                HStack(spacing: 4) {
                    Image(systemName: "divide")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.teal)

                    Text(String(describing: state.data.suggestion?.sensitivityRatio ?? 1))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.5))
                        .background(.ultraThinMaterial)
                )
                .onTapGesture {
                    if (state.autoisf && !disabled()) || enabled() {
                        displayAutoHistory.toggle()
                    } else {
                        displayDynamicHistory.toggle()
                    }
                }
            }
            .offset(x: 130)
            .padding(.top, 10)
        }

        private func enabled() -> Bool {
            guard let or = fetchedPercent.first, or.enabled else { return false }
            guard let aisf = fetchedAISF.first else { return false }
            return aisf.autoisf
        }

        private func disabled() -> Bool {
            guard let or = fetchedPercent.first, or.enabled else { return false }
            guard let aisf = fetchedAISF.first else { return false }
            return !aisf.autoisf
        }

        private var animateLoopView: Bool {
            -1 * animateLoop.timeIntervalSinceNow < 1.5
        }

        private var animateTIRView: Bool {
            -1 * animateTIR.timeIntervalSinceNow < 1.5
        }

        private func timeIsNowLoop() {
            animateLoop = Date.now
        }

        private func timeIsNowTIR() {
            animateTIR = Date.now
        }

        private var animation: any View {
            ActivityIndicator(isAnimating: .constant(true), style: .large)
        }

        @Environment(\.scenePhase) private var scenePhase

        var body: some View {
            GeometryReader { geo in
                if onboarded.first?.firstRun ?? true, let openAPSSettings = state.openAPSSettings {
                    importResetSettingsView(settings: openAPSSettings)
                } else {
                    ZStack(alignment: .bottom) {
                        VStack(spacing: 0) {
                            headerView(geo)
                                .zIndex(1)

                            ScrollView {
                                VStack(spacing: 20) {
                                    chart
                                        .padding(.top, 10)

                                    timeSetting
                                        .overlay { isfView }
                                        .padding(.horizontal, 16)

                                    if !state.data.glucose.isEmpty {
                                        preview
                                    }

                                    loopPreview
                                        .padding(.vertical, 8)

                                    if state.carbData > 0 {
                                        activeCOBView
                                    }

                                    if !state.iobData.isEmpty {
                                        activeIOBView
                                    }

                                    insulinView
                                    mealsView
                                }
                                .padding(.bottom, 100)
                                .opacity(animateUI ? 1 : 0)
                                .offset(y: animateUI ? 0 : 40)
                                .background {
                                    GeometryReader { proxy in
                                        let scrollPosition = proxy.frame(in: .named("HomeScrollView")).minY
                                        let yThreshold: CGFloat = -550
                                        Color.clear
                                            .onChange(of: scrollPosition) {
                                                if scrollPosition < yThreshold, state.iobs > 0 || state.carbData > 0,
                                                   !state.skipGlucoseChart
                                                {
                                                    withAnimation(.easeOut(duration: 0.3)) { displayGlucose = true }
                                                } else {
                                                    withAnimation(.easeOut(duration: 0.4)) { displayGlucose = false }
                                                }
                                            }
                                    }
                                }
                            }
                            .coordinateSpace(name: "HomeScrollView")
                        }

                        buttonPanel(geo)
                            .zIndex(2)
                    }
                    .background(
                        colorScheme == .light ?
                            LinearGradient(colors: [Color(white: 0.95), Color(white: 0.9)], startPoint: .top, endPoint: .bottom) :
                            LinearGradient(
                                colors: [Color(red: 0.04, green: 0.06, blue: 0.14), Color(red: 0.01, green: 0.01, blue: 0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )
                    .ignoresSafeArea(edges: .vertical)
                    .overlay {
                        if let progress = state.bolusProgress, let amount = state.bolusAmount {
                            ZStack {
                                RoundedRectangle(cornerRadius: 40, style: .continuous)
                                    .fill(colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.9))
                                    .background(.ultraThinMaterial)
                                    .frame(maxWidth: 320, maxHeight: 90)
                                    .shadow(radius: 20)
                                bolusProgressView(progress: progress, amount: amount)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .offset(y: -100)
                        }
                    }
                    .onChange(of: scenePhase) {
                        switch scenePhase {
                        case .active:
                            state.startTimer()
                        case .background,
                             .inactive:
                            state.stopTimer()
                        default:
                            break
                        }
                    }
                    .onAppear {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.8, blendDuration: 0).delay(0.1)) {
                            animateUI = true
                        }
                    }
                }
            }
            .onAppear {
                if onboarded.first?.firstRun ?? true {
                    state.fetchPreferences()
                }
            }
            .navigationTitle("Home")
            .navigationBarHidden(true)
            .ignoresSafeArea(.keyboard)
            .sheet(isPresented: $displayAutoHistory) {
                AutoISFHistoryView(units: state.data.units)
                    .environment(\.colorScheme, colorScheme)
            }
            .sheet(isPresented: $displayDynamicHistory) {
                DynamicHistoryView(units: state.data.units)
                    .environment(\.colorScheme, colorScheme)
            }
            .popup(isPresented: state.isStatusPopupPresented, alignment: .bottom, direction: .bottom) {
                popup
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 40, style: .continuous)
                            .fill(colorScheme == .dark ? Color(red: 0.08, green: 0.12, blue: 0.22) : Color.white)
                            .background(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 40, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                    )
                    .onTapGesture {
                        state.isStatusPopupPresented = false
                    }
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .local)
                            .onEnded { value in
                                if value.translation.height < 0 {
                                    state.isStatusPopupPresented = false
                                }
                            }
                    )
            }
        }

        private var popup: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.statusTitle).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.white)
                    .padding(.bottom, 4)
                if let suggestion = state.data.suggestion {
                    TagCloudView(tags: suggestion.reasonParts).animation(.none, value: false)

                    Text(suggestion.reasonConclusion.capitalizingFirstLetter())
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                } else {
                    Text("No suggestion found").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.white)
                }
                if let errorMessage = state.errorMessage, let date = state.errorDate {
                    Text(NSLocalizedString("Status at", comment: "") + " " + dateFormatter.string(from: date))
                        .foregroundColor(.white)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(.bottom, 4)
                        .padding(.top, 8)
                    Text(errorMessage).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(.orange)
                } else if let suggestion = state.data.suggestion, (suggestion.bg ?? 100) == 400 {
                    Text("Invalid CGM reading (HIGH).").font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.loopRed).padding(.top, 8)
                    Text("SMBs and High Temps Disabled.").font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white).padding(.bottom, 4)
                }
            }
        }

        private func importResetSettingsView(settings: Preferences) -> some View {
            Restore.RootView(
                resolver: resolver,
                openAPS: settings
            )
        }
    }
}
