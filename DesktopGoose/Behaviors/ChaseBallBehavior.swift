import Foundation
import SceneKit

/// Behavior for chasing a thrown ball and throwing it back
class ChaseBallBehavior: GooseBehavior {
    
    var minimumDuration: TimeInterval { 1.0 }
    var maximumDuration: TimeInterval { 15.0 }
    var weight: Double { 0 }  // Not randomly selected, only triggered by ball throw
    var cooldown: TimeInterval { 0 }  // No cooldown - chase whenever ball is thrown
    
    private weak var controller: GooseController?
    private var chaseSpeed: CGFloat = 280  // Faster than normal walking!
    
    private enum Phase {
        case chasing
        case catching
        case throwingBack
        case celebrating
    }
    
    private var phase: Phase = .chasing
    private var phaseTimer: TimeInterval = 0
    private var hasCaughtBall: Bool = false
    
    init(controller: GooseController) {
        self.controller = controller
    }
    
    func enter() {
        phase = .chasing
        phaseTimer = 0
        hasCaughtBall = false
        
        // Goose gets excited!
        controller?.honk()
    }
    
    func update(deltaTime: CGFloat) {
        guard let controller = controller else { return }
        
        phaseTimer += TimeInterval(deltaTime)
        
        switch phase {
        case .chasing:
            updateChasing(controller: controller, deltaTime: deltaTime)
            
        case .catching:
            updateCatching(controller: controller, deltaTime: deltaTime)
            
        case .throwingBack:
            updateThrowingBack(controller: controller, deltaTime: deltaTime)
            
        case .celebrating:
            updateCelebrating(controller: controller, deltaTime: deltaTime)
        }
    }
    
    private func updateChasing(controller: GooseController, deltaTime: CGFloat) {
        // Get the ball position to chase
        if let ballPosition = controller.getChaseBallTarget() {
            // Chase the ball!
            controller.moveTo(ballPosition)
            
            // Use faster speed when chasing
            controller.moveSpeed = chaseSpeed
            
            // Check if we caught up to the ball
            let goosePos = controller.position
            let dx = ballPosition.x - goosePos.x
            let dy = ballPosition.y - goosePos.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance < 60 {
                // Caught the ball! Stop it!
                controller.stopBall()
                controller.stopMoving()
                phase = .catching
                phaseTimer = 0
                controller.honk()  // Triumphant honk!
            }
        } else {
            // Ball stopped on its own - go get it anyway if close
            controller.requestStateTransition(to: .wandering)
        }
    }
    
    private func updateCatching(controller: GooseController, deltaTime: CGFloat) {
        // Brief pause while "picking up" the ball
        if phaseTimer > 0.5 {
            phase = .throwingBack
            phaseTimer = 0
        }
    }
    
    private func updateThrowingBack(controller: GooseController, deltaTime: CGFloat) {
        // Throw the ball back - aim at the plant!
        if phaseTimer < 0.1 {
            let throwSpeed: CGFloat = CGFloat.random(in: 400...600)
            var throwVelocity: CGPoint
            
            // Try to aim at the plant
            if let plantPos = controller.getPlantPosition() {
                let goosePos = controller.position
                let dx = plantPos.x - goosePos.x
                let dy = plantPos.y - goosePos.y
                let distance = sqrt(dx * dx + dy * dy)
                
                if distance > 0 {
                    // Aim at plant with some randomness
                    let aimAngle = atan2(dy, dx)
                    let wobble = CGFloat.random(in: -0.3...0.3)  // Add some inaccuracy
                    let finalAngle = aimAngle + wobble
                    
                    throwVelocity = CGPoint(
                        x: cos(finalAngle) * throwSpeed,
                        y: sin(finalAngle) * throwSpeed
                    )
                    NSLog("🎯 Goose aiming at plant!")
                } else {
                    // Fallback to random
                    let angle = CGFloat.random(in: 0...(2 * .pi))
                    throwVelocity = CGPoint(x: cos(angle) * throwSpeed, y: sin(angle) * throwSpeed)
                }
            } else {
                // No plant - throw randomly
                let angle = CGFloat.random(in: 0...(2 * .pi))
                throwVelocity = CGPoint(x: cos(angle) * throwSpeed, y: sin(angle) * throwSpeed)
            }
            
            controller.throwBallBack(velocity: throwVelocity)
            controller.honk()  // Throwing honk!
        }
        
        if phaseTimer > 0.3 {
            phase = .celebrating
            phaseTimer = 0
        }
    }
    
    private func updateCelebrating(controller: GooseController, deltaTime: CGFloat) {
        // Quick celebration then back to wandering
        if phaseTimer > 1.0 {
            controller.moveSpeed = 150  // Reset speed
            controller.requestStateTransition(to: .wandering)
        }
    }
    
    func exit() {
        controller?.stopMoving()
        controller?.moveSpeed = 150  // Reset speed
        phase = .chasing
        hasCaughtBall = false
    }
    
    func canTransitionTo(_ state: GooseState) -> Bool {
        // Can be interrupted except while throwing
        return phase != .throwingBack
    }
}
