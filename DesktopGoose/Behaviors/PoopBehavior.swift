import Foundation
import SceneKit

/// Behavior where the goose poops on the screen
class PoopBehavior: GooseBehavior {
    
    var minimumDuration: TimeInterval { 1.5 }
    var maximumDuration: TimeInterval { 2.0 }
    var weight: Double { 0.2 }  // 20% chance
    var cooldown: TimeInterval { 20.0 }  // Not too often
    
    private weak var controller: GooseController?
    private var hasPooped: Bool = false
    private var poopTimer: TimeInterval = 0
    
    init(controller: GooseController) {
        self.controller = controller
    }
    
    func enter() {
        hasPooped = false
        poopTimer = 0
        
        // Stop and squat
        controller?.stopMoving()
        controller?.gooseNode.stopWalkAnimation()
        
        NSLog("🦆💩 Goose is about to poop!")
    }
    
    func update(deltaTime: CGFloat) {
        guard let controller = controller else { return }
        
        poopTimer += TimeInterval(deltaTime)
        
        if !hasPooped && poopTimer > 0.8 {
            // Drop the poop!
            hasPooped = true
            let goosePos = controller.position
            controller.dropPoop(at: goosePos)
            
            // Little hop after pooping
            controller.gooseNode.playHopAnimation()
        }
        
        if poopTimer > 1.5 {
            // Done, waddle away
            controller.requestStateTransition(to: .wandering)
        }
    }
    
    func exit() {
        hasPooped = false
        poopTimer = 0
    }
    
    func canTransitionTo(_ state: GooseState) -> Bool {
        return hasPooped  // Don't interrupt mid-poop!
    }
}


