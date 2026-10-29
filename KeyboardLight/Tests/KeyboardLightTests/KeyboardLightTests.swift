import Foundation
import Testing
@testable import KeyboardLight

@MainActor
private final class MockBackend: KeyboardBackend {
    var state = KeyboardSnapshot(brightness: 0.64, autoBrightness: true, idleDimmingSuspended: false)
    var writes: [(brightness: Float, fade: Int, persist: Bool)] = []
    var policyWrites: [String] = []
    var failBrightness = false
    var failAutomatic = false
    var failReadAfterSuspension = false

    func discoverBuiltInKeyboard() throws -> UInt64 {
        42
    }

    func readState(keyboardID: UInt64) throws -> KeyboardSnapshot {
        if failReadAfterSuspension && state.idleDimmingSuspended {
            throw failure
        }
        var result = state
        if !state.idleDimmingSuspended {
            result.brightness = 0
        }
        return result
    }

    func setBrightness(_ value: Float, fadeMilliseconds: Int, persist: Bool, keyboardID: UInt64) throws {
        if failBrightness {
            throw failure
        }
        writes.append((value, fadeMilliseconds, persist))
        state.brightness = value
    }

    func setAutoBrightness(_ enabled: Bool, keyboardID: UInt64) throws {
        if failAutomatic && !enabled {
            throw failure
        }
        policyWrites.append("automatic=\(enabled)")
        state = KeyboardSnapshot(brightness: state.brightness, autoBrightness: enabled, idleDimmingSuspended: state.idleDimmingSuspended)
    }

    func setIdleDimmingSuspended(_ suspended: Bool, keyboardID: UInt64) throws {
        policyWrites.append("suspended=\(suspended)")
        state = KeyboardSnapshot(brightness: state.brightness, autoBrightness: state.autoBrightness, idleDimmingSuspended: suspended)
    }

    private var failure: NSError {
        NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simulated failure"])
    }
}

@Test @MainActor
func launchOnlyReadsState() {
    let backend = MockBackend()
    let model = KeyboardLightModel(backend: backend)
    #expect(model.canControl)
    #expect(backend.writes.isEmpty)
    #expect(backend.policyWrites.isEmpty)
}

@Test @MainActor
func routineRestoresRememberedBrightnessAndPolicies() async throws {
    let backend = MockBackend()
    let model = KeyboardLightModel(backend: backend)
    model.play()
    try await Task.sleep(for: .milliseconds(20))
    #expect(model.isPlaying)
    #expect(backend.state.idleDimmingSuspended)
    #expect(!backend.state.autoBrightness)
    #expect(backend.writes.first?.fade == 120)
    #expect(model.stopRoutine())
    #expect(backend.state.brightness == 0.64)
    #expect(backend.state.autoBrightness)
    #expect(!backend.state.idleDimmingSuspended)
    #expect(backend.writes.allSatisfy { !$0.persist })
}

@Test @MainActor
func cancelledRoutineCannotOverwriteManualChoice() async throws {
    let backend = MockBackend()
    let model = KeyboardLightModel(backend: backend)
    model.play()
    try await Task.sleep(for: .milliseconds(20))
    model.setManualBrightness(0.3)
    try await Task.sleep(for: .milliseconds(30))
    #expect(!model.isPlaying)
    #expect(backend.state.brightness == 0.3)
    #expect(backend.writes.last?.persist == true)
    #expect(backend.writes.last?.fade == 0)
    #expect(backend.state.autoBrightness)
    #expect(!backend.state.idleDimmingSuspended)
}

@Test @MainActor
func failedRestoreStillRestoresPoliciesAndCanBeRetried() async throws {
    let backend = MockBackend()
    let model = KeyboardLightModel(backend: backend)
    model.play()
    try await Task.sleep(for: .milliseconds(20))
    backend.failBrightness = true
    #expect(!model.stopRoutine())
    #expect(model.needsRecovery)
    #expect(!model.canControl)
    #expect(backend.state.autoBrightness)
    #expect(!backend.state.idleDimmingSuspended)
    backend.failBrightness = false
    #expect(model.stopRoutine())
    #expect(!model.needsRecovery)
    #expect(backend.state.brightness == 0.64)
}

@Test @MainActor
func setupFailureRestoresIdleDimming() {
    let backend = MockBackend()
    backend.failAutomatic = true
    let model = KeyboardLightModel(backend: backend)
    model.play()
    #expect(!model.isPlaying)
    #expect(!backend.state.idleDimmingSuspended)
    #expect(backend.state.autoBrightness)
    #expect(backend.writes.isEmpty)
    #expect(model.errorMessage != nil)
}

@Test @MainActor
func failedSnapshotDoesNotWriteDimmedZeroOverRememberedBrightness() {
    let backend = MockBackend()
    backend.failReadAfterSuspension = true
    let model = KeyboardLightModel(backend: backend)
    model.play()
    #expect(!backend.state.idleDimmingSuspended)
    #expect(backend.state.brightness == 0.64)
    #expect(backend.writes.isEmpty)
}

@Test @MainActor
func timedPlaybackStopsAndRestores() async throws {
    let backend = MockBackend()
    let model = KeyboardLightModel(backend: backend)
    model.loopsUntilStopped = false
    model.durationSeconds = 1
    model.paceSeconds = 3
    model.play()
    try await Task.sleep(for: .milliseconds(1150))
    #expect(!model.isPlaying)
    #expect(backend.state.brightness == 0.64)
    #expect(!backend.state.idleDimmingSuspended)
}

@Test @MainActor
func nonfiniteBrightnessIsRejectedWithoutWrites() {
    let backend = MockBackend()
    let model = KeyboardLightModel(backend: backend)
    model.setManualBrightness(.nan)
    #expect(backend.writes.isEmpty)
    #expect(backend.policyWrites.isEmpty)
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["KEYBOARD_LIGHT_HARDWARE_TEST"] == "1"))
@MainActor
func realKeyboardRoutineRestoresState() async throws {
    let backend = CoreBrightnessBackend()
    let identifier = try backend.discoverBuiltInKeyboard()
    let initial = try backend.readState(keyboardID: identifier)
    try backend.setIdleDimmingSuspended(true, keyboardID: identifier)
    defer {
        try? backend.setIdleDimmingSuspended(initial.idleDimmingSuspended, keyboardID: identifier)
    }
    let active = try backend.readState(keyboardID: identifier)
    let model = KeyboardLightModel(backend: backend)
    defer {
        model.stopRoutine()
    }
    model.minimum = max(0, active.brightness - 0.15)
    model.maximum = min(1, active.brightness + 0.05)
    model.play()
    try await Task.sleep(for: .milliseconds(350))
    #expect(model.isPlaying)
    #expect(model.errorMessage == nil)
    #expect(model.stopRoutine())
    try await Task.sleep(for: .milliseconds(200))
    let restored = try backend.readState(keyboardID: identifier)
    #expect(abs(restored.brightness - active.brightness) < 0.001)
    #expect(restored.autoBrightness == initial.autoBrightness)
    #expect(restored.idleDimmingSuspended)
}
