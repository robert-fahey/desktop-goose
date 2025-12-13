import Foundation
import SceneKit

/// Behavior where the goose plays dodgeball with the droid
class DodgeballBehavior: GooseBehavior {
    
    var minimumDuration: TimeInterval { 10.0 }
    var maximumDuration: TimeInterval { 60.0 }
    var weight: Double { 0 }  // Triggered by droid presence, not random
    var cooldown: TimeInterval { 0 }
    
    private weak var controller: GooseController?
    
    private enum Phase {
        case findingBall
        case grabbingBall
        case aiming
        case throwing
        case dodging
        case celebrating
        case fleeing
    }
    
    private var phase: Phase = .findingBall
    private var phaseTimer: TimeInterval = 0
    private var gooseHits: Int = 0  // Times goose hit droid
    private var droidHits: Int = 0  // Times droid hit goose
    private var targetBall: DesktopObject?
    private var dodgeDirection: CGPoint = .zero
    
    init(controller: GooseController) {
        self.controller = controller
    }
    
    func enter() {
        phase = .findingBall
        phaseTimer = 0
        gooseHits = 0
        droidHits = 0
        targetBall = nil
        
        controller?.gooseNode.startWalkAnimation()
        controller?.honk()  // Challenge honk!
        NSLog("🦆⚽🤖 Dodgeball match begins!")
    }
    
    func update(deltaTime: CGFloat) {
        guard let controller = controller else { return }
        
        phaseTimer += TimeInterval(deltaTime)
        
        // Check game end conditions
        guard let droid = controller.getDroid(), droid.isActive else {
            // Droid gone
            controller.requestStateTransition(to: .wandering)
            return
        }
        
        if gooseHits >= 3 {
            // Goose wins!
            if phase != .celebrating {
                phase = .celebrating
                phaseTimer = 0
                NSLog("🦆🏆 Goose wins dodgeball!")
            }
        }
        
        if droidHits >= 3 {
            // Droid wins - flee!
            if phase != .fleeing {
                phase = .fleeing
                phaseTimer = 0
                NSLog("🤖🏆 Droid wins dodgeball!")
            }
        }
        
        switch phase {
        case .findingBall:
            updateFindingBall(controller: controller, deltaTime: deltaTime)
        case .grabbingBall:
            updateGrabbingBall(controller: controller, deltaTime: deltaTime)
        case .aiming:
            updateAiming(controller: controller, droid: droid, deltaTime: deltaTime)
        case .throwing:
            updateThrowing(controller: controller, droid: droid, deltaTime: deltaTime)
        case .dodging:
            updateDodging(controller: controller, deltaTime: deltaTime)
        case .celebrating:
            updateCelebrating(controller: controller, deltaTime: deltaTime)
        case .fleeing:
            updateFleeing(controller: controller, droid: droid, deltaTime: deltaTime)
        }
    }
    
    private func updateFindingBall(controller: GooseController, deltaTime: CGFloat) {
        // Find closest ball
        guard let ball = controller.getClosestBall() else {
            // No balls - just flee
            controller.requestStateTransition(to: .fleeingFromDroid)
            return
        }
        
        targetBall = ball
        phase = .grabbingBall
        phaseTimer = 0
    }
    
    private func updateGrabbingBall(controller: GooseController, deltaTime: CGFloat) {
        guard let ball = targetBall else {
            phase = .findingBall
            return
        }
        
        let ballPos = CGPoint(x: ball.position.x, y: ball.position.y)
        controller.moveTo(ballPos)
        controller.gooseNode.startWalkAnimation()
        
        let goosePos = controller.position
        let distance = sqrt(pow(goosePos.x - ballPos.x, 2) + pow(goosePos.y - ballPos.y, 2))
        
        if distance < 50 {
            phase = .aiming
            phaseTimer = 0
            controller.stopMoving()
        }
        
        // Timeout or droid too close
        if phaseTimer > 5.0 {
            phase = .dodging
            phaseTimer = 0
        }
    }
    
    private func updateAiming(controller: GooseController, droid: Droid, deltaTime: CGFloat) {
        guard let ball = targetBall else {
            phase = .findingBall
            return
        }
        
        // Face the droid
        let goosePos = controller.position
        let droidPos = CGPoint(x: droid.position.x, y: droid.position.y)
        let dx = droidPos.x - goosePos.x
        let dy = droidPos.y - goosePos.y
        let angle = atan2(dy, dx)
        controller.gooseNode.eulerAngles.y = angle - .pi / 2
        
        // Check if droid is too close
        let distance = sqrt(dx * dx + dy * dy)
        if distance < 100 {
            phase = .dodging
            phaseTimer = 0
            return
        }
        
        if phaseTimer > 0.5 {
            phase = .throwing
            phaseTimer = 0
        }
    }
    
    private func updateThrowing(controller: GooseController, droid: Droid, deltaTime: CGFloat) {
        guard let ball = targetBall else {
            phase = .findingBall
            return
        }
        
        if phaseTimer < 0.1 {
            // THROW!
            let droidPos = CGPoint(x: droid.position.x, y: droid.position.y)
            let ballPos = CGPoint(x: ball.position.x, y: ball.position.y)
            let dx = droidPos.x - ballPos.x
            let dy = droidPos.y - ballPos.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance > 0 {
                let throwForce: CGFloat = 1200
                ball.velocity = CGPoint(
                    x: dx / distance * throwForce,
                    y: dy / distance * throwForce
                )
                
                controller.gooseNode.playHopAnimation()
                controller.honk()
                NSLog("🦆⚽💨 Goose throws ball at droid!")
            }
        }
        
        if phaseTimer > 0.5 {
            targetBall = nil
            phase = .findingBall
            phaseTimer = 0
        }
    }
    
    private func updateDodging(controller: GooseController, deltaTime: CGFloat) {
        // Quick dodge to the side
        if phaseTimer < 0.1 {
            let goosePos = controller.position
            dodgeDirection = CGPoint(
                x: CGFloat.random(in: -1...1),
                y: CGFloat.random(in: -1...1)
            )
            let length = sqrt(dodgeDirection.x * dodgeDirection.x + dodgeDirection.y * dodgeDirection.y)
            if length > 0 {
                dodgeDirection.x /= length
                dodgeDirection.y /= length
            }
        }
        
        let goosePos = controller.position
        let dodgeTarget = CGPoint(
            x: goosePos.x + dodgeDirection.x * 150,
            y: goosePos.y + dodgeDirection.y * 150
        )
        controller.moveTo(dodgeTarget)
        controller.gooseNode.startWalkAnimation()
        
        if phaseTimer > 1.0 {
            phase = .findingBall
            phaseTimer = 0
        }
    }
    
    private func updateCelebrating(controller: GooseController, deltaTime: CGFloat) {
        // Victory dance!
        if Int(phaseTimer * 3) % 2 == 0 {
            controller.honk()
            controller.gooseNode.playHopAnimation()
        }
        
        if phaseTimer > 5.0 {
            controller.requestStateTransition(to: .wandering)
        }
    }
    
    private func updateFleeing(controller: GooseController, droid: Droid, deltaTime: CGFloat) {
        // Run away from droid
        let goosePos = controller.position
        let droidPos = CGPoint(x: droid.position.x, y: droid.position.y)
        let dx = goosePos.x - droidPos.x
        let dy = goosePos.y - droidPos.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance > 0 {
            let fleeTarget = CGPoint(
                x: goosePos.x + (dx / distance) * 200,
                y: goosePos.y + (dy / distance) * 200
            )
            controller.moveTo(fleeTarget)
            controller.gooseNode.startWalkAnimation()
        }
        
        if phaseTimer > 5.0 || distance > 300 {
            controller.requestStateTransition(to: .wandering)
        }
    }
    
    /// Call this when a ball hits the droid
    func onBallHitDroid() {
        gooseHits += 1
        NSLog("🎯 Goose hit droid! Score: \(gooseHits)/3")
        controller?.honk()
    }
    
    /// Call this when a ball hits the goose (kicked back by droid)
    func onBallHitGoose() {
        droidHits += 1
        NSLog("💥 Droid hit goose! Score: \(droidHits)/3")
        phase = .dodging
        phaseTimer = 0
    }
    
    func exit() {
        controller?.stopMoving()
        controller?.gooseNode.stopWalkAnimation()
    }
    
    func canTransitionTo(_ state: GooseState) -> Bool {
        return phase == .celebrating || phase == .fleeing
    }
}

