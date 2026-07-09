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
        Settings {
            SettingsView()
        }
        .windowResizability(.contentSize)
        // Without this, SwiftUI treats Settings as the app's only window
        // scene and opens it on a fresh launch.
        .defaultLaunchBehavior(.suppressed)
    }
}

enum SettingsOpener {
    /// The app is an accessory (LSUIElement), so it must activate itself
    /// first or the settings window opens behind the frontmost app without
    /// key focus.
    static func open() {
        NSApp.activate()
        EnvironmentValues().openSettings()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// A headless app has nothing to reopen when launched again from Finder
    /// or the Dock, so treat that as a request for the settings window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsOpener.open()
        return false
    }
}
