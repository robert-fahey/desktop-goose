import SceneKit
import Cocoa

/// A poop left by the goose - persists on screen
class Poop: SCNNode {
    
    private static let poopSize: CGFloat = 15
    
    /// Collision radius for detecting ball hits
    let collisionRadius: CGFloat = 20
    
    /// Whether this poop has been smeared
    private(set) var isSmeared: Bool = false
    
    /// How many times this poop has been smeared (more smears = flatter)
    private var smearCount: Int = 0
    
    override init() {
        super.init()
        createPoopGeometry()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createPoopGeometry() {
        // Create a stylized poop shape using stacked spheres
        let baseColor = NSColor(red: 0.95, green: 0.95, blue: 0.9, alpha: 1.0)  // White/off-white (goose poop!)
        
        // Bottom blob
        let bottomSphere = SCNSphere(radius: Poop.poopSize * 0.5)
        bottomSphere.firstMaterial?.diffuse.contents = baseColor
        bottomSphere.firstMaterial?.shininess = 0.3
        let bottomNode = SCNNode(geometry: bottomSphere)
        bottomNode.name = "poopBlob"
        bottomNode.position = SCNVector3(0, Poop.poopSize * 0.3, 0)
        addChildNode(bottomNode)
        
        // Middle blob (slightly smaller)
        let middleSphere = SCNSphere(radius: Poop.poopSize * 0.4)
        middleSphere.firstMaterial?.diffuse.contents = baseColor
        middleSphere.firstMaterial?.shininess = 0.3
        let middleNode = SCNNode(geometry: middleSphere)
        middleNode.name = "poopBlob"
        middleNode.position = SCNVector3(0, Poop.poopSize * 0.7, 0)
        addChildNode(middleNode)
        
        // Top blob (smallest)
        let topSphere = SCNSphere(radius: Poop.poopSize * 0.25)
        topSphere.firstMaterial?.diffuse.contents = baseColor
        topSphere.firstMaterial?.shininess = 0.3
        let topNode = SCNNode(geometry: topSphere)
        topNode.name = "poopBlob"
        topNode.position = SCNVector3(0, Poop.poopSize * 1.0, 0)
        addChildNode(topNode)
        
        // Add a little splat animation when created
        self.scale = SCNVector3(0.1, 0.1, 0.1)
        
        let scaleUp = SCNAction.scale(to: 1.2, duration: 0.1)
        let scaleDown = SCNAction.scale(to: 1.0, duration: 0.1)
        scaleUp.timingMode = .easeOut
        scaleDown.timingMode = .easeIn
        
        self.runAction(SCNAction.sequence([scaleUp, scaleDown]))
    }
    
    /// Check if a point collides with this poop
    func checkCollision(with point: CGPoint, radius: CGFloat) -> Bool {
        let dx = CGFloat(position.x) - point.x
        let dy = CGFloat(position.y) - point.y
        let distance = sqrt(dx * dx + dy * dy)
        return distance < (collisionRadius + radius)
    }
    
    /// Smear the poop in the direction of impact
    func smear(direction: CGPoint, force: CGFloat) {
        isSmeared = true
        smearCount += 1
        
        // Calculate smear angle
        let angle = atan2(direction.y, direction.x)
        
        // Flatten and stretch in direction of impact
        let stretchFactor = min(1.0 + force / 300, 3.0)  // More force = more stretch
        let flattenFactor = max(0.3, 1.0 - CGFloat(smearCount) * 0.2)  // Each smear flattens more
        
        // Move slightly in impact direction
        let moveDistance = min(force / 10, 30)
        let moveAction = SCNAction.moveBy(
            x: cos(angle) * moveDistance,
            y: sin(angle) * moveDistance,
            z: 0,
            duration: 0.15
        )
        
        // Squash and stretch animation
        let currentScale = self.scale
        let smearScale = SCNVector3(
            x: currentScale.x * stretchFactor,
            y: currentScale.y * flattenFactor,
            z: currentScale.z * stretchFactor
        )
        
        let squashAction = SCNAction.customAction(duration: 0.15) { node, elapsed in
            let t = elapsed / 0.15
            node.scale = SCNVector3(
                x: currentScale.x + (smearScale.x - currentScale.x) * t,
                y: currentScale.y + (smearScale.y - currentScale.y) * t,
                z: currentScale.z + (smearScale.z - currentScale.z) * t
            )
        }
        
        // Rotate to align with smear direction
        let rotateAction = SCNAction.rotateTo(x: 0, y: 0, z: angle, duration: 0.1)
        
        // Darken/dirty the color slightly with each smear
        for child in childNodes where child.name == "poopBlob" {
            if let material = child.geometry?.firstMaterial {
                let dirtyFactor = max(0.6, 1.0 - CGFloat(smearCount) * 0.1)
                material.diffuse.contents = NSColor(
                    red: 0.95 * dirtyFactor,
                    green: 0.95 * dirtyFactor,
                    blue: 0.85 * dirtyFactor,  // Gets slightly yellowish when smeared
                    alpha: 1.0
                )
            }
        }
        
        self.runAction(SCNAction.group([moveAction, squashAction, rotateAction]))
        
        NSLog("💩 Poop smeared! (smear count: \(smearCount))")
    }
}

