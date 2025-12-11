import Foundation
import CoreGraphics

class WindowPerchBehavior: GooseBehavior {
    
    private weak var controller: GooseController?
    private let windowObserver: WindowObserver
    
    // Behavior configuration
    var minimumDuration: TimeInterval { 5.0 }
    var maximumDuration: TimeInterval { 15.0 }
    var weight: Double { 1.2 }
    var cooldown: TimeInterval { 20.0 }
    
    // State
    private var targetWindow: WindowInfo?
    private var perchPosition: CGPoint = .zero
    private var isPerched = false
    
    init(controller: GooseController, windowObserver: WindowObserver) {
        self.controller = controller
        self.windowObserver = windowObserver
    }
    
    func enter() {
        // Find a window to perch on
        let windows = windowObserver.getVisibleWindows()
        
        // Filter to reasonable perching targets (not too small, not the goose's window)
        let perchableWindows = windows.filter { window in
            window.bounds.width > 200 &&
            window.bounds.height > 100 &&
            !window.ownerName.contains("DesktopGoose")
        }
        
        if let window = perchableWindows.randomElement() {
            targetWindow = window
            
            // Calculate perch position (on top of the window's title bar)
            // macOS coordinate system: origin at bottom-left
            let perchX = window.bounds.minX + CGFloat.random(in: 50...(window.bounds.width - 50))
            let perchY = window.bounds.maxY + 10 // Just above the window
            
            perchPosition = CGPoint(x: perchX, y: perchY)
            controller?.moveTo(perchPosition)
        } else {
            // No windows found, just wander instead
            controller?.requestStateTransition(to: .wandering)
        }
    }
    
    func update(deltaTime: CGFloat) {
        guard let controller = controller else { return }
        
        if !isPerched && !controller.isMoving {
            // Arrived at perch
            isPerched = true
            controller.playIdleAnimation()
            
            // Occasionally honk while perched
            if Double.random(in: 0...1) < 0.3 {
                controller.honk()
            }
        }
        
        if isPerched {
            // Check if window has moved
            if let target = targetWindow {
                let currentWindows = windowObserver.getVisibleWindows()
                if let updatedWindow = currentWindows.first(where: { $0.windowID == target.windowID }) {
                    // Window still exists, update perch position if needed
                    let newPerchY = updatedWindow.bounds.maxY + 10
                    let newPerchX = updatedWindow.bounds.minX + (perchPosition.x - target.bounds.minX)
                    
                    if abs(newPerchY - perchPosition.y) > 5 || abs(newPerchX - perchPosition.x) > 5 {
                        perchPosition = CGPoint(x: newPerchX, y: newPerchY)
                        controller.position = perchPosition
                    }
                } else {
                    // Window closed, end behavior
                    controller.requestStateTransition(to: .wandering)
                }
            }
        }
    }
    
    func exit() {
        isPerched = false
        targetWindow = nil
        controller?.stopIdleAnimation()
    }
}

