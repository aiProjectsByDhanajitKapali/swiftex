import SwiftUI

@main
struct SwiftexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Swiftex") {
            ContentView()
                .frame(minWidth: 620, minHeight: 560)
        }
        .windowResizability(.contentMinSize)
    }
}

/// Launched as an SPM executable, the process needs to opt into being a regular,
/// foreground GUI app so the window appears and can take focus.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
