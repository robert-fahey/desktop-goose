import Foundation
import SceneKit

/// Behavior for moving furniture around - either reacting to user moving it, or randomly rearranging
class FurnitureMoveBehavior: GooseBehavior {
    
    var minimumDuration: TimeInterval { 3.0 }
    var maximumDuration: TimeInterval { 8.0 }
    var weight: Double { 0.5 }  // 50% chance to randomly move furniture - goose loves rearranging!
    var cooldown: TimeInterval { 8.0 }  // Frequent furniture interactions
    
    private weak var controller: GooseController?
    private var targetObject: DesktopObject?
    private var pushDirection: CGPoint = .zero
    
    // 3D rotation parameters
    private var rotationAxisX: CGFloat = 0
    private var rotationAxisY: CGFloat = 0
    private var rotationAxisZ: CGFloat = 0
    private var rotationSpeed: CGFloat = 0
    
    private enum Phase {
        case walkingToObject
        case pushing
        case admiring
    }
    
    private var phase: Phase = .walkingToObject
    private var phaseTimer: TimeInterval = 0
    private var pushTimer: TimeInterval = 0
    private let pushDuration: TimeInterval = 1.5
    
    init(controller: GooseController) {
        self.controller = controller
    }
    
    func enter() {
        phase = .walkingToObject
        phaseTimer = 0
        pushTimer = 0
        
        // Pick a random furniture object to move
        if targetObject == nil {
            targetObject = controller?.getRandomFurniture()
        }
        
        guard targetObject != nil else {
            // No furniture to move, exit
            controller?.requestStateTransition(to: .wandering)
            return
        }
        
        // Pick a random push direction
        let angle = CGFloat.random(in: 0...(2 * .pi))
        pushDirection = CGPoint(x: cos(angle), y: sin(angle))
        
        // Pick random 3D rotation parameters
        rotationAxisX = CGFloat.random(in: -1...1)
        rotationAxisY = CGFloat.random(in: -1...1)
        rotationAxisZ = CGFloat.random(in: -1...1)
        rotationSpeed = CGFloat.random(in: 0.5...2.0)  // Radians per second
        
        // Start walking
        controller?.gooseNode.startWalkAnimation()
        
        NSLog("🦆 Goose decided to rearrange some furniture!")
    }
    
    func update(deltaTime: CGFloat) {
        guard let controller = controller, let target = targetObject else { return }
        
        phaseTimer += TimeInterval(deltaTime)
        
        switch phase {
        case .walkingToObject:
            updateWalking(controller: controller, target: target, deltaTime: deltaTime)
            
        case .pushing:
            updatePushing(controller: controller, target: target, deltaTime: deltaTime)
            
        case .admiring:
            updateAdmiring(controller: controller, deltaTime: deltaTime)
        }
    }
    
    private func updateWalking(controller: GooseController, target: DesktopObject, deltaTime: CGFloat) {
        let targetPos = CGPoint(x: target.position.x, y: target.position.y)
        controller.moveTo(targetPos)
        
        // Check if we've reached the object
        let goosePos = controller.position
        let dx = targetPos.x - goosePos.x
        let dy = targetPos.y - goosePos.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance < 60 {
            // Reached it! Start pushing
            phase = .pushing
            phaseTimer = 0
            pushTimer = 0
            controller.stopMoving()
            controller.honk()  // Announce we're about to move it!
        }
        
        // Timeout if we can't reach it
        if phaseTimer > 10 {
            controller.requestStateTransition(to: .wandering)
        }
    }
    
    private func updatePushing(controller: GooseController, target: DesktopObject, deltaTime: CGFloat) {
        pushTimer += TimeInterval(deltaTime)
        
        // Push the object!
        let pushSpeed: CGFloat = 30 * deltaTime
        let pushX = pushDirection.x * pushSpeed
        let pushY = pushDirection.y * pushSpeed
        
        // Update target position (SCNNode.position uses CGFloat on macOS)
        target.position.x += pushX
        target.position.y += pushY
        
        // Rotate the object in 3D!
        let rotationAmount = rotationSpeed * deltaTime
        target.eulerAngles.x += rotationAxisX * rotationAmount
        target.eulerAngles.y += rotationAxisY * rotationAmount
        target.eulerAngles.z += rotationAxisZ * rotationAmount
        
        // Goose follows along, pushing
        controller.gooseNode.position.x += pushX
        controller.gooseNode.position.y += pushY
        
        // Keep screen bounds
        let bounds = controller.screenManager.primaryScreenBounds
        let minX = bounds.minX + 50
        let maxX = bounds.maxX - 50
        let minY = bounds.minY + 50
        let maxY = bounds.maxY - 50
        
        target.position.x = max(minX, min(maxX, target.position.x))
        target.position.y = max(minY, min(maxY, target.position.y))
        
        // Occasional honk while pushing
        if Int(pushTimer * 3) % 2 == 0 && CGFloat.random(in: 0...1) < 0.02 {
            controller.honk()
        }
        
        if pushTimer >= pushDuration {
            // Done pushing!
            phase = .admiring
            phaseTimer = 0
            controller.gooseNode.stopWalkAnimation()
            controller.gooseNode.playIdleAnimation()
        }
    }
    
    private func updateAdmiring(controller: GooseController, deltaTime: CGFloat) {
        // Look at our handiwork
        if phaseTimer > 1.5 {
            // Satisfied honk
            controller.honk()
            controller.requestStateTransition(to: .wandering)
        }
    }
    
    func exit() {
        controller?.stopMoving()
        if let goose = controller?.gooseNode {
            goose.stopWalkAnimation()
        }
        targetObject = nil
        phase = .walkingToObject
    }
    
    func canTransitionTo(_ state: GooseState) -> Bool {
        return phase != .pushing  // Don't interrupt mid-push
    }
    
    /// Set a specific object to move (when reacting to user moving furniture)
    func setTargetObject(_ object: DesktopObject) {
        targetObject = object
        
        // Set up random rotation for this adjustment too
        rotationAxisX = CGFloat.random(in: -1...1)
        rotationAxisY = CGFloat.random(in: -1...1)
        rotationAxisZ = CGFloat.random(in: -1...1)
        rotationSpeed = CGFloat.random(in: 0.5...2.0)
    }
}

