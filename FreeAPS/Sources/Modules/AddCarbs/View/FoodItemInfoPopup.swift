import Foundation
import SwiftUI

struct FoodItemInfoPopup: View {
    let foodItem: FoodItemDetailed
    let onPortionChange: ((Decimal) -> Void)?

    @State private var multiplier: Decimal

    init(foodItem: FoodItemDetailed, onPortionChange: ((Decimal) -> Void)? = nil) {
        self.foodItem = foodItem
        self.onPortionChange = onPortionChange
        _multiplier = State(initialValue: foodItem.portionSizeOrMultiplier)
    }

    private var shouldShowStandardServing: Bool {
        let hasDescription = foodItem.standardServing != nil && !(foodItem.standardServing?.isEmpty ?? true)
        let hasSize = foodItem.standardServingSize != nil
        return hasDescription || hasSize
    }

    @ViewBuilder private func standardServingContent(foodItem: FoodItemDetailed) -> some View {
        if let servingDescription = foodItem.standardServing, !servingDescription.isEmpty {
            Text(servingDescription)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }

    private func standardServingTitle(unit: String) -> String {
        if let servingSize = foodItem.standardServingSize {
            let formattedSize = String(format: "%.0f", Double(truncating: servingSize as NSNumber))
            return NSLocalizedString("Standard Serving", comment: "") + " - \(formattedSize) \(unit)"
        }
        return "Standard Serving"
    }

    private func calculatedNutrient(for nutrient: NutrientType) -> Decimal? {
        guard let baseValue = foodItem.nutrition.values[nutrient] else { return nil }
        return foodItem.isPerServing ? (baseValue * multiplier) : (baseValue * (multiplier / 100))
    }

    private func calculatedCalories() -> Decimal {
        let carbs = calculatedNutrient(for: .carbs) ?? 0
        let fat = calculatedNutrient(for: .fat) ?? 0
        let protein = calculatedNutrient(for: .protein) ?? 0
        return (carbs * 4) + (protein * 4) + (fat * 9)
    }

    var body: some View {
        let unit = (foodItem.units ?? .grams).dimension.symbol

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Titel
                Text(foodItem.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.top, 10)

                // Portionen-Steuerung (iPhone 17 Style Pill)
                if onPortionChange != nil {
                    HStack {
                        HStack(spacing: 0) {
                            Button(action: {
                                let step: Decimal = foodItem.isPerServing ? 0.5 : 10.0
                                let minVal: Decimal = foodItem.isPerServing ? 0.5 : 10.0
                                if multiplier > minVal {
                                    multiplier -= step
                                    onPortionChange?(multiplier)
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(width: 44, height: 40)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)

                                let displayVal = Double(truncating: multiplier as NSNumber)
                                let isInt = floor(displayVal) == displayVal
                                Text(
                                    "\(displayVal, specifier: isInt ? "%.0f" : "%.1f") \(foodItem.isPerServing ? "servings" : unit)"
                                )
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)

                            Button(action: {
                                let step: Decimal = foodItem.isPerServing ? 0.5 : 10.0
                                multiplier += step
                                onPortionChange?(multiplier)
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(width: 44, height: 40)
                            }
                        }
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // Nährwert-Tabelle
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text("")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("This portion")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 90, alignment: .trailing)
                        Text(foodItem.isPerServing ? "Per serving" : "Per 100\(unit)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 90, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    ForEach(NutrientType.allCases) { nutrient in
                        let nutrientValue = foodItem.nutrition.values[nutrient]
                        if nutrient.isPrimary || (nutrientValue != nil && nutrientValue! > 0) {
                            Divider()
                            DetailedNutritionRow(
                                localizedLabel: nutrient.localizedLabel,
                                iconName: icon(for: nutrient),
                                iconColor: color(for: nutrient),
                                portionValue: calculatedNutrient(for: nutrient),
                                per100Value: nutrientValue,
                                unit: nutrient.unit
                            )
                        }
                    }

                    Divider()
                    DetailedNutritionRow(
                        localizedLabel: NSLocalizedString("Calories", comment: ""),
                        iconName: "flame.fill",
                        iconColor: .red,
                        portionValue: calculatedCalories(),
                        per100Value: foodItem.nutrition.values.calories,
                        unit: UnitEnergy.kilocalories
                    )
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding(.horizontal)

                if shouldShowStandardServing {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(standardServingTitle(unit: unit), systemImage: "chart.bar.doc.horizontal")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        standardServingContent(foodItem: foodItem)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)
                }
                Spacer(minLength: 8)
            }
            .padding(.vertical)
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

private struct DetailedNutritionRow: View {
    let localizedLabel: String
    let iconName: String
    let iconColor: Color
    let portionValue: Decimal?
    let per100Value: Decimal?
    let unit: Dimension

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                if !iconName.isEmpty {
                    Image(systemName: iconName)
                        .foregroundColor(iconColor)
                        .font(.system(size: 14))
                        .frame(width: 16)
                }
                Text(localizedLabel)
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let value = portionValue, value > 0 {
                HStack(spacing: 2) {
                    Text("\(Double(truncating: value as NSNumber), specifier: "%.1f")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(unit.symbol)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                        .frame(width: 24, alignment: .leading)
                }
                .frame(width: 90, alignment: .trailing)
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 90, alignment: .trailing)
            }

            if let value = per100Value, value > 0 {
                HStack(spacing: 2) {
                    Text("\(Double(truncating: value as NSNumber), specifier: "%.1f")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(unit.symbol)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                        .frame(width: 24, alignment: .leading)
                }
                .frame(width: 90, alignment: .trailing)
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 90, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
