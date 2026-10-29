import Foundation
import Observation

@MainActor
@Observable
final class KeyboardLightModel {
    private let backend: any KeyboardBackend
    private(set) var keyboardID: UInt64?
    private(set) var brightness: Float = 0
    private(set) var isPlaying = false
    private(set) var needsRecovery = false
    private(set) var isUnsupported = false
    var errorMessage: String?
    var minimum: Float = 0
    var maximum: Float = 1
    var routineKind: RoutineKind = .twinkle
    var fadeSeconds = 0.12
    var paceSeconds = 1.0
    var durationSeconds = 30.0
    var loopsUntilStopped = true

    @ObservationIgnored private var session: KeyboardSession?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var routineTask: Task<Void, Never>?

    var canControl: Bool {
        keyboardID != nil && !needsRecovery
    }

    init(backend: any KeyboardBackend = CoreBrightnessBackend()) {
        self.backend = backend
        refresh()
    }

    isolated deinit {
        routineTask?.cancel()
    }

    func refresh() {
        guard !isPlaying, session == nil else {
            return
        }
        do {
            let identifier = try backend.discoverBuiltInKeyboard()
            brightness = try backend.readState(keyboardID: identifier).brightness
            keyboardID = identifier
            isUnsupported = false
            errorMessage = nil
        } catch {
            keyboardID = nil
            isUnsupported = true
            errorMessage = error.localizedDescription
        }
    }

    func setManualBrightness(_ value: Float) {
        guard value.isFinite, (0...1).contains(value), stopRoutine(), let identifier = keyboardID else {
            return
        }
        do {
            try beginSession(identifier: identifier)
            session?.restoreBrightness = true
            try backend.setBrightness(value, fadeMilliseconds: 0, persist: true, keyboardID: identifier)
            brightness = value
            errorMessage = nil
            // A deliberate manual choice stays selected; temporary policies are restored.
            session?.restoreBrightness = false
            _ = restoreState()
        } catch {
            let failure = error.localizedDescription
            if restoreState() {
                errorMessage = failure
            }
        }
    }

    func play() {
        guard stopRoutine(), let identifier = keyboardID else {
            return
        }
        guard minimum.isFinite, maximum.isFinite, fadeSeconds.isFinite,
              paceSeconds.isFinite, durationSeconds.isFinite else {
            errorMessage = "Choose finite brightness and timing values."
            return
        }
        do {
            try beginSession(identifier: identifier)
            isPlaying = true
            errorMessage = nil
            generation += 1
            let token = generation
            let lower = max(0, min(1, min(minimum, maximum)))
            let upper = max(lower, min(1, max(minimum, maximum)))
            let fade = max(0.05, min(0.5, fadeSeconds))
            let pace = max(0.5, min(3, paceSeconds))
            let duration = loopsUntilStopped ? nil : max(1, min(120, durationSeconds))
            let kind = routineKind
            routineTask = Task { [weak self] in
                await self?.run(
                    kind: kind,
                    identifier: identifier,
                    token: token,
                    lower: lower,
                    upper: upper,
                    fade: fade,
                    pace: pace,
                    duration: duration
                )
            }
        } catch {
            let failure = error.localizedDescription
            if restoreState() {
                errorMessage = failure
            }
        }
    }

    @discardableResult
    func stopRoutine() -> Bool {
        // Invalidate ownership before cancelling: an old task cannot restore over a new command.
        generation += 1
        routineTask?.cancel()
        routineTask = nil
        isPlaying = false
        return restoreState()
    }

    private func beginSession(identifier: UInt64) throws {
        guard session == nil else {
            throw failure("Restore the previous keyboard state before continuing.")
        }
        let original = try backend.readState(keyboardID: identifier)
        session = KeyboardSession(original: original)
        if !original.idleDimmingSuspended {
            session?.restoreIdleDimming = true
            try backend.setIdleDimmingSuspended(true, keyboardID: identifier)
        }
        // Suspending idle dimming exposes the remembered level rather than the dimmed zero.
        let active = try backend.readState(keyboardID: identifier)
        session?.original.brightness = active.brightness
        if original.autoBrightness {
            session?.restoreAutomatic = true
            try backend.setAutoBrightness(false, keyboardID: identifier)
        }
    }

    private func restoreState() -> Bool {
        guard let identifier = keyboardID, var pending = session else {
            needsRecovery = false
            return true
        }
        var failures: [String] = []
        if pending.restoreBrightness {
            do {
                try backend.setBrightness(pending.original.brightness, fadeMilliseconds: 120, persist: false, keyboardID: identifier)
                brightness = pending.original.brightness
                pending.restoreBrightness = false
            } catch {
                failures.append(error.localizedDescription)
            }
        }
        // Attempt each policy even when a preceding restore failed.
        if pending.restoreAutomatic {
            do {
                try backend.setAutoBrightness(pending.original.autoBrightness, keyboardID: identifier)
                pending.restoreAutomatic = false
            } catch {
                failures.append(error.localizedDescription)
            }
        }
        if pending.restoreIdleDimming {
            do {
                try backend.setIdleDimmingSuspended(pending.original.idleDimmingSuspended, keyboardID: identifier)
                pending.restoreIdleDimming = false
            } catch {
                failures.append(error.localizedDescription)
            }
        }
        session = pending.needsRestoration ? pending : nil
        needsRecovery = session != nil
        if needsRecovery {
            errorMessage = "Could not fully restore the keyboard. \(failures.joined(separator: " "))"
        }
        return !needsRecovery
    }

    private func run(
        kind: RoutineKind,
        identifier: UInt64,
        token: Int,
        lower: Float,
        upper: Float,
        fade: Double,
        pace: Double,
        duration: Double?
    ) async {
        let clock = ContinuousClock()
        let deadline = duration.map { clock.now + .seconds($0) }
        var accent = false
        var previous = session?.original.brightness ?? brightness
        var generator = SystemRandomNumberGenerator()
        while !Task.isCancelled, token == generation {
            if let deadline, clock.now >= deadline {
                break
            }
            let value: Float
            let transition: Double
            let delay: Double
            switch kind {
            case .twinkle:
                value = TwinklePattern.nextBrightness(after: previous, in: lower...upper, using: &generator)
                transition = fade
                delay = pace * Double.random(in: 0.7...1.3)
            case .sparkle:
                accent.toggle()
                value = accent ? Float.random(in: (lower + (upper - lower) * 0.9)...upper) : lower
                transition = fade
                delay = max(0.25, pace * (accent ? 0.35 : Double.random(in: 0.7...1.2)))
            case .breathe:
                accent.toggle()
                value = accent ? upper : lower
                transition = max(1, pace)
                delay = transition
            }
            do {
                session?.restoreBrightness = true
                try backend.setBrightness(value, fadeMilliseconds: Int(transition * 1000), persist: false, keyboardID: identifier)
                brightness = value
                previous = value
                let next = clock.now + .seconds(delay)
                try await clock.sleep(until: deadline.map { min(next, $0) } ?? next)
            } catch is CancellationError {
                break
            } catch {
                errorMessage = error.localizedDescription
                break
            }
        }
        guard token == generation else {
            return
        }
        isPlaying = false
        routineTask = nil
        _ = restoreState()
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "KeyboardLight", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
