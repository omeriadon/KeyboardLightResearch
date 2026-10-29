import Foundation

enum TwinklePattern {
    static func nextBrightness(
        after previous: Float,
        in range: ClosedRange<Float>,
        using generator: inout some RandomNumberGenerator
    ) -> Float {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else {
            return range.lowerBound
        }
        let previousWasBright = previous >= range.lowerBound + span / 2
        let switchEnds = Double.random(in: 0..<1, using: &generator) < 0.85
        let useBrightEnd = switchEnds ? !previousWasBright : previousWasBright
        // Cluster at the endpoints, retaining small variations within each glint.
        let distanceFromEdge = Float(pow(Double.random(in: 0...1, using: &generator), 3)) * span * 0.15
        return useBrightEnd ? range.upperBound - distanceFromEdge : range.lowerBound + distanceFromEdge
    }
}
