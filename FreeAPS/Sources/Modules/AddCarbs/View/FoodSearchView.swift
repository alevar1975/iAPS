import Combine
import SwiftUI

struct FoodSearchView: View {
    @ObservedObject var state: FoodSearchStateModel
    var onSelect: (FoodItem, UIImage?) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var showingAIAnalysisResults = false
    @State private var aiAnalysisResult: AIFoodAnalysisResult?
    @State private var aiAnalysisImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBarView
                contentView
            }
            .navigationTitle("Lebensmittel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .fullScreenCover(isPresented: $state.navigateToBarcode) {
                BarcodeScannerView(
                    onBarcodeScanned: handleBarcodeScan,
                    onCancel: { state.navigateToBarcode = false }
                )
            }
            .fullScreenCover(isPresented: $state.navigateToAICamera) {
                AICameraView(
                    onFoodAnalyzed: handleAIAnalysis,
                    onCancel: { state.navigateToAICamera = false }
                )
            }
        }
    }

    // MARK: - Subviews

    private var searchBarView: some View {
        HStack(spacing: 12) {
            pilledSearchField
            barcodeButton
            aiCameraButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .zIndex(1)
    }

    private var pilledSearchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Suchen...", text: $state.foodSearchText)
                .font(.system(.body, design: .rounded))
                .autocorrectionDisabled()
                .onSubmit { state.performSearch(query: state.foodSearchText) }

            if !state.foodSearchText.isEmpty {
                Button(action: {
                    state.foodSearchText = ""
                    state.searchResults = []
                    state.aiSearchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.ultraThinMaterial).clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    private var barcodeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            state.navigateToBarcode = true
        } label: {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 20)).foregroundColor(.blue)
                .frame(width: 44, height: 44).background(Color.blue.opacity(0.15)).clipShape(Circle())
        }
    }

    private var aiCameraButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            state.navigateToAICamera = true
        } label: {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 20)).foregroundColor(.purple)
                .frame(width: 44, height: 44).background(Color.purple.opacity(0.15)).clipShape(Circle())
        }
    }

    @ViewBuilder private var contentView: some View {
        if showingAIAnalysisResults, let result = aiAnalysisResult {
            AIAnalysisResultsView(
                analysisResult: result,
                onFoodItemSelected: { item in
                    // Hier sind die Werte bereits Decimal
                    self.convertToItemAndSelect(
                        name: item.name,
                        carbs: item.carbs,
                        fat: item.fat,
                        protein: item.protein,
                        source: "AI",
                        image: self.aiAnalysisImage
                    )
                },
                onCompleteMealSelected: { meal in
                    // Hier sind die Werte bereits Decimal
                    self.convertToItemAndSelect(
                        name: meal.name,
                        carbs: meal.carbs,
                        fat: meal.fat,
                        protein: meal.protein,
                        source: "AI",
                        image: self.aiAnalysisImage
                    )
                }
            )
        } else {
            FoodSearchResultsView(
                searchResults: state.searchResults,
                aiSearchResults: state.aiSearchResults,
                isSearching: state.isLoading,
                errorMessage: state.errorMessage,
                onProductSelected: { p in
                    // Hier konvertieren wir Double -> Decimal
                    self.convertToItemAndSelect(
                        name: p.productName ?? "Unknown",
                        carbs: Decimal(p.nutriments.carbohydrates ?? 0),
                        fat: Decimal(p.nutriments.fat ?? 0),
                        protein: Decimal(p.nutriments.proteins ?? 0),
                        source: "OpenFoodFacts",
                        url: p.imageFrontURL ?? p.imageURL
                    )
                },
                onAIProductSelected: { item in
                    // Hier konvertieren wir Double -> Decimal
                    self.convertToItemAndSelect(
                        name: item.name,
                        carbs: Decimal(item.carbs),
                        fat: Decimal(item.fat),
                        protein: Decimal(item.protein),
                        source: "AI Search",
                        url: item.imageURL
                    )
                }
            )
        }
    }

    // MARK: - Helper

    private func convertToItemAndSelect(
        name: String,
        carbs: Decimal, // 🟢 FIX: Jetzt auf Decimal umgestellt
        fat: Decimal,
        protein: Decimal,
        source: String,
        url: String? = nil,
        image: UIImage? = nil
    ) {
        let newItem = FoodItem(
            name: name,
            carbs: carbs,
            fat: fat,
            protein: protein,
            source: source,
            imageURL: url
        )
        handleFoodItemSelection(newItem, image: image)
    }

    // MARK: - Handlers

    private func handleBarcodeScan(_ barcode: String) {
        state.navigateToBarcode = false
        state.foodSearchText = barcode
        state.performSearch(query: barcode)
    }

    private func handleAIAnalysis(_ analysisResult: AIFoodAnalysisResult, image: UIImage?) {
        aiAnalysisResult = analysisResult
        showingAIAnalysisResults = true
        aiAnalysisImage = image

        let aiFoodItems = analysisResult.foodItemsDetailed.map { foodItem in
            AIFoodItem(
                name: foodItem.name,
                brand: nil,
                calories: foodItem.calories ?? 0,
                carbs: foodItem.carbohydrates,
                protein: foodItem.protein ?? analysisResult.totalProtein ?? 0,
                fat: foodItem.fat ?? analysisResult.totalFat ?? 0,
                imageURL: nil
            )
        }
        state.aiSearchResults = aiFoodItems
    }

    private func handleFoodItemSelection(_ foodItem: FoodItem, image: UIImage?) {
        onSelect(foodItem, image)
        dismiss()
    }
}
