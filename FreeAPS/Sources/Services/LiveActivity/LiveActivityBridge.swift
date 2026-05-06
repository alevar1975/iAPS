import ActivityKit
import Foundation
import Swinject
import UIKit

extension LiveActivityAttributes.ContentState {
    static func formatGlucose(_ value: Int, mmol: Bool, forceSign: Bool) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        if mmol {
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 1
        }
        if forceSign {
            formatter.positivePrefix = formatter.plusSign
        }
        formatter.roundingMode = .halfUp

        return formatter
            .string(from: mmol ? value.asMmolL as NSNumber : NSNumber(value: value)) ?? ""
    }

    static func formatter(_ string: NSNumber) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter.string(from: string) ?? ""
    }

    static func carbFormatter(_ string: NSNumber) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: string) ?? ""
    }

    init?(
        new bg: Readings?,
        prev: Readings?,
        mmol: Bool,
        suggestion: Suggestion,
        iob: Decimal?,
        loopDate: Date,
        readings: [Readings]?,
        predictions: Predictions?,
        showChart: Bool,
        chartLowThreshold: Int,
        chartHighThreshold: Int
    ) {
        guard let glucose = bg?.glucose else {
            return nil
        }

        let formattedBG = Self.formatGlucose(Int(glucose), mmol: mmol, forceSign: false)

        // 🟢 MEGA-FIX 3.0: Harte Delta-Regel auch für das Live Activity Banner
        let currentBg = Int(glucose)
        let prevBg = Int(prev?.glucose ?? Int16(currentBg))
        let deltaInt = currentBg - prevBg

        var trendString = "Flat"
        if deltaInt > 10 { trendString = "DoubleUp" }
        else if deltaInt > 5 { trendString = "SingleUp" }
        else if deltaInt < -10 { trendString = "DoubleDown" }
        else if deltaInt < -5 { trendString = "SingleDown" }
        // else -> bleibt "Flat"

        let change = Self.formatGlucose(deltaInt, mmol: mmol, forceSign: true)
        let cobString = Self.carbFormatter((suggestion.cob ?? 0) as NSNumber)
        let iobString = Self.formatter((iob ?? 0) as NSNumber)
        let eventual = Self.formatGlucose(suggestion.eventualBG ?? 100, mmol: mmol, forceSign: false)
        let mmol = mmol

        let activityPredictions: LiveActivityAttributes.ActivityPredictions?
        if let predictions = predictions, let bgDate = bg?.date {
            func createPoints(from values: [Int]?) -> LiveActivityAttributes.ValueSeries? {
                let prefixToTake = 24
                if let values = values {
                    let dates = values.dropFirst().indices.prefix(prefixToTake).map {
                        bgDate.addingTimeInterval(TimeInterval($0 * 5 * 60))
                    }
                    let clampedValues = values.dropFirst().prefix(prefixToTake).map { Int16(clamping: $0) }
                    return LiveActivityAttributes.ValueSeries(dates: dates, values: clampedValues)
                } else {
                    return nil
                }
            }

            let converted = LiveActivityAttributes.ActivityPredictions(
                iob: createPoints(from: predictions.iob),
                zt: createPoints(from: predictions.zt),
                cob: createPoints(from: predictions.cob),
                uam: createPoints(from: predictions.uam)
            )
            activityPredictions = converted
        } else {
            activityPredictions = nil
        }

        let preparedReadings: LiveActivityAttributes.ValueSeries? = {
            guard let readings else { return nil }
            let validReadings = readings.compactMap { reading -> (Date, Int16)? in
                guard let date = reading.date else { return nil }
                return (date, reading.glucose)
            }

            let dates = validReadings.map(\.0)
            let values = validReadings.map(\.1)

            return LiveActivityAttributes.ValueSeries(dates: dates, values: values)
        }()

        self.init(
            bg: formattedBG,
            direction: trendString,
            change: change,
            date: bg?.date ?? Date.now,
            iob: iobString,
            cob: cobString,
            loopDate: loopDate,
            eventual: eventual,
            mmol: mmol,
            readings: preparedReadings,
            predictions: activityPredictions,
            showChart: showChart,
            chartLowThreshold: Int16(clamping: chartLowThreshold),
            chartHighThreshold: Int16(clamping: chartHighThreshold)
        )
    }
}

private struct ActiveActivity {
    let activity: Activity<LiveActivityAttributes>
    let startDate: Date

    func needsRecreation() -> Bool {
        switch activity.activityState {
        case .dismissed,
             .ended,
             .stale:
            return true
        case .active: break
        @unknown default:
            return true
        }

        return -startDate.timeIntervalSinceNow >
            TimeInterval(60 * 60)
    }
}

final class LiveActivityBridge: Injectable, ObservableObject, SettingsObserver {
    @Injected() private var settingsManager: SettingsManager!
    @Injected() private var storage: FileStorage!
    @Injected() private var broadcaster: Broadcaster!

    private let coreDataStorage = CoreDataStorage()

    private let activityAuthorizationInfo = ActivityAuthorizationInfo()
    @Published private(set) var systemEnabled: Bool

    private var settings: FreeAPSSettings {
        settingsManager.settings
    }

    private var knownSettings: FreeAPSSettings?

    private var currentActivity: ActiveActivity?
    private var latestGlucose: Readings?
    private var loopDate: Date?
    private var suggestion: Suggestion?
    private var iob: Decimal?

    init(resolver: Resolver) {
        systemEnabled = activityAuthorizationInfo.areActivitiesEnabled

        injectServices(resolver)
        broadcaster.register(SuggestionObserver.self, observer: self)
        broadcaster.register(EnactedSuggestionObserver.self, observer: self)
        broadcaster.register(PumpHistoryObserver.self, observer: self)

        Foundation.NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { _ in
            self.forceActivityUpdate()
        }

        Foundation.NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { _ in
            self.forceActivityUpdate()
        }

        knownSettings = settings
        broadcaster.register(SettingsObserver.self, observer: self)

        monitorForLiveActivityAuthorizationChanges()
    }

    func settingsDidChange(_ newSettings: FreeAPSSettings) {
        if let knownSettings = self.knownSettings {
            if newSettings.useLiveActivity != knownSettings.useLiveActivity ||
                newSettings.liveActivityChart != knownSettings.liveActivityChart ||
                newSettings.liveActivityChartShowPredictions != knownSettings.liveActivityChartShowPredictions
            {
                forceActivityUpdate(force: true)
            }
        }
        knownSettings = newSettings
    }

    private func monitorForLiveActivityAuthorizationChanges() {
        Task {
            for await activityState in activityAuthorizationInfo.activityEnablementUpdates {
                if activityState != systemEnabled {
                    await MainActor.run {
                        systemEnabled = activityState
                    }
                }
            }
        }
    }

    private func forceActivityUpdate(force: Bool = false) {
        if settings.useLiveActivity {
            if force || currentActivity?.needsRecreation() ?? true,
               let suggestion = storage.retrieveFile(OpenAPS.Enact.suggested, as: Suggestion.self)
            {
                suggestionDidUpdate(suggestion)
            }
        } else {
            Task {
                await self.endActivity()
            }
        }
    }

    @MainActor private func pushUpdate(_ state: LiveActivityAttributes.ContentState) async {
        for unknownActivity in Activity<LiveActivityAttributes>.activities
            .filter({ self.currentActivity?.activity.id != $0.id })
        {
            await unknownActivity.end(nil, dismissalPolicy: .immediate)
        }

        if let currentActivity {
            if currentActivity.needsRecreation(), UIApplication.shared.applicationState == .active {
                await endActivity()
                await pushUpdate(state)
            } else {
                let encoder = JSONEncoder()
                let encodedLength: Int = {
                    if let data = try? encoder.encode(state) {
                        return data.count
                    } else {
                        return 0
                    }
                }()

                let content = {
                    if encodedLength > 4 * 1024 {
                        return ActivityContent(
                            state: state.withoutPredictions(),
                            staleDate: Date.now.addingTimeInterval(TimeInterval(12 * 60))
                        )
                    } else {
                        return ActivityContent(
                            state: state,
                            staleDate: Date.now.addingTimeInterval(TimeInterval(12 * 60))
                        )
                    }
                }()

                await currentActivity.activity.update(content)
            }
        } else {
            do {
                let settings = self.settings
                let nonStale = ActivityContent(
                    state: LiveActivityAttributes.ContentState(
                        bg: "--",
                        direction: nil,
                        change: "--",
                        date: Date.now,
                        iob: "--",
                        cob: "--",
                        loopDate: Date.now, eventual: "--", mmol: false,
                        readings: nil,
                        predictions: nil,
                        showChart: settings.liveActivityChart,
                        chartLowThreshold: Int16(clamping: (settings.low as NSDecimalNumber).intValue),
                        chartHighThreshold: Int16(clamping: (settings.high as NSDecimalNumber).intValue)
                    ),
                    staleDate: Date.now.addingTimeInterval(60)
                )

                let activity = try Activity.request(
                    attributes: LiveActivityAttributes(startDate: Date.now),
                    content: nonStale,
                    pushType: nil
                )

                currentActivity = ActiveActivity(activity: activity, startDate: Date.now)

                await pushUpdate(state)
            } catch {
                print("activity creation error: \(error)")
            }
        }
    }

    private func endActivity() async {
        if let currentActivity {
            await currentActivity.activity.end(nil, dismissalPolicy: .immediate)
            self.currentActivity = nil
        }

        for unknownActivity in Activity<LiveActivityAttributes>.activities {
            await unknownActivity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

extension LiveActivityBridge: SuggestionObserver, EnactedSuggestionObserver, PumpHistoryObserver {
    func pumpHistoryDidUpdate(_: [PumpHistoryEvent]) {
        iob = coreDataStorage.fetchInsulinData(interval: DateFilter().oneHour).first?.iob
    }

    func enactedSuggestionDidUpdate(_ suggestion: Suggestion) {
        let settings = self.settings

        guard settings.useLiveActivity else {
            if currentActivity != nil {
                Task { await self.endActivity() }
            }
            return
        }
        defer { self.suggestion = suggestion }

        let glucose = coreDataStorage.fetchGlucose(interval: DateFilter().threeHours)
        let prev = glucose.count > 1 ? glucose[1] : glucose.first

        guard let content = LiveActivityAttributes.ContentState(
            new: glucose.first,
            prev: prev,
            mmol: settings.units == .mmolL,
            suggestion: suggestion,
            iob: suggestion.iob,
            loopDate: (suggestion.recieved ?? false) ? (suggestion.timestamp ?? .distantPast) :
                (coreDataStorage.fetchLastLoop()?.timestamp ?? .distantPast),
            readings: settings.liveActivityChart ? glucose : nil,
            predictions: settings.liveActivityChart && settings.liveActivityChartShowPredictions ? suggestion.predictions : nil,
            showChart: settings.liveActivityChart,
            chartLowThreshold: Int(settings.low),
            chartHighThreshold: Int(settings.high)
        ) else { return }

        Task { await self.pushUpdate(content) }
    }

    func suggestionDidUpdate(_ suggestion: Suggestion) {
        let settings = self.settings

        guard settings.useLiveActivity else {
            if currentActivity != nil {
                Task { await self.endActivity() }
            }
            return
        }
        defer { self.suggestion = suggestion }

        let glucose = coreDataStorage.fetchGlucose(interval: DateFilter().threeHours)
        let prev = glucose.count > 1 ? glucose[1] : glucose.first

        guard let content = LiveActivityAttributes.ContentState(
            new: glucose.first,
            prev: prev,
            mmol: settings.units == .mmolL,
            suggestion: suggestion,
            iob: suggestion.iob,
            loopDate: settings.closedLoop ? (coreDataStorage.fetchLastLoop()?.timestamp ?? .distantPast) : suggestion
                .timestamp ?? .distantPast,
            readings: settings.liveActivityChart ? glucose : nil,
            predictions: settings.liveActivityChart && settings.liveActivityChartShowPredictions ? suggestion.predictions : nil,
            showChart: settings.liveActivityChart,
            chartLowThreshold: Int(settings.low),
            chartHighThreshold: Int(settings.high)
        ) else { return }

        Task { await self.pushUpdate(content) }
    }
}
