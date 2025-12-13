import Foundation
import CoreGraphics
import Cocoa

struct WindowInfo {
    let windowID: CGWindowID
    let ownerName: String
    let windowName: String
    let bounds: CGRect
    let layer: Int
    let isOnScreen: Bool
}

class WindowObserver {
    
    /// Check if we have accessibility permissions
    static var hasAccessibilityPermission: Bool {
        return AXIsProcessTrusted()
    }
    
    /// Request accessibility permission (opens System Preferences)
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    /// Get all visible windows on screen
    func getVisibleWindows() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        return windowList.compactMap { dict -> WindowInfo? in
            guard let windowID = dict[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = dict[kCGWindowBounds as String] as? [String: CGFloat],
                  let ownerName = dict[kCGWindowOwnerName as String] as? String else {
                return nil
            }
            
            // Parse bounds
            guard let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"] else {
                return nil
            }
            
            // Convert from CGWindowList coordinate system (top-left origin) to Cocoa (bottom-left)
            var bounds = CGRect(x: x, y: y, width: width, height: height)
            if let screen = NSScreen.main {
                bounds.origin.y = screen.frame.height - bounds.origin.y - bounds.height
            }
            
            let windowName = dict[kCGWindowName as String] as? String ?? ""
            let layer = dict[kCGWindowLayer as String] as? Int ?? 0
            let isOnScreen = dict[kCGWindowIsOnscreen as String] as? Bool ?? true
            
            return WindowInfo(
                windowID: windowID,
                ownerName: ownerName,
                windowName: windowName,
                bounds: bounds,
                layer: layer,
                isOnScreen: isOnScreen
            )
        }
    }
    
    /// Get windows for a specific application
    func getWindows(forApp appName: String) -> [WindowInfo] {
        return getVisibleWindows().filter { $0.ownerName == appName }
    }
    
    /// Find the window directly under a point
    func window(at point: CGPoint) -> WindowInfo? {
        let windows = getVisibleWindows()
        
        // Find windows that contain the point, sorted by layer (frontmost first)
        let containing = windows
            .filter { $0.bounds.contains(point) }
            .sorted { $0.layer > $1.layer }
        
        return containing.first
    }
    
    /// Get the frontmost window (excluding system UI elements)
    func getFrontmostWindow() -> WindowInfo? {
        let windows = getVisibleWindows()
        
        // Filter out system elements and find the frontmost
        return windows
            .filter { window in
                !["Window Server", "Dock", "SystemUIServer", "Control Center", "Notification Center"]
                    .contains(window.ownerName)
            }
            .sorted { $0.layer > $1.layer }
            .first
    }
}



