//
//  ShoveTests.swift
//  ShoveTests
//
//  Created by Jeremy Kanter on 7/8/26.
//

import CoreGraphics
import Foundation
import Testing
@testable import Shove

@MainActor
struct LayoutEngineTests {
    /// A 1200×900 visible frame at the origin, so twelfths are 100 pt wide.
    let screen = CGRect(x: 0, y: 0, width: 1200, height: 900)
    /// An arbitrary frame that matches no cycle step.
    let floating = CGRect(x: 123, y: 77, width: 500, height: 300)

    private func press(_ direction: Direction, on frame: CGRect, screen: CGRect? = nil) -> CGRect {
        LayoutEngine.nextFrame(direction: direction, current: frame, screen: screen ?? self.screen).frame
    }

    @Test func leftFirstPressIsLeftHalf() {
        #expect(press(.left, on: floating) == CGRect(x: 0, y: 0, width: 600, height: 900))
    }

    @Test func leftCycleWalksAllTwelfthsAndWraps() {
        var frame = floating
        var widths: [CGFloat] = []
        for _ in 0..<13 {
            frame = press(.left, on: frame)
            widths.append(frame.width)
            #expect(frame.minX == 0)
            #expect(frame.minY == 0)
            #expect(frame.height == 900)
        }
        #expect(widths == [600, 500, 400, 300, 200, 100, 1200, 1100, 1000, 900, 800, 700, 600])
    }

    @Test func rightCyclePinsRightEdgeOnOffsetScreen() {
        // Simulates a second display sitting to the right of the primary.
        let screen = CGRect(x: 1512, y: 100, width: 1200, height: 900)
        var frame = floating
        for _ in 0..<12 {
            frame = press(.right, on: frame, screen: screen)
            #expect(frame.maxX == screen.maxX)
            #expect(frame.minY == screen.minY)
            #expect(frame.height == screen.height)
        }
        #expect(frame.width == 700)
    }

    @Test func upFirstPressFillsScreenThenCyclesCenteredWidths() {
        var frame = press(.up, on: floating)
        #expect(frame == screen)
        var widths: [CGFloat] = []
        for _ in 0..<6 {
            frame = press(.up, on: frame)
            widths.append(frame.width)
            #expect(abs(frame.midX - screen.midX) <= 1)
            #expect(frame.height == 900)
        }
        #expect(widths == [1000, 800, 600, 400, 200, 1200])
    }

    @Test func downCyclesHeightsAndKeepsWidth() {
        var frame = press(.down, on: floating)
        #expect(frame == CGRect(x: 123, y: 0, width: 500, height: 450))
        var heights: [CGFloat] = []
        for _ in 0..<4 {
            frame = press(.down, on: frame)
            heights.append(frame.height)
            #expect(frame.minX == 123)
            #expect(frame.width == 500)
            #expect(frame.minY == 0)
        }
        #expect(heights == [225, 900, 675, 450])
    }

    @Test func matchingToleratesSmallDeviations() {
        // A window a few points off the left-half step (an app that snaps its
        // size) still advances to the next step instead of restarting.
        let almostLeftHalf = CGRect(x: 0, y: 3, width: 594, height: 892)
        #expect(press(.left, on: almostLeftHalf).width == 500)
    }

    @Test func mismatchBeyondToleranceRestartsCycle() {
        let notAStep = CGRect(x: 0, y: 0, width: 650, height: 900)
        #expect(press(.left, on: notAStep).width == 600)
    }

    @Test func windowOnNoStepRestartsCycle() {
        // Without a clamp memo (e.g. after a manual move), a window on no
        // step restarts at step 0.
        let atMinimum = CGRect(x: 0, y: 0, width: 450, height: 900)
        #expect(press(.left, on: atMinimum).width == 600)
    }

    @Test func clampedContinuationSkipsToFullScreen() {
        // Indigo scenario: 1/3 (step 2) clamped at a 450 pt minimum. The next
        // press skips 1/4, 1/6, and 1/12 and lands on full screen.
        let atMinimum = CGRect(x: 0, y: 0, width: 450, height: 900)
        let (step, frame) = LayoutEngine.frame(
            afterClampedStep: 2,
            direction: .left,
            current: atMinimum,
            screen: screen,
            minSize: CGSize(width: 450, height: 900)
        )
        #expect(step == 6)
        #expect(frame == screen)

        // Down: 1/4 height (step 1) clamped at 400 pt continues to full height.
        let bottomClamped = CGRect(x: 123, y: 0, width: 500, height: 400)
        let (downStep, downFrame) = LayoutEngine.frame(
            afterClampedStep: 1,
            direction: .down,
            current: bottomClamped,
            screen: screen,
            minSize: CGSize(width: 500, height: 400)
        )
        #expect(downStep == 2)
        #expect(downFrame == CGRect(x: 123, y: 0, width: 500, height: 900))
    }

    @Test func clampedContinuationWithHugeMinimumFallsBackToLargest() {
        let (step, frame) = LayoutEngine.frame(
            afterClampedStep: 0,
            direction: .left,
            current: CGRect(x: 0, y: 0, width: 1200, height: 900),
            screen: screen,
            minSize: CGSize(width: 1300, height: 900)
        )
        #expect(step == 6)
        #expect(frame == screen)
    }

    @Test func cornerMovesKeepSizeAndPinTopCorners() {
        let topLeft = LayoutEngine.frame(corner: .topLeft, current: floating, screen: screen)
        #expect(topLeft == CGRect(x: 0, y: 600, width: 500, height: 300))

        // Offset screen simulating a second display.
        let offset = CGRect(x: 1512, y: 100, width: 1200, height: 900)
        let topRight = LayoutEngine.frame(corner: .topRight, current: floating, screen: offset)
        #expect(topRight.size == floating.size)
        #expect(topRight.maxX == offset.maxX)
        #expect(topRight.maxY == offset.maxY)
    }

    @Test func directionsInterpretEachOthersFramesByGeometry() {
        // A left-half window isn't centered, so Up starts its cycle fresh.
        let leftHalf = CGRect(x: 0, y: 0, width: 600, height: 900)
        #expect(press(.up, on: leftHalf) == screen)
        // A full-screen window matches Left's full-width step, so Left
        // continues from there to 11/12.
        #expect(press(.left, on: screen).width == 1100)
        // A left-half window is full height, so Down advances to 3/4 height.
        #expect(press(.down, on: leftHalf) == CGRect(x: 0, y: 0, width: 600, height: 675))
    }
}
