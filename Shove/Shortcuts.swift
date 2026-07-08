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

    static func shove(_ direction: Direction) {
        guard AccessibilityPermission.isGranted,
              let window = FocusedWindow.current(),
              let current = window.frame,
              let screen = window.screen else {
            NSSound.beep()
            return
        }
        let visible = screen.visibleFrame
        var target = LayoutEngine.nextFrame(direction: direction, current: current, screen: visible)
        window.apply(target)
        guard var achieved = window.frame else { return }

        // The AX API doesn't expose a window's minimum size, so probe: if the
        // window came back larger than requested, it clamped. Redo the cycle
        // treating the clamped size as the minimum, skipping steps it can't
        // reach.
        let tolerance = LayoutEngine.tolerance
        if achieved.width > target.width + tolerance || achieved.height > target.height + tolerance {
            let retry = LayoutEngine.nextFrame(
                direction: direction,
                current: current,
                screen: visible,
                minSize: achieved.size
            )
            if retry != target {
                target = retry
                window.apply(target)
                achieved = window.frame ?? achieved
            }
        }

        // If the size still isn't what was asked for, the position was
        // computed for the wrong size — re-pin the window's anchored edge.
        if abs(achieved.width - target.width) > tolerance || abs(achieved.height - target.height) > tolerance {
            let pinned = pin(achieved, direction: direction, screen: visible)
            if pinned.origin != achieved.origin {
                window.move(to: pinned)
            }
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
