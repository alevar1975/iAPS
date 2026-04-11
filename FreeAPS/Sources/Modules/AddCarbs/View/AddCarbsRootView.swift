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

        // States für den Alert
        @State private var activeRule: IAPSMealRule? = nil
        @State private var showMealAlert = false

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
        @State private var showingFoodSearch = false
        @State private var foodSearchText = ""
        @State private var searchResults: [FoodItem] = []
        @State private var isLoading = false
        @State private var errorMessage: String?
        @State private var selectedFoodItem: AIFoodItem?
        @State private var portionGrams: Double = 100.00001
        @State private var selectedFoodImage: UIImage?
        @State private var saveAlert = false

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

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }

        var body: some View {
            if meal {
                normalMealView
            } else {
                shortcuts()
            }
        }

        private var mealView: some View {
            Form {
                if state.ai {
                    foodSearch
                }

                if let carbsReq = state.carbsRequired, state.carbs < carbsReq {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Carbs required")
                                .fontWeight(.medium)
                            Spacer()
                            Text((formatter.string(from: carbsReq as NSNumber) ?? "") + " g")
                                .bold()
                                .foregroundColor(.orange)
                        }
                    }
                }

                Section {
                    mealPresets.padding(.vertical, 4)

                    MacroInputRow(
                        title: "Carbs",
                        icon: "leaf.fill",
                        color: .primary,
                        value: $state.carbs,
                        formatter: formatter,
                        unit: "g"
                    )

                    if state.useFPUconversion {
                        MacroInputRow(
                            title: "Fat",
                            icon: "drop.fill",
                            color: .blue,
                            value: $state.fat,
                            formatter: formatter,
                            unit: "g"
                        )
                        MacroInputRow(
                            title: "Protein",
                            icon: "bolt.fill",
                            color: .green,
                            value: $state.protein,
                            formatter: formatter,
                            unit: "g"
                        )
                    }

                    if state.combinedPresets.isNotEmpty {
                        let summary = state.waitersNotepad()
                        if summary.isNotEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Total Summary")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(summary, id: \.self) { item in
                                            Text(item)
                                                .font(.footnote.weight(.semibold))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.green.opacity(0.15))
                                                .foregroundColor(.green)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.gray)
                            .font(.title3)
                            .frame(width: 30)

                        Text("Time")
                            .fontWeight(.medium)

                        Spacer()

                        if !pushed {
                            Button {
                                withAnimation(.spring()) { pushed = true }
                            } label: {
                                Text("Now")
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.primary)
                        } else {
                            HStack(spacing: 12) {
                                Button { state.date = state.date.addingTimeInterval(-15.minutes.timeInterval) }
                                label: { Image(systemName: "minus") }
                                    .buttonStyle(.bordered)
                                    .buttonBorderShape(.circle)
                                    .tint(.blue)

                                DatePicker(
                                    "Time",
                                    selection: $state.date,
                                    displayedComponents: [.hourAndMinute]
                                )
                                .controlSize(.mini)
                                .labelsHidden()

                                Button {
                                    state.date = state.date.addingTimeInterval(15.minutes.timeInterval)
                                }
                                label: { Image(systemName: "plus") }
                                    .buttonStyle(.bordered)
                                    .buttonBorderShape(.circle)
                                    .tint(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if state.carbs > 0, let profile = state.id, profile != "None", state.carbsRequired != nil {
                    Section {
                        Button {
                            state.hypoTreatment = true
                            button.toggle()
                            if button { state.add(override, fetch: editMode, customDuration: nil) }
                        } label: {
                            HStack {
                                Image(systemName: "cross.case.fill")
                                Text("Hypo Treatment")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                        }
                    }
                    .listRowBackground(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.orange, Color.red.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .tint(.white)
                }

                // 🟢 NEU: KI Typ, iAPS Berechnung & Dauer (anpassbar)
                Section(header: Text("Verstoffwechselung & KI").textCase(.uppercase)) {
                    let rule = state.evaluateMeal()
                    let standardDuration = state.getIAPSStandardDuration()

                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                            .font(.title3)
                            .frame(width: 30)

                        Text("Typ")
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Spacer()

                        Text(rule?.category ?? "Standard")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(rule != nil ? Color.purple.opacity(0.15) : Color.secondary.opacity(0.15))
                            .foregroundColor(rule != nil ? .purple : .secondary)
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)

                    // Zeigt den iAPS Standardwert als Referenz an (nur wenn FPU im Spiel ist)
                    if standardDuration > 0 {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .foregroundColor(.blue)
                                .font(.title3)
                                .frame(width: 30)

                            Text("iAPS Standard")
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            Spacer()

                            Text("\(String(format: "%.1f", standardDuration)) h")
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    // Die manuelle / überschreibbare Zeit
                    MacroInputRow(
                        title: "Dauer (anpassbar)",
                        icon: "timer",
                        color: .orange,
                        value: $state.customDuration,
                        formatter: formatter,
                        unit: "h"
                    )
                }
                .onChange(of: state.carbs) { _ in updateDuration() }
                .onChange(of: state.fat) { _ in updateDuration() }
                .onChange(of: state.protein) { _ in updateDuration() }
                .onAppear { updateDuration() }

                Section {
                    Button {
                        proceedWithSave(
                            customDuration: state
                                .customDuration > 0 ? Double(truncating: state.customDuration as NSNumber) : nil
                        )
                    } label: {
                        Text(((state.skipBolus && !override && !editMode) || state.carbs <= 0) ? "Save Meal" : "Continue")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    }
                    .disabled(empty)
                }
                .listRowBackground(
                    empty ? Color(.systemGray5) : Color(.systemBlue)
                )
                .tint(empty ? .secondary : .white)
            }
            .compactSectionSpacing()
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: Button("Cancel", action: {
                state.hideModal()
                if editMode { state.apsManager.determineBasalSync() }
            }))
            .sheet(isPresented: $presentPresets, content: { presetView })
            .sheet(isPresented: $showingFoodSearch) {
                FoodSearchView(
                    state: foodSearchState,
                    onSelect: { selectedFood, image in handleSelectedFood(selectedFood, image: image) }
                )
            }
            .alert(isPresented: $saveAlert) { alert(food: selectedFoodItem) }
        }

        // 🟢 Aktualisiert die Dauer automatisch, wenn Makros geändert werden. KI gewinnt, ansonsten iAPS Standard.
        private func updateDuration() {
            if let rule = state.evaluateMeal() {
                state.customDuration = Decimal(rule.durationHours)
            } else {
                state.customDuration = Decimal(state.getIAPSStandardDuration())
            }
        }

        private func proceedWithSave(customDuration: Double? = nil) {
            button.toggle()
            if button { state.add(override, fetch: editMode, customDuration: customDuration) }
        }

        private var meal: Bool {
            mode == .meal || foodSearchState.mealView
        }

        @ViewBuilder private func shortcuts() -> some View {
            switch mode {
            case .image: imageView
            case .barcode: barcodeView
            case .presets: mealPresetsView
            case .search: foodsearchView
            default: normalMealView
            }
        }

        private var normalMealView: some View { mealView.onAppear { state.loadEntries(editMode) } }
        private var imageView: some View { mealView.onAppear { state.loadEntries(editMode)
            showingFoodSearch.toggle()
            foodSearchState.navigateToAICamera = true } }
        private var barcodeView: some View { mealView.onAppear { state.loadEntries(editMode)
            showingFoodSearch.toggle()
            foodSearchState.navigateToBarcode.toggle() } }
        private var mealPresetsView: some View { mealView.onAppear { state.loadEntries(editMode)
            presentPresets.toggle() } }
        private var foodsearchView: some View { mealView.onAppear { state.loadEntries(editMode)
            showingFoodSearch.toggle() } }

        private var foodSearch: some View {
            Group {
                foodSearchSection
                if let selectedFood = selectedFoodItem {
                    SelectedFoodView(
                        food: selectedFood,
                        foodImage: selectedFoodImage,
                        portionGrams: $portionGrams,
                        onChange: {
                            selectedFoodItem = nil
                            selectedFoodImage = nil
                            showingFoodSearch = true
                        },
                        onTakeOver: { food in
                            state.carbs += portionGrams != 100.00001 ? Decimal(max(food.carbs, 0) / (portionGrams / 100))
                                .rounded(to: 0) : Decimal(max(food.carbs, 0))
                            state.fat += portionGrams != 100.00001 ? Decimal(max(food.fat, 0) / (portionGrams / 100))
                                .rounded(to: 0) : Decimal(max(food.fat, 0))
                            state.protein += portionGrams != 100.00001 ? Decimal(max(food.protein, 0) / (portionGrams / 100))
                                .rounded(to: 0) : Decimal(max(food.protein, 0))
                            selectedFoodImage = nil
                            showingFoodSearch = false
                            if !state.skipSave { saveAlert.toggle() } else { cache(food: selectedFood) }
                        }
                    )
                }
            }
        }

        private var foodSearchSection: some View {
            Section {
                Button { showingFoodSearch = true } label: {
                    HStack {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.multicolor)
                        Text("Search Food Database")
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.popUpGray)
                            .font(.system(size: 14, weight: .bold))
                    }.foregroundColor(.blue)
                }.buttonStyle(PlainButtonStyle())
            } header: {
                HStack {
                    Text("AI Food Search")
                        .textCase(.uppercase)
                    Spacer()
                    NavigationLink(destination: AISettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }

        private func cache(food: AIFoodItem) {
            let cache = Presets(context: moc)
            cache.carbs = Decimal(food.carbs) as NSDecimalNumber
            cache.fat = Decimal(food.fat) as NSDecimalNumber
            cache.protein = Decimal(food.protein) as NSDecimalNumber
            cache.dish = (portionGrams != 100.00001) ? food.name + " \(portionGrams)g" : food.name

            if state.selection?.dish != cache.dish {
                state.selection = cache
                state.combinedPresets.append((state.selection, 1))
            } else if state.combinedPresets.last != nil {
                state.combinedPresets[state.combinedPresets.endIndex - 1].portions += 1
            }
        }

        private func addToPresetsIfNew(food: AIFoodItem) {
            let preset = Presets(context: moc)
            preset
                .carbs = (portionGrams != 100.0 || portionGrams != 100.00001) ?
                (Decimal(max(food.carbs * (portionGrams / 100), 0)).rounded(to: 1) as NSDecimalNumber) :
                Decimal(max(food.carbs, 0)) as NSDecimalNumber
            preset
                .fat = (portionGrams != 100.0 || portionGrams != 100.00001) ?
                (Decimal(max(food.fat * (portionGrams / 100), 0)).rounded(to: 1) as NSDecimalNumber) :
                Decimal(max(food.fat, 0)) as NSDecimalNumber
            preset
                .protein = (portionGrams != 100.0 || portionGrams != 100.00001) ?
                (Decimal(max(food.protein * (portionGrams / 100), 0)).rounded(to: 1) as NSDecimalNumber) :
                Decimal(max(food.protein, 0)) as NSDecimalNumber
            preset.dish = portionGrams != 100.00001 ? food.name + " \(portionGrams)g" : food.name

            if moc.hasChanges, !carbPresets.compactMap(\.dish).contains(preset.dish), !food.name.isEmpty {
                do {
                    try moc.save()
                    state.selection = preset
                    state.addPresetToNewMeal()
                    selectedFoodItem = nil
                } catch { print("Couldn't save " + (preset.dish ?? "new preset.")) }
            }
        }

        private func handleSelectedFood(_ foodItem: FoodItem) {
            let calculatedCalories = Double(truncating: foodItem.carbs as NSNumber) * 4 +
                Double(truncating: foodItem.protein as NSNumber) * 4 + Double(truncating: foodItem.fat as NSNumber) * 9
            let aiFoodItem = AIFoodItem(
                name: foodItem.name,
                brand: foodItem.source,
                calories: calculatedCalories,
                carbs: Double(truncating: foodItem.carbs as NSNumber),
                protein: Double(truncating: foodItem.protein as NSNumber),
                fat: Double(truncating: foodItem.fat as NSNumber),
                imageURL: foodItem.imageURL
            )
            selectedFoodItem = aiFoodItem
            portionGrams = 100.00001
            showingFoodSearch = false
        }

        private var empty: Bool { state.carbs <= 0 && state.fat <= 0 && state.protein <= 0 }

        private var mealPresets: some View {
            HStack {
                if state.selection == nil {
                    Button { presentPresets.toggle() } label: {
                        HStack {
                            Text(state.selection?.dish ?? NSLocalizedString("Saved Food", comment: ""))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    minusButton
                    Spacer()
                    Button { presentPresets.toggle() } label: {
                        HStack {
                            Text(state.selection?.dish ?? NSLocalizedString("Saved Food", comment: ""))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    Spacer()
                    plusButton
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }

        private var minusButton: some View {
            Button {
                withAnimation {
                    state.subtract()
                    if empty { state.selection = nil
                        state.combinedPresets = [] }
                }
            } label: {
                Image(systemName: "minus")
                    .font(.title3.weight(.bold))
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.2))
                    .foregroundColor(.primary)
                    .clipShape(Circle())
            }
            .buttonStyle(.borderless)
            .disabled(state.selection == nil)
        }

        private var plusButton: some View {
            Button {
                withAnimation { state.plus() }
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
                    .frame(width: 32, height: 32)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .clipShape(Circle())
            }
            .buttonStyle(.borderless)
            .disabled(state.selection == nil)
        }

        private var presetView: some View {
            Form {
                Section {} header: { back }
                if !empty {
                    Section {
                        Button { addfromCarbsView() } label: {
                            HStack {
                                Text("Save as Preset")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(
                                    "[ C: " + (formatter.string(from: state.carbs as NSNumber) ?? "") + " | F: " +
                                        (formatter.string(from: state.fat as NSNumber) ?? "") + " | P: " +
                                        (formatter.string(from: state.protein as NSNumber) ?? "") + " ]"
                                )
                                .font(.caption)
                                .opacity(0.9)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color(.systemBlue))
                        .tint(.white)
                    } header: { Text("Save") }
                }

                let filtered = carbPresets.filter { !($0.dish ?? "").isEmpty && ($0.dish ?? "Empty") != "Empty" }
                    .removeDublicates()

                if filtered.count > 4 {
                    Section {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                            TextField("Search", text: $string)
                        }
                    } header: { Text("Search") }
                }

                let data = string.isEmpty ? filtered : carbPresets
                    .filter { ($0.dish ?? "").localizedCaseInsensitiveContains(string) }

                Section {
                    ForEach(data, id: \.self) { preset in presetsList(for: preset) }.onDelete(perform: delete)
                } header: {
                    HStack {
                        Text("Saved Food")
                        Button {
                            state.presetToEdit = Presets(context: moc)
                            newPreset = (NSLocalizedString("New", comment: ""), 0, 0, 0)
                            state.edit = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.borderless)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .sheet(isPresented: $state.edit, content: { editView })
            .environment(\.colorScheme, colorScheme)
        }

        private var back: some View {
            Button { reset() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .padding(8)
            }
            .foregroundStyle(.primary)
            .background(Color(.systemGray5))
            .clipShape(Circle())
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 10)
        }

        private func alert(food: AIFoodItem?) -> Alert {
            if let food = food {
                return Alert(
                    title: Text(
                        NSLocalizedString("Save", comment: "") + " \"" + food
                            .name + "\" " + NSLocalizedString("as new Meal Preset?", comment: "")
                    ),
                    message: Text("To avoid having to search for same food on web again."),
                    primaryButton: .default(Text("Yes").bold(), action: { addToPresetsIfNew(food: food) }),
                    secondaryButton: .cancel(Text("No"), action: { cache(food: food) })
                )
            }
            return Alert(
                title: Text("Oops!"),
                message: Text(
                    NSLocalizedString("Something isnt't working with food item ", comment: "") + "\"" +
                        (food?.name ?? "nil")
                ),
                primaryButton: .cancel(Text("OK")),
                secondaryButton: .cancel()
            )
        }

        @ViewBuilder private func presetsList(for preset: Presets) -> some View {
            let dish = preset.dish ?? ""
            if !preset.hasChanges {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dish)
                            .font(.headline)
                        HStack(spacing: 12) {
                            Label("\(preset.carbs ?? 0)g", systemImage: "leaf.fill").foregroundColor(.primary)
                            Label("\(preset.fat ?? 0)g", systemImage: "drop.fill").foregroundColor(.blue)
                            Label("\(preset.protein ?? 0)g", systemImage: "bolt.fill").foregroundColor(.green)
                        }
                        .font(.caption2.weight(.bold))
                        .opacity(0.8)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            state.selection = preset
                            state.addU(state.selection)
                            reset()
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            state.edit = true
                            state.presetToEdit = preset
                            update()
                        } label: { Label("Edit", systemImage: "pencil") }
                            .tint(.orange)
                    }
                }
                .padding(.vertical, 4)
            }
        }

        private func delete(at offsets: IndexSet) {
            for index in offsets { moc.delete(carbPresets[index]) }
            do { try moc.save() } catch { debug(.apsManager, "Couldn't delete meal preset.") }
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
            if moc.hasChanges { do { try moc.save() } catch { debug(.apsManager, "Failed to save") } }
            state.edit = false
        }

        private func update() {
            newPreset.dish = state.presetToEdit?.dish ?? ""
            newPreset.carbs = (state.presetToEdit?.carbs ?? 0) as Decimal
            newPreset.fat = (state.presetToEdit?.fat ?? 0) as Decimal
            newPreset.protein = (state.presetToEdit?.protein ?? 0) as Decimal
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

        private func reset() { presentPresets = false
            string = "" }

        private var disabled: Bool {
            (newPreset == (NSLocalizedString("New", comment: ""), 0, 0, 0)) || (newPreset.dish == "") ||
                (newPreset.carbs + newPreset.fat + newPreset.protein <= 0) }

        private func handleSelectedFood(_ foodItem: FoodItem, image: UIImage? = nil) {
            let aiFoodItem = foodItem.toAIFoodItem()
            selectedFoodItem = aiFoodItem
            selectedFoodImage = image
            portionGrams = 100.0
            showingFoodSearch = false
        }

        private var editView: some View {
            Form {
                Section {
                    HStack { TextField("Dish Name", text: $newPreset.dish).font(.headline) }
                    MacroInputRow(
                        title: "Carbs",
                        icon: "leaf.fill",
                        color: .primary,
                        value: $newPreset.carbs,
                        formatter: formatter,
                        unit: "g"
                    )
                    MacroInputRow(
                        title: "Fat",
                        icon: "drop.fill",
                        color: .blue,
                        value: $newPreset.fat,
                        formatter: formatter,
                        unit: "g"
                    )
                    MacroInputRow(
                        title: "Protein",
                        icon: "bolt.fill",
                        color: .green,
                        value: $newPreset.protein,
                        formatter: formatter,
                        unit: "g"
                    )
                } header: { Text("Edit Saved Food") }

                Section {
                    Button { save() } label: {
                        Text("Save Preset")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(!disabled ? Color(.systemBlue) : Color(.systemGray4))
                    .tint(.white).disabled(disabled)
                }
            }.environment(\.colorScheme, colorScheme)
        }
    }
}

// Anpassbare Makro-Reihe mit Einheit (damit wir auch "h" für Stunden nutzen können)
struct MacroInputRow: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var value: Decimal
    let formatter: NumberFormatter
    var unit: String = "g"

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 30)

            Text(title)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Spacer()

            DecimalTextField(
                "0",
                value: $value,
                formatter: formatter,
                autofocus: false,
                liveEditing: true
            )
            .font(.title3.weight(.bold))
            .foregroundColor(color)

            Text(unit)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

public extension Color {
    static func randomGreen(randomOpacity: Bool = false) -> Color {
        Color(
            red: .random(in: 0 ... 1), green: .random(in: 0.4 ... 0.7), blue: .random(in: 0.2 ... 1),
            opacity: randomOpacity ? .random(in: 0.8 ... 1) : 1
        )
    }
}
