//
//  ShoveApp.swift
//  Shove
//
//  Created by Jeremy Kanter on 7/8/26.
//

import SwiftUI

@main
struct ShoveApp: App {
    init() {
        AccessibilityPermission.promptIfNeeded()
        ShortcutHandler.registerAll()
        #if DEBUG
        ShortcutHandler.registerDebugHook()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
