import CoreData
import Foundation
import SwiftUI

// Lightweight Structs nur für die Mahlzeiten-Regeln der KI
struct IAPSMealRule: Codable, Equatable {
    let category: String
    let overridePct: Int
    let durationHours: Double
    let expectedPeakHours: Double
    let avgMaxBg: Int
    let iapsUnderprediction: Int

    enum CodingKeys: String, CodingKey {
        case category
        case overridePct = "override_pct"
        case durationHours = "duration_hours"
        case expectedPeakHours = "expected_peak_hours"
        case avgMaxBg = "avg_max_bg"
        case iapsUnderprediction = "iaps_underprediction"
    }
}

struct IAPSActionsResponse: Codable {
    let mealRules: [IAPSMealRule]?

    enum CodingKeys: String, CodingKey {
        case mealRules = "meal_rules"
    }
}

extension AddCarbs {
    final class StateModel: BaseStateModel<Provider> {
        @Injected() var carbsStorage: CarbsStorage!
        @Injected() var apsManager: APSManager!
        @Injected() var settings: SettingsManager!
        @Injected() var nightscoutManager: NightscoutManager!

        @Published var carbs: Decimal = 0
        @Published var date = Date()
        @Published var protein: Decimal = 0
        @Published var fat: Decimal = 0
        @Published var carbsRequired: Decimal?
        @Published var useFPUconversion: Bool = false
        @Published var dish: String = ""
        @Published var selection: Presets?
        @Published var maxCarbs: Decimal = 0
        @Published var note: String = ""
        @Published var id_: String = ""
        @Published var skipBolus: Bool = false
        @Published var id: String?
        @Published var hypoTreatment = false
        @Published var presetToEdit: Presets?
        @Published var edit = false
        @Published var ai = false
        @Published var skipSave = false

        @Published var combinedPresets: [(preset: Presets?, portions: Double)] = []
        @Published var mealRules: [IAPSMealRule] = []

        // Variable für deine manuelle oder automatische Dauer-Eingabe
        @Published var customDuration: Decimal = 0

        let now = Date.now

        let coredataContext = CoreDataStack.shared.persistentContainer.viewContext
        let coredataContextBackground = CoreDataStack.shared.persistentContainer.newBackgroundContext()

        override func subscribe() {
            carbsRequired = provider.suggestion?.carbsReq
            id = settings.settings.profileID
            maxCarbs = settings.settings.maxCarbs
            skipBolus = settingsManager.settings.skipBolusScreenAfterCarbs
            useFPUconversion = settingsManager.settings.useFPUconversion
            ai = settingsManager.settings.ai
            skipSave = settingsManager.settings.skipSave

            fetchMealRules()
        }

        func fetchMealRules() {
            guard let url = URL(string: "https://alentestetkidiab.de/weekly_actions_latest.json") else { return }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data else { return }
                if let decoded = try? JSONDecoder().decode(IAPSActionsResponse.self, from: data) {
                    DispatchQueue.main.async {
                        self.mealRules = decoded.mealRules ?? []
                    }
                }
            }.resume()
        }

        func evaluateMeal() -> IAPSMealRule? {
            let c = NSDecimalNumber(decimal: carbs).doubleValue
            let f = NSDecimalNumber(decimal: fat).doubleValue
            let p = NSDecimalNumber(decimal: protein).doubleValue

            var detectedCategory = ""
            if f > 25 || p > 35 {
                if c > 40 { detectedCategory = "Mixed (Pizza-Effekt)" }
                else { detectedCategory = "High FPU (Fett/Protein)" }
            } else if c > 30 {
                detectedCategory = "High Carb"
            }

            return mealRules.first(where: { $0.category == detectedCategory })
        }

        // 🟢 FIX: Alles durchgehend als 'Decimal' rechnen, um Typ-Konflikte mit 'adjustment' zu vermeiden
        func getIAPSStandardDuration() -> Double {
            if fat == 0, protein == 0 { return 0 } // Normale Kohlenhydrate ohne FPU-Streckung

            let adjustment = settings.settings.individualAdjustmentFactor
            let timeCap = settings.settings.timeCap

            let kcal = protein * 4 + fat * 9
            let carbEquivalents = (kcal / 10) * adjustment
            let fpus = carbEquivalents / 10

            switch fpus {
            case ..<2: return 3
            case 2 ..< 3: return 4
            case 3 ..< 4: return 5
            default: return Double(timeCap)
            }
        }

        func add(_ continue_: Bool, fetch: Bool, customDuration: Double? = nil) {
            guard carbs > 0 || fat > 0 || protein > 0 else {
                showModal(for: nil)
                return
            }
            carbs = min(carbs, maxCarbs)
            id_ = UUID().uuidString

            let carbsToStore = [CarbsEntry(
                id: id_,
                createdAt: now,
                actualDate: date,
                carbs: carbs,
                fat: fat,
                protein: protein,
                note: note,
                enteredBy: CarbsEntry.manual,
                isFPU: false,
                kcal: nil,
                duration: customDuration
            )]

            if hypoTreatment { hypo() }

            if (skipBolus && !continue_ && !fetch) || hypoTreatment {
                carbsStorage.storeCarbs(carbsToStore, customDuration: customDuration)
                apsManager.determineBasalSync()
                showModal(for: nil)
            } else if carbs > 0 {
                saveToCoreData(carbsToStore)
                showModal(for: .bolus(waitForSuggestion: true, fetch: true))
            } else if !empty {
                carbsStorage.storeCarbs(carbsToStore, customDuration: customDuration)
                apsManager.determineBasalSync()
                showModal(for: nil)
            } else {
                hideModal()
            }
        }

        func deletePreset() {
            if selection != nil {
                carbs -= ((selection?.carbs ?? 0) as NSDecimalNumber) as Decimal
                fat -= ((selection?.fat ?? 0) as NSDecimalNumber) as Decimal
                protein -= ((selection?.protein ?? 0) as NSDecimalNumber) as Decimal
                try? coredataContext.delete(selection!)
                try? coredataContext.save()
            }
        }

        func removePresetFromNewMeal() {
            if let index = combinedPresets.firstIndex(where: { $0.preset == selection }) {
                if combinedPresets[index].portions > 0.5 {
                    combinedPresets[index].portions -= 0.5
                } else if combinedPresets[index].portions == 0.5 {
                    combinedPresets.remove(at: index)
                    selection = nil
                }
            }
        }

        func addPresetToNewMeal(half: Bool = false) {
            if let index = combinedPresets.firstIndex(where: { $0.preset == selection }) {
                combinedPresets[index].portions += (half ? 0.5 : 1)
            } else {
                combinedPresets.append((selection, 1))
            }
        }

        func waitersNotepad() -> [String] {
            guard combinedPresets.isNotEmpty else { return [] }

            if carbs == 0, protein == 0, fat == 0 {
                return []
            }

            var presetsString: [String] = combinedPresets.map { item in
                "\(item.portions) \(item.preset?.dish ?? "")"
            }

            if presetsString.isNotEmpty {
                let totCarbs = combinedPresets
                    .compactMap({ each in (each.preset?.carbs ?? 0) as Decimal * Decimal(each.portions) })
                    .reduce(0, +)
                let totFat = combinedPresets.compactMap({ each in (each.preset?.fat ?? 0) as Decimal * Decimal(each.portions) })
                    .reduce(0, +)
                let totProtein = combinedPresets
                    .compactMap({ each in (each.preset?.protein ?? 0) as Decimal * Decimal(each.portions) }).reduce(0, +)
                let margins: Decimal = 1.8

                if carbs > totCarbs + margins {
                    presetsString.append("+ \(carbs - totCarbs) carbs")
                } else if carbs + margins < totCarbs {
                    presetsString.append("- \(totCarbs - carbs) carbs")
                }

                if fat > totFat + margins {
                    presetsString.append("+ \(fat - totFat) fat")
                } else if fat + margins < totFat {
                    presetsString.append("- \(totFat - fat) fat")
                }

                if protein > totProtein + margins {
                    presetsString.append("+ \(protein - totProtein) protein")
                } else if protein + margins < totProtein {
                    presetsString.append("- \(totProtein - protein) protein")
                }
            }

            return presetsString.removeDublicates()
        }

        func loadEntries(_ editMode: Bool) {
            if editMode {
                coredataContext.performAndWait {
                    var mealToEdit = [Meals]()
                    let requestMeal = Meals.fetchRequest() as NSFetchRequest<Meals>
                    let sortMeal = NSSortDescriptor(key: "createdAt", ascending: false)
                    requestMeal.sortDescriptors = [sortMeal]
                    requestMeal.fetchLimit = 1
                    try? mealToEdit = self.coredataContext.fetch(requestMeal)

                    self.carbs = Decimal(mealToEdit.first?.carbs ?? 0)
                    self.fat = Decimal(mealToEdit.first?.fat ?? 0)
                    self.protein = Decimal(mealToEdit.first?.protein ?? 0)
                    self.note = mealToEdit.first?.note ?? ""
                    self.id_ = mealToEdit.first?.id ?? ""
                }
            }
        }

        func subtract() {
            let presetCarbs = ((selection?.carbs ?? 0) as NSDecimalNumber) as Decimal
            if carbs != 0, carbs - presetCarbs >= 0 {
                carbs -= presetCarbs * 0.5
            } else { carbs = 0 }

            let presetFat = ((selection?.fat ?? 0) as NSDecimalNumber) as Decimal
            if fat != 0, presetFat >= 0 {
                fat -= presetFat * 0.5
            } else { fat = 0 }

            let presetProtein = ((selection?.protein ?? 0) as NSDecimalNumber) as Decimal
            if protein != 0, presetProtein >= 0 {
                protein -= presetProtein * 0.5
            } else { protein = 0 }

            removePresetFromNewMeal()
        }

        func plus() {
            carbs += (((selection?.carbs ?? 0) as NSDecimalNumber) as Decimal * 0.5)
            fat += (((selection?.fat ?? 0) as NSDecimalNumber) as Decimal * 0.5)
            protein += (((selection?.protein ?? 0) as NSDecimalNumber) as Decimal * 0.5)
            addPresetToNewMeal(half: true)
        }

        func addU(_ selection: Presets?) {
            carbs += ((selection?.carbs ?? 0) as NSDecimalNumber) as Decimal
            fat += ((selection?.fat ?? 0) as NSDecimalNumber) as Decimal
            protein += ((selection?.protein ?? 0) as NSDecimalNumber) as Decimal
            addPresetToNewMeal()
        }

        func saveToCoreData(_ stored: [CarbsEntry]) {
            CoreDataStorage().saveMeal(stored, now: now)
        }

        private var empty: Bool {
            carbs <= 0 && fat <= 0 && protein <= 0
        }

        private func hypo() {
            let os = OverrideStorage()

            if let activeOveride = os.fetchLatestOverride().first {
                let presetName = os.isPresetName()
                if let preset = presetName {
                    if let duration = os.cancelProfile() {
                        nightscoutManager.editOverride(preset, duration, activeOveride.date ?? Date.now)
                    }
                } else if activeOveride.isPreset {
                    if let duration = os.cancelProfile() {
                        nightscoutManager.editOverride("📉", duration, activeOveride.date ?? Date.now)
                    }
                } else {
                    let nsString = activeOveride.percentage.formatted() != "100" ? activeOveride.percentage
                        .formatted() + " %" : "Custom"
                    if let duration = os.cancelProfile() {
                        nightscoutManager.editOverride(nsString, duration, activeOveride.date ?? Date.now)
                    }
                }
            }

            guard let profileID = id, profileID != "None" else {
                return
            }
            if profileID == "Hypo Treatment" {
                let override = OverridePresets(context: coredataContextBackground)
                override.percentage = 90
                override.smbIsOff = true
                override.duration = 45
                override.name = "📉"
                override.advancedSettings = true
                override.target = 117
                override.date = Date.now
                override.indefinite = false
                os.overrideFromPreset(override, profileID)
                nightscoutManager.uploadOverride(
                    "📉",
                    Double(45),
                    override.date ?? Date.now
                )
            } else {
                os.activatePreset(profileID)
            }
        }
    }
}
