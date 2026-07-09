//
//  SettingsView.swift
//  Shove
//
//  Created by Jeremy Kanter on 7/8/26.
//

import Combine
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var isTrusted = AccessibilityPermission.isGranted
    @State private var startsAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("reverseWhileHeld") private var reverseWhileHeld = true
    private let trustCheck = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                permissionStatus
            }
            Section("Shortcuts") {
                ForEach(shortcutRows, id: \.name.rawValue) { row in
                    KeyboardShortcuts.Recorder(row.label, name: row.name)
                }
            }
            Section {
                Toggle("Pressing the opposite arrow steps backward while the modifier keys stay held", isOn: $reverseWhileHeld)
                Toggle("Start Shove at login", isOn: $startsAtLogin)
                    .onChange(of: startsAtLogin) { _, enabled in
                        setLoginItem(enabled)
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .onReceive(trustCheck) { _ in
            isTrusted = AccessibilityPermission.isGranted
        }
    }

    private var shortcutRows: [(name: KeyboardShortcuts.Name, label: String)] {
        Direction.allCases.map { ($0.shortcutName, $0.label) }
            + Corner.allCases.map { ($0.shortcutName, $0.label) }
            + [(.shoveCenter, "Center without resizing")]
    }

    private func setLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            startsAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    @ViewBuilder
    private var permissionStatus: some View {
        if isTrusted {
            Label("Accessibility access granted", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("Accessibility access required", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Shove needs Accessibility access to move and resize windows of other apps.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Open System Settings…") {
                    AccessibilityPermission.openSystemSettings()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
