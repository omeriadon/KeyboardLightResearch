import CoreBrightnessBridge
import Foundation

@MainActor
protocol KeyboardBackend: AnyObject {
    func discoverBuiltInKeyboard() throws -> UInt64
    func readState(keyboardID: UInt64) throws -> KeyboardSnapshot
    func setBrightness(_ value: Float, fadeMilliseconds: Int, persist: Bool, keyboardID: UInt64) throws
    func setAutoBrightness(_ enabled: Bool, keyboardID: UInt64) throws
    func setIdleDimmingSuspended(_ suspended: Bool, keyboardID: UInt64) throws
}

@MainActor
final class CoreBrightnessBackend: KeyboardBackend {
    private let bridge = KBCoreBrightnessBridge()

    func discoverBuiltInKeyboard() throws -> UInt64 {
        var error: NSError?
        let identifiers = bridge.keyboardIDs(error: &error)
        if let error {
            throw error
        }
        for number in identifiers {
            let identifier = number.uint64Value
            let builtIn = bridge.isKeyboardBuiltIn(identifier, error: &error)
            if let error {
                throw error
            }
            if builtIn {
                return identifier
            }
        }
        throw failure("No built-in keyboard backlight was found.")
    }

    func readState(keyboardID: UInt64) throws -> KeyboardSnapshot {
        var error: NSError?
        let brightness = bridge.brightness(forKeyboard: keyboardID, error: &error)
        if let error {
            throw error
        }
        guard brightness.isFinite, (0...1).contains(brightness) else {
            throw failure("The system returned an invalid brightness level.")
        }
        let automatic = bridge.isAutoBrightnessEnabled(forKeyboard: keyboardID, error: &error)
        if let error {
            throw error
        }
        let suspended = bridge.isIdleDimmingSuspended(forKeyboard: keyboardID, error: &error)
        if let error {
            throw error
        }
        return KeyboardSnapshot(brightness: brightness, autoBrightness: automatic, idleDimmingSuspended: suspended)
    }

    func setBrightness(_ value: Float, fadeMilliseconds: Int, persist: Bool, keyboardID: UInt64) throws {
        guard value.isFinite, (0...1).contains(value), (0...3000).contains(fadeMilliseconds) else {
            throw failure("Brightness or fade duration is outside its supported range.")
        }
        var error: NSError?
        guard bridge.setBrightness(value, fadeSpeed: Int32(fadeMilliseconds), commit: persist, keyboard: keyboardID, error: &error) else {
            throw error ?? failure("The system declined the brightness change.")
        }
    }

    func setAutoBrightness(_ enabled: Bool, keyboardID: UInt64) throws {
        var error: NSError?
        guard bridge.enableAutoBrightness(enabled, keyboard: keyboardID, error: &error) else {
            throw error ?? failure("Could not restore automatic brightness.")
        }
    }

    func setIdleDimmingSuspended(_ suspended: Bool, keyboardID: UInt64) throws {
        var error: NSError?
        guard bridge.suspendIdleDimming(suspended, keyboard: keyboardID, error: &error) else {
            throw error ?? failure("Could not restore idle dimming.")
        }
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "KeyboardLight", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
