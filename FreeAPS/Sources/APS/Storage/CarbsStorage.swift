import CoreData
import Foundation
import SwiftDate
import Swinject

protocol CarbsObserver {
    func carbsDidUpdate(_ carbs: [CarbsEntry])
}

protocol CarbsStorage {
    func storeCarbs(_ carbs: [CarbsEntry], customDuration: Double?)
    func storeCarbs(_ carbs: [CarbsEntry])
    func syncDate() -> Date
    func recent() -> [CarbsEntry]
    func nightscoutTretmentsNotUploaded() -> [NigtscoutTreatment]
    func allNightscoutTreatments() -> [NigtscoutTreatment]
    func deleteCarbsAndFPUs(at date: Date)
    func deleteOldRecords(olderThanDays: Int)
}

final class BaseCarbsStorage: CarbsStorage, Injectable {
    private let processQueue = DispatchQueue(label: "BaseCarbsStorage.processQueue")
    @Injected() private var storage: FileStorage!
    @Injected() private var broadcaster: Broadcaster!
    @Injected() private var settings: SettingsManager!

    let coredataContext = CoreDataStack.shared.persistentContainer.viewContext

    init(resolver: Resolver) {
        injectServices(resolver)
    }

    func storeCarbs(_ entries: [CarbsEntry]) {
        storeCarbs(entries, customDuration: nil)
    }

    func storeCarbs(_ entries: [CarbsEntry], customDuration: Double?) {
        processQueue.sync {
            let file = OpenAPS.Monitor.carbHistory
            var uniqEvents: [CarbsEntry] = []

            let cbs = entries.last?.carbs ?? 0
            let fat = entries.last?.fat ?? 0
            let protein = entries.last?.protein ?? 0
            let note = entries.last?.note
            let creationDate = entries.last?.createdAt ?? Date.now

            self.storage.transaction { storage in

                // -------------------------- FPU --------------------------------------
                if fat > 0 || protein > 0 {
                    let interval = settings.settings.minuteInterval
                    let timeCap = settings.settings.timeCap
                    let adjustment = settings.settings.individualAdjustmentFactor
                    let delay = settings.settings.delay
                    let kcal = protein * 4 + fat * 9
                    let carbEquivalents = (kcal / 10) * adjustment
                    let fpus = carbEquivalents / 10

                    var computedDuration: Double = 0
                    if let custom = customDuration, custom > 0 {
                        computedDuration = custom
                        debug(.default, "Nutze KI/Custom FPU-Dauer: \(computedDuration) Stunden")
                    } else {
                        switch fpus {
                        case ..<2:
                            computedDuration = 3
                        case 2 ..< 3:
                            computedDuration = 4
                        case 3 ..< 4:
                            computedDuration = 5
                        default:
                            computedDuration = Double(timeCap)
                        }
                        debug(.default, "Nutze Warschauer FPU-Dauer: \(computedDuration) Stunden")
                    }

                    var equivalent: Decimal = carbEquivalents / Decimal(computedDuration)
                    equivalent /= Decimal(60 / interval)
                    equivalent = Decimal(round(Double(equivalent * 10)) / 10)
                    equivalent = equivalent > IAPSconfig.minimumCarbEquivalent ? max(equivalent, 1) : 0

                    var numberOfEquivalents = equivalent > 0 ? carbEquivalents / equivalent : 0
                    var firstIndex = true
                    var useDate = entries.last?.actualDate ?? Date()
                    var futureCarbArray = [CarbsEntry]()

                    while carbEquivalents > 0, numberOfEquivalents > 0 {
                        if firstIndex {
                            useDate = useDate.addingTimeInterval(delay.minutes.timeInterval)
                            firstIndex = false
                        } else { useDate = useDate.addingTimeInterval(interval.minutes.timeInterval) }

                        let eachCarbEntry = CarbsEntry(
                            id: UUID().uuidString, createdAt: creationDate, actualDate: useDate,
                            carbs: equivalent, fat: 0, protein: 0, note: nil,
                            enteredBy: CarbsEntry.manual, isFPU: true, kcal: nil,
                            duration: customDuration // 🟢 FIX: Dauer übergeben
                        )
                        futureCarbArray.append(eachCarbEntry)
                        numberOfEquivalents -= 1
                    }

                    if carbEquivalents > 0, !futureCarbArray.isEmpty {
                        storage.append(futureCarbArray, to: file, uniqBy: \.id)
                    }
                } // ------------------------- END OF FPU ----------------------------------------

                // ------------------------- NORMAL CARBS ----------------------------------------
                if let entry = entries.last {
                    let onlyCarbs = CarbsEntry(
                        id: entry.id ?? "",
                        createdAt: creationDate,
                        actualDate: entry.actualDate ?? entry.createdAt,
                        carbs: entry.carbs,
                        fat: fat,
                        protein: protein,
                        note: entry.note ?? "",
                        enteredBy: entry.enteredBy ?? "",
                        isFPU: false,
                        kcal: nil,
                        duration: customDuration // 🟢 FIX: Dauer übergeben
                    )

                    if entries.filter({ $0.carbs > 0 }).count > 1 {
                        storage.append(entries, to: file, uniqBy: \.createdAt)
                    } else {
                        storage.append([onlyCarbs], to: file, uniqBy: \.id)
                    }
                }

                // ------------------------- CLEANUP & SAVE --------------------------------------
                uniqEvents = storage.retrieve(file, as: [CarbsEntry].self)?
                    .filter { $0.createdAt.addingTimeInterval(1.days.timeInterval) > Date() }
                    .sorted { $0.createdAt > $1.createdAt } ?? []
                storage.save(Array(uniqEvents), as: file)
            }

            self.coredataContext.perform {
                let carbDataForStats = Carbohydrates(context: self.coredataContext)

                carbDataForStats.carbs = cbs as NSDecimalNumber
                carbDataForStats.fat = fat as NSDecimalNumber
                carbDataForStats.protein = protein as NSDecimalNumber

                let kcalValue =
                    (Double(truncating: carbDataForStats.carbs ?? 0) * 4.0) +
                    (Double(truncating: carbDataForStats.fat ?? 0) * 9.0) +
                    (Double(truncating: carbDataForStats.protein ?? 0) * 4.0)

                carbDataForStats.kcal = NSDecimalNumber(value: kcalValue)
                carbDataForStats.note = note
                carbDataForStats.id = UUID().uuidString
                carbDataForStats.date = creationDate

                try? self.coredataContext.save()
            }

            broadcaster.notify(CarbsObserver.self, on: processQueue) {
                $0.carbsDidUpdate(uniqEvents)
            }
        }
    }

    func syncDate() -> Date {
        Date().addingTimeInterval(-1.days.timeInterval)
    }

    func recent() -> [CarbsEntry] {
        storage.retrieve(OpenAPS.Monitor.carbHistory, as: [CarbsEntry].self)?.reversed() ?? []
    }

    func deleteCarbsAndFPUs(at date: Date) {
        processQueue.sync {
            var allValues = storage.retrieve(OpenAPS.Monitor.carbHistory, as: [CarbsEntry].self) ?? []
            allValues.removeAll(where: { $0.createdAt == date })
            storage.save(allValues, as: OpenAPS.Monitor.carbHistory)
            broadcaster.notify(CarbsObserver.self, on: processQueue) {
                $0.carbsDidUpdate(allValues)
            }
        }
    }

    func nightscoutTretmentsNotUploaded() -> [NigtscoutTreatment] {
        let uploaded = storage.retrieve(OpenAPS.Nightscout.uploadedCarbs, as: [NigtscoutTreatment].self) ?? []

        let eventsManual = recent()
            .filter {
                ($0.enteredBy == CarbsEntry.manual || $0.enteredBy == CarbsEntry.remote) &&
                    ($0.carbs > 0 || ($0.fat ?? 0) > 0 || ($0.protein ?? 0) > 0) }
        let treatments = eventsManual.map {
            NigtscoutTreatment(
                duration: nil,
                rawDuration: nil,
                rawRate: nil,
                absolute: nil,
                rate: nil,
                eventType: .nsCarbCorrection,
                createdAt: $0.actualDate ?? .distantPast,
                enteredBy: CarbsEntry.manual,
                bolus: nil,
                insulin: nil,
                carbs: $0.carbs,
                fat: $0.fat,
                protein: $0.protein,
                foodType: $0.note,
                targetTop: nil,
                targetBottom: nil,
                id: $0.id,
                fpuID: nil,
                creation_date: $0.createdAt
            )
        }
        return Array(Set(treatments).subtracting(Set(uploaded)))
    }

    func allNightscoutTreatments() -> [NigtscoutTreatment] {
        let eventsManual = recent()
            .filter {
                ($0.enteredBy == CarbsEntry.manual || $0.enteredBy == CarbsEntry.remote) &&
                    ($0.carbs > 0 || ($0.fat ?? 0) > 0 || ($0.protein ?? 0) > 0) }

        return eventsManual.map {
            NigtscoutTreatment(
                duration: nil,
                rawDuration: nil,
                rawRate: nil,
                absolute: nil,
                rate: nil,
                eventType: .nsCarbCorrection,
                createdAt: $0.actualDate ?? .distantPast,
                enteredBy: CarbsEntry.manual,
                bolus: nil,
                insulin: nil,
                carbs: $0.carbs,
                fat: $0.fat,
                protein: $0.protein,
                foodType: $0.note,
                targetTop: nil,
                targetBottom: nil,
                id: $0.id,
                fpuID: nil,
                creation_date: $0.createdAt
            )
        }
    }

    func getMacroStats() -> (count: Int, oldestDate: Date?) {
        let allValues = storage.retrieve(OpenAPS.Monitor.carbHistory, as: [CarbsEntry].self) ?? []
        let count = allValues.count
        let oldest = allValues.min(by: { $0.createdAt < $1.createdAt })?.createdAt
        return (count, oldest)
    }

    func deleteOldRecords(olderThanDays: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()

        processQueue.sync {
            var allValues = storage.retrieve(OpenAPS.Monitor.carbHistory, as: [CarbsEntry].self) ?? []
            allValues.removeAll(where: { $0.createdAt < cutoff })
            storage.save(allValues, as: OpenAPS.Monitor.carbHistory)

            var uploaded = storage.retrieve(OpenAPS.Nightscout.uploadedCarbs, as: [NigtscoutTreatment].self) ?? []
            uploaded.removeAll(where: { ($0.createdAt ?? .distantFuture) < cutoff })
            storage.save(uploaded, as: OpenAPS.Nightscout.uploadedCarbs)
        }

        coredataContext.perform {
            let fetchRequest = Carbohydrates.fetchRequest() as NSFetchRequest<Carbohydrates>
            fetchRequest.predicate = NSPredicate(format: "date < %@", cutoff as NSDate)
            do {
                let oldEntries = try self.coredataContext.fetch(fetchRequest)
                for entry in oldEntries {
                    self.coredataContext.delete(entry)
                }
                if self.coredataContext.hasChanges { try self.coredataContext.save() }
            } catch {}
        }
    }
}
