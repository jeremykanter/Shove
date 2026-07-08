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
    /// Frames are appended to /tmp/shove-debug.log.
    static func registerDebugHook() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("ShoveDebugPress"), object: nil, queue: .main
        ) { note in
            MainActor.assumeIsolated {
                let direction: Direction? = switch note.object as? String {
                case "left": .left
                case "right": .right
                case "up": .up
                case "down": .down
                default: nil
                }
                guard let direction else { return }
                let before = FocusedWindow.current()?.frame
                shove(direction)
                let after = FocusedWindow.current()?.frame
                let line = "\(note.object ?? "?"): \(before.map(String.init(describing:)) ?? "nil") -> \(after.map(String.init(describing:)) ?? "nil")\n"
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
    }

    static func shove(_ corner: Corner) {
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

    static func shove(_ direction: Direction) {
        guard AccessibilityPermission.isGranted,
              let window = FocusedWindow.current(),
              let current = window.frame,
              let screen = window.screen else {
            NSSound.beep()
            return
        }
        let visible = screen.visibleFrame

        let step: Int
        let target: CGRect
        if let clamp = pendingClamp,
           clamp.direction == direction,
           window.isSame(as: clamp.window),
           LayoutEngine.roughlyEqual(current, clamp.frame) {
            (step, target) = LayoutEngine.frame(
                afterClampedStep: clamp.step,
                direction: direction,
                current: current,
                screen: visible,
                minSize: clamp.minSize
            )
        } else {
            (step, target) = LayoutEngine.nextFrame(direction: direction, current: current, screen: visible)
        }
        pendingClamp = nil

        window.apply(target)
        guard let achieved = window.frame else { return }

        // A window with size constraints settles at whatever size it accepts
        // (e.g. its minimum); the position was computed for the requested
        // size, so re-pin the anchored edge to match reality.
        let tolerance = LayoutEngine.tolerance
        guard abs(achieved.width - target.width) > tolerance || abs(achieved.height - target.height) > tolerance else {
            return
        }
        var settled = achieved
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
