//
//  FocusedWindow.swift
//  Shove
//

import AppKit
import ApplicationServices

enum AccessibilityPermission {
    static var isGranted: Bool { AXIsProcessTrusted() }

    static func promptIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

/// The focused window of the frontmost app, addressed through the
/// Accessibility API. All frames exposed here are in Cocoa screen
/// coordinates (origin bottom-left of the primary display); conversion to
/// the AX API's top-left-origin coordinates happens internally.
struct FocusedWindow {
    private let element: AXUIElement
    private let appElement: AXUIElement

    static func current() -> FocusedWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focused: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focused)
        guard result == .success, let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return nil
        }
        return FocusedWindow(element: focused as! AXUIElement, appElement: appElement)
    }

    var frame: CGRect? {
        guard let position = pointValue(for: kAXPositionAttribute),
              let size = sizeValue(for: kAXSizeAttribute) else {
            return nil
        }
        return Self.flip(CGRect(origin: position, size: size))
    }

    /// The screen the window mostly lives on.
    var screen: NSScreen? {
        guard let frame else { return NSScreen.main }
        func overlap(_ screen: NSScreen) -> CGFloat {
            let intersection = screen.frame.intersection(frame)
            return intersection.isNull ? 0 : intersection.width * intersection.height
        }
        let best = NSScreen.screens.max { overlap($0) < overlap($1) }
        return (best.map(overlap) ?? 0) > 0 ? best : NSScreen.main
    }

    func apply(_ target: CGRect) {
        let axTarget = Self.flip(target)
        // Position strictly before size: an AX size change anchors the
        // window's top-left and gets clamped to the screen from the *current*
        // origin (a centered window asking for full width only gets the space
        // to its right), whereas moving is never clamped — a window may
        // briefly overhang the screen edge, which mostly stays invisible.
        withoutEnhancedUserInterface {
            set(axTarget.origin, for: kAXPositionAttribute)
            set(axTarget.size, for: kAXSizeAttribute)
        }
    }

    /// Moves the window so it occupies `frame`'s origin without resizing.
    /// `frame` must carry the window's actual size — the coordinate flip
    /// needs it to place the top-left corner correctly.
    func move(to frame: CGRect) {
        withoutEnhancedUserInterface {
            set(Self.flip(frame).origin, for: kAXPositionAttribute)
        }
    }

    /// Chromium/Electron apps that have the AXEnhancedUserInterface flag set
    /// ignore or misapply AX position changes. Clear the flag around frame
    /// changes and restore it afterward (the same workaround Rectangle uses).
    private func withoutEnhancedUserInterface(_ body: () -> Void) {
        let attribute = "AXEnhancedUserInterface" as CFString
        var value: CFTypeRef?
        let wasEnabled = AXUIElementCopyAttributeValue(appElement, attribute, &value) == .success
            && (value as? Bool ?? false)
        if wasEnabled {
            AXUIElementSetAttributeValue(appElement, attribute, kCFBooleanFalse)
        }
        body()
        if wasEnabled {
            AXUIElementSetAttributeValue(appElement, attribute, kCFBooleanTrue)
        }
    }

    /// Converts between Cocoa (bottom-left origin) and AX (top-left origin)
    /// screen coordinates. The transform is its own inverse.
    private static func flip(_ rect: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    private func pointValue(for attribute: String) -> CGPoint? {
        guard let axValue = copyValue(for: attribute) else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(axValue, .cgPoint, &point) ? point : nil
    }

    private func sizeValue(for attribute: String) -> CGSize? {
        guard let axValue = copyValue(for: attribute) else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(axValue, .cgSize, &size) ? size : nil
    }

    private func copyValue(for attribute: String) -> AXValue? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let value, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        return (value as! AXValue)
    }

    private func set(_ point: CGPoint, for attribute: String) {
        var point = point
        guard let axValue = AXValueCreate(.cgPoint, &point) else { return }
        AXUIElementSetAttributeValue(element, attribute as CFString, axValue)
    }

    private func set(_ size: CGSize, for attribute: String) {
        var size = size
        guard let axValue = AXValueCreate(.cgSize, &size) else { return }
        AXUIElementSetAttributeValue(element, attribute as CFString, axValue)
    }
}
