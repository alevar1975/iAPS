import Foundation

class MealMode: ObservableObject {
    enum Mode {
        case image
        case barcode
        case presets
        case meal
        case search // 🟢 Das hier einfach hinzufügen!
    }

    var mode: Mode = .meal
}
