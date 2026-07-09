//
//  Shortcuts.swift
//  Shove
//

import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let shoveLeft = Self("shoveLeft", default: .init(.leftArrow, modifiers: [.command, .shift, .option, .control]))
    static let shoveRight = Self("shoveRight", default: .init(.rightArrow, modifiers: [.command, .shift, .option, .control]))
    static let shoveUp = Self("shoveUp", default: .init(.upArrow, modifiers: [.command, .shift, .option, .control]))
    static let shoveDown = Self("shoveDown", default: .init(.downArrow, modifiers: [.command, .shift, .option, .control]))
    static let shoveTopLeft = Self("shoveTopLeft", default: .init(.leftBracket, modifiers: [.command, .shift, .option, .control]))
    static let shoveTopRight = Self("shoveTopRight", default: .init(.rightBracket, modifiers: [.command, .shift, .option, .control]))
    static let shoveCenter = Self("shoveCenter", default: .init(.quote, modifiers: [.command, .shift, .option, .control]))
}

extension Corner {
    var shortcutName: KeyboardShortcuts.Name {
        switch self {
        case .topLeft: .shoveTopLeft
        case .topRight: .shoveTopRight
        }
    }

    var label: String {
        switch self {
        case .topLeft: "Move to the top-left corner"
        case .topRight: "Move to the top-right corner"
        }
    }
}

extension Direction {
    var shortcutName: KeyboardShortcuts.Name {
        switch self {
        case .left: .shoveLeft
        case .right: .shoveRight
        case .up: .shoveUp
        case .down: .shoveDown
        }
    }

    var label: String {
        switch self {
        case .left: "Left half, then cycle widths from the left edge"
        case .right: "Right half, then cycle widths from the right edge"
        case .up: "Full screen, then cycle centered widths"
        case .down: "Bottom half, then cycle heights from the bottom edge"
        }
    }
}

enum ShortcutHandler {
    #if DEBUG
    /// Lets a test harness trigger presses without synthesizing keyboard
    /// events: `ShoveDebugPress` with object "left"/"right"/"up"/"down".
    /// "windows" instead lists the app's visible windows. Results are
    /// appended to /tmp/shove-debug.log.
    static func registerDebugHook() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("ShoveDebugPress"), object: nil, queue: .main
        ) { note in
            MainActor.assumeIsolated {
                func log(_ line: String) {
                    if let data = line.data(using: .utf8),
                       let handle = FileHandle(forWritingAtPath: "/tmp/shove-debug.log") ?? {
                           FileManager.default.createFile(atPath: "/tmp/shove-debug.log", contents: nil)
                           return FileHandle(forWritingAtPath: "/tmp/shove-debug.log")
                       }() {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                }
                if note.object as? String == "windows" {
                    let titles = NSApp.windows.filter(\.isVisible).map { "\(type(of: $0)) \"\($0.title)\"" }
                    log("windows: [\(titles.joined(separator: ", "))]\n")
                    return
                }
                if let object = note.object as? String, object.hasPrefix("shrink:"),
                   let width = Double(object.dropFirst("shrink:".count)) {
                    let window = FocusedWindow.current()
                    let before = window?.frame
                    if let window, let frame = window.frame {
                        window.setSizeOnce(CGSize(width: width, height: frame.height))
                    }
                    let after = window?.frame
                    log("\(object): \(before.map(String.init(describing:)) ?? "nil") -> \(after.map(String.init(describing:)) ?? "nil")\n")
                    return
                }
                let before = FocusedWindow.current()?.frame
                switch note.object as? String {
                case "left": shove(.left)
                case "right": shove(.right)
                case "up": shove(.up)
                case "down": shove(.down)
                case "center": center()
                case "release": heldChain = nil
                default: return
                }
                let after = FocusedWindow.current()?.frame
                log("\(note.object ?? "?"): \(before.map(String.init(describing:)) ?? "nil") -> \(after.map(String.init(describing:)) ?? "nil")\n")
            }
        }
    }
    #endif

    static func registerAll() {
        for direction in Direction.allCases {
            KeyboardShortcuts.onKeyDown(for: direction.shortcutName) {
                shove(direction)
            }
        }
        for corner in Corner.allCases {
            KeyboardShortcuts.onKeyDown(for: corner.shortcutName) {
                shove(corner)
            }
        }
        KeyboardShortcuts.onKeyDown(for: .shoveCenter) {
            center()
        }
        // The reverse gesture lives and dies with the modifier keys, so watch
        // for releases. The global monitor covers presses while another app is
        // frontmost (it needs the Accessibility trust the app already
        // requires); the local one covers Shove's own window.
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            let flags = event.modifierFlags
            MainActor.assumeIsolated { modifiersChanged(to: flags) }
        }
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let flags = event.modifierFlags
            MainActor.assumeIsolated { modifiersChanged(to: flags) }
            return event
        }
    }

    private static func modifiersChanged(to flags: NSEvent.ModifierFlags) {
        guard let chain = heldChain,
              !flags.intersection(.deviceIndependentFlagsMask).isSuperset(of: chain.modifiers) else {
            return
        }
        heldChain = nil
    }

    static func center() {
        heldChain = nil
        guard AccessibilityPermission.isGranted,
              let window = FocusedWindow.current(),
              let current = window.frame,
              let screen = window.screen else {
            NSSound.beep()
            return
        }
        window.move(to: LayoutEngine.centeredFrame(current: current, screen: screen.visibleFrame))
    }

    static func shove(_ corner: Corner) {
        heldChain = nil
        guard AccessibilityPermission.isGranted,
              let window = FocusedWindow.current(),
              let current = window.frame,
              let screen = window.screen else {
            NSSound.beep()
            return
        }
        window.move(to: LayoutEngine.frame(corner: corner, current: current, screen: screen.visibleFrame))
    }

    /// Set when the last shove asked for a size the window refused (clamped
    /// at its minimum). A clamped window sits on no cycle step, so stateless
    /// matching alone would restart the cycle; this remembers where in the
    /// cycle the window was so the next press continues past the unreachable
    /// steps to full screen. Invalidated by anything that changes the window
    /// or its frame.
    private static var pendingClamp: (window: FocusedWindow, direction: Direction, step: Int, frame: CGRect, minSize: CGSize)?

    /// Alive while the user keeps the triggering shortcut's modifiers held
    /// after a directional shove: the opposite arrow then steps backward
    /// through this cycle instead of starting its own. Cleared by the
    /// flagsChanged monitors the moment any of the modifiers is released,
    /// and invalidated by anything that changes the window or its frame.
    private static var heldChain: (window: FocusedWindow, direction: Direction, step: Int, frame: CGRect, modifiers: NSEvent.ModifierFlags)?

    private static var reverseWhileHeld: Bool {
        UserDefaults.standard.object(forKey: "reverseWhileHeld") == nil
            || UserDefaults.standard.bool(forKey: "reverseWhileHeld")
    }

    static func shove(_ pressed: Direction) {
        guard AccessibilityPermission.isGranted,
              let window = FocusedWindow.current(),
              let current = window.frame,
              let screen = window.screen else {
            NSSound.beep()
            return
        }
        let visible = screen.visibleFrame

        // A clamp memo only applies while nothing about the window changed.
        let clamp = pendingClamp.flatMap { memo in
            window.isSame(as: memo.window) && LayoutEngine.roughlyEqual(current, memo.frame) ? memo : nil
        }
        pendingClamp = nil

        // The cycle being walked: the opposite direction's, stepped backward,
        // when the modifiers never left the keyboard; otherwise the pressed
        // direction's, forward.
        let direction: Direction
        let step: Int
        let target: CGRect
        if reverseWhileHeld,
           let chain = heldChain,
           chain.direction == pressed.opposite,
           window.isSame(as: chain.window),
           LayoutEngine.roughlyEqual(current, chain.frame) {
            direction = chain.direction
            (step, target) = LayoutEngine.frame(
                beforeStep: chain.step,
                direction: direction,
                current: current,
                screen: visible,
                minSize: clamp?.direction == direction ? clamp?.minSize : nil
            )
        } else if let clamp, clamp.direction == pressed {
            direction = pressed
            (step, target) = LayoutEngine.frame(
                afterClampedStep: clamp.step,
                direction: direction,
                current: current,
                screen: visible,
                minSize: clamp.minSize
            )
        } else {
            direction = pressed
            (step, target) = LayoutEngine.nextFrame(direction: direction, current: current, screen: visible)
        }
        heldChain = nil

        window.apply(target)
        guard let achieved = window.frame else { return }

        // A window with size constraints settles at whatever size it accepts
        // (e.g. its minimum); the position was computed for the requested
        // size, so re-pin the anchored edge to match reality.
        let tolerance = LayoutEngine.tolerance
        var settled = achieved
        if abs(achieved.width - target.width) > tolerance || abs(achieved.height - target.height) > tolerance {
            let pinned = pin(achieved, direction: direction, screen: visible)
            if pinned.origin != achieved.origin {
                window.move(to: pinned)
                settled = window.frame ?? pinned
            }
            // Only a window that came back *larger* than asked is min-clamped;
            // remember it so the next press can continue the cycle.
            if achieved.width > target.width + tolerance || achieved.height > target.height + tolerance {
                pendingClamp = (window, direction, step, settled, achieved.size)
            }
        }
        // Arm the reverse gesture for the next press. A shortcut without
        // modifiers has nothing to hold, so it never chains.
        if let modifiers = KeyboardShortcuts.getShortcut(for: pressed.shortcutName)?.modifiers,
           !modifiers.isEmpty {
            heldChain = (window, direction, step, settled, modifiers)
        }
    }

    /// `frame` with its origin corrected so the direction's anchored edge
    /// sits where the cycle promises it, whatever size the window ended up.
    private static func pin(_ frame: CGRect, direction: Direction, screen: CGRect) -> CGRect {
        var frame = frame
        frame.origin.y = screen.minY
        switch direction {
        case .left:
            frame.origin.x = screen.minX
        case .right:
            frame.origin.x = screen.maxX - frame.width
        case .up:
            frame.origin.x = (screen.midX - frame.width / 2).rounded()
        case .down:
            break
        }
        return frame
    }
}
