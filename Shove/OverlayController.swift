//
//  OverlayController.swift
//  Shove
//

import AppKit
import SwiftUI

/// Owns the grid overlay panel: shows it centered on the shoved window's
/// screen, keeps it up while the shortcut's modifiers stay held, and fades
/// it out one second after they're released (or one second after the
/// press, for shortcuts with no modifiers to hold).
@MainActor
final class OverlayController {
    static let shared = OverlayController()

    private let model = OverlayModel()
    private var panel: NSPanel?

    /// The triggering shortcut's modifiers while we're waiting for the user
    /// to release them; nil once the fade countdown is running.
    private var awaitedModifiers: NSEvent.ModifierFlags?
    private var fadeTask: Task<Void, Never>?
    /// Bumped by every show() and fadeOut() so a stale fade completion can't
    /// hide a freshly re-shown panel.
    private var fadeGeneration = 0

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "showOverlay") == nil
            || UserDefaults.standard.bool(forKey: "showOverlay")
    }

    /// Shows or updates the overlay centered on `screen`. The fade countdown
    /// waits for `heldModifiers` to be released; if they're empty or already
    /// up (e.g. the debug hook fired the shortcut), it starts immediately.
    func show(_ content: OverlayContent, on screen: NSScreen, heldModifiers: NSEvent.ModifierFlags) {
        guard isEnabled else { return }

        fadeTask?.cancel()
        fadeTask = nil
        fadeGeneration += 1

        model.content = content

        let panel = panel ?? makePanel()
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(CGPoint(
            x: (visible.midX - size.width / 2).rounded(),
            y: (visible.midY - size.height / 2).rounded()
        ))
        // A zero-duration group replaces any in-flight fade animation.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            panel.animator().alphaValue = 1
        }
        panel.orderFrontRegardless()

        let held = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if !heldModifiers.isEmpty, held.isSuperset(of: heldModifiers) {
            awaitedModifiers = heldModifiers
        } else {
            awaitedModifiers = nil
            startFadeCountdown()
        }
    }

    /// Forwarded from ShortcutHandler's flagsChanged monitors.
    func modifiersChanged(to flags: NSEvent.ModifierFlags) {
        guard let awaited = awaitedModifiers,
              !flags.intersection(.deviceIndependentFlagsMask).isSuperset(of: awaited) else {
            return
        }
        awaitedModifiers = nil
        startFadeCountdown()
    }

    private func startFadeCountdown() {
        fadeTask?.cancel()
        fadeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.fadeOut()
        }
    }

    private func fadeOut() {
        guard let panel else { return }
        fadeGeneration += 1
        let generation = fadeGeneration
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { [weak self] in
                guard let self, self.fadeGeneration == generation else { return }
                self.panel?.orderOut(nil)
            }
        }
    }

    private func makePanel() -> NSPanel {
        let hosting = NSHostingView(rootView: OverlayGridView(model: model))
        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.animationBehavior = .none
        panel.contentView = hosting
        self.panel = panel
        return panel
    }
}
