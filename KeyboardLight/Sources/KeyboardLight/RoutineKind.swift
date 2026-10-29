import Foundation

enum RoutineKind: String, CaseIterable, Identifiable, Sendable {
    case twinkle = "Twinkle"
    case sparkle = "Sparkle"
    case breathe = "Breathe"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .twinkle:
            "sparkles"
        case .sparkle:
            "wand.and.stars"
        case .breathe:
            "wind"
        }
    }

    var detail: String {
        switch self {
        case .twinkle:
            "Random glints that jump between dim and bright."
        case .sparkle:
            "Bright accents above a quiet glow."
        case .breathe:
            "A slow rise and fall in brightness."
        }
    }
}
