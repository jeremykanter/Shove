//
//  ShoveApp.swift
//  Shove
//
//  Created by Jeremy Kanter on 7/8/26.
//

import SwiftUI

@main
struct ShoveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        AccessibilityPermission.promptIfNeeded()
        ShortcutHandler.registerAll()
        #if DEBUG
        ShortcutHandler.registerDebugHook()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            SettingsView()
                .frame(minWidth: 400, idealWidth: 480, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

/// Runs "headless": the app is a regular foreground app (Dock icon + menu bar)
/// only while its settings window is open, and drops to `.accessory` once the
/// window closes so the global hotkeys keep working in the background with no
/// Dock presence. Relaunching from Spotlight/Finder reopens the window.
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Flip to background (accessory) once the user closes the settings
        // window, so the app runs headless without a Dock icon.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil)

        // Never force the app headless mid-test — a UI test launches this app
        // and expects its window to stay put.
        guard !Self.isRunningUnderTests else { return }

        // Detect a login-item (background) launch and start headless. A manual
        // Finder/Spotlight launch activates the app almost immediately; a login
        // launch never does and leaves its window unshown in the background. If
        // we still aren't active a moment later, we were launched at login —
        // drop the Dock icon and close the unshown window.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !NSApp.isActive else { return }
            NSApp.setActivationPolicy(.accessory)
            self.closeAllWindows()
        }
    }

    private func closeAllWindows() {
        for window in NSApp.windows where !(window is NSPanel) {
            window.close()
        }
    }

    /// Keep the app alive (headless) when the settings window is closed — the
    /// global hotkeys live on past the window.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Relaunching from Spotlight/Finder while already running: bring the app
    /// back to the foreground and reopen the settings window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    /// When the last visible window closes, go headless (no Dock icon). The
    /// overlay is an `NSPanel`, so it never counts as a real window here.
    @objc private func windowWillClose(_ notification: Notification) {
        // The closing window is still in `NSApp.windows` during this
        // notification, so defer the check to the next runloop tick.
        DispatchQueue.main.async {
            let hasVisibleWindow = NSApp.windows.contains {
                $0.isVisible && !($0 is NSPanel)
            }
            if !hasVisibleWindow {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    static var isRunningUnderTests: Bool {
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil { return true }
        return CommandLine.arguments.contains("-uiTestingDisableAutomation")
    }
}
