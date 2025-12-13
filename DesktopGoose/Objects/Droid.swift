import SceneKit
import Foundation

/// The menacing droid that chases the goose
class Droid: SCNNode {
    
    /// Current velocity
    var velocity: CGPoint = .zero
    
    /// Movement speed when chasing
    var chaseSpeed: CGFloat = 120.0
    
    /// Collision radius for ball detection
    var collisionRadius: CGFloat = 40
    
    /// Whether the droid is currently knocked over
    private(set) var isKnockedOver: Bool = false
    
    /// Timer for how long droid stays knocked over
    private var knockedOverTimer: TimeInterval = 0
    private let knockedOverDuration: TimeInterval = 5.0
    
    /// Whether the droid is currently active (on screen)
    private(set) var isActive: Bool = false
    
    /// Timer for droid appearance duration
    private var activeTimer: TimeInterval = 0
    private var activeDuration: TimeInterval = 30.0  // 30 seconds of chasing
    
    private var modelContainer: SCNNode?
    
    override init() {
        super.init()
        loadModel()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func loadModel() {
        guard let url = Bundle.main.url(forResource: "droid", withExtension: "usdz") else {
            NSLog("❌ Could not find droid.usdz")
            createFallbackModel()
            return
        }
        
        do {
            let scene = try SCNScene(url: url, options: [.checkConsistency: true])
            
            modelContainer = SCNNode()
            for child in scene.rootNode.childNodes {
                modelContainer?.addChildNode(child.clone())
            }
            
            // Scale to appropriate size
            let targetSize: CGFloat = 80
            let (minBound, maxBound) = modelContainer!.boundingBox
            let modelWidth = CGFloat(maxBound.x - minBound.x)
            let modelHeight = CGFloat(maxBound.y - minBound.y)
            let modelDepth = CGFloat(maxBound.z - minBound.z)
            let maxDimension = max(modelWidth, max(modelHeight, modelDepth))
            
            if maxDimension > 0 {
                let scale = targetSize / maxDimension
                // Negative X scale to mirror the model horizontally
                modelContainer?.scale = SCNVector3(-scale, scale, scale)
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
            NSLog("✅ Loaded droid model")
        } catch {
            NSLog("❌ Failed to load droid.usdz: \(error)")
            createFallbackModel()
        }
    }
    
    private func createFallbackModel() {
        let sphere = SCNSphere(radius: 30)
        sphere.firstMaterial?.diffuse.contents = NSColor.darkGray
        sphere.firstMaterial?.metalness.contents = 0.8
        let sphereNode = SCNNode(geometry: sphere)
        
        // Add an "eye" to make it look robotic
        let eye = SCNCylinder(radius: 8, height: 5)
        eye.firstMaterial?.diffuse.contents = NSColor.red
        eye.firstMaterial?.emission.contents = NSColor.red
        let eyeNode = SCNNode(geometry: eye)
        eyeNode.position = SCNVector3(0, 0, 25)
        eyeNode.eulerAngles.x = .pi / 2
        sphereNode.addChildNode(eyeNode)
        
        modelContainer = sphereNode
        addChildNode(sphereNode)
    }
    
    /// Spawn the droid at a random edge of the screen
    func spawn(screenBounds: CGRect) {
        guard !isActive else { return }
        
        isActive = true
        isKnockedOver = false
        activeTimer = 0
        activeDuration = CGFloat.random(in: 20...40)  // Random duration
        
        // Spawn from a random edge
        let edge = Int.random(in: 0...3)
        var spawnPos: CGPoint
        
        switch edge {
        case 0: // Top
            spawnPos = CGPoint(x: CGFloat.random(in: screenBounds.minX...screenBounds.maxX), y: screenBounds.maxY + 50)
        case 1: // Right
            spawnPos = CGPoint(x: screenBounds.maxX + 50, y: CGFloat.random(in: screenBounds.minY...screenBounds.maxY))
        case 2: // Bottom
            spawnPos = CGPoint(x: CGFloat.random(in: screenBounds.minX...screenBounds.maxX), y: screenBounds.minY - 50)
        default: // Left
            spawnPos = CGPoint(x: screenBounds.minX - 50, y: CGFloat.random(in: screenBounds.minY...screenBounds.maxY))
        }
        
        position = SCNVector3(x: spawnPos.x, y: spawnPos.y, z: 0)
        isHidden = false
        
        // Reset rotation if was knocked over
        modelContainer?.eulerAngles = SCNVector3Zero
        
        NSLog("🤖 Droid spawned!")
    }
    
    /// Despawn the droid (move off screen and hide)
    func despawn() {
        isActive = false
        isHidden = true
        velocity = .zero
        NSLog("🤖 Droid despawned")
    }
    
    /// Chase the goose!
    func chaseTarget(targetPosition: CGPoint, deltaTime: CGFloat) {
        guard isActive && !isKnockedOver else { return }
        
        let dx = targetPosition.x - CGFloat(position.x)
        let dy = targetPosition.y - CGFloat(position.y)
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance > 5 {
            let dirX = dx / distance
            let dirY = dy / distance
            
            velocity.x = dirX * chaseSpeed
            velocity.y = dirY * chaseSpeed
            
            // Face the direction of movement
            let angle = atan2(dy, dx)
            modelContainer?.eulerAngles.y = -angle + .pi / 2
        }
    }
    
    /// Update the droid each frame
    func update(deltaTime: CGFloat, screenBounds: CGRect) -> Bool {
        guard isActive else { return false }
        
        // Handle knocked over state
        if isKnockedOver {
            knockedOverTimer += deltaTime
            if knockedOverTimer >= knockedOverDuration {
                standUp()
            }
            return true
        }
        
        // Update active timer
        activeTimer += deltaTime
        if activeTimer >= activeDuration {
            despawn()
            return false
        }
        
        // Apply velocity
        position.x += velocity.x * deltaTime
        position.y += velocity.y * deltaTime
        
        // Keep on screen (mostly)
        let margin: CGFloat = 50
        if position.x < screenBounds.minX - margin {
            position.x = screenBounds.minX - margin
        } else if position.x > screenBounds.maxX + margin {
            position.x = screenBounds.maxX + margin
        }
        
        if position.y < screenBounds.minY - margin {
            position.y = screenBounds.minY - margin
        } else if position.y > screenBounds.maxY + margin {
            position.y = screenBounds.maxY + margin
        }
        
        // Add some wobble/hover animation
        let wobble = sin(activeTimer * 3) * 0.1
        modelContainer?.eulerAngles.z = wobble
        
        return true
    }
    
    /// Check if a point (like the ball) collides with the droid
    func checkCollision(with point: CGPoint, radius: CGFloat) -> Bool {
        guard isActive && !isKnockedOver else { return false }
        
        let dx = CGFloat(position.x) - point.x
        let dy = CGFloat(position.y) - point.y
        let distance = sqrt(dx * dx + dy * dy)
        return distance < (collisionRadius + radius)
    }
    
    /// Get knocked over by the ball!
    func knockOver(impactDirection: CGPoint, impactForce: CGFloat) {
        guard !isKnockedOver else { return }
        
        isKnockedOver = true
        knockedOverTimer = 0
        velocity = .zero
        
        // Dramatic fall animation
        let fallAngle = atan2(impactDirection.y, impactDirection.x)
        let fallRotation: CGFloat = .pi / 2 * 0.9
        
        let fallAction = SCNAction.rotateBy(
            x: -sin(fallAngle) * fallRotation,
            y: 0,
            z: cos(fallAngle) * fallRotation,
            duration: 0.5
        )
        fallAction.timingMode = .easeIn
        
        // Sparks/glitch effect
        let flashOn = SCNAction.run { [weak self] _ in
            self?.modelContainer?.opacity = 0.5
        }
        let flashOff = SCNAction.run { [weak self] _ in
            self?.modelContainer?.opacity = 1.0
        }
        let flash = SCNAction.sequence([flashOn, SCNAction.wait(duration: 0.1), flashOff])
        let flickerAction = SCNAction.repeat(flash, count: 5)
        
        modelContainer?.runAction(SCNAction.group([fallAction, flickerAction]))
        
        // Slide from impact
        let slideDistance: CGFloat = min(impactForce * 0.2, 60)
        let slideAction = SCNAction.moveBy(
            x: impactDirection.x * slideDistance,
            y: impactDirection.y * slideDistance,
            z: 0,
            duration: 0.5
        )
        self.runAction(slideAction)
        
        NSLog("🤖💥 Droid knocked over!")
    }
    
    /// Stand back up after being knocked over
    private func standUp() {
        guard isKnockedOver else { return }
        
        let standAction = SCNAction.rotateTo(x: 0, y: modelContainer?.eulerAngles.y ?? 0, z: 0, duration: 0.5)
        standAction.timingMode = .easeOut
        
        modelContainer?.runAction(standAction) { [weak self] in
            self?.isKnockedOver = false
            NSLog("🤖 Droid standing back up!")
        }
    }
    
    /// Check if the droid is close enough to catch the goose
    func isNearGoose(goosePosition: CGPoint, catchRadius: CGFloat = 50) -> Bool {
        guard isActive && !isKnockedOver else { return false }
        
        let dx = CGFloat(position.x) - goosePosition.x
        let dy = CGFloat(position.y) - goosePosition.y
        let distance = sqrt(dx * dx + dy * dy)
        return distance < catchRadius
    }
    
    /// Kick a ball back at the goose (for dodgeball)
    func kickBallAtGoose(ball: SCNNode, goosePosition: CGPoint) {
        guard isActive && !isKnockedOver else { return }
        
        let ballPos = CGPoint(x: ball.position.x, y: ball.position.y)
        let dx = goosePosition.x - ballPos.x
        let dy = goosePosition.y - ballPos.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance > 0 {
            let kickForce: CGFloat = 800  // Droid kicks hard!
            // Assuming ball has velocity property (DesktopObject)
            if let desktopBall = ball as? DesktopObject {
                desktopBall.velocity = CGPoint(
                    x: dx / distance * kickForce,
                    y: dy / distance * kickForce
                )
                NSLog("🤖⚽ Droid kicks ball at goose!")
            }
        }
    }
    
    /// Check if a ball is nearby (for dodgeball reactive kicking)
    func getNearbyBall(objects: [DesktopObject]) -> DesktopObject? {
        guard isActive && !isKnockedOver else { return nil }
        
        let balls = objects.filter { $0.isThrowable }
        let droidPos = CGPoint(x: position.x, y: position.y)
        
        for ball in balls {
            let ballPos = CGPoint(x: ball.position.x, y: ball.position.y)
            let dx = droidPos.x - ballPos.x
            let dy = droidPos.y - ballPos.y
            let distance = sqrt(dx * dx + dy * dy)
            
            // Check if ball is close and moving slowly (catchable)
            let ballSpeed = sqrt(ball.velocity.x * ball.velocity.x + ball.velocity.y * ball.velocity.y)
            if distance < 100 && ballSpeed < 200 {
                return ball
            }
        }
        return nil
    }
}

