import SwiftUI

struct BrightnessView: View {
    @Bindable var model: KeyboardLightModel
    private let presets = [0, 25, 50, 75, 100]

    var body: some View {
        List {
            Section {
                Slider(
                    value: Binding(
                        get: { model.brightness },
                        set: { model.setManualBrightness($0) }
                    ),
                    in: 0...1
                ) {
                    Label("Brightness", systemImage: "light.max")
                } minimumValueLabel: {
                    Image(systemName: "light.min")
                        .accessibilityHidden(true)
                } maximumValueLabel: {
                    Image(systemName: "light.max")
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("Keyboard brightness")
                .accessibilityValue(Text(model.brightness, format: .percent.precision(.fractionLength(0))))
                .accessibilityIdentifier("brightness.slider")
                .padding(.vertical, 12)

                HStack {
                    ForEach(presets, id: \.self) { percent in
                        Button("\(percent)%", systemImage: percent == 0 ? "light.min" : "light.max") {
                            model.setManualBrightness(Float(percent) / 100)
                        }
                        .accessibilityLabel("Set brightness to \(percent) percent")
                        .accessibilityIdentifier("brightness.preset.\(percent)")
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Whole-keyboard brightness")
            } footer: {
                Text("Changes apply instantly and stop any routine. Your normal automatic brightness and idle dimming remain in effect afterward.")
            }
            .disabled(!model.canControl)

            Section("Decorative lighting") {
                Label("Twinkle, sparkle, or breathe with short, soft fades in Routines.", systemImage: "sparkles")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }
        }
        .listStyle(.inset)
    }
}
