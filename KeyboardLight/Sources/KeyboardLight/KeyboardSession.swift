struct KeyboardSession {
    var original: KeyboardSnapshot
    var restoreBrightness = false
    var restoreAutomatic = false
    var restoreIdleDimming = false

    var needsRestoration: Bool {
        restoreBrightness || restoreAutomatic || restoreIdleDimming
    }
}
