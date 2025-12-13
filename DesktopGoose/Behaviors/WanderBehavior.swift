import Foundation
import CoreGraphics

class WanderBehavior: GooseBehavior {
    
    private weak var controller: GooseController?
    private let screenManager: ScreenManager
    
    // Behavior configuration
    var minimumDuration: TimeInterval { 5.0 }
    var maximumDuration: TimeInterval { 15.0 }
    var weight: Double { 3.0 } // High weight - wandering is the default
    var cooldown: TimeInterval { 1.0 }
    
    // Wandering state
    private var currentTarget: CGPoint?
    private var waitingAtTarget = false
    private var waitTimer: TimeInterval = 0
    
    init(controller: GooseController, screenManager: ScreenManager) {
        self.controller = controller
        self.screenManager = screenManager
    }
    
    func enter() {
        pickNewTarget()
    }
    
    func update(deltaTime: CGFloat) {
        guard let controller = controller else { return }
        
        if waitingAtTarget {
            waitTimer -= TimeInterval(deltaTime)
            if waitTimer <= 0 {
                waitingAtTarget = false
                pickNewTarget()
            }
        } else if !controller.isMoving {
            // Reached destination, wait a bit
            waitingAtTarget = true
            waitTimer = Double.random(in: 0.5...2.0)
            controller.playIdleAnimation()
        }
    }
    
    func exit() {
        controller?.stopMoving()
        controller?.stopIdleAnimation()
        currentTarget = nil
        waitingAtTarget = false
    }
    
    private func pickNewTarget() {
        guard let controller = controller else { return }
        
        let bounds = screenManager.primaryScreenBounds
        let margin: CGFloat = 100 // Keep away from edges
        
        // Pick a random point, but not too close to current position
        var attempts = 0
        var target: CGPoint
        
        repeat {
            target = CGPoint(
                x: CGFloat.random(in: (bounds.minX + margin)...(bounds.maxX - margin)),
                y: CGFloat.random(in: (bounds.minY + margin)...(bounds.maxY - margin))
            )
            attempts += 1
        } while distanceBetween(controller.position, target) < 200 && attempts < 10
        
        currentTarget = target
        controller.stopIdleAnimation()
        controller.moveTo(target)
    }
    
    private func distanceBetween(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
}



