import Foundation
import CoreGraphics
import Cocoa

class CursorController {
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // For smooth cursor movement
    private var isGrabbing = false
    private var grabOffset: CGPoint = .zero
    
    init() {
        // Note: CGEventTap requires accessibility permissions
    }
    
    deinit {
        stopEventTap()
    }
    
    /// Move the cursor to a specific position
    func moveCursor(to point: CGPoint) {
        // Convert from Cocoa coordinates (bottom-left origin) to CG coordinates (top-left)
        var cgPoint = point
        if let screen = NSScreen.main {
            cgPoint.y = screen.frame.height - point.y
        }
        
        CGWarpMouseCursorPosition(cgPoint)
        
        // Re-associate mouse with display to prevent issues
        CGAssociateMouseAndMouseCursorPosition(1)
    }
    
    /// Get current cursor position in Cocoa coordinates
    func getCursorPosition() -> CGPoint {
        var point = NSEvent.mouseLocation
        // NSEvent.mouseLocation already uses Cocoa coordinates (bottom-left origin)
        return point
    }
    
    /// Start grabbing the cursor (blocks user input)
    func startGrab(offset: CGPoint = .zero) {
        guard !isGrabbing else { return }
        isGrabbing = true
        grabOffset = offset
        
        // Hide the real cursor
        NSCursor.hide()
        
        // Optionally set up event tap to intercept mouse events
        setupEventTap()
    }
    
    /// Stop grabbing the cursor
    func stopGrab() {
        guard isGrabbing else { return }
        isGrabbing = false
        
        // Show the cursor again
        NSCursor.unhide()
        
        // Remove event tap
        stopEventTap()
    }
    
    // MARK: - Event Tap (for intercepting mouse events)
    
    private func setupEventTap() {
        // Create an event tap to intercept mouse movement
        let eventMask = (1 << CGEventType.mouseMoved.rawValue) |
                        (1 << CGEventType.leftMouseDragged.rawValue) |
                        (1 << CGEventType.rightMouseDragged.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                // Consume the event while grabbing (don't let it through)
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let controller = Unmanaged<CursorController>.fromOpaque(refcon).takeUnretainedValue()
                
                if controller.isGrabbing {
                    // Block the event
                    return nil
                }
                
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap. Accessibility permission may be required.")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    private func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
    }
    
    // MARK: - Helpers
    
    /// Smoothly animate cursor to a position
    func animateCursor(to destination: CGPoint, duration: TimeInterval, completion: (() -> Void)? = nil) {
        let start = getCursorPosition()
        let startTime = Date()
        
        Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / duration, 1.0)
            
            // Ease-out interpolation
            let eased = 1 - pow(1 - progress, 3)
            
            let x = start.x + (destination.x - start.x) * eased
            let y = start.y + (destination.y - start.y) * eased
            
            self?.moveCursor(to: CGPoint(x: x, y: y))
            
            if progress >= 1.0 {
                timer.invalidate()
                completion?()
            }
        }
    }
}



