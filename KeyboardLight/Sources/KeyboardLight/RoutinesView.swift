import SwiftUI

struct RoutinesView: View {
    @Bindable var model: KeyboardLightModel

    var body: some View {
        List {
            Section("Pattern") {
                Picker("Routine", selection: $model.routineKind) {
                    ForEach(RoutineKind.allCases) { kind in
                        Label(kind.rawValue, systemImage: kind.symbol)
                            .tag(kind)
                    }
                }
                .accessibilityLabel("Lighting routine")
                .accessibilityIdentifier("routine.pattern")
                Text(model.routineKind.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .disabled(model.isPlaying || !model.canControl)

            Section("Glow") {
                LabeledContent("Dim level") {
                    Slider(value: $model.minimum, in: 0...model.maximum)
                        .accessibilityLabel("Routine dim level")
                        .accessibilityIdentifier("routine.minimum")
                    Text(model.minimum, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
                LabeledContent("Bright level") {
                    Slider(value: $model.maximum, in: model.minimum...1)
                        .accessibilityLabel("Routine bright level")
                        .accessibilityIdentifier("routine.maximum")
                    Text(model.maximum, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
                LabeledContent("Fade") {
                    Slider(value: $model.fadeSeconds, in: 0.05...0.5, step: 0.01)
                        .accessibilityLabel("Routine fade in seconds")
                        .accessibilityIdentifier("routine.fade")
                    Text("\(model.fadeSeconds, format: .number.precision(.fractionLength(2))) s")
                        .monospacedDigit()
                        .frame(width: 58, alignment: .trailing)
                }
                .disabled(model.routineKind == .breathe)
                LabeledContent("Pace") {
                    Slider(value: $model.paceSeconds, in: 0.5...3, step: 0.1)
                        .accessibilityLabel("Routine pace in seconds")
                        .accessibilityIdentifier("routine.pace")
                    Text("\(model.paceSeconds, format: .number.precision(.fractionLength(1))) s")
                        .monospacedDigit()
                        .frame(width: 58, alignment: .trailing)
                }
            }
            .disabled(model.isPlaying || !model.canControl)

            Section {
                Toggle("Loop until stopped", isOn: $model.loopsUntilStopped)
                    .accessibilityLabel("Loop routine until stopped")
                    .accessibilityIdentifier("routine.loop")
                if !model.loopsUntilStopped {
                    LabeledContent("Run for") {
                        Slider(value: $model.durationSeconds, in: 1...120, step: 1)
                            .accessibilityLabel("Playback duration in seconds")
                            .accessibilityIdentifier("routine.duration")
                        Text("\(model.durationSeconds, format: .number.precision(.fractionLength(0))) s")
                            .monospacedDigit()
                            .frame(width: 58, alignment: .trailing)
                    }
                }
            }
            .disabled(model.isPlaying || !model.canControl)

            Section {
                HStack {
                    if model.isPlaying {
                        Label("Playing \(model.routineKind.rawValue)", systemImage: "waveform")
                            .accessibilityIdentifier("routine.status")
                        Spacer()
                        Button(role: .cancel) {
                            model.stopRoutine()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .accessibilityLabel("Stop routine and restore keyboard settings")
                        .accessibilityIdentifier("routine.stop")
                        .keyboardShortcut(.escape, modifiers: [])
                    } else {
                        Spacer()
                        Button(role: .confirm) {
                            model.play()
                        } label: {
                            Label("Play", systemImage: "play.fill")
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(!model.canControl)
                        .accessibilityLabel("Play selected lighting routine")
                        .accessibilityIdentifier("routine.play")
                    }
                }
                .padding(.vertical, 6)
            } footer: {
                Text("White light across the whole keyboard. Stop restores your starting brightness. Playback also stops when this tab closes, your Mac sleeps, or you quit.")
            }
        }
        .listStyle(.inset)
        .onDisappear {
            model.stopRoutine()
        }
    }
}
