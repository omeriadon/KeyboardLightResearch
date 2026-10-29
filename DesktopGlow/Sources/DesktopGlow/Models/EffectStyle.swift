import Foundation

public enum EffectStyle: String, CaseIterable, Codable, Sendable {
    case snow
    case sparkle
    case festive

    public var title: String {
        switch self {
        case .snow:
            return "Snow"
        case .sparkle:
            return "Sparkle"
        case .festive:
            return "Festive"
        }
    }

    public var symbol: String {
        switch self {
        case .snow:
            return "snowflake"
        case .sparkle:
            return "sparkles"
        case .festive:
            return "party.popper"
        }
    }
}
