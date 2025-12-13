import Foundation
import CoreGraphics
import Cocoa

/// Behavior where the goose chases the mouse cursor for attention
class MouseChaseBehavior: GooseBehavior {
    
    private weak var controller: GooseController?
    
    // Behavior configuration
    var minimumDuration: TimeInterval { 10.0 }  // Chase for exactly 10 seconds
    var maximumDuration: TimeInterval { 10.0 }
    var weight: Double { 0 }  // Not randomly selected - triggered by idle timeout
    var cooldown: TimeInterval { 60.0 }  // Don't repeat too often
    
    private var chaseTimer: TimeInterval = 0
    private let chaseDuration: TimeInterval = 10.0
    private var chaseSpeed: CGFloat = 200  // Fast but not instant
    private var lastHonkTime: TimeInterval = 0
    
    init(controller: GooseController) {
        self.controller = controller
    }
    
    func enter() {
        chaseTimer = 0
        lastHonkTime = 0
        
        // Excited honk - goose wants attention!
        controller?.honk()
        
        // Start walk animation
        controller?.gooseNode.startWalkAnimation()
        
        NSLog("🦆 Goose is bored! Chasing the mouse for attention!")
    }
    
    func update(deltaTime: CGFloat) {
        guard let controller = controller else { return }
        
        chaseTimer += TimeInterval(deltaTime)
        
        // Done chasing?
        if chaseTimer >= chaseDuration {
            controller.requestStateTransition(to: .wandering)
            return
        }
        
        // Get current cursor position (Cocoa coordinates)
        let cursorPos = NSEvent.mouseLocation
        
        // Chase the cursor!
        let goosePos = controller.position
        let dx = cursorPos.x - goosePos.x
        let dy = cursorPos.y - goosePos.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance > 20 {
            // Move toward cursor
            let direction = CGPoint(x: dx / distance, y: dy / distance)
            let newX = goosePos.x + direction.x * chaseSpeed * deltaTime
            let newY = goosePos.y + direction.y * chaseSpeed * deltaTime
            controller.position = CGPoint(x: newX, y: newY)
            
            // Update facing direction
            let angle = atan2(direction.y, direction.x)
            controller.gooseNode.eulerAngles.y = angle - .pi / 2
        }
        
        // Occasional excited honk while chasing
        if chaseTimer - lastHonkTime > 2.0 {
            controller.honk()
            lastHonkTime = chaseTimer
        }
        
        // Play hop animation occasionally when close
        if distance < 80 && Int(chaseTimer * 2) % 3 == 0 {
            controller.gooseNode.playHopAnimation()
        }
    }
    
    func exit() {
        controller?.gooseNode.stopWalkAnimation()
        chaseTimer = 0
        NSLog("🦆 Goose got attention, back to normal")
    }
    
    func canTransitionTo(_ state: GooseState) -> Bool {
        // Can be interrupted by user interaction
        return true
    }
}


