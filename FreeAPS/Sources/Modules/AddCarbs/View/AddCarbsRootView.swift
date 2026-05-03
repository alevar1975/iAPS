import Combine
import CoreData
import OSLog
import SwiftUI
import Swinject

extension AddCarbs {
    struct RootView: BaseView {
        let resolver: Resolver
        let editMode: Bool
        let override: Bool
        let mode: MealMode.Mode
        @StateObject var state: StateModel
        @StateObject var foodSearchState = FoodSearchStateModel()

        @State var dish: String = ""
        @State var isPromptPresented = false
        @State var saved = false
        @State var pushed = false
        @State var button = false

        @State private var showAlert = false
        @State private var presentPresets = false
        @State private var string = ""
        @State private var newPreset: (dish: String, carbs: Decimal, fat: Decimal, protein: Decimal) = ("", 0, 0, 0)
        // Food Search States
        @State private var showCancelConfirmation = false

        @FetchRequest(
            entity: Presets.entity(),
            sortDescriptors: [NSSortDescriptor(key: "dish", ascending: true)], predicate:
            NSCompoundPredicate(
                andPredicateWithSubpredicates: [
                    NSPredicate(format: "dish != %@", " " as String),
                    NSPredicate(format: "dish != %@", "Empty" as String)
                ]
            )
        ) var carbPresets: FetchedResults<Presets>

        @Environment(\.managedObjectContext) var moc
        @Environment(\.colorScheme) var colorScheme
        @EnvironmentObject var mainState: Main.StateModel

        init(
            resolver: Resolver,
            editMode: Bool,
            override: Bool,
            mode: MealMode.Mode
        ) {
            self.resolver = resolver
            self.editMode = editMode
            self.override = override
            self.mode = mode
            _state = StateObject(wrappedValue: StateModel(resolver: resolver))
        }

        private static let formatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }()

        private func format(_ value: Decimal) -> String {
            Self.formatter.string(from: value as NSNumber) ?? ""
        }

        var body: some View {
            content
                .background(Color(.systemGroupedBackground))
                .compactSectionSpacing()
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(leading: leadingNavItem, trailing: trailingNavItem)
                .sheet(isPresented: $foodSearchState.showingSettings) {
                    FoodSearchSettingsView(state: state)
                }
                .sheet(isPresented: $isPromptPresented) { editView }
                .confirmationDialog(
                    "Discard Meal?",
                    isPresented: $showCancelConfirmation,
                    titleVisibility: .visible,
                    actions: cancelDialogActions,
                    message: { Text("Do you want to discard this meal?") }
                )
                .onAppear(perform: handleOnAppear)
                .onDisappear { mainState.shouldPreventModalDismiss = false }
                .onChange(of: shouldPreventDismiss) { syncDismissState() }
                .onChange(of: foodSearchState.showSavedFoods) { syncDismissState() }
                .onChange(of: carbPresets.count) { updateSavedFoods() }
                .sheet(isPresented: $foodSearchState.showNewSavedFoodEntry) { foodItemEditorSheet }

                // MARK: - Automatische Dauer-Neuberechnung bei jeder Makro-Anpassung

                .onChange(of: state.carbs) { _ in updateDuration() }
                .onChange(of: state.fat) { _ in updateDuration() }
                .onChange(of: state.protein) { _ in updateDuration() }
        }

        @ViewBuilder private var content: some View {
            VStack(spacing: 0) {
                FoodSearchBar(rootState: state, state: foodSearchState)
                    .padding(.horizontal)

                if foodSearchState.showingFoodSearch {
                    foodSearchView
                } else {
                    mealView
                }
            }
        }

        private var foodSearchView: some View {
            FoodSearchView(
                state: foodSearchState,
                onContinue: handleFoodContinue,
                onHypoTreatment: hypoHandler,
                onPersist: saveOrUpdatePreset,
                onDelete: deletePreset,
                continueButtonLabelKey: continueLabel,
                hypoTreatmentButtonLabelKey: "Hypo Treatment"
            )
        }

        @ViewBuilder private var foodItemEditorSheet: some View {
            FoodItemEditorSheet(
                existingItem: foodSearchState.newFoodEntryToEdit,
                title: NSLocalizedString("Add Food Manually", comment: ""),
                allExistingTags: Set(foodSearchState.savedFoods?.foodItems.flatMap { $0.tags ?? [] } ?? []),
                showTagsAndFavorite: true,
                onSave: { foodItem in
                    saveOrUpdatePreset(foodItem)
                    foodSearchState.showNewSavedFoodEntry = false
                    foodSearchState.newFoodEntryToEdit = nil
                },
                onCancel: {
                    foodSearchState.showNewSavedFoodEntry = false
                    foodSearchState.newFoodEntryToEdit = nil
                }
            )
        }

        // FIX: Sicheres Auslesen der Makros für Hypo Handler
        private var hypoHandler: ((FoodItemDetailed, UIImage?, Date?) -> Void)? {
            guard state.id != nil,
                  state.id != "None",
                  state.carbsRequired != nil else { return nil }

            return { food, _, date in
                button.toggle()
                guard button else { return }

                state.hypoTreatment = true
                if let carbs = food.nutrition.values[.carbs] { state.carbs += carbs }
                if let fat = food.nutrition.values[.fat] { state.fat += fat }
                if let protein = food.nutrition.values[.protein] { state.protein += protein }
                if let d = date { state.date = d }

                let customDur = state.customDuration > 0 ? Double(truncating: state.customDuration as NSNumber) : nil
                state.add(override, fetch: editMode, customDuration: customDur)
            }
        }

        private var navigationTitle: LocalizedStringKey {
            foodSearchState.showSavedFoods ? "Saved Foods" : "Add Meal"
        }

        @ViewBuilder private var leadingNavItem: some View {
            if foodSearchState.showSavedFoods {
                Button(action: {
                    foodSearchState.showNewSavedFoodEntry = true
                }) {
                    Label("New", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.blue)
                }
            }
        }

        private var trailingNavItem: some View {
            Button(action: handleDismissAction) {
                Text(foodSearchState.showSavedFoods ? "Done" : "Cancel")
            }
        }

        private var continueLabel: LocalizedStringKey {
            (state.skipBolus && !override && !editMode) ? "Save" : "Continue"
        }

        @ViewBuilder private func cancelDialogActions() -> some View {
            Button("Discard", role: .destructive) {
                state.hideModal()
                if editMode { state.apsManager.determineBasalSync() }
            }
            Button("Cancel", role: .cancel) {}
        }

        private var mealView: some View {
            Form {
                if let carbsReq = state.carbsRequired, state.carbs < carbsReq {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                            Text("Carbs required")
                            Spacer()
                            Text((Self.formatter.string(from: carbsReq as NSNumber) ?? "") + " g")
                                .bold().foregroundColor(.orange)
                        }
                    }
                }

                Section {
                    mealPresets

                    HStack {
                        Image(systemName: "leaf.fill").foregroundColor(.primary).frame(width: 30)
                        Text("Carbs").fontWeight(.semibold)
                        Spacer()
                        DecimalTextField(
                            "0",
                            value: $state.carbs,
                            formatter: Self.formatter,
                            autofocus: true,
                            liveEditing: true
                        )
                        Text("grams").foregroundColor(.secondary)
                    }

                    if state.useFPUconversion {
                        proteinAndFat()
                    }

                    // MARK: - Waiters Notepad Zusammenfassung

                    if state.combinedPresets.isNotEmpty {
                        let summary = state.waitersNotepad()
                        if summary.isNotEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(summary, id: \.self) { item in
                                        Text(item)
                                            .font(.footnote.weight(.semibold))
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(Color.green.opacity(0.15))
                                            .foregroundColor(.green)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // Time
                    HStack {
                        Image(systemName: "clock.fill").foregroundColor(.gray).frame(width: 30)
                        Text("Uhrzeit")
                        Spacer()
                        if !pushed {
                            Button {
                                pushed = true
                            } label: { Text("Jetzt") }.buttonStyle(.borderless).foregroundColor(.secondary).padding(.trailing, 5)
                        } else {
                            Button { state.date = state.date.addingTimeInterval(-15.minutes.timeInterval) }
                            label: { Image(systemName: "minus.circle") }.tint(.blue).buttonStyle(.borderless)
                            DatePicker(
                                "Time",
                                selection: $state.date,
                                displayedComponents: [.hourAndMinute]
                            ).controlSize(.mini)
                                .labelsHidden()
                            Button {
                                state.date = state.date.addingTimeInterval(15.minutes.timeInterval)
                            }
                            label: { Image(systemName: "plus.circle") }.tint(.blue).buttonStyle(.borderless)
                        }
                    }
                }

                // MARK: - Verstoffwechselung & KI

                Section(header: Text("VERSTOFFWECHSELUNG & KI").textCase(.uppercase).foregroundColor(.secondary)) {
                    let rule = state.evaluateMeal()
                    let standardDuration = state.getIAPSStandardDuration()

                    HStack {
                        Image(systemName: "sparkles").foregroundColor(.purple).frame(width: 30)
                        Text("Typ")
                        Spacer()
                        Text(rule?.category ?? "Standard")
                            .font(.caption).fontWeight(.semibold)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    if standardDuration > 0 {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal").foregroundColor(.blue).frame(width: 30)
                            Text("iAPS Standard")
                            Spacer()
                            Text("\(String(format: "%.1f", standardDuration)) h").foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Image(systemName: "timer").foregroundColor(.orange).frame(width: 30)
                        Text("Dauer (anpassbar)")
                        Spacer()
                        DecimalTextField("0", value: $state.customDuration, formatter: Self.formatter, liveEditing: true)
                        Text("h").foregroundColor(.secondary)
                    }
                }

                if !empty, !saved {
                    Button { saveAsPreset() }
                    label: {
                        Text("Save as preset").foregroundStyle(.orange)
                    }
                    .buttonStyle(.borderless)
                    .listRowBackground(Color(.systemGroupedBackground))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // Optional Hypo Treatment
                if state.carbs > 0, let profile = state.id, profile != "None", state.carbsRequired != nil {
                    Section {
                        Button {
                            state.hypoTreatment = true
                            button.toggle()
                            if button { state.add(override, fetch: editMode) }
                        }
                        label: {
                            Text("Hypo Treatment")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }.listRowBackground(Color(.orange).opacity(0.9)).tint(.white)
                }

                Section {
                    Button {
                        button.toggle()
                        if button {
                            let customDur = state.customDuration > 0 ? Double(truncating: state.customDuration as NSNumber) : nil
                            state.add(override, fetch: editMode, customDuration: customDur)
                        }
                    }
                    label: {
                        Text(
                            ((state.skipBolus && !override && !editMode) || state.carbs <= 0) ? "Save Meal" :
                                "Continue"
                        ) }
                        .disabled(empty)
                        .frame(maxWidth: .infinity, alignment: .center)
                }.listRowBackground(!empty ? Color(.systemBlue) : Color(.systemGray4))
                    .tint(.white)
            }
            .sheet(isPresented: $presentPresets, content: { presetView })
        }

        private var meal: Bool {
            mode == .meal
        }

        private var hasUnsavedFoodSearchResults: Bool {
            foodSearchState.showingFoodSearch && foodSearchState.searchResultsState.nonDeletedItems.isNotEmpty
        }

        // MARK: - Helper Functions

        private func updateDuration() {
            if let rule = state.evaluateMeal() {
                state.customDuration = Decimal(rule.durationHours)
            } else {
                state.customDuration = Decimal(state.getIAPSStandardDuration())
            }
        }

        // Opens an edit-and-save View
        private func saveAsPreset() {
            foodSearchState.newFoodEntryToEdit = FoodItemDetailed(
                name: "New",
                nutrition: FoodNutrition.perServing(
                    values: [
                        .carbs: state.carbs,
                        .protein: state.protein,
                        .fat: state.fat
                    ],
                    servingsMultiplier: 1.0
                ),
                source: .manual
            )
            foodSearchState.showNewSavedFoodEntry = true
            saved.toggle()
        }

        // FIX: Sicheres Auslesen der Makros beim Fortfahren der Suche
        private func handleFoodContinue(_ food: FoodItemDetailed, _: UIImage?, date: Date?) {
            button.toggle()
            guard button else { return }

            state.hypoTreatment = false
            if let carbs = food.nutrition.values[.carbs] { state.carbs += carbs }
            if let fat = food.nutrition.values[.fat] { state.fat += fat }
            if let protein = food.nutrition.values[.protein] { state.protein += protein }
            if let d = date { state.date = d }

            let customDur = state.customDuration > 0 ? Double(truncating: state.customDuration as NSNumber) : nil
            state.add(override, fetch: editMode, customDuration: customDur)
        }

        private func handleOnAppear() {
            syncDismissState()

            state.loadEntries(editMode)
            addMissingFoodIDs()
            updateSavedFoods()
            updateDuration()

            guard !meal else { return }

            switch mode {
            case .image:
                if state.ai {
                    showFoodSearch(.camera)
                }
            case .barcode:
                showFoodSearch(.barcodeScanner)
            case .presets:
                foodSearchState.showingFoodSearch = true
                foodSearchState.showSavedFoods = true
            default:
                break
            }
        }

        private func syncDismissState() {
            mainState.shouldPreventModalDismiss = shouldPreventDismiss
        }

        private func showFoodSearch(_ route: FoodSearchRoute) {
            foodSearchState.foodSearchRoute = route
            foodSearchState.showingFoodSearch = true
        }

        @ViewBuilder private func proteinAndFat() -> some View {
            HStack {
                Image(systemName: "drop.fill").foregroundColor(.blue).frame(width: 30)
                Text("Fat").foregroundColor(.blue)
                Spacer()
                DecimalTextField(
                    "0",
                    value: $state.fat,
                    formatter: Self.formatter,
                    autofocus: false,
                    liveEditing: true
                )
                Text("grams").foregroundColor(.secondary)
            }
            HStack {
                Image(systemName: "bolt.fill").foregroundColor(.green).frame(width: 30)
                Text("Protein").foregroundColor(.green)
                Spacer()
                DecimalTextField(
                    "0",
                    value: $state.protein,
                    formatter: Self.formatter,
                    autofocus: false,
                    liveEditing: true
                )
                Text("grams").foregroundColor(.secondary)
            }
        }

        // Transform Presets to FoodItemDetailed
        private func transformPresetsToFoodItems(_ presets: FetchedResults<Presets>) -> [FoodItemDetailed] {
            presets.compactMap { preset -> FoodItemDetailed? in
                FoodItemDetailed.fromPreset(preset: preset)
            }
        }

        private func addMissingFoodIDs() {
            let noId = carbPresets.filter { $0.foodID == nil }
            if noId.isNotEmpty {
                for preset in noId {
                    preset.foodID = UUID()
                }
                do {
                    try moc.save()
                } catch {
                    print("Couldn't save presets after adding IDs: \(error.localizedDescription)")
                }
            }
        }

        // Update savedFoods when presets change
        private func updateSavedFoods() {
            let foodItems = transformPresetsToFoodItems(carbPresets)
            foodSearchState.savedFoods = FoodItemGroup(
                foodItems: foodItems,
                briefDescription: nil,
                overallDescription: nil,
                diabetesConsiderations: nil,
                source: .database,
                barcode: nil,
                textQuery: nil
            )
        }

        // MARK: - Food Search Section

        private func saveOrUpdatePreset(_ food: FoodItemDetailed) {
            guard food.name.isNotEmpty else { return }

            let existingPreset = carbPresets.first(where: { preset in
                preset.foodID == food.id
            })

            let preset = existingPreset ?? Presets(context: moc)

            food.updatePreset(preset: preset)

            do {
                try moc.save()
                updateSavedFoods()
            } catch {
                print("Couldn't save " + (preset.dish ?? "new preset."))
            }
        }

        private func deletePreset(_ food: FoodItemDetailed) {
            // Find preset by food ID
            if let presetToDelete = carbPresets.first(where: { preset in
                preset.foodID == food.id
            }) {
                moc.delete(presetToDelete)
                do {
                    try moc.save()
                } catch {
                    debug(.apsManager, "Couldn't delete meal preset for food: \(food.name).")
                }
            }
        }

        private var empty: Bool {
            state.carbs <= 0 && state.fat <= 0 && state.protein <= 0
        }

        private var mealPresets: some View {
            Section {
                HStack {
                    if state.selection == nil {
                        Text("Gespeichertes Essen").foregroundColor(.primary)
                        Spacer()
                        Button(action: { presentPresets.toggle() }) {
                            Image(systemName: "chevron.right").foregroundColor(.secondary).font(.caption).padding(.leading, 20)
                        }
                    } else {
                        minusButton
                        Spacer()

                        VStack(spacing: 2) {
                            // Holt sich die aktuellen Portionen sicher aus dem StateModel
                            let portions = state.combinedPresets.first(where: { $0.preset == state.selection })?.portions ?? 1.0
                            Text("\(format(Decimal(portions)))x").font(.caption).foregroundColor(.secondary)

                            Button { presentPresets.toggle() }
                            label: {
                                Text(state.selection?.dish ?? NSLocalizedString("Saved Food", comment: ""))
                                    .fontWeight(.semibold).foregroundColor(.primary)
                                    .lineLimit(1).truncationMode(.tail)
                            }
                        }

                        Spacer()
                        plusButton
                    }
                }
            }.dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }

        private var minusButton: some View {
            Button {
                state.subtract()
                if empty {
                    state.selection = nil
                    state.combinedPresets = []
                }
            }
            label: { Image(systemName: "minus.circle.fill").font(.title2).foregroundColor(.blue) }
                .buttonStyle(.borderless)
                .disabled(state.selection == nil)
        }

        private var plusButton: some View {
            Button {
                state.plus()
            }
            label: { Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.blue) }
                .buttonStyle(.borderless)
                .disabled(state.selection == nil)
        }

        private var presetView: some View {
            Form {
                Section {} header: { back }

                if !empty {
                    Section {
                        Button {
                            addfromCarbsView()
                        }
                        label: {
                            HStack {
                                Text("Save as Preset")
                                Spacer()
                                Text(
                                    "[Carbs: \(format(state.carbs)), Fat: \(format(state.fat)), Protein: \(format(state.protein))]"
                                )
                            }
                        }.frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color(.systemBlue)).tint(.white)
                    }
                    header: { Text("Save") }
                }

                let filtered = carbPresets.filter { !($0.dish ?? "").isEmpty && ($0.dish ?? "Empty") != "Empty" }
                    .removeDublicates()
                if filtered.count > 4 {
                    Section {
                        TextField("Search", text: $string)
                    } header: { Text("Search") }
                }
                let data = string.isEmpty ? filtered : carbPresets
                    .filter { ($0.dish ?? "").localizedCaseInsensitiveContains(string) }

                Section {
                    ForEach(data, id: \.self) { preset in
                        presetsList(for: preset)
                    }.onDelete(perform: delete)
                } header: {
                    HStack {
                        Text("Saved Food")
                        Button {
                            state.presetToEdit = Presets(context: moc)
                            newPreset = (NSLocalizedString("New", comment: ""), 0, 0, 0)
                            state.edit = true
                        } label: { Image(systemName: "plus").font(.system(size: 22)) }
                            .buttonStyle(.borderless).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .sheet(isPresented: $state.edit, content: { editView })
            .environment(\.colorScheme, colorScheme)
        }

        private var back: some View {
            Button { reset() }
            label: { Image(systemName: "chevron.backward").font(.system(size: 22)).padding(5) }
                .foregroundStyle(.primary)
                .buttonBorderShape(.circle)
                .buttonStyle(.borderedProminent)
                .tint(colorScheme == .light ? Color.white.opacity(0.5) : Color(.systemGray5))
                .offset(x: -10)
        }

        @ViewBuilder private func presetsList(for preset: Presets) -> some View {
            let dish = preset.dish ?? ""

            if !preset.hasChanges {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(dish).font(.headline).foregroundColor(.primary)

                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "leaf.fill").foregroundColor(.primary)
                                Text("\(format((preset.carbs as Decimal?) ?? 0))g")
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "drop.fill").foregroundColor(.blue)
                                Text("\(format((preset.fat as Decimal?) ?? 0))g")
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill").foregroundColor(.green)
                                Text("\(format((preset.protein as Decimal?) ?? 0))g")
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 4)
                    .onTapGesture {
                        state.selection = preset
                        state.addU(state.selection)
                        reset()
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            state.edit = true
                            state.presetToEdit = preset
                            update()
                        } label: {
                            Label("Edit", systemImage: "pencil.line")
                        }
                    }
                }
            }
        }

        private func delete(at offsets: IndexSet) {
            for index in offsets {
                let preset = carbPresets[index]
                moc.delete(preset)
            }
            do {
                try moc.save()
            } catch {
                debug(.apsManager, "Couldn't delete meal preset at \(offsets).")
            }
        }

        private func save() {
            if let preset = state.presetToEdit {
                preset.dish = newPreset.dish
                preset.carbs = newPreset.carbs as NSDecimalNumber
                preset.fat = newPreset.fat as NSDecimalNumber
                preset.protein = newPreset.protein as NSDecimalNumber
            } else if !disabled {
                let preset = Presets(context: moc)
                preset.carbs = newPreset.carbs as NSDecimalNumber
                preset.fat = newPreset.fat as NSDecimalNumber
                preset.protein = newPreset.protein as NSDecimalNumber
                preset.dish = newPreset.dish
            }

            if moc.hasChanges {
                do {
                    try moc.save()
                } catch { debug(.apsManager, "Failed to save \(moc.updatedObjects)") }
            }
            state.edit = false
            isPromptPresented = false
        }

        private func update() {
            newPreset.dish = state.presetToEdit?.dish ?? ""
            newPreset.carbs = (state.presetToEdit?.carbs as Decimal?) ?? 0
            newPreset.fat = (state.presetToEdit?.fat as Decimal?) ?? 0
            newPreset.protein = (state.presetToEdit?.protein as Decimal?) ?? 0
        }

        private func addfromCarbsView() {
            newPreset = (
                NSLocalizedString("New", comment: ""),
                state.carbs.rounded(to: 1),
                state.fat.rounded(to: 1),
                state.protein.rounded(to: 1)
            )
            state.edit = true
        }

        private func reset() {
            presentPresets = false
            string = ""
        }

        private var disabled: Bool {
            (newPreset == (NSLocalizedString("New", comment: ""), 0, 0, 0)) || (newPreset.dish == "") ||
                (newPreset.carbs + newPreset.fat + newPreset.protein <= 0)
        }

        /// Determines if the view should prevent interactive dismissal (swipe down)
        private var shouldPreventDismiss: Bool {
            // Prevent dismiss if showing saved foods OR if there are unsaved changes
            if foodSearchState.showSavedFoods {
                return true // Block swipe when saved foods are shown
            } else if hasUnsavedFoodSearchResults {
                return true // Block swipe when there are unsaved food search results
            } else {
                return false // Allow swipe in other cases
            }
        }

        /// Handles the dismiss action from the Cancel/Done button
        private func handleDismissAction() {
            // If showing saved foods, just close them
            if foodSearchState.showSavedFoods {
                withAnimation(.easeInOut(duration: 0.3)) {
                    foodSearchState.showSavedFoods = false
                }
                return
            }

            // If there are unsaved food search results, show confirmation
            if hasUnsavedFoodSearchResults {
                showCancelConfirmation = true
                return
            }

            // Otherwise, just dismiss
            state.hideModal()
            if editMode { state.apsManager.determineBasalSync() }
        }

        private var editView: some View {
            Form {
                Section {
                    HStack {
                        TextField("", text: $newPreset.dish)
                    }
                    HStack {
                        Image(systemName: "leaf.fill").foregroundColor(.primary).frame(width: 30)
                        Text("Carbs").foregroundStyle(.secondary)
                        Spacer()
                        DecimalTextField("0", value: $newPreset.carbs, formatter: Self.formatter, liveEditing: true)
                    }
                    HStack {
                        Image(systemName: "drop.fill").foregroundColor(.blue).frame(width: 30)
                        Text("Fat").foregroundStyle(.secondary)
                        Spacer()
                        DecimalTextField("0", value: $newPreset.fat, formatter: Self.formatter, liveEditing: true)
                    }
                    HStack {
                        Image(systemName: "bolt.fill").foregroundColor(.green).frame(width: 30)
                        Text("Protein").foregroundStyle(.secondary)
                        Spacer()
                        DecimalTextField("0", value: $newPreset.protein, formatter: Self.formatter, liveEditing: true)
                    }
                } header: { Text("Saved Food") }

                Section {
                    Button { save() }
                    label: { Text("Save") }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(!disabled ? Color(.systemBlue) : Color(.systemGray4))
                        .tint(.white)
                        .disabled(disabled)
                }
            }.environment(\.colorScheme, colorScheme)
        }
    }
}
