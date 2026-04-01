import SwiftUI

struct SelectedFoodView: View {
    let food: AIFoodItem
    let foodImage: UIImage?
    @Binding var portionGrams: Double
    var onChange: () -> Void
    var onTakeOver: (AIFoodItem) -> Void

    @State private var showMultiplierEditor = false

    private var isAIProduct: Bool {
        (food.brand ?? "").lowercased().contains("ai overall analysis")
    }

    private var displayCarbs: Double {
        isAIProduct ? food.carbs : food.carbs * (portionGrams / 100.0)
    }

    private var displayFat: Double {
        isAIProduct ? food.fat : food.fat * (portionGrams / 100.0)
    }

    private var displayProtein: Double {
        isAIProduct ? food.protein : food.protein * (portionGrams / 100.0)
    }

    private var displayCalories: Double {
        isAIProduct ? food.calories : food.calories * (portionGrams / 100.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 1. HEADER: Bild, Titel und Tags (Vollständig erhalten inkl. AsyncImage)
            HStack(alignment: .top, spacing: 16) {
                Group {
                    if let foodImage = foodImage {
                        Image(uiImage: foodImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 75, height: 75)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 3)
                    } else if let imageURLString = food.imageURL,
                              let imageURL = URL(string: imageURLString)
                    {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 75, height: 75)
                            case let .success(image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 75, height: 75)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 3)
                            case .failure:
                                placeholderImage
                            @unknown default:
                                placeholderImage
                            }
                        }
                    } else {
                        placeholderImage
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(food.name)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Tags: AI Analysis oder 100g
                    HStack(spacing: 4) {
                        Image(systemName: isAIProduct ? "brain" : "scalemass")
                            .font(.caption)

                        if isAIProduct {
                            Text("AI Analysis")
                                .font(.caption)
                        } else if portionGrams == 100.0 {
                            Text("100g")
                                .font(.caption)
                        }
                    }
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        isAIProduct ? Color.purple.opacity(0.15) :
                            (portionGrams == 100.0 ? Color.blue.opacity(0.15) : Color.clear)
                    )
                    .foregroundColor(
                        isAIProduct ? .purple :
                            (portionGrams == 100.0 ? .blue : .clear)
                    )
                    .clipShape(Capsule())
                }
                Spacer()
            }
            .padding(.bottom, 4)

            // 2. MAKROS: Das große, edle 2x2 Grid (iPhone 17 Style)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NutritionBadge(value: displayCarbs, unit: "g", label: "Carbs", color: .blue, icon: "chart.pie.fill")
                NutritionBadge(value: displayFat, unit: "g", label: "Fett", color: .orange, icon: "flame.fill")
                NutritionBadge(value: displayProtein, unit: "g", label: "Protein", color: .red, icon: "bolt.heart.fill")
                if food.calories > 0 {
                    NutritionBadge(value: displayCalories, unit: " kcal", label: "Kalorien", color: .green, icon: "leaf.fill")
                }
            }

            // 3. PORTION & MULTIPLIER (Vollständig erhalten)
            if !isAIProduct {
                HStack {
                    Text("Menge / Portion:")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showMultiplierEditor = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("\(portionGrams, specifier: "%.0f")g")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                }
                .padding(.top, 4)
            }

            // 4. ACTION BUTTONS (Beide Buttons erhalten)
            HStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onChange()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Neu suchen")
                    }
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.secondary.opacity(0.15))
                    .foregroundColor(.primary)
                    .cornerRadius(16)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    let adjustedFood = AIFoodItem(
                        name: food.name,
                        brand: food.brand,
                        calories: displayCalories,
                        carbs: displayCarbs,
                        protein: displayProtein,
                        fat: displayFat,
                        imageURL: food.imageURL
                    )
                    onTakeOver(adjustedFood)
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Übernehmen")
                    }
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 4)
        }
        // 5. KARTEN-STYLING & SHEET
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .sheet(isPresented: $showMultiplierEditor) {
            MultiplierEditorView(grams: $portionGrams)
        }
    }

    private var placeholderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
                .frame(width: 75, height: 75)
            Image(systemName: "fork.knife")
                .font(.system(size: 24))
                .foregroundColor(.gray.opacity(0.4))
        }
    }

    // 🟢 NEU: Das große, leuchtende Makro-Badge
    private struct NutritionBadge: View {
        let value: Double
        let unit: String
        let label: String
        let color: Color
        let icon: String

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(value, specifier: "%.1f")\(NSLocalizedString(unit, comment: ""))")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(color)
                        .contentTransition(.numericText()) // Rollt sanft beim Ändern!
                    Text(NSLocalizedString(label, comment: ""))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
    }
}
