import SwiftUI

@main
struct MyCreativeCameraApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onDisappear {
                    terminateApp()
                }
        }
    }

    private func terminateApp() {
        NSApplication.shared.terminate(self)
    }
}
