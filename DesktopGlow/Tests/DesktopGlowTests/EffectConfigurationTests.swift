import Foundation
import Testing
@testable import DesktopGlow

struct EffectConfigurationTests {
    @Test
    func normalizedClampsFiniteValues() {
        let configuration = EffectConfiguration(
            style: .snow,
            density: -1,
            speed: 2,
            opacity: 0.25
        )

        #expect(configuration.normalized == EffectConfiguration(
            style: .snow,
            density: 0,
            speed: 1,
            opacity: 0.25
        ))
    }

    @Test
    func normalizedUsesDefaultsForNonFiniteValues() {
        let configuration = EffectConfiguration(
            density: .nan,
            speed: .infinity,
            opacity: -.infinity
        )

        #expect(configuration.normalized == EffectConfiguration())
    }

    @Test
    func normalizedPreservesValidValues() {
        let configuration = EffectConfiguration(
            style: .sparkle,
            density: 0.2,
            speed: 0.8,
            opacity: 0.4
        )

        #expect(configuration.normalized == configuration)
    }
}
