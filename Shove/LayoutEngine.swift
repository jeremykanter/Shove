//
//  LayoutEngine.swift
//  Shove
//

import CoreGraphics

enum Direction: CaseIterable {
    case left, right, up, down

    /// The fraction of the screen each cycle step occupies — width for
    /// left/right/up, height for down. Index 0 is the first-press step.
    var fractions: [CGFloat] {
        switch self {
        case .left, .right:
            [6, 5, 4, 3, 2, 1, 12, 11, 10, 9, 8, 7].map { $0 / 12 }
        case .up:
            [6, 5, 4, 3, 2, 1].map { $0 / 6 }
        case .down:
            [6, 3, 12, 9].map { $0 / 12 }
        }
    }
}

enum Corner: CaseIterable {
    case topLeft, topRight
}

/// Pure geometry for the shove cycles. All rects are in Cocoa screen
/// coordinates (origin bottom-left, y increasing upward); `screen` is the
/// screen's visible frame.
enum LayoutEngine {
    /// Per-edge slack when matching the window against a cycle step, so apps
    /// that snap their size (e.g. Terminal's row/column increments) still
    /// count as "on" a step.
    static let tolerance: CGFloat = 16

    /// The step the window should get on the next press: if its current
    /// frame sits on step `i` of the direction's cycle, step `i + 1`
    /// (wrapping); otherwise step 0.
    static func nextFrame(direction: Direction, current: CGRect, screen: CGRect) -> (step: Int, frame: CGRect) {
        let stepCount = direction.fractions.count
        let matched = (0..<stepCount).first { step in
            matches(current, frame(step: step, direction: direction, screen: screen, current: current), direction: direction)
        }
        let next = matched.map { ($0 + 1) % stepCount } ?? 0
        return (next, frame(step: next, direction: direction, screen: screen, current: current))
    }

    /// Continues the cycle for a window that clamped at its minimum size on
    /// `step`: returns the first following step the window can actually
    /// reach, skipping the ones below its minimum — so a clamped window
    /// proceeds to the wrap (full screen) instead of restarting the cycle.
    static func frame(afterClampedStep step: Int, direction: Direction, current: CGRect, screen: CGRect, minSize: CGSize) -> (step: Int, frame: CGRect) {
        let stepCount = direction.fractions.count
        for offset in 1...stepCount {
            let next = (step + offset) % stepCount
            let candidate = frame(step: next, direction: direction, screen: screen, current: current)
            if fits(candidate, minSize: minSize, direction: direction) {
                return (next, candidate)
            }
        }
        // The minimum exceeds even the largest step; hand back the largest.
        let largest = direction.fractions.firstIndex(of: direction.fractions.max()!)!
        return (largest, frame(step: largest, direction: direction, screen: screen, current: current))
    }

    static func roughlyEqual(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= tolerance
            && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance
            && abs(a.height - b.height) <= tolerance
    }

    private static func fits(_ candidate: CGRect, minSize: CGSize, direction: Direction) -> Bool {
        direction == .down
            ? candidate.height >= minSize.height - tolerance
            : candidate.width >= minSize.width - tolerance
    }

    /// `current` moved (not resized) to the center of the screen, with the
    /// slight above-center vertical bias AppKit's `NSWindow.center()` uses:
    /// a third of the leftover vertical space above the window, two thirds
    /// below.
    static func centeredFrame(current: CGRect, screen: CGRect) -> CGRect {
        var frame = current
        frame.origin.x = (screen.midX - frame.width / 2).rounded()
        let slack = max(screen.height - frame.height, 0)
        frame.origin.y = (screen.minY + slack * 2 / 3).rounded()
        return frame
    }

    /// `current` moved (not resized) into the given corner of the screen.
    static func frame(corner: Corner, current: CGRect, screen: CGRect) -> CGRect {
        var frame = current
        frame.origin.y = screen.maxY - frame.height
        frame.origin.x = corner == .topLeft ? screen.minX : screen.maxX - frame.width
        return frame
    }

    static func frame(step: Int, direction: Direction, screen: CGRect, current: CGRect) -> CGRect {
        let fraction = direction.fractions[step]
        switch direction {
        case .left:
            let width = (screen.width * fraction).rounded()
            return CGRect(x: screen.minX, y: screen.minY, width: width, height: screen.height)
        case .right:
            let width = (screen.width * fraction).rounded()
            return CGRect(x: screen.maxX - width, y: screen.minY, width: width, height: screen.height)
        case .up:
            let width = (screen.width * fraction).rounded()
            return CGRect(x: (screen.midX - width / 2).rounded(), y: screen.minY, width: width, height: screen.height)
        case .down:
            let height = (screen.height * fraction).rounded()
            return CGRect(x: current.minX, y: screen.minY, width: current.width, height: height)
        }
    }

    private static func matches(_ current: CGRect, _ step: CGRect, direction: Direction) -> Bool {
        func close(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) <= tolerance }
        // Down only constrains the vertical axis; the window keeps its width.
        let horizontalMatch = direction == .down
            || (close(current.minX, step.minX) && close(current.width, step.width))
        return horizontalMatch
            && close(current.minY, step.minY)
            && close(current.height, step.height)
    }
}
