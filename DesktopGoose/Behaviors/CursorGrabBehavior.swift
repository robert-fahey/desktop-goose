import Foundation
import CoreGraphics
import Cocoa

class CursorGrabBehavior: GooseBehavior {
    
    private weak var controller: GooseController?
    private let cursorController = CursorController()
    
    // Behavior configuration
    var minimumDuration: TimeInterval { 2.0 }
    var maximumDuration: TimeInterval { 5.0 }
    var weight: Double { 0.8 } // Less common, more chaotic
    var cooldown: TimeInterval { 30.0 } // Long cooldown - this is annoying!
    
    // State
    private enum Phase {
        case approaching
        case grabbing
        case dragging
        case releasing
    }
    
    private var phase: Phase = .approaching
    private var dragTarget: CGPoint = .zero
    private var dragProgress: CGFloat = 0
    private var originalCursorPosition: CGPoint = .zero
    
    init(controller: GooseController) {
        self.controller = controller
    }
    
    func enter() {
        phase = .approaching
        
        // Get current cursor position
        originalCursorPosition = NSEvent.mouseLocation
        
        // Flip Y coordinate (NSEvent uses bottom-left origin)
        if let screen = NSScreen.main {
            originalCursorPosition.y = screen.frame.height - originalCursorPosition.y
        }
        
        // Move toward cursor
        controller?.moveTo(originalCursorPosition)
    }
    
    func update(deltaTime: CGFloat) {
        guard let controller = controller else { return }
        
        switch phase {
        case .approaching:
            updateApproaching(controller: controller)
        case .grabbing:
            updateGrabbing(controller: controller, deltaTime: deltaTime)
        case .dragging:
            updateDragging(controller: controller, deltaTime: deltaTime)
        case .releasing:
            break // Just wait for state machine to transition
        }
    }
    
    func exit() {
        phase = .approaching
        dragProgress = 0
    }
    
    private func updateApproaching(controller: GooseController) {
        // Update target to follow cursor
        var cursorPos = NSEvent.mouseLocation
        if let screen = NSScreen.main {
            cursorPos.y = screen.frame.height - cursorPos.y
        }
        
        // Check if we've reached the cursor
        let distance = distanceBetween(controller.position, cursorPos)
        
        if distance < 30 {
            // Start grabbing
            phase = .grabbing
            controller.stopMoving()
            controller.honk()
            
            // Pick a random drag target
            if let screen = NSScreen.main {
                dragTarget = CGPoint(
                    x: CGFloat.random(in: 100...(screen.frame.width - 100)),
                    y: CGFloat.random(in: 100...(screen.frame.height - 100))
                )
            }
        } else {
            // Keep following cursor
            controller.moveTo(cursorPos)
        }
    }
    
    private func updateGrabbing(controller: GooseController, deltaTime: CGFloat) {
        // Brief pause before dragging
        dragProgress += deltaTime * 2
        if dragProgress >= 1.0 {
            phase = .dragging
            dragProgress = 0
        }
    }
    
    private func updateDragging(controller: GooseController, deltaTime: CGFloat) {
        // Drag the cursor toward the target
        dragProgress += deltaTime * 0.5 // Slow drag
        
        if dragProgress >= 1.0 {
            phase = .releasing
            return
        }
        
        // Interpolate cursor position
        var currentCursor = NSEvent.mouseLocation
        if let screen = NSScreen.main {
            currentCursor.y = screen.frame.height - currentCursor.y
        }
        
        let newX = currentCursor.x + (dragTarget.x - currentCursor.x) * CGFloat(deltaTime) * 3
        let newY = currentCursor.y + (dragTarget.y - currentCursor.y) * CGFloat(deltaTime) * 3
        
        // Move the cursor
        cursorController.moveCursor(to: CGPoint(x: newX, y: newY))
        
        // Move goose with cursor
        controller.position = CGPoint(x: newX - 20, y: newY - 20)
    }
    
    func canTransitionTo(_ state: GooseState) -> Bool {
        // Don't interrupt while dragging
        return phase == .releasing || phase == .approaching
    }
    
    private func distanceBetween(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
}

