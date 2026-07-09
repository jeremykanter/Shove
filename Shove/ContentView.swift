//
//  ContentView.swift
//  Shove
//
//  Created by Jeremy Kanter on 7/8/26.
//

import Combine
import SwiftUI
import KeyboardShortcuts

struct ContentView: View {
    @State private var isTrusted = AccessibilityPermission.isGranted
    @AppStorage("reverseWhileHeld") private var reverseWhileHeld = true
    private let trustCheck = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            permissionStatus
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                ForEach(shortcutRows, id: \.name.rawValue) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(KeyboardShortcuts.getShortcut(for: row.name)?.description ?? "—")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 90, alignment: .leading)
                        Text(row.label)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Divider()
            Toggle("Pressing the opposite arrow steps backward while the modifier keys stay held", isOn: $reverseWhileHeld)
                .font(.callout)
        }
        .padding(24)
        .frame(width: 440)
        .onReceive(trustCheck) { _ in
            isTrusted = AccessibilityPermission.isGranted
        }
    }

    private var shortcutRows: [(name: KeyboardShortcuts.Name, label: String)] {
        Direction.allCases.map { ($0.shortcutName, $0.label) }
            + Corner.allCases.map { ($0.shortcutName, $0.label) }
            + [(.shoveCenter, "Center without resizing")]
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
    ContentView()
}
