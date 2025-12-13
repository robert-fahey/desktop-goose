import SceneKit
import Foundation
import AVFoundation

/// A pushable object on the desktop that the goose can interact with
class DesktopObject: SCNNode {
    
    /// Velocity of the object (for physics simulation)
    var velocity: CGPoint = .zero
    
    /// Friction coefficient (0-1, higher = more friction)
    var friction: CGFloat = 0.98
    
    /// Bounciness when hitting screen edges (0-1)
    var bounciness: CGFloat = 0.7
    
    /// Size of the object for collision detection
    var collisionRadius: CGFloat = 25
    
    /// Mass affects how easily the goose can push it
    var mass: CGFloat = 1.0
    
    /// Whether the goose should push this object on current contact
    var shouldBePushed: Bool = false
    
    /// Whether the object can be thrown (true) or just placed (false)
    var isThrowable: Bool = true
    
    /// Whether the object can be pushed by the ball (even if not throwable)
    var isPushable: Bool = false
    
    /// Whether the object's rotation resets when user interacts with it
    var resetsRotation: Bool = false
    
    /// Whether this object can be used as a hiding spot
    var isHidingSpot: Bool = false
    
    /// Rotation velocity for spinning effect
    var rotationVelocity: CGFloat = 0
    
    /// Wobble state
    private var isWobbling: Bool = false
    
    /// Knocked over state
    private(set) var isKnockedOver: Bool = false
    private var knockedOverTimer: TimeInterval = 0
    
    private var modelContainer: SCNNode?
    
    init(modelName: String, size: CGFloat = 50) {
        super.init()
        self.collisionRadius = size / 2
        loadModel(named: modelName, targetSize: size)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func loadModel(named name: String, targetSize: CGFloat) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz") else {
            NSLog("❌ Could not find \(name).usdz")
            createFallbackSphere(size: targetSize)
            return
        }
        
        do {
            let scene = try SCNScene(url: url, options: [.checkConsistency: true])
            
            modelContainer = SCNNode()
            for child in scene.rootNode.childNodes {
                modelContainer?.addChildNode(child.clone())
            }
            
            // Scale to target size
            let (minBound, maxBound) = modelContainer!.boundingBox
            let modelWidth = CGFloat(maxBound.x - minBound.x)
            let modelHeight = CGFloat(maxBound.y - minBound.y)
            let modelDepth = CGFloat(maxBound.z - minBound.z)
            let maxDimension = max(modelWidth, max(modelHeight, modelDepth))
            
            if maxDimension > 0 {
                let scale = targetSize / maxDimension
                modelContainer?.scale = SCNVector3(scale, scale, scale)
            }
            
            // Center the model
            let centerX = CGFloat(minBound.x + maxBound.x) / 2
            let centerY = CGFloat(minBound.y + maxBound.y) / 2
            let centerZ = CGFloat(minBound.z + maxBound.z) / 2
            modelContainer?.position = SCNVector3(
                -centerX * modelContainer!.scale.x,
                -centerY * modelContainer!.scale.y,
                -centerZ * modelContainer!.scale.z
            )
            
            addChildNode(modelContainer!)
            NSLog("✅ Loaded desktop object: \(name)")
        } catch {
            NSLog("❌ Failed to load \(name).usdz: \(error)")
            createFallbackSphere(size: targetSize)
        }
    }
    
    private func createFallbackSphere(size: CGFloat) {
        let sphere = SCNSphere(radius: size / 2)
        sphere.firstMaterial?.diffuse.contents = NSColor.red
        let sphereNode = SCNNode(geometry: sphere)
        addChildNode(sphereNode)
    }
    
    /// Update physics simulation
    func update(deltaTime: CGFloat, screenBounds: CGRect) {
        // Apply velocity
        position.x += velocity.x * deltaTime
        position.y += velocity.y * deltaTime
        
        // Apply friction
        velocity.x *= friction
        velocity.y *= friction
        
        // Stop if velocity is very small
        if abs(velocity.x) < 1 && abs(velocity.y) < 1 {
            velocity = .zero
        }
        
        // Bounce off screen edges
        let x = position.x
        let y = position.y
        
        if x - collisionRadius < screenBounds.minX {
            position.x = screenBounds.minX + collisionRadius
            velocity.x = -velocity.x * bounciness
        } else if x + collisionRadius > screenBounds.maxX {
            position.x = screenBounds.maxX - collisionRadius
            velocity.x = -velocity.x * bounciness
        }
        
        if y - collisionRadius < screenBounds.minY {
            position.y = screenBounds.minY + collisionRadius
            velocity.y = -velocity.y * bounciness
        } else if y + collisionRadius > screenBounds.maxY {
            position.y = screenBounds.maxY - collisionRadius
            velocity.y = -velocity.y * bounciness
        }
        
        // Rotate based on velocity (rolling effect)
        if velocity.x != 0 || velocity.y != 0 {
            let rollSpeed: CGFloat = 0.1
            let vx = velocity.x
            let vy = velocity.y
            let dt = deltaTime
            modelContainer?.eulerAngles.z -= vx * rollSpeed * dt
            modelContainer?.eulerAngles.x += vy * rollSpeed * dt
        }
    }
    
    /// Apply an impulse to the object
    func applyImpulse(_ impulse: CGPoint) {
        velocity.x += impulse.x / mass
        velocity.y += impulse.y / mass
    }
    
    /// Check collision with a point (like the goose position)
    func checkCollision(with point: CGPoint, radius: CGFloat) -> Bool {
        let dx = CGFloat(position.x) - point.x
        let dy = CGFloat(position.y) - point.y
        let distance = sqrt(dx * dx + dy * dy)
        return distance < (collisionRadius + radius)
    }
    
    /// Rotate based on mouse movement direction
    func rotateTowardMovement(dx: CGFloat, dy: CGFloat, speed: CGFloat) {
        guard let container = modelContainer else { return }
        
        // Tilt in the direction of movement
        let tiltAmount: CGFloat = min(speed / 500, 0.3)  // Cap the tilt
        let targetTiltX = -dy / 100 * tiltAmount
        let targetTiltZ = dx / 100 * tiltAmount
        
        // Smoothly interpolate toward target tilt
        let currentX = container.eulerAngles.x
        let currentZ = container.eulerAngles.z
        container.eulerAngles.x = currentX + (targetTiltX - currentX) * 0.2
        container.eulerAngles.z = currentZ + (targetTiltZ - currentZ) * 0.2
        
        // Add rotation around Y axis based on movement
        container.eulerAngles.y += dx * 0.002
    }
    
    /// Apply spin when released
    func applySpin(mouseVelocity: CGPoint) {
        // Calculate spin from mouse velocity
        let speed = sqrt(mouseVelocity.x * mouseVelocity.x + mouseVelocity.y * mouseVelocity.y)
        rotationVelocity = mouseVelocity.x * 0.01  // Spin based on horizontal velocity
        
        // Also trigger wobble
        if speed > 50 {
            playWobbleAnimation()
        }
    }
    
    /// Play a wobble animation when placed
    func playWobbleAnimation() {
        guard let container = modelContainer, !isWobbling else { return }
        isWobbling = true
        
        // Create wobble animation
        let wobbleLeft = SCNAction.rotateBy(x: 0, y: 0, z: 0.15, duration: 0.1)
        let wobbleRight = SCNAction.rotateBy(x: 0, y: 0, z: -0.3, duration: 0.2)
        let wobbleBack = SCNAction.rotateBy(x: 0, y: 0, z: 0.2, duration: 0.15)
        let wobbleSettle = SCNAction.rotateBy(x: 0, y: 0, z: -0.1, duration: 0.1)
        let settle = SCNAction.rotateBy(x: 0, y: 0, z: 0.05, duration: 0.08)
        
        let wobble = SCNAction.sequence([wobbleLeft, wobbleRight, wobbleBack, wobbleSettle, settle])
        wobble.timingMode = .easeOut
        
        container.runAction(wobble) { [weak self] in
            self?.isWobbling = false
            // Reset tilt
            self?.modelContainer?.eulerAngles.z = 0
            self?.modelContainer?.eulerAngles.x = 0
        }
    }
    
    /// Update spin rotation (call each frame)
    func updateSpin(deltaTime: CGFloat) {
        guard let container = modelContainer, abs(rotationVelocity) > 0.001 else { return }
        
        // Apply rotation
        container.eulerAngles.y += rotationVelocity
        
        // Friction to slow down spin
        rotationVelocity *= 0.95
        
        // Stop when very slow
        if abs(rotationVelocity) < 0.001 {
            rotationVelocity = 0
        }
    }
    
    /// Knock the object over (from ball impact)
    func knockOver(impactDirection: CGPoint, impactForce: CGFloat) {
        guard let container = modelContainer, !isKnockedOver else { return }
        isKnockedOver = true
        knockedOverTimer = 0
        
        // Calculate fall direction based on impact
        let fallAngle = atan2(impactDirection.y, impactDirection.x)
        
        // Dramatic fall animation
        let fallRotation: CGFloat = .pi / 2 * 0.8  // Almost horizontal
        let fallDuration: TimeInterval = 0.4
        
        // Fall in the direction of impact
        let fallAction = SCNAction.rotateBy(
            x: -sin(fallAngle) * fallRotation,
            y: 0,
            z: cos(fallAngle) * fallRotation,
            duration: fallDuration
        )
        fallAction.timingMode = .easeIn
        
        // Bounce slightly then stay down
        let bounceAction = SCNAction.sequence([
            SCNAction.rotateBy(x: sin(fallAngle) * 0.1, y: 0, z: -cos(fallAngle) * 0.1, duration: 0.1),
            SCNAction.rotateBy(x: -sin(fallAngle) * 0.05, y: 0, z: cos(fallAngle) * 0.05, duration: 0.1)
        ])
        
        // Stay knocked over - don't auto-recover! User must pick it up.
        let sequence = SCNAction.sequence([fallAction, bounceAction])
        container.runAction(sequence)
        
        // Also slide a bit in impact direction
        let slideDistance: CGFloat = min(impactForce * 0.3, 80)
        let slideAction = SCNAction.moveBy(
            x: impactDirection.x * slideDistance,
            y: impactDirection.y * slideDistance,
            z: 0,
            duration: fallDuration
        )
        slideAction.timingMode = .easeOut
        self.runAction(slideAction)
    }
    
    /// Stand the object back up (when user picks it up and places it)
    func standUp() {
        guard let container = modelContainer, isKnockedOver else { return }
        
        // Animate back to upright
        let standAction = SCNAction.rotateTo(x: 0, y: container.eulerAngles.y, z: 0, duration: 0.3)
        standAction.timingMode = .easeOut
        
        container.runAction(standAction) { [weak self] in
            self?.isKnockedOver = false
        }
        
        // Play a wobble as it settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.playWobbleAnimation()
        }
    }
    
    /// Reset rotation to upright (when user places furniture after goose messed with it)
    func resetRotation() {
        // Animate the object back to upright orientation
        let resetAction = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)
        resetAction.timingMode = .easeOut
        
        // Also reset the parent node's euler angles
        self.runAction(resetAction)
        
        // Reset model container too if it exists
        if let container = modelContainer {
            let containerReset = SCNAction.rotateTo(x: 0, y: container.eulerAngles.y, z: 0, duration: 0.3)
            containerReset.timingMode = .easeOut
            container.runAction(containerReset)
        }
    }
}

