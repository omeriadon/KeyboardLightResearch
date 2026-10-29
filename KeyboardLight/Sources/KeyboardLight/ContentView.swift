import SwiftUI
import AppKit

struct ContentView: View {
    @Bindable var model: KeyboardLightModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "keyboard")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Keyboard Light")
                        .font(.title2.bold())
                    Text(model.isPlaying ? "Playing \(model.routineKind.rawValue)" : "A little glow for your Mac.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("keyboard.status")
                }
                Spacer()
                Text(model.brightness, format: .percent.precision(.fractionLength(0)))
                    .font(.title2.monospacedDigit())
                    .accessibilityLabel("Requested brightness")
                    .accessibilityIdentifier("keyboard.level")
            }
            .padding()

            if let error = model.errorMessage {
                HStack(alignment: .top) {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .accessibilityIdentifier("keyboard.error")
                    Spacer()
                    if model.needsRecovery {
                        Button("Restore", systemImage: "arrow.uturn.backward") {
                            if model.stopRoutine() {
                                model.errorMessage = nil
                            }
                        }
                        .accessibilityLabel("Retry restoring keyboard settings")
                        .accessibilityIdentifier("keyboard.restore")
                    } else {
                        Button("Refresh", systemImage: "arrow.clockwise") {
                            model.refresh()
                        }
                        .accessibilityLabel("Refresh keyboard connection")
                        .accessibilityIdentifier("keyboard.refresh")
                    }
                }
                .padding()
                .background(.quaternary)
            }

            TabView {
                Tab("Brightness", systemImage: "light.max") {
                    BrightnessView(model: model)
                }
                Tab("Routines", systemImage: "sparkles") {
                    RoutinesView(model: model)
                }
            }
            .padding([.horizontal, .bottom])
        }
        .tint(.green)
        .onDisappear {
            model.stopRoutine()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)) { _ in
            model.stopRoutine()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidResignActiveNotification)) { _ in
            model.stopRoutine()
        }
    }
}
