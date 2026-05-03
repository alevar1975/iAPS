import Foundation
import SwiftUI

struct FoodItemRow: View {
    let foodItem: FoodItemDetailed
    let onPortionChange: ((Decimal) -> Void)?
    let onDelete: (() -> Void)?
    let onPersist: ((FoodItemDetailed) -> Void)?
    let savedFoodIds: Set<UUID>
    let allExistingTags: Set<String>
    let isFirst: Bool
    let isLast: Bool

    @State private var showItemInfo = false
    @State private var showPortionAdjuster = false

    private var isSaved: Bool {
        savedFoodIds.contains(foodItem.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                // Name Row
                HStack {
                    Text(foodItem.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    if foodItem.source.isAI, let confidence = foodItem.confidence {
                        ConfidenceBadge(level: confidence)
                    }
                }

                // Portion Button (Gray Pill)
                if onPortionChange != nil {
                    Button(action: {
                        showPortionAdjuster = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption)
                            let val = Double(truncating: foodItem.portionSizeOrMultiplier as NSNumber)
                            let isInt = floor(val) == val
                            Text(
                                "\(val, specifier: isInt ? "%.0f" : "%.1f") \(foodItem.isPerServing ? "serving" : (foodItem.units?.dimension.symbol ?? "g"))"
                            )
                            .font(.caption)
                            .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .foregroundColor(.secondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Nährwert Icons (Blatt, Blitz, Tropfen, Flamme)
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
                        Text("\(Double(truncating: (foodItem.caloriesInThisPortion ?? 0) as NSNumber), specifier: "%.0f") kcal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                showItemInfo = true
            }
            .contextMenu {
                if onPortionChange != nil {
                    Button {
                        showPortionAdjuster = true
                    } label: {
                        Label("Edit Portion", systemImage: "slider.horizontal.3")
                    }
                }

                if foodItem.source != .database {
                    if isSaved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.secondary)
                    } else if let onPersist = onPersist {
                        Button {
                            onPersist(foodItem)
                        } label: {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                    }
                }

                if let onDelete = onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Remove from meal", systemImage: "trash")
                    }
                }
            }
        }
        .padding(.top, isFirst ? 8 : 0)
        .padding(.bottom, isLast ? 8 : 0)
        .background(Color(.systemBackground)) // Hellerer moderner Look
        .when(onDelete != nil) { view in
            view.swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .when(onPortionChange != nil) { view in
            view.swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    showPortionAdjuster = true
                } label: {
                    Label("Edit Portion", systemImage: "slider.horizontal.3")
                }
                .tint(.orange)
            }
        }
        .sheet(isPresented: $showPortionAdjuster) {
            PortionAdjusterView(
                foodItem: foodItem,
                onSave: { newPortion in
                    onPortionChange?(newPortion)
                    showPortionAdjuster = false
                },
                onCancel: {
                    showPortionAdjuster = false
                }
            )
            .presentationDetents([.height(foodItem.hasNutritionValues ? 420 : 340)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showItemInfo) {
            FoodItemInfoPopup(foodItem: foodItem, onPortionChange: onPortionChange)
                .presentationDetents([.height(foodItem.preferredInfoSheetHeight()), .large])
                .presentationDragIndicator(.visible)
        }
    }

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
