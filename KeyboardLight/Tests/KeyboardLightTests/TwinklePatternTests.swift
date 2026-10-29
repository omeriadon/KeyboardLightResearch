import Testing
@testable import KeyboardLight

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64 = 0x123456789ABCDEF

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

@Test
func twinklePrefersVisibleJumpsAndBothBrightnessExtremes() {
    var generator = SeededGenerator()
    var previous: Float = 0.5
    var largeJumps = 0
    var dimGlints = 0
    var brightGlints = 0
    for _ in 0..<2000 {
        let next = TwinklePattern.nextBrightness(after: previous, in: 0...1, using: &generator)
        #expect((0...1).contains(next))
        #expect(next <= 0.15 || next >= 0.85)
        if abs(next - previous) > 0.65 {
            largeJumps += 1
        }
        if next < 0.1 {
            dimGlints += 1
        }
        if next > 0.9 {
            brightGlints += 1
        }
        previous = next
    }
    #expect(largeJumps > 1500)
    #expect(dimGlints > 700)
    #expect(brightGlints > 700)
}

@Test
func twinkleRespectsCustomAndFixedBrightnessLimits() {
    var generator = SeededGenerator()
    var previous: Float = 0.4
    for _ in 0..<100 {
        let next = TwinklePattern.nextBrightness(after: previous, in: 0.3...0.6, using: &generator)
        #expect((0.3...0.6).contains(next))
        previous = next
    }
    #expect(TwinklePattern.nextBrightness(after: 1, in: 0.4...0.4, using: &generator) == 0.4)
}
