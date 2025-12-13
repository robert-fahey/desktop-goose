import Foundation
import SceneKit

/// Behavior where the goose flees from the droid and tries to kick the ball at it
class FleeFromDroidBehavior: GooseBehavior {
    
    var minimumDuration: TimeInterval { 1.0 }
    var maximumDuration: TimeInterval { 60.0 }  // As long as droid is active
    var weight: Double { 0 }  // Triggered programmatically, not randomly
    var cooldown: TimeInterval { 0 }
    
    private weak var controller: GooseController?
    
    private enum Phase {
        case fleeing
        case findingBall
        case chasingBall
        case aimingKick
        case kicking
    }
    
    private var phase: Phase = .fleeing
    private var phaseTimer: TimeInterval = 0
    private var fleeDirection: CGPoint = .zero
    private var kickCooldown: TimeInterval = 0
    
    init(controller: GooseController) {
        self.controller = controller
    }
    
    func enter() {
        phase = .fleeing
        phaseTimer = 0
        kickCooldown = 0
        
        controller?.gooseNode.startWalkAnimation()
        controller?.honk()  // Panic honk!
        
        NSLog("🦆😱 Goose is fleeing from the droid!")
    }
    
    func update(deltaTime: CGFloat) {
        guard let controller = controller else { return }
        
        phaseTimer += TimeInterval(deltaTime)
        kickCooldown -= TimeInterval(deltaTime)
        
        // Check if droid is still active
        guard let droid = controller.getDroid(), droid.isActive else {
            // Droid is gone, return to normal
            controller.requestStateTransition(to: .wandering)
            return
        }
        
        // If droid is knocked over, maybe gloat a bit
        if droid.isKnockedOver {
            // Honk triumphantly and wander
            if phaseTimer > 1.0 {
                controller.honk()
                phaseTimer = 0
            }
            // Keep some distance but don't flee
            let goosePos = controller.position
            let droidPos = CGPoint(x: droid.position.x, y: droid.position.y)
            let dx = goosePos.x - droidPos.x
            let dy = goosePos.y - droidPos.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance < 150 {
                // Move away slowly
                let fleeTarget = CGPoint(x: goosePos.x + dx * 0.5, y: goosePos.y + dy * 0.5)
                controller.moveTo(fleeTarget)
            } else {
                controller.stopMoving()
                controller.gooseNode.playIdleAnimation()
            }
            return
        }
        
        switch phase {
        case .fleeing:
            updateFleeing(controller: controller, droid: droid, deltaTime: deltaTime)
        case .findingBall:
            updateFindingBall(controller: controller, deltaTime: deltaTime)
        case .chasingBall:
            updateChasingBall(controller: controller, deltaTime: deltaTime)
        case .aimingKick:
            updateAimingKick(controller: controller, droid: droid, deltaTime: deltaTime)
        case .kicking:
            updateKicking(controller: controller, droid: droid, deltaTime: deltaTime)
        }
    }
    
    private func updateFleeing(controller: GooseController, droid: Droid, deltaTime: CGFloat) {
        let goosePos = controller.position
        let droidPos = CGPoint(x: droid.position.x, y: droid.position.y)
        
        // Calculate flee direction (away from droid)
        let dx = goosePos.x - droidPos.x
        let dy = goosePos.y - droidPos.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance > 0 {
            fleeDirection = CGPoint(x: dx / distance, y: dy / distance)
        }
        
        // Flee!
        let fleeSpeed: CGFloat = 200  // Faster than normal walking
        let fleeDistance: CGFloat = 150
        let fleeTarget = CGPoint(
            x: goosePos.x + fleeDirection.x * fleeDistance,
            y: goosePos.y + fleeDirection.y * fleeDistance
        )
        
        controller.moveTo(fleeTarget)
        controller.gooseNode.startWalkAnimation()
        
        // Honk in panic occasionally
        if phaseTimer > 2.0 {
            controller.honk()
            phaseTimer = 0
        }
        
        // If we're far enough and have a ball, consider kicking it
        if distance > 200 && kickCooldown <= 0 {
            if let _ = controller.getBallPosition() {
                phase = .findingBall
                phaseTimer = 0
            }
        }
        
        // Droid too close! Keep fleeing
        if distance < 100 {
            controller.honk()  // Panic!
        }
    }
    
    private func updateFindingBall(controller: GooseController, deltaTime: CGFloat) {
        guard let ballPos = controller.getBallPosition() else {
            phase = .fleeing
            return
        }
        
        let goosePos = controller.position
        let dx = ballPos.x - goosePos.x
        let dy = ballPos.y - goosePos.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance < 60 {
            phase = .aimingKick
            phaseTimer = 0
            controller.gooseNode.stopWalkAnimation()
        } else {
            controller.moveTo(ballPos)
            controller.gooseNode.startWalkAnimation()
        }
        
        // Timeout - go back to fleeing
        if phaseTimer > 5.0 {
            phase = .fleeing
            phaseTimer = 0
        }
    }
    
    private func updateChasingBall(controller: GooseController, deltaTime: CGFloat) {
        // Same as finding ball essentially
        updateFindingBall(controller: controller, deltaTime: deltaTime)
    }
    
    private func updateAimingKick(controller: GooseController, droid: Droid, deltaTime: CGFloat) {
        let goosePos = controller.position
        let droidPos = CGPoint(x: droid.position.x, y: droid.position.y)
        
        // Face the droid
        let dx = droidPos.x - goosePos.x
        let dy = droidPos.y - goosePos.y
        let angle = atan2(dy, dx)
        controller.gooseNode.eulerAngles.y = angle - .pi / 2
        
        // Wind up...
        if phaseTimer > 0.5 {
            phase = .kicking
            phaseTimer = 0
        }
    }
    
    private func updateKicking(controller: GooseController, droid: Droid, deltaTime: CGFloat) {
        if phaseTimer < 0.1 {
            // Kick!
            let goosePos = controller.position
            let droidPos = CGPoint(x: droid.position.x, y: droid.position.y)
            
            let dx = droidPos.x - goosePos.x
            let dy = droidPos.y - goosePos.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance > 0 {
                let kickDirection = CGPoint(x: dx / distance, y: dy / distance)
                let kickForce: CGFloat = 1000  // Strong kick!
                
                controller.kickBall(velocity: CGPoint(
                    x: kickDirection.x * kickForce,
                    y: kickDirection.y * kickForce
                ))
                
                controller.gooseNode.playHopAnimation()
                controller.honk()  // Attack honk!
                
                NSLog("🦆⚽ Goose kicked ball at droid!")
            }
            
            kickCooldown = 5.0  // Can't kick again for 5 seconds
        }
        
        if phaseTimer > 0.5 {
            phase = .fleeing
            phaseTimer = 0
        }
    }
    
    func exit() {
        controller?.stopMoving()
        controller?.gooseNode.stopWalkAnimation()
    }
    
    func canTransitionTo(_ state: GooseState) -> Bool {
        // Only transition out if droid is gone or knocked over for a while
        return true
    }
}

