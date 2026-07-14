//
//  GridHighlight.swift
//  Shove
//

import CoreGraphics

/// What the overlay displays: the window's cells on the grid (directional
/// shoves) or a single dot marking a corner/center move.
enum OverlayContent: Equatable {
    case grid(GridHighlight)
    case indicator(Indicator)
}

/// The region a move-only shortcut targets, shown as a dot in that part of
/// the (grid-less) frame.
enum Indicator: Equatable {
    case topLeft, topRight, center

    init(corner: Corner) {
        switch corner {
        case .topLeft: self = .topLeft
        case .topRight: self = .topRight
        }
    }
}

/// Which cells of the overlay's 12×4 grid are lit. Columns run left to
/// right (0..<12); rows run top to bottom (0..<4) — the flip from Cocoa's
/// Y-up screen coordinates happens in `cells(for:in:)`.
struct GridHighlight: Equatable {
    static let columns = 12
    static let rows = 4

    let columnRange: Range<Int>
    let rowRange: Range<Int>

    func contains(column: Int, row: Int) -> Bool {
        columnRange.contains(column) && rowRange.contains(row)
    }

    /// The cells covered by a window frame (Cocoa coordinates), proportional
    /// to the screen's visible frame. Each edge rounds to the nearest grid
    /// line; a range that rounds away to nothing widens to the single cell
    /// containing the window's midpoint on that axis.
    static func cells(for target: CGRect, in screen: CGRect) -> GridHighlight {
        GridHighlight(
            columnRange: span(
                from: (target.minX - screen.minX) / screen.width,
                to: (target.maxX - screen.minX) / screen.width,
                cells: columns
            ),
            rowRange: span(
                from: (screen.maxY - target.maxY) / screen.height,
                to: (screen.maxY - target.minY) / screen.height,
                cells: rows
            )
        )
    }

    /// Maps a normalized 0...1 edge pair onto grid indices, rounding each
    /// edge to the nearest grid line and clamping to the grid.
    private static func span(from lower: CGFloat, to upper: CGFloat, cells: Int) -> Range<Int> {
        let count = CGFloat(cells)
        var first = Int((lower * count).rounded().clamped(to: 0...count))
        var last = Int((upper * count).rounded().clamped(to: 0...count))
        if first >= last {
            // Too narrow to cross a grid line; light the cell under the midpoint.
            let midpoint = ((lower + upper) / 2 * count).rounded(.down)
            first = Int(midpoint.clamped(to: 0...count - 1))
            last = first + 1
        }
        return first..<last
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
