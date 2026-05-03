import Foundation

// --- KLASSISCHE & KI-STRUKTUREN (Fix für die "Missing Type" Fehler) ---

/// Der Basis-Typ für die manuelle Suche und CoreData-Anbindung
struct FoodItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let carbs: Decimal
    let protein: Decimal?
    let fat: Decimal?
    let kcal: Decimal? // Hilft auch gegen den CoreDataStorage-Fehler
}

/// Spezieller Typ für die neue KI-Bildanalyse (AIFoodItem)
struct AIFoodItem: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let carbs: Decimal
    let protein: Decimal
    let fat: Decimal
    let confidence: Double

    // 🟢 NEU: Ergänzungen für deine v1-Ansicht!
    var brand: String? = nil
    var calories: Decimal? = nil
    var imageURL: String? = nil
}

// --- NEUE BILD-SUCHE (Version 2) ---

/// Erforderlich für die neue Thumbnail-Vorschau in der Suche
struct ImageSearchResult: Identifiable {
    let id: String
    let thumbnailURL: String?
    let fullURL: String
    let attribution: String?
}

/// Tags für die Favoriten-Markierung
enum FoodTags {
    static let favorites = "⭐️"
}
