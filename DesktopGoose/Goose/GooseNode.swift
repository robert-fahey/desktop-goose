import SceneKit
import Foundation

class GooseNode: SCNNode {
    
    // Goose dimensions (in scene units)
    static let defaultSize: CGFloat = 80
    
    // Animation state
    var isWalking = false
    var isHonking = false
    
    // Direction the goose is facing (radians, 0 = right, π/2 = up)
    var facingDirection: CGFloat = 0 {
        didSet {
            self.eulerAngles.y = facingDirection
        }
    }
    
    // Model container node (for animations on the whole model)
    private var modelContainer: SCNNode?
    
    override init() {
        super.init()
        loadGooseModel()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Load the goose USDZ model
    private func loadGooseModel() {
        guard let url = Bundle.main.url(forResource: "goose", withExtension: "usdz") else {
            NSLog("❌ Error: goose.usdz not found in bundle")
            addFallbackGoose()
            return
        }
        
        do {
            // Load with options to preserve materials and textures
            let scene = try SCNScene(url: url, options: [
                .checkConsistency: true,
                .convertToYUp: true,
                .preserveOriginalTopology: true
            ])
            
            // Create container for the model
            modelContainer = SCNNode()
            
            // Clone nodes while preserving materials
            for child in scene.rootNode.childNodes {
                let clonedChild = child.clone()
                preserveMaterials(from: child, to: clonedChild)
                modelContainer?.addChildNode(clonedChild)
            }
            
            // Scale and position the model appropriately
            let targetSize = GooseNode.defaultSize
            
            // Calculate bounding box to determine scale
            let (minBound, maxBound) = modelContainer!.boundingBox
            
            let modelHeight = CGFloat(maxBound.y - minBound.y)
            let modelWidth = CGFloat(maxBound.x - minBound.x)
            let modelDepth = CGFloat(maxBound.z - minBound.z)
            let maxDimension = max(modelHeight, max(modelWidth, modelDepth))
            
            if maxDimension > 0 {
                let scale = targetSize / maxDimension
                modelContainer?.scale = SCNVector3(scale, scale, scale)
            } else {
                addFallbackGoose()
                return
            }
            
            // Center the model at origin
            let centerY = CGFloat(minBound.y + maxBound.y) / 2
            modelContainer?.position.y = -centerY * modelContainer!.scale.y
            
            // Face forward
            modelContainer?.eulerAngles.y = .pi
            
            // Ensure proper lighting mode for materials
            applyLightingMode(to: modelContainer!)
            
            addChildNode(modelContainer!)
            
            print("✅ Successfully loaded goose.usdz")
        } catch {
            print("❌ Failed to load goose.usdz: \(error)")
            addFallbackGoose()
        }
    }
    
    /// Recursively preserve materials from source to cloned node
    private func preserveMaterials(from source: SCNNode, to dest: SCNNode) {
        // Copy geometry materials
        if let sourceGeometry = source.geometry, let destGeometry = dest.geometry {
            destGeometry.materials = sourceGeometry.materials.compactMap { 
                $0.copy() as? SCNMaterial 
            }
        }
        
        // Recursively handle child nodes
        for (index, sourceChild) in source.childNodes.enumerated() {
            if index < dest.childNodes.count {
                preserveMaterials(from: sourceChild, to: dest.childNodes[index])
            }
        }
    }
    
    /// Apply proper lighting mode and colors to materials
    private func applyLightingMode(to node: SCNNode) {
        applyGooseColors(to: node)
        
        // Recursively apply to children
        for child in node.childNodes {
            applyLightingMode(to: child)
        }
    }
    
    /// Apply the Untitled Goose Game color scheme to the model
    private func applyGooseColors(to node: SCNNode) {
        guard let geometry = node.geometry else { return }
        
        let nodeName = (node.name ?? "").lowercased()
        
        // Define goose colors (Untitled Goose Game style)
        let white = NSColor(red: 0.98, green: 0.98, blue: 0.96, alpha: 1.0)  // Slightly warm white
        let orange = NSColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1.0)  // Beak/feet orange
        let black = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)   // Eye black
        
        for material in geometry.materials {
            material.lightingModel = .blinn
            material.isDoubleSided = true
            
            // Determine color based on node name or material name
            let materialName = (material.name ?? "").lowercased()
            let combinedName = nodeName + materialName
            
            if combinedName.contains("beak") || combinedName.contains("bill") {
                material.diffuse.contents = orange
            } else if combinedName.contains("foot") || combinedName.contains("feet") || combinedName.contains("leg") || combinedName.contains("web") {
                material.diffuse.contents = orange
            } else if combinedName.contains("eye") || combinedName.contains("pupil") {
                material.diffuse.contents = black
            } else {
                // Default to white (body, neck, wings)
                material.diffuse.contents = white
            }
        }
    }
    
    /// Add a simple procedural goose as fallback
    private func addFallbackGoose() {
        print("🦆 Creating fallback procedural goose")
        modelContainer = SCNNode()
        
        // Body - white sphere
        let body = SCNSphere(radius: 30)
        body.firstMaterial?.diffuse.contents = NSColor.white
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 30, 0)
        modelContainer?.addChildNode(bodyNode)
        
        // Head - smaller white sphere
        let head = SCNSphere(radius: 15)
        head.firstMaterial?.diffuse.contents = NSColor.white
        let headNode = SCNNode(geometry: head)
        headNode.position = SCNVector3(0, 70, 15)
        modelContainer?.addChildNode(headNode)
        
        // Beak - orange cone
        let beak = SCNCone(topRadius: 0, bottomRadius: 5, height: 15)
        beak.firstMaterial?.diffuse.contents = NSColor.orange
        let beakNode = SCNNode(geometry: beak)
        beakNode.position = SCNVector3(0, 70, 30)
        beakNode.eulerAngles.x = .pi / 2
        modelContainer?.addChildNode(beakNode)
        
        addChildNode(modelContainer!)
    }
    
    // MARK: - Animations
    
    func startWalkAnimation() {
        guard !isWalking, let container = modelContainer else { return }
        isWalking = true
        
        // Pronounced waddle - side to side rocking like a real goose
        let waddleLeft = SCNAction.rotateBy(x: 0, y: 0, z: 0.15, duration: 0.12)
        waddleLeft.timingMode = .easeInEaseOut
        let waddleRight = SCNAction.rotateBy(x: 0, y: 0, z: -0.15, duration: 0.12)
        waddleRight.timingMode = .easeInEaseOut
        
        let waddle = SCNAction.sequence([
            waddleLeft,
            SCNAction.rotateBy(x: 0, y: 0, z: -0.15, duration: 0.12),
            waddleRight,
            SCNAction.rotateBy(x: 0, y: 0, z: 0.15, duration: 0.12)
        ])
        
        // Bouncy bob up and down
        let bobUp = SCNAction.moveBy(x: 0, y: 4, z: 0, duration: 0.12)
        bobUp.timingMode = .easeOut
        let bobDown = SCNAction.moveBy(x: 0, y: -4, z: 0, duration: 0.12)
        bobDown.timingMode = .easeIn
        let bob = SCNAction.sequence([bobUp, bobDown, bobUp, bobDown])
        
        // Head thrust forward motion (goose-like strut)
        let headForward = SCNAction.rotateBy(x: 0.08, y: 0, z: 0, duration: 0.12)
        let headBack = SCNAction.rotateBy(x: -0.08, y: 0, z: 0, duration: 0.12)
        let headBob = SCNAction.sequence([headForward, headBack, headForward, headBack])
        
        let walkCycle = SCNAction.group([waddle, bob, headBob])
        container.runAction(SCNAction.repeatForever(walkCycle), forKey: "walk")
    }
    
    func stopWalkAnimation() {
        guard isWalking, let container = modelContainer else { return }
        isWalking = false
        
        container.removeAction(forKey: "walk")
        container.removeAction(forKey: "panic")
        
        // Smooth reset to neutral position
        let currentY = container.eulerAngles.y
        let currentX = container.position.x
        let currentZ = container.position.z
        let reset = SCNAction.group([
            SCNAction.rotateTo(x: 0, y: currentY, z: 0, duration: 0.2),
            SCNAction.move(to: SCNVector3(currentX, 0, currentZ), duration: 0.2)
        ])
        reset.timingMode = .easeOut
        container.runAction(reset)
    }
    
    /// Fast panic animation when picked up - legs flailing!
    func playPanicAnimation() {
        guard let container = modelContainer else { return }
        
        // Stop any current walk animation
        container.removeAction(forKey: "walk")
        container.removeAction(forKey: "panic")
        isWalking = true  // Use same flag to track
        
        // FAST waddle side to side (panicking!)
        let waddleLeft = SCNAction.rotateBy(x: 0, y: 0, z: 0.2, duration: 0.05)
        let waddleRight = SCNAction.rotateBy(x: 0, y: 0, z: -0.2, duration: 0.05)
        let waddle = SCNAction.sequence([
            waddleLeft,
            SCNAction.rotateBy(x: 0, y: 0, z: -0.2, duration: 0.05),
            waddleRight,
            SCNAction.rotateBy(x: 0, y: 0, z: 0.2, duration: 0.05)
        ])
        
        // Fast bobbing (like running in air)
        let bobUp = SCNAction.moveBy(x: 0, y: 6, z: 0, duration: 0.05)
        bobUp.timingMode = .easeOut
        let bobDown = SCNAction.moveBy(x: 0, y: -6, z: 0, duration: 0.05)
        bobDown.timingMode = .easeIn
        let bob = SCNAction.sequence([bobUp, bobDown, bobUp, bobDown])
        
        // Fast head movement (panicked!)
        let headForward = SCNAction.rotateBy(x: 0.12, y: 0, z: 0, duration: 0.05)
        let headBack = SCNAction.rotateBy(x: -0.12, y: 0, z: 0, duration: 0.05)
        let headBob = SCNAction.sequence([headForward, headBack, headForward, headBack])
        
        let panicCycle = SCNAction.group([waddle, bob, headBob])
        container.runAction(SCNAction.repeatForever(panicCycle), forKey: "panic")
    }
    
    /// Stop panic animation
    func stopPanicAnimation() {
        guard let container = modelContainer else { return }
        isWalking = false
        
        container.removeAction(forKey: "panic")
        
        // Reset to neutral
        let currentY = container.eulerAngles.y
        let reset = SCNAction.group([
            SCNAction.rotateTo(x: 0, y: currentY, z: 0, duration: 0.15),
            SCNAction.move(to: SCNVector3(0, 0, 0), duration: 0.15)
        ])
        reset.timingMode = .easeOut
        container.runAction(reset)
    }
    
    func playHonkAnimation() {
        guard !isHonking, let container = modelContainer else { return }
        isHonking = true
        
        // Dramatic honk - neck extends, head thrusts forward aggressively
        let prepareHonk = SCNAction.group([
            SCNAction.rotateBy(x: -0.3, y: 0, z: 0, duration: 0.1),  // Pull back
            SCNAction.moveBy(x: 0, y: 3, z: 0, duration: 0.1)        // Rise up slightly
        ])
        
        let honkThrust = SCNAction.group([
            SCNAction.rotateBy(x: 0.5, y: 0, z: 0, duration: 0.08),  // Thrust forward
            SCNAction.moveBy(x: 0, y: -2, z: 0, duration: 0.08)
        ])
        
        let honkHold = SCNAction.wait(duration: 0.15)
        
        let honkRecover = SCNAction.group([
            SCNAction.rotateBy(x: -0.2, y: 0, z: 0, duration: 0.2),
            SCNAction.moveBy(x: 0, y: -1, z: 0, duration: 0.2)
        ])
        
        // Add a little shake for emphasis
        let shake = SCNAction.sequence([
            SCNAction.rotateBy(x: 0, y: 0.05, z: 0, duration: 0.03),
            SCNAction.rotateBy(x: 0, y: -0.1, z: 0, duration: 0.06),
            SCNAction.rotateBy(x: 0, y: 0.05, z: 0, duration: 0.03)
        ])
        
        let honkMotion = SCNAction.sequence([
            prepareHonk,
            honkThrust,
            SCNAction.group([honkHold, SCNAction.repeat(shake, count: 2)]),
            honkRecover
        ])
        
        container.runAction(honkMotion) { [weak self] in
            self?.isHonking = false
        }
    }
    
    func playIdleAnimation() {
        guard let container = modelContainer else { return }
        
        // Random idle behaviors
        let behaviors: [SCNAction] = [
            // Look around curiously
            SCNAction.sequence([
                SCNAction.rotateBy(x: 0, y: 0.4, z: 0, duration: 0.5),
                SCNAction.wait(duration: 0.8),
                SCNAction.rotateBy(x: 0, y: -0.8, z: 0, duration: 0.7),
                SCNAction.wait(duration: 0.5),
                SCNAction.rotateBy(x: 0, y: 0.4, z: 0, duration: 0.4)
            ]),
            // Preen/clean feathers
            SCNAction.sequence([
                SCNAction.rotateBy(x: 0.2, y: 0.3, z: 0.1, duration: 0.3),
                SCNAction.wait(duration: 0.2),
                SCNAction.rotateBy(x: 0, y: 0, z: -0.2, duration: 0.15),
                SCNAction.rotateBy(x: 0, y: 0, z: 0.2, duration: 0.15),
                SCNAction.rotateBy(x: -0.2, y: -0.3, z: -0.1, duration: 0.3)
            ]),
            // Ruffle feathers / shake
            SCNAction.sequence([
                SCNAction.group([
                    SCNAction.sequence([
                        SCNAction.scale(by: 1.1, duration: 0.1),
                        SCNAction.scale(by: 0.909, duration: 0.1)
                    ]),
                    SCNAction.sequence([
                        SCNAction.rotateBy(x: 0, y: 0, z: 0.1, duration: 0.05),
                        SCNAction.rotateBy(x: 0, y: 0, z: -0.2, duration: 0.1),
                        SCNAction.rotateBy(x: 0, y: 0, z: 0.2, duration: 0.1),
                        SCNAction.rotateBy(x: 0, y: 0, z: -0.1, duration: 0.05)
                    ])
                ])
            ]),
            // Stretch neck up
            SCNAction.sequence([
                SCNAction.rotateBy(x: -0.25, y: 0, z: 0, duration: 0.4),
                SCNAction.wait(duration: 0.6),
                SCNAction.rotateBy(x: 0.25, y: 0, z: 0, duration: 0.3)
            ])
        ]
        
        // Create a looping idle with random behaviors
        guard let randomBehavior = behaviors.randomElement() else { return }
        let idleLoop = SCNAction.sequence([
            SCNAction.wait(duration: Double.random(in: 2...4)),
            randomBehavior,
            SCNAction.wait(duration: Double.random(in: 1...2))
        ])
        
        container.runAction(SCNAction.repeatForever(idleLoop), forKey: "idle")
    }
    
    /// Play a wing flap animation
    func playWingFlap() {
        guard let container = modelContainer else { return }
        
        // Quick scale pulse to simulate wing flap
        let flapUp = SCNAction.group([
            SCNAction.scale(by: 1.15, duration: 0.08),
            SCNAction.moveBy(x: 0, y: 5, z: 0, duration: 0.08)
        ])
        let flapDown = SCNAction.group([
            SCNAction.scale(by: 0.87, duration: 0.1),
            SCNAction.moveBy(x: 0, y: -5, z: 0, duration: 0.1)
        ])
        
        let flap = SCNAction.sequence([flapUp, flapDown, flapUp, flapDown])
        container.runAction(flap, forKey: "flap")
    }
    
    /// Quick excited hop
    func playHopAnimation() {
        guard let container = modelContainer else { return }
        
        let hop = SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 15, z: 0, duration: 0.15),
            SCNAction.moveBy(x: 0, y: -15, z: 0, duration: 0.15)
        ])
        hop.timingMode = .easeOut
        container.runAction(hop, forKey: "hop")
    }
    
    func stopIdleAnimation() {
        modelContainer?.removeAction(forKey: "idle")
    }
    
    // MARK: - Sleep Animations
    
    func playSleepAnimation() {
        guard let container = modelContainer else { return }
        
        // Stop other animations
        stopWalkAnimation()
        stopIdleAnimation()
        
        // Settle down - lower body, tuck head
        let settleDown = SCNAction.group([
            SCNAction.rotateBy(x: 0.3, y: 0, z: 0, duration: 0.8),  // Tuck head
            SCNAction.moveBy(x: 0, y: -20, z: 0, duration: 0.8),   // Lower down
            SCNAction.scale(by: 0.95, duration: 0.8)               // Slightly smaller (curled up)
        ])
        settleDown.timingMode = .easeInEaseOut
        
        // Gentle breathing animation
        let breatheIn = SCNAction.scale(by: 1.02, duration: 2.0)
        let breatheOut = SCNAction.scale(by: 0.98, duration: 2.0)
        let breathing = SCNAction.repeatForever(SCNAction.sequence([breatheIn, breatheOut]))
        
        container.runAction(SCNAction.sequence([settleDown, breathing]), forKey: "sleep")
    }
    
    func stopSleepAnimation() {
        guard let container = modelContainer else { return }
        
        container.removeAction(forKey: "sleep")
        
        // Wake up - return to normal position
        let wakeUp = SCNAction.group([
            SCNAction.rotateTo(x: 0, y: container.eulerAngles.y, z: 0, duration: 0.5),
            SCNAction.moveBy(x: 0, y: 20, z: 0, duration: 0.5),
            SCNAction.scale(to: 1.0, duration: 0.5)
        ])
        wakeUp.timingMode = .easeOut
        
        container.runAction(wakeUp)
    }
}
