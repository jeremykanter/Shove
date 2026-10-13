import AppKit
import SwiftUI
import Testing
@testable import Shove

@MainActor
struct ZZRenderSettingsTests {
    @Test func renderSettings() throws {
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 760), styleMask: [.titled], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: appearance)
            let host = NSHostingView(rootView: SettingsView().frame(width: 480, height: 760))
            window.contentView = host
            window.orderFront(nil)
            for _ in 0..<5 { RunLoop.main.run(until: Date().addingTimeInterval(0.2)) }
            host.layoutSubtreeIfNeeded()
            let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: rep)
            let data = try #require(rep.representation(using: .png, properties: [:]))
            try data.write(to: URL(fileURLWithPath: "/private/tmp/claude-501/-Users-jeremyk-Documents-App-Projects-Shove/2fe43549-1578-427d-9de6-ead2633999fb/scratchpad/settings-\(name).png"))
            window.close()
        }
    }
}
