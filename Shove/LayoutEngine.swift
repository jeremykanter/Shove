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

    /// The frame the window should get on the next press: if its current
    /// frame sits on step `i` of the direction's cycle, the frame for step
    /// `i + 1` (wrapping); otherwise the frame for step 0. Steps the window
    /// cannot shrink to (its minimum size, if known, exceeds them on the
    /// cycling axis) are skipped.
    static func nextFrame(direction: Direction, current: CGRect, screen: CGRect, minSize: CGSize = .zero) -> CGRect {
        let stepCount = direction.fractions.count
        let matched = (0..<stepCount).first { step in
            matches(current, frame(step: step, direction: direction, screen: screen, current: current), direction: direction)
        }
        let start = matched.map { $0 + 1 } ?? 0
        for offset in 0..<stepCount {
            let step = (start + offset) % stepCount
            let candidate = frame(step: step, direction: direction, screen: screen, current: current)
            if fits(candidate, minSize: minSize, direction: direction) {
                return candidate
            }
        }
        // The window's minimum exceeds even the largest step; give it the
        // largest one and let the caller re-pin the clamped result.
        let largest = direction.fractions.firstIndex(of: direction.fractions.max()!)!
        return frame(step: largest, direction: direction, screen: screen, current: current)
    }

    private static func fits(_ candidate: CGRect, minSize: CGSize, direction: Direction) -> Bool {
        direction == .down
            ? candidate.height >= minSize.height - tolerance
            : candidate.width >= minSize.width - tolerance
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
