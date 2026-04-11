import Foundation

struct TemporaryData: JSON, Equatable {
    var forBolusView = CarbsEntry(
        id: "",
        createdAt: Date.distantPast, // 🟢 FIX: Explizit Date.distantPast
        actualDate: Date.distantPast, // 🟢 FIX: Explizit Date.distantPast
        carbs: 0,
        fat: 0,
        protein: 0,
        note: "",
        enteredBy: "",
        isFPU: false,
        kcal: nil,
        duration: nil // 🟢 FIX: Dauer hinzugefügt
    )
}
