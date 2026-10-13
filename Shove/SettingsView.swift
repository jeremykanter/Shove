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
    @AppStorage("showOverlay") private var showOverlay = true
    @ObservedObject private var updater = UpdaterModel.shared
    private let trustCheck = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shove")
                        .font(.title.bold())
                    Text("Fling your windows around")
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Shove in the opposite direction while continuing to hold the modifier keys to step backwards through the cycle", isOn: $reverseWhileHeld)
                    Toggle("Show overlay while moving windows", isOn: $showOverlay)
                    Toggle("Start at login", isOn: $startsAtLogin)
                        .onChange(of: startsAtLogin) { _, enabled in
                            setLoginItem(enabled)
                        }
                    Toggle("Automatically check for updates", isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.setAutomaticallyChecksForUpdates($0) }
                    ))
                }
                if !isTrusted {
                    permissionStatus
                }
            }
            .frame(width: 280)
            .padding(24)
            Divider()
            Form {
                Section("Shove") {
                    KeyboardShortcuts.Recorder("Shove left", name: .shoveLeft)
                    KeyboardShortcuts.Recorder("Shove right", name: .shoveRight)
                    KeyboardShortcuts.Recorder("Shove middle", name: .shoveUp)
                    KeyboardShortcuts.Recorder("Shove down", name: .shoveDown)
                }
                Section("Move") {
                    KeyboardShortcuts.Recorder("Move to top-left", name: .shoveTopLeft)
                    KeyboardShortcuts.Recorder("Move to top-right", name: .shoveTopRight)
                    KeyboardShortcuts.Recorder("Move to center", name: .shoveCenter)
                }
            }
            .formStyle(.grouped)
            .onReceive(trustCheck) { _ in
                isTrusted = AccessibilityPermission.isGranted
            }
        }
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
        VStack(alignment: .leading, spacing: 12) {
            if #available(macOS 27, *) {
                Text("\(Image(systemName: "exclamationmark.triangle")) Shove needs Device Control and Data Access permissions to move windows")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(Image(systemName: "exclamationmark.triangle")) Shove needs Device Control and Data Access permissions to move windows")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button("Open System Settings…") {
                AccessibilityPermission.openSystemSettings()
            }
            .controlSize(.small)
        }
    }
}

#Preview {
    SettingsView()
}
