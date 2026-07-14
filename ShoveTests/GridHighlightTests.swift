//
//  GridHighlightTests.swift
//  ShoveTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Shove

struct GridHighlightTests {
    /// A 1200×900 visible frame at the origin, so grid columns are 100 pt
    /// wide and grid rows 225 pt tall.
    let screen = CGRect(x: 0, y: 0, width: 1200, height: 900)

    @Test func fullScreenLightsEverything() {
        let highlight = GridHighlight.cells(for: screen, in: screen)
        #expect(highlight == GridHighlight(columnRange: 0..<12, rowRange: 0..<4))
    }

    @Test func leftHalfLightsLeftSixColumns() {
        let half = CGRect(x: 0, y: 0, width: 600, height: 900)
        let highlight = GridHighlight.cells(for: half, in: screen)
        #expect(highlight == GridHighlight(columnRange: 0..<6, rowRange: 0..<4))
    }

    @Test func bottomAnchoredWindowLightsBottomRows() {
        // Cocoa's y grows upward, so minY == screen.minY is the *bottom* of
        // the grid, not the top.
        let bottom = CGRect(x: 100, y: 0, width: 500, height: 450)
        let highlight = GridHighlight.cells(for: bottom, in: screen)
        #expect(highlight == GridHighlight(columnRange: 1..<6, rowRange: 2..<4))
    }

    @Test func topPinnedWindowLightsTopRows() {
        let top = CGRect(x: 700, y: 450, width: 500, height: 450)
        let highlight = GridHighlight.cells(for: top, in: screen)
        #expect(highlight == GridHighlight(columnRange: 7..<12, rowRange: 0..<2))
    }

    @Test func edgesRoundToNearestGridLine() {
        // A min-clamped window at 4.5 columns wide: 4.5 rounds half away
        // from zero to 5.
        let clamped = CGRect(x: 0, y: 0, width: 450, height: 900)
        let highlight = GridHighlight.cells(for: clamped, in: screen)
        #expect(highlight.columnRange == 0..<5)
    }

    @Test func tinyWindowStillLightsOneCell() {
        let tiny = CGRect(x: 595, y: 445, width: 10, height: 10)
        let highlight = GridHighlight.cells(for: tiny, in: screen)
        #expect(highlight.columnRange.count == 1)
        #expect(highlight.rowRange.count == 1)
        #expect(highlight == GridHighlight(columnRange: 6..<7, rowRange: 2..<3))
    }

    @Test func tinyWindowInCornerStaysOnGrid() {
        let corner = CGRect(x: 1195, y: 0, width: 10, height: 10)
        let highlight = GridHighlight.cells(for: corner, in: screen)
        #expect(highlight == GridHighlight(columnRange: 11..<12, rowRange: 3..<4))
    }

    @Test func overhangingWindowClampsToGrid() {
        let overhang = CGRect(x: 900, y: -100, width: 600, height: 500)
        let highlight = GridHighlight.cells(for: overhang, in: screen)
        #expect(highlight == GridHighlight(columnRange: 9..<12, rowRange: 2..<4))
    }

    @Test func offsetScreenIsRelative() {
        // Simulates a second display sitting to the right of the primary.
        let offset = CGRect(x: 1512, y: 100, width: 1200, height: 900)
        let half = CGRect(x: offset.minX, y: offset.minY, width: 600, height: 900)
        let highlight = GridHighlight.cells(for: half, in: offset)
        #expect(highlight == GridHighlight(columnRange: 0..<6, rowRange: 0..<4))
    }

    @Test func indicatorFromCorner() {
        #expect(Indicator(corner: .topLeft) == .topLeft)
        #expect(Indicator(corner: .topRight) == .topRight)
    }
}
