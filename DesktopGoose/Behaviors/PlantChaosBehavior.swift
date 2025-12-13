import Foundation
import SceneKit

/// Behavior where the goose hides behind clustered plants, honks menacingly, then knocks them all over
class PlantChaosBehavior: GooseBehavior {
    
    var minimumDuration: TimeInterval { 5.0 }
    var maximumDuration: TimeInterval { 20.0 }
    var weight: Double { 0.4 }  // 40% chance when plants are clustered
    var cooldown: TimeInterval { 60.0 }  // Don't repeat too often
    
    private weak var controller: GooseController?
    
    private enum Phase {
        case approaching
        case hiding
        case honking
        case rampaging
        case fleeing
    }
    
    private var phase: Phase = .approaching
    private var phaseTimer: TimeInterval = 0
    private var honkCount: Int = 0
    private var targetHonks: Int = 0
    private var honkCooldown: TimeInterval = 0
    private var plantIndex: Int = 0
    private var clusteredPlants: [DesktopObject] = []
    private var clusterCenter: CGPoint = .zero
    private var hidingPosition: CGPoint = .zero
    
    init(controller: GooseController) {
        self.controller = controller
    }
    
    func enter() {
        phase = .approaching
        phaseTimer = 0
        honkCount = 0
        targetHonks = Int.random(in: 3...5)
        honkCooldown = 0
        plantIndex = 0
        
        // Get clustered plants
        guard let plants = controller?.getClusteredPlants(),
              let center = controller?.getPlantClusterCenter() else {
            controller?.requestStateTransition(to: .wandering)
            return
        }
        
        clusteredPlants = plants
        clusterCenter = center
        
        // Calculate hiding position (behind the cluster from screen center)
        let screenCenter = controller?.screenManager.primaryScreenBounds.center ?? .zero
        let dx = clusterCenter.x - screenCenter.x
        let dy = clusterCenter.y - screenCenter.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance > 0 {
            let dirX = dx / distance
            let dirY = dy / distance
            hidingPosition = CGPoint(
                x: clusterCenter.x + dirX * 60,  // Behind the cluster
                y: clusterCenter.y + dirY * 60
            )
        } else {
            hidingPosition = CGPoint(x: clusterCenter.x + 60, y: clusterCenter.y)
        }
        
        controller?.gooseNode.startWalkAnimation()
        NSLog("🦆🌿 Goose spotted clustered plants... mischief incoming!")
    }
    
    func update(deltaTime: CGFloat) {
        guard let controller = controller else { return }
        
        phaseTimer += TimeInterval(deltaTime)
        
        switch phase {
        case .approaching:
            updateApproaching(controller: controller, deltaTime: deltaTime)
        case .hiding:
            updateHiding(controller: controller, deltaTime: deltaTime)
        case .honking:
            updateHonking(controller: controller, deltaTime: deltaTime)
        case .rampaging:
            updateRampaging(controller: controller, deltaTime: deltaTime)
        case .fleeing:
            updateFleeing(controller: controller, deltaTime: deltaTime)
        }
    }
    
    private func updateApproaching(controller: GooseController, deltaTime: CGFloat) {
        controller.moveTo(hidingPosition)
        
        let goosePos = controller.position
        let dx = hidingPosition.x - goosePos.x
        let dy = hidingPosition.y - goosePos.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance < 30 {
            phase = .hiding
            phaseTimer = 0
            controller.stopMoving()
            controller.gooseNode.stopWalkAnimation()
        }
        
        // Timeout
        if phaseTimer > 8 {
            phase = .hiding
            phaseTimer = 0
        }
    }
    
    private func updateHiding(controller: GooseController, deltaTime: CGFloat) {
        // Face toward the center of the cluster (outward from hiding spot)
        let goosePos = controller.position
        let dx = clusterCenter.x - goosePos.x
        let dy = clusterCenter.y - goosePos.y
        let angle = atan2(dy, dx)
        controller.gooseNode.eulerAngles.y = angle - .pi / 2
        
        // Wait a moment before honking
        if phaseTimer > 1.0 {
            phase = .honking
            phaseTimer = 0
            honkCooldown = 0
        }
    }
    
    private func updateHonking(controller: GooseController, deltaTime: CGFloat) {
        honkCooldown -= TimeInterval(deltaTime)
        
        if honkCooldown <= 0 && honkCount < targetHonks {
            controller.honk()
            honkCount += 1
            honkCooldown = CGFloat.random(in: 0.5...1.5)  // Pause between honks
            
            // Maybe hop excitedly
            if CGFloat.random(in: 0...1) < 0.3 {
                controller.gooseNode.playHopAnimation()
            }
        }
        
        // All honks done - time to rampage!
        if honkCount >= targetHonks && phaseTimer > 2.0 {
            phase = .rampaging
            phaseTimer = 0
            plantIndex = 0
            controller.gooseNode.startWalkAnimation()
            NSLog("🦆💥 Goose is going on a rampage!")
        }
    }
    
    private func updateRampaging(controller: GooseController, deltaTime: CGFloat) {
        guard plantIndex < clusteredPlants.count else {
            // All plants knocked over!
            phase = .fleeing
            phaseTimer = 0
            controller.honk()  // Triumphant honk!
            return
        }
        
        let targetPlant = clusteredPlants[plantIndex]
        let plantPos = CGPoint(x: targetPlant.position.x, y: targetPlant.position.y)
        
        controller.moveTo(plantPos)
        
        let goosePos = controller.position
        let dx = plantPos.x - goosePos.x
        let dy = plantPos.y - goosePos.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Close enough to knock over
        if distance < 40 {
            if !targetPlant.isKnockedOver {
                let impactDir = CGPoint(x: dx / max(distance, 1), y: dy / max(distance, 1))
                targetPlant.knockOver(impactDirection: impactDir, impactForce: 200)
                controller.honk()  // Chaos honk!
            }
            plantIndex += 1
        }
        
        // Timeout per plant
        if phaseTimer > 3.0 {
            plantIndex += 1
            phaseTimer = 0
        }
    }
    
    private func updateFleeing(controller: GooseController, deltaTime: CGFloat) {
        // Run away from the scene of the crime
        let goosePos = controller.position
        let dx = goosePos.x - clusterCenter.x
        let dy = goosePos.y - clusterCenter.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance > 0 {
            let fleeTarget = CGPoint(
                x: goosePos.x + (dx / distance) * 200,
                y: goosePos.y + (dy / distance) * 200
            )
            controller.moveTo(fleeTarget)
        }
        
        // Occasional triumphant honk while fleeing
        if phaseTimer > 1.5 {
            controller.honk()
            phaseTimer = 0
        }
        
        // Done fleeing after some distance
        if distance > 200 || phaseTimer > 5.0 {
            controller.requestStateTransition(to: .wandering)
        }
    }
    
    func exit() {
        controller?.stopMoving()
        controller?.gooseNode.stopWalkAnimation()
    }
    
    func canTransitionTo(_ state: GooseState) -> Bool {
        // Can be interrupted in approaching or fleeing phases
        return phase == .approaching || phase == .fleeing
    }
}

// MARK: - Helper extension for CGRect
private extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}

