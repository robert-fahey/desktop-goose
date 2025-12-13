import Foundation
import SceneKit

/// Behavior where the goose sets up bowling pins with plants and kicks a ball at them
class BowlingBehavior: GooseBehavior {
    
    var minimumDuration: TimeInterval { 10.0 }
    var maximumDuration: TimeInterval { 30.0 }
    var weight: Double { 0.2 }  // 20% chance
    var cooldown: TimeInterval { 120.0 }  // 2 minute cooldown
    
    private weak var controller: GooseController?
    
    private enum Phase {
        case setup
        case arrangingPins
        case gettingBall
        case liningUp
        case runUp
        case kicking
        case watching
        case celebrating
    }
    
    private var phase: Phase = .setup
    private var phaseTimer: TimeInterval = 0
    private var plants: [DesktopObject] = []
    private var ball: DesktopObject?
    private var pinPositions: [CGPoint] = []
    private var currentPinIndex: Int = 0
    private var pinsKnockedDown: Int = 0
    private var alleyCenter: CGPoint = .zero
    private var ballStartPosition: CGPoint = .zero
    
    init(controller: GooseController) {
        self.controller = controller
    }
    
    func enter() {
        phase = .setup
        phaseTimer = 0
        currentPinIndex = 0
        pinsKnockedDown = 0
        
        // Get standing plants
        guard let standingPlants = controller?.getStandingPlants(),
              standingPlants.count >= 3 else {
            controller?.requestStateTransition(to: .wandering)
            return
        }
        
        // Get a ball
        guard let availableBall = controller?.getAnyBall() else {
            controller?.requestStateTransition(to: .wandering)
            return
        }
        
        plants = Array(standingPlants.prefix(4))  // Use up to 4 plants
        ball = availableBall
        
        // Calculate bowling alley center (in middle of screen)
        let bounds = controller?.screenManager.primaryScreenBounds ?? .zero
        alleyCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        
        // Set up pin positions in triangle formation
        setupPinPositions()
        
        controller?.gooseNode.startWalkAnimation()
        NSLog("🎳🦆 Goose is setting up bowling!")
    }
    
    private func setupPinPositions() {
        let spacing: CGFloat = 80
        
        switch plants.count {
        case 3:
            // Triangle: 1-2 formation
            pinPositions = [
                CGPoint(x: alleyCenter.x, y: alleyCenter.y + spacing),  // Front
                CGPoint(x: alleyCenter.x - spacing/2, y: alleyCenter.y + spacing * 2),  // Back left
                CGPoint(x: alleyCenter.x + spacing/2, y: alleyCenter.y + spacing * 2)   // Back right
            ]
        case 4:
            // Diamond: 1-2-1 formation
            pinPositions = [
                CGPoint(x: alleyCenter.x, y: alleyCenter.y + spacing),  // Front
                CGPoint(x: alleyCenter.x - spacing/2, y: alleyCenter.y + spacing * 2),  // Middle left
                CGPoint(x: alleyCenter.x + spacing/2, y: alleyCenter.y + spacing * 2),  // Middle right
                CGPoint(x: alleyCenter.x, y: alleyCenter.y + spacing * 3)   // Back
            ]
        default:
            pinPositions = []
        }
        
        // Ball starts 300 pixels away from pins
        ballStartPosition = CGPoint(x: alleyCenter.x, y: alleyCenter.y - 300)
    }
    
    func update(deltaTime: CGFloat) {
        guard let controller = controller else { return }
        
        phaseTimer += TimeInterval(deltaTime)
        
        switch phase {
        case .setup:
            phase = .arrangingPins
            phaseTimer = 0
        case .arrangingPins:
            updateArrangingPins(controller: controller, deltaTime: deltaTime)
        case .gettingBall:
            updateGettingBall(controller: controller, deltaTime: deltaTime)
        case .liningUp:
            updateLiningUp(controller: controller, deltaTime: deltaTime)
        case .runUp:
            updateRunUp(controller: controller, deltaTime: deltaTime)
        case .kicking:
            updateKicking(controller: controller, deltaTime: deltaTime)
        case .watching:
            updateWatching(controller: controller, deltaTime: deltaTime)
        case .celebrating:
            updateCelebrating(controller: controller, deltaTime: deltaTime)
        }
    }
    
    private func updateArrangingPins(controller: GooseController, deltaTime: CGFloat) {
        guard currentPinIndex < plants.count else {
            // All pins arranged!
            phase = .gettingBall
            phaseTimer = 0
            return
        }
        
        let plant = plants[currentPinIndex]
        let targetPos = pinPositions[currentPinIndex]
        
        // Move to plant
        let plantPos = CGPoint(x: plant.position.x, y: plant.position.y)
        let goosePos = controller.position
        let distToPlant = sqrt(pow(goosePos.x - plantPos.x, 2) + pow(goosePos.y - plantPos.y, 2))
        
        if distToPlant > 50 {
            controller.moveTo(plantPos)
            controller.gooseNode.startWalkAnimation()
        } else {
            // Push plant to target position
            let distToTarget = sqrt(pow(plantPos.x - targetPos.x, 2) + pow(plantPos.y - targetPos.y, 2))
            
            if distToTarget > 20 {
                controller.moveTo(targetPos)
                // Simulate pushing by moving plant along with goose
                let dx = targetPos.x - plantPos.x
                let dy = targetPos.y - plantPos.y
                let distance = max(distToTarget, 1)
                plant.velocity = CGPoint(x: dx / distance * 100, y: dy / distance * 100)
            } else {
                // Pin positioned!
                plant.velocity = .zero
                currentPinIndex += 1
                phaseTimer = 0
            }
        }
        
        // Timeout per pin
        if phaseTimer > 10 {
            currentPinIndex += 1
            phaseTimer = 0
        }
    }
    
    private func updateGettingBall(controller: GooseController, deltaTime: CGFloat) {
        guard let ball = ball else {
            controller.requestStateTransition(to: .wandering)
            return
        }
        
        let ballPos = CGPoint(x: ball.position.x, y: ball.position.y)
        controller.moveTo(ballPos)
        
        let goosePos = controller.position
        let distance = sqrt(pow(goosePos.x - ballPos.x, 2) + pow(goosePos.y - ballPos.y, 2))
        
        if distance < 40 {
            // Got the ball! Push it to start position
            let distToStart = sqrt(pow(ballPos.x - ballStartPosition.x, 2) + pow(ballPos.y - ballStartPosition.y, 2))
            
            if distToStart > 30 {
                controller.moveTo(ballStartPosition)
                let dx = ballStartPosition.x - ballPos.x
                let dy = ballStartPosition.y - ballPos.y
                let dist = max(distToStart, 1)
                ball.velocity = CGPoint(x: dx / dist * 100, y: dy / dist * 100)
            } else {
                // Ball in position!
                ball.velocity = .zero
                phase = .liningUp
                phaseTimer = 0
            }
        }
        
        if phaseTimer > 15 {
            controller.requestStateTransition(to: .wandering)
        }
    }
    
    private func updateLiningUp(controller: GooseController, deltaTime: CGFloat) {
        guard let ball = ball else { return }
        
        // Position behind ball
        let behindBall = CGPoint(x: ballStartPosition.x, y: ballStartPosition.y - 80)
        controller.moveTo(behindBall)
        
        let goosePos = controller.position
        let distance = sqrt(pow(goosePos.x - behindBall.x, 2) + pow(goosePos.y - behindBall.y, 2))
        
        if distance < 20 {
            controller.stopMoving()
            controller.gooseNode.stopWalkAnimation()
            
            // Face the pins
            let angle = atan2(alleyCenter.y - goosePos.y, alleyCenter.x - goosePos.x)
            controller.gooseNode.eulerAngles.y = angle - .pi / 2
            
            if phaseTimer > 1.0 {
                phase = .runUp
                phaseTimer = 0
                NSLog("🦆💨 Goose is doing the run-up!")
            }
        }
        
        if phaseTimer > 8 {
            controller.requestStateTransition(to: .wandering)
        }
    }
    
    private func updateRunUp(controller: GooseController, deltaTime: CGFloat) {
        guard let ball = ball else { return }
        
        // Run toward ball
        let ballPos = CGPoint(x: ball.position.x, y: ball.position.y)
        controller.moveTo(ballPos)
        controller.gooseNode.startWalkAnimation()
        
        let goosePos = controller.position
        let distance = sqrt(pow(goosePos.x - ballPos.x, 2) + pow(goosePos.y - ballPos.y, 2))
        
        if distance < 50 || phaseTimer > 2.0 {
            phase = .kicking
            phaseTimer = 0
        }
    }
    
    private func updateKicking(controller: GooseController, deltaTime: CGFloat) {
        guard let ball = ball else { return }
        
        if phaseTimer < 0.1 {
            // KICK!
            let dx = alleyCenter.x - ball.position.x
            let dy = alleyCenter.y - ball.position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance > 0 {
                let kickForce: CGFloat = 1500  // Strong kick!
                ball.velocity = CGPoint(
                    x: dx / distance * kickForce,
                    y: dy / distance * kickForce
                )
                
                controller.gooseNode.playHopAnimation()
                controller.honk()
                NSLog("🎳💥 Strike!")
            }
        }
        
        if phaseTimer > 0.5 {
            phase = .watching
            phaseTimer = 0
            controller.stopMoving()
            controller.gooseNode.stopWalkAnimation()
        }
    }
    
    private func updateWatching(controller: GooseController, deltaTime: CGFloat) {
        // Count knocked over pins
        if phaseTimer > 3.0 {
            pinsKnockedDown = plants.filter { $0.isKnockedOver }.count
            phase = .celebrating
            phaseTimer = 0
            NSLog("🎳 Pins knocked down: \(pinsKnockedDown)/\(plants.count)")
        }
    }
    
    private func updateCelebrating(controller: GooseController, deltaTime: CGFloat) {
        if pinsKnockedDown >= plants.count {
            // STRIKE! Celebrate!
            if phaseTimer < 3.0 {
                if Int(phaseTimer * 2) % 2 == 0 {
                    controller.honk()
                    controller.gooseNode.playHopAnimation()
                }
            }
        } else if pinsKnockedDown == 0 {
            // Gutter ball - sulk
            controller.gooseNode.playIdleAnimation()
        } else {
            // Some pins down
            controller.honk()
        }
        
        if phaseTimer > 5.0 {
            controller.requestStateTransition(to: .wandering)
        }
    }
    
    func exit() {
        controller?.stopMoving()
        controller?.gooseNode.stopWalkAnimation()
    }
    
    func canTransitionTo(_ state: GooseState) -> Bool {
        return phase == .setup || phase == .celebrating
    }
}

