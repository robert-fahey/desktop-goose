import Foundation
import SceneKit

/// Behavior where the goose goes to find a ball and KICKS IT HARD
class PlayWithBallBehavior: GooseBehavior {
    
    var minimumDuration: TimeInterval { 5.0 }
    var maximumDuration: TimeInterval { 15.0 }
    var weight: Double { 0.4 }  // 40% chance - goose loves playing with the ball!
    var cooldown: TimeInterval { 8.0 }
    
    private weak var controller: GooseController?
    
    private enum Phase {
        case approachingBall      // Walk toward ball
        case backingUp            // Back up for run-up
        case runningUp            // CHARGE!
        case kicking              // The big kick
        case watchingBallBounce   // Admire the chaos
        case celebrating
    }
    
    private var phase: Phase = .approachingBall
    private var phaseTimer: TimeInterval = 0
    private var kickCount: Int = 0
    private let maxKicks: Int = 2  // Fewer but bigger kicks
    
    // Run-up tracking
    private var runUpStartPos: CGPoint = .zero
    private var kickDirection: CGPoint = .zero
    private var ballTargetPos: CGPoint = .zero
    private let runUpDistance: CGFloat = 150  // Back up this far
    private let chargeSpeed: CGFloat = 400   // FAST run toward ball
    
    init(controller: GooseController) {
        self.controller = controller
    }
    
    func enter() {
        phase = .approachingBall
        phaseTimer = 0
        kickCount = 0
        
        // Start walking
        controller?.gooseNode.startWalkAnimation()
        
        NSLog("🦆⚽ Goose is going to KICK the ball!")
    }
    
    func update(deltaTime: CGFloat) {
        guard let controller = controller else { return }
        
        phaseTimer += TimeInterval(deltaTime)
        
        switch phase {
        case .approachingBall:
            updateApproaching(controller: controller, deltaTime: deltaTime)
        case .backingUp:
            updateBackingUp(controller: controller, deltaTime: deltaTime)
        case .runningUp:
            updateRunningUp(controller: controller, deltaTime: deltaTime)
        case .kicking:
            updateKicking(controller: controller, deltaTime: deltaTime)
        case .watchingBallBounce:
            updateWatching(controller: controller, deltaTime: deltaTime)
        case .celebrating:
            updateCelebrating(controller: controller, deltaTime: deltaTime)
        }
    }
    
    private func updateApproaching(controller: GooseController, deltaTime: CGFloat) {
        guard let ballPos = controller.getBallPosition() else {
            controller.requestStateTransition(to: .wandering)
            return
        }
        
        ballTargetPos = ballPos
        controller.moveTo(ballPos)
        
        let goosePos = controller.position
        let dx = ballPos.x - goosePos.x
        let dy = ballPos.y - goosePos.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance < 80 {
            // Near the ball - now back up for the run-up!
            phase = .backingUp
            phaseTimer = 0
            controller.stopMoving()
            controller.honk()  // "I'm gonna kick it!"
            
            // Calculate kick direction (random-ish)
            let kickAngle = CGFloat.random(in: 0...(2 * .pi))
            kickDirection = CGPoint(x: cos(kickAngle), y: sin(kickAngle))
            
            // Back up position is opposite of kick direction
            runUpStartPos = CGPoint(
                x: ballPos.x - kickDirection.x * runUpDistance,
                y: ballPos.y - kickDirection.y * runUpDistance
            )
            
            NSLog("🦆 Backing up for the run-up!")
        }
        
        if phaseTimer > 10 {
            controller.requestStateTransition(to: .wandering)
        }
    }
    
    private func updateBackingUp(controller: GooseController, deltaTime: CGFloat) {
        // Walk backward to run-up position
        controller.moveTo(runUpStartPos)
        
        let goosePos = controller.position
        let dx = runUpStartPos.x - goosePos.x
        let dy = runUpStartPos.y - goosePos.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance < 30 || phaseTimer > 3.0 {
            // Ready to charge!
            phase = .runningUp
            phaseTimer = 0
            controller.stopMoving()
            
            // Face the ball
            let angle = atan2(kickDirection.y, kickDirection.x)
            controller.gooseNode.eulerAngles.y = angle - .pi / 2
            
            // Pause dramatically before charging
            controller.honk()  // "HERE I COME!"
            
            NSLog("🦆💨 CHARGING!")
        }
    }
    
    private func updateRunningUp(controller: GooseController, deltaTime: CGFloat) {
        // Brief pause at start for dramatic effect
        if phaseTimer < 0.3 {
            return
        }
        
        // CHARGE toward the ball at high speed!
        let goosePos = controller.position
        let dx = ballTargetPos.x - goosePos.x
        let dy = ballTargetPos.y - goosePos.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance > 5 {
            // Keep charging
            let moveX = kickDirection.x * chargeSpeed * deltaTime
            let moveY = kickDirection.y * chargeSpeed * deltaTime
            controller.gooseNode.position.x += moveX
            controller.gooseNode.position.y += moveY
            
            // Fast waddle animation
            if !controller.gooseNode.isWalking {
                controller.gooseNode.startWalkAnimation()
            }
        }
        
        if distance < 40 || phaseTimer > 2.0 {
            // KICK!
            phase = .kicking
            phaseTimer = 0
        }
    }
    
    private func updateKicking(controller: GooseController, deltaTime: CGFloat) {
        if phaseTimer < 0.1 {
            return
        }
        
        // MASSIVE KICK!
        let kickStrength = CGFloat.random(in: 800...1200)  // Much stronger!
        let kickVelocity = CGPoint(
            x: kickDirection.x * kickStrength,
            y: kickDirection.y * kickStrength
        )
        
        controller.kickBall(velocity: kickVelocity)
        controller.gooseNode.playHopAnimation()
        controller.honk()  // Victory honk!
        
        NSLog("🦆⚽💥 KICKED! Velocity: \(kickStrength)")
        
        kickCount += 1
        phase = .watchingBallBounce
        phaseTimer = 0
    }
    
    private func updateWatching(controller: GooseController, deltaTime: CGFloat) {
        // Watch the ball ping pong around
        controller.gooseNode.stopWalkAnimation()
        
        if phaseTimer > 2.0 {
            if kickCount >= maxKicks {
                phase = .celebrating
                phaseTimer = 0
            } else {
                // Go for another kick!
                phase = .approachingBall
                phaseTimer = 0
                controller.gooseNode.startWalkAnimation()
            }
        }
    }
    
    private func updateCelebrating(controller: GooseController, deltaTime: CGFloat) {
        if phaseTimer > 1.0 {
            controller.honk()
            controller.gooseNode.playHopAnimation()
            controller.requestStateTransition(to: .wandering)
        }
    }
    
    func exit() {
        controller?.stopMoving()
        controller?.gooseNode.stopWalkAnimation()
        phase = .approachingBall
        kickCount = 0
    }
    
    func canTransitionTo(_ state: GooseState) -> Bool {
        return phase != .runningUp && phase != .kicking  // Don't interrupt mid-charge!
    }
}

