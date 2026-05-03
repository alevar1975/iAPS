import Foundation
import SwiftUI

struct FoodItemsSelectorView: View {
    let searchResult: FoodItemGroup
    let onFoodItemSelected: (FoodItemDetailed) -> Void
    let onFoodItemRemoved: (FoodItemDetailed) -> Void
    let isItemAdded: (FoodItemDetailed) -> Bool
    let onDismiss: () -> Void
    let onImageSearch: (String) async -> [ImageSearchResult]
    let onPersist: ((FoodItemDetailed) -> Void)?
    let onDelete: ((FoodItemDetailed) -> Void)?
    let useTransparentBackground: Bool

    var filterText: String = ""
    var showTagCloud: Bool = false

    @State private var selectedTags: Set<String> = []

    private var allExistingTags: Set<String> {
        Set(searchResult.foodItems.flatMap { $0.tags ?? [] })
    }

    private var displayTitle: String {
        if searchResult.source == .database {
            return "Saved Foods"
        } else if let query = searchResult.textQuery {
            return query
        } else {
            return "Search Results"
        }
    }

    private var allTags: [String] {
        var seen = Set<String>()
        var result: [String] = []
        var hasFavorites = false

        let matchingFoods: [FoodItemDetailed]
        if selectedTags.isEmpty {
            matchingFoods = searchResult.foodItems
        } else {
            matchingFoods = searchResult.foodItems.filter { foodItem in
                guard let tags = foodItem.tags else { return false }
                return selectedTags.allSatisfy { selectedTag in
                    tags.contains(selectedTag)
                }
            }
        }

        for foodItem in matchingFoods {
            if let tags = foodItem.tags {
                for tag in tags {
                    if tag == FoodTags.favorites {
                        hasFavorites = true
                    }
                    if !seen.contains(tag) {
                        seen.insert(tag)
                        if tag != FoodTags.favorites {
                            result.append(tag)
                        }
                    }
                }
            }
        }

        if hasFavorites {
            result.insert(FoodTags.favorites, at: 0)
        }

        return result
    }

    private var filteredFoodItems: [FoodItemDetailed] {
        let trimmedFilter = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var items = searchResult.foodItems

        if !trimmedFilter.isEmpty {
            items = items.filter { foodItem in
                foodItem.name.lowercased().contains(trimmedFilter)
            }
        }

        if !selectedTags.isEmpty {
            items = items.filter { foodItem in
                guard let tags = foodItem.tags else { return false }
                return selectedTags.allSatisfy { selectedTag in
                    tags.contains(selectedTag)
                }
            }
        }

        return items
    }

    var body: some View {
        Group {
            if filteredFoodItems.isEmpty && !filterText.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                            .padding(.top, 40)

                        Text("No foods found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .scrollDismissesKeyboard(.immediately)
            } else {
                List {
                    if showTagCloud && !allTags.isEmpty {
                        Section {
                            FoodTagCloudView(
                                tags: allTags,
                                selectedTags: $selectedTags
                            )
                            .padding(.vertical, 8)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(useTransparentBackground ? Color.clear : Color(.systemBackground))
                    }

                    ForEach(Array(filteredFoodItems.enumerated()), id: \.element.id) { index, foodItem in
                        if foodItem.name.isNotEmpty {
                            FoodItemsSelectorItemRow(
                                foodItem: foodItem,
                                onAdd: {
                                    onFoodItemSelected(foodItem)
                                },
                                onRemove: {
                                    onFoodItemRemoved(foodItem)
                                },
                                isAdded: isItemAdded(foodItem),
                                isFirst: index == 0,
                                isLast: index == filteredFoodItems.count - 1,
                                useTransparentBackground: useTransparentBackground,
                                onPersist: onPersist,
                                onDelete: onDelete,
                                onImageSearch: onImageSearch,
                                allExistingTags: allExistingTags
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden, edges: .top)
                            .listRowSeparator(
                                index != filteredFoodItems.count - 1 ? .visible : .hidden,
                                edges: .bottom
                            )
                            .listRowBackground(useTransparentBackground ? Color.clear : Color(.systemBackground))
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .onChange(of: allExistingTags) { _, newValue in
            selectedTags = selectedTags.intersection(newValue)
        }
    }
}

private struct FoodItemsSelectorItemRow: View {
    let foodItem: FoodItemDetailed
    let onAdd: () -> Void
    let onRemove: () -> Void
    let isAdded: Bool
    let isFirst: Bool
    let isLast: Bool
    let useTransparentBackground: Bool
    let onPersist: ((FoodItemDetailed) -> Void)?
    let onDelete: ((FoodItemDetailed) -> Void)?
    let onImageSearch: (String) async -> [ImageSearchResult]
    let allExistingTags: Set<String>

    @State private var showItemInfo = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showImageSelector = false
    @State private var isSavingImage = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                if onPersist != nil {
                    Button(action: {
                        showImageSelector = true
                    }) {
                        if isSavingImage {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(width: 60, height: 60)
                                .overlay(ProgressView().controlSize(.small))
                        } else if foodItem.imageURL != nil {
                            FoodItemThumbnail(imageURL: foodItem.imageURL)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    VStack(spacing: 2) {
                                        Image(systemName: "camera")
                                            .font(.system(size: 18))
                                            .foregroundColor(.secondary.opacity(0.6))
                                        Text("Add")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundColor(.secondary.opacity(0.6))
                                    }
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSavingImage)
                    .contextMenu {
                        if foodItem.imageURL != nil {
                            Button(role: .destructive) {
                                removeImage()
                            } label: {
                                Label("Remove Image", systemImage: "trash")
                            }
                        }
                    }
                } else {
                    FoodItemThumbnail(imageURL: foodItem.imageURL)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(foodItem.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button(action: isAdded ? onRemove : onAdd) {
                            Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(isAdded ? .green : .accentColor)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                    }

                    // MARK: - Die kompakten horizontalen Icons

                    HStack(spacing: 12) {
                        ForEach(NutrientType.allCases.filter { $0.isPrimary }) { nutrient in
                            HStack(spacing: 4) {
                                Image(systemName: icon(for: nutrient))
                                    .foregroundColor(color(for: nutrient))
                                    .font(.system(size: 12))
                                Text(
                                    "\(Double(truncating: (foodItem.nutrientInThisPortion(nutrient) ?? 0) as NSNumber), specifier: "%.1f")g"
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 12))
                            Text(
                                "\(Double(truncating: (foodItem.caloriesInThisPortion ?? 0) as NSNumber), specifier: "%.0f") kcal"
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                showItemInfo = true
            }
        }
        .padding(.top, isFirst ? 8 : 0)
        .padding(.bottom, isLast ? 8 : 0)
        .background(useTransparentBackground ? Color.clear : Color(.systemBackground))
        .when(onPersist != nil) { view in
            view.swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.orange)
            }
        }
        .when(onDelete != nil) { view in
            view.swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
        }
        .confirmationDialog(
            "Delete Saved Food",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                onDelete?(foodItem)
            }
            Button("Cancel", role: .cancel) {
                showDeleteConfirmation = false
            }
        } message: {
            Text(
                "Are you sure you want to permanently delete \"\(foodItem.name)\" from your saved foods? This action cannot be undone."
            )
        }
        .sheet(isPresented: $showItemInfo) {
            FoodItemInfoPopup(foodItem: foodItem)
                .presentationDetents([.height(foodItem.preferredInfoSheetHeight()), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showImageSelector) {
            ImageSelectorView(
                initialSearchTerm: foodItem.standardName ?? foodItem.name,
                onSave: { selectedImage in
                    handleImageSelection(selectedImage)
                },
                onSearch: onImageSearch
            )
        }
        .sheet(isPresented: $showEditSheet) {
            FoodItemEditorSheet(
                existingItem: foodItem,
                title: "Edit Saved Food",
                allExistingTags: allExistingTags,
                showTagsAndFavorite: true,
                onSave: handleSave,
                onCancel: {
                    showEditSheet = false
                }
            )
        }
    }

    private func handleSave(_ editedItem: FoodItemDetailed) {
        onPersist?(editedItem)
        showEditSheet = false
    }

    private func handleImageSelection(_ image: UIImage) {
        guard let onPersist = onPersist else { return }
        isSavingImage = true
        showImageSelector = false

        Task { @MainActor in
            if let imageURL = await FoodImageStorageManager.shared.saveImage(image, for: foodItem.id) {
                let updatedItem = foodItem.copy(imageURL: imageURL)
                onPersist(updatedItem)
            }
            isSavingImage = false
        }
    }

    private func removeImage() {
        guard let onPersist = onPersist else { return }
        let updatedItem = foodItem.copy(imageURL: .some(nil))
        onPersist(updatedItem)
    }

    // Helper für die Icons in der Suchliste
    private func icon(for nutrient: NutrientType) -> String {
        switch nutrient {
        case .carbs: return "leaf.fill"
        case .fat: return "drop.fill"
        case .protein: return "bolt.fill"
        default: return ""
        }
    }

    private func color(for nutrient: NutrientType) -> Color {
        switch nutrient {
        case .carbs: return .primary
        case .fat: return .blue
        case .protein: return .green
        default: return .secondary
        }
    }
}
