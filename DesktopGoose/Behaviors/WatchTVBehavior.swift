import Foundation
import SceneKit

/// Behavior where the goose watches TV from behind the couch and honks at it
class WatchTVBehavior: GooseBehavior {
    
    var minimumDuration: TimeInterval { 8.0 }
    var maximumDuration: TimeInterval { 20.0 }
    var weight: Double { 0.3 }  // 30% chance
    var cooldown: TimeInterval { 30.0 }
    
    private weak var controller: GooseController?
    
    private enum Phase {
        case walkingToCouch
        case settlingIn
        case watching
        case leaving
    }
    
    private var phase: Phase = .walkingToCouch
    private var phaseTimer: TimeInterval = 0
    private var watchTimer: TimeInterval = 0
    private var honkTimer: TimeInterval = 0
    private var savedPosition: SCNVector3 = SCNVector3Zero
    private var couchPosition: CGPoint = .zero
    private var tvPosition: CGPoint = .zero
    private var watchingPosition: CGPoint = .zero
    
    init(controller: GooseController) {
        self.controller = controller
    }
    
    func enter() {
        phase = .walkingToCouch
        phaseTimer = 0
        watchTimer = 0
        honkTimer = CGFloat.random(in: 1...3)  // First honk soon
        
        // Save position
        if let gooseNode = controller?.gooseNode {
            savedPosition = gooseNode.position
        }
        
        // Check if TV and couch are roughly aligned
        guard let couch = controller?.getCouchHidingSpot(),
              let tv = controller?.getTVPosition() else {
            // No TV or couch - just wander
            controller?.requestStateTransition(to: .wandering)
            return
        }
        
        couchPosition = couch
        tvPosition = tv
        
        // Check if they're roughly on the same horizontal plane (within 150px)
        let verticalDiff = abs(couch.y - tv.y)
        if verticalDiff > 150 {
            // Not aligned well enough
            controller?.requestStateTransition(to: .wandering)
            return
        }
        
        // Calculate watching position (behind couch, facing TV)
        watchingPosition = CGPoint(
            x: couchPosition.x,
            y: couchPosition.y - 40  // Behind the couch
        )
        
        // Start walking
        controller?.gooseNode.startWalkAnimation()
        
        NSLog("🦆📺 Goose wants to watch TV!")
    }
    
    func update(deltaTime: CGFloat) {
        guard let controller = controller else { return }
        
        phaseTimer += TimeInterval(deltaTime)
        
        switch phase {
        case .walkingToCouch:
            updateWalking(controller: controller, deltaTime: deltaTime)
        case .settlingIn:
            updateSettling(controller: controller, deltaTime: deltaTime)
        case .watching:
            updateWatching(controller: controller, deltaTime: deltaTime)
        case .leaving:
            updateLeaving(controller: controller, deltaTime: deltaTime)
        }
    }
    
    private func updateWalking(controller: GooseController, deltaTime: CGFloat) {
        controller.moveTo(watchingPosition)
        
        let goosePos = controller.position
        let dx = watchingPosition.x - goosePos.x
        let dy = watchingPosition.y - goosePos.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance < 30 {
            phase = .settlingIn
            phaseTimer = 0
            controller.stopMoving()
        }
        
        if phaseTimer > 8 {
            controller.requestStateTransition(to: .wandering)
        }
    }
    
    private func updateSettling(controller: GooseController, deltaTime: CGFloat) {
        // Face the TV
        let goosePos = controller.position
        let dx = tvPosition.x - goosePos.x
        let dy = tvPosition.y - goosePos.y
        let angle = atan2(dy, dx)
        
        controller.gooseNode.eulerAngles.y = angle - .pi / 2
        controller.gooseNode.stopWalkAnimation()
        controller.gooseNode.playIdleAnimation()
        
        if phaseTimer > 0.5 {
            phase = .watching
            phaseTimer = 0
            watchTimer = CGFloat.random(in: 8...15)  // Watch for 8-15 seconds
            
            controller.honk()  // Excited to watch TV!
            NSLog("📺 Goose is watching TV!")
        }
    }
    
    private func updateWatching(controller: GooseController, deltaTime: CGFloat) {
        watchTimer -= TimeInterval(deltaTime)
        honkTimer -= TimeInterval(deltaTime)
        
        // Honk at the TV!
        if honkTimer <= 0 {
            controller.honk()
            
            // Maybe hop excitedly
            if CGFloat.random(in: 0...1) < 0.3 {
                controller.gooseNode.playHopAnimation()
            }
            
            // Random time until next honk (0.5-3 seconds - lots of honking!)
            honkTimer = CGFloat.random(in: 0.5...3)
        }
        
        // Done watching?
        if watchTimer <= 0 {
            phase = .leaving
            phaseTimer = 0
            controller.gooseNode.stopIdleAnimation()
        }
    }
    
    private func updateLeaving(controller: GooseController, deltaTime: CGFloat) {
        // Walk back to saved position
        controller.gooseNode.startWalkAnimation()
        
        let targetPos = CGPoint(x: CGFloat(savedPosition.x), y: CGFloat(savedPosition.y))
        controller.moveTo(targetPos)
        
        let goosePos = controller.position
        let dx = targetPos.x - goosePos.x
        let dy = targetPos.y - goosePos.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance < 30 || phaseTimer > 5 {
            controller.requestStateTransition(to: .wandering)
        }
    }
    
    func exit() {
        controller?.stopMoving()
        controller?.gooseNode.stopWalkAnimation()
        controller?.gooseNode.stopIdleAnimation()
    }
    
    func canTransitionTo(_ state: GooseState) -> Bool {
        return phase != .settlingIn
    }
}


