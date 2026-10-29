import Foundation

public struct EffectConfiguration: Equatable, Codable, Sendable {
    public var style: EffectStyle
    public var density: Double
    public var speed: Double
    public var opacity: Double

    public init(
        style: EffectStyle = .festive,
        density: Double = 0.45,
        speed: Double = 0.5,
        opacity: Double = 0.65
    ) {
        self.style = style
        self.density = density
        self.speed = speed
        self.opacity = opacity
    }

    public var normalized: Self {
        Self(
            style: style,
            density: Self.clamp(density, defaultValue: 0.45),
            speed: Self.clamp(speed, defaultValue: 0.5),
            opacity: Self.clamp(opacity, defaultValue: 0.65)
        )
    }

    private static func clamp(_ value: Double, defaultValue: Double) -> Double {
        guard value.isFinite else {
            return defaultValue
        }
        return min(max(value, 0), 1)
    }
}
