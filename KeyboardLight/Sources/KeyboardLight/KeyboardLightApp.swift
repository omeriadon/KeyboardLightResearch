import SwiftUI

@main
struct KeyboardLightApp: App {
    @NSApplicationDelegateAdaptor(KeyboardLightAppDelegate.self) private var delegate
    @State private var model = KeyboardLightModel()

    var body: some Scene {
        Window("Keyboard Light", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 600, idealWidth: 640, minHeight: 620, idealHeight: 700)
                .onAppear {
                    delegate.model = model
                }
        }
        .defaultSize(width: 640, height: 700)
        .commands {
            CommandMenu("Keyboard") {
                Button("Stop and Restore", systemImage: "stop.fill") {
                    if model.stopRoutine() {
                        model.errorMessage = nil
                    }
                }
                .accessibilityIdentifier("menu.stop")
                .keyboardShortcut(".")
            }
        }
    }
}
