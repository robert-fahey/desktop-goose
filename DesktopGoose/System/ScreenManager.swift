import Cocoa

class ScreenManager {
    
    /// All available screens
    var screens: [NSScreen] {
        return NSScreen.screens
    }
    
    /// The main/primary screen
    var primaryScreen: NSScreen? {
        return NSScreen.main
    }
    
    /// Bounds of the primary screen
    var primaryScreenBounds: CGRect {
        return primaryScreen?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
    }
    
    /// Combined bounds of all screens
    var allScreensBounds: CGRect {
        var combined = CGRect.zero
        for screen in screens {
            combined = combined.union(screen.frame)
        }
        return combined
    }
    
    /// Get the screen containing a point
    func screen(containing point: CGPoint) -> NSScreen? {
        for screen in screens {
            if screen.frame.contains(point) {
                return screen
            }
        }
        return primaryScreen
    }
    
    /// Get safe area (excluding menu bar and dock)
    func safeArea(for screen: NSScreen) -> CGRect {
        return screen.visibleFrame
    }
    
    /// Check if a point is within any screen bounds
    func isPointOnScreen(_ point: CGPoint) -> Bool {
        for screen in screens {
            if screen.frame.contains(point) {
                return true
            }
        }
        return false
    }
    
    /// Clamp a point to stay within screen bounds
    func clampToScreen(_ point: CGPoint, margin: CGFloat = 50) -> CGPoint {
        guard let screen = screen(containing: point) ?? primaryScreen else {
            return point
        }
        
        let bounds = screen.frame
        return CGPoint(
            x: max(bounds.minX + margin, min(point.x, bounds.maxX - margin)),
            y: max(bounds.minY + margin, min(point.y, bounds.maxY - margin))
        )
    }
    
    /// Get a random point on the primary screen
    func randomPointOnPrimaryScreen(margin: CGFloat = 100) -> CGPoint {
        guard let screen = primaryScreen else {
            return CGPoint(x: 500, y: 500)
        }
        
        let safeArea = self.safeArea(for: screen)
        return CGPoint(
            x: CGFloat.random(in: (safeArea.minX + margin)...(safeArea.maxX - margin)),
            y: CGFloat.random(in: (safeArea.minY + margin)...(safeArea.maxY - margin))
        )
    }
    
    /// Get dock position and size
    var dockInfo: (position: DockPosition, size: CGFloat)? {
        guard let mainScreen = primaryScreen else { return nil }
        
        let fullFrame = mainScreen.frame
        let visibleFrame = mainScreen.visibleFrame
        
        // Determine dock position based on difference between full and visible frames
        if visibleFrame.minY > fullFrame.minY {
            // Dock is at bottom
            let dockHeight = visibleFrame.minY - fullFrame.minY
            return (.bottom, dockHeight)
        } else if visibleFrame.minX > fullFrame.minX {
            // Dock is at left
            let dockWidth = visibleFrame.minX - fullFrame.minX
            return (.left, dockWidth)
        } else if visibleFrame.maxX < fullFrame.maxX {
            // Dock is at right
            let dockWidth = fullFrame.maxX - visibleFrame.maxX
            return (.right, dockWidth)
        }
        
        return nil
    }
    
    enum DockPosition {
        case left
        case bottom
        case right
    }
    
    /// Get menu bar height
    var menuBarHeight: CGFloat {
        guard let mainScreen = primaryScreen else { return 25 }
        return mainScreen.frame.maxY - mainScreen.visibleFrame.maxY
    }
}



