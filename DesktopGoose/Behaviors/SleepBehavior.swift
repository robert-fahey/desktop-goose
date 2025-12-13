import Foundation
import SceneKit
import AppKit

/// Behavior for sleeping - goose pulls out a bed and lies on it
class SleepBehavior: GooseBehavior {
    
    var minimumDuration: TimeInterval { 1.0 }
    var maximumDuration: TimeInterval { 999999 }  // Sleep until woken
    var weight: Double { 0 }  // Not randomly selected
    var cooldown: TimeInterval { 0 }
    
    private weak var controller: GooseController?
    private weak var sceneView: GooseSceneView?
    
    private enum Phase {
        case walkingToEdge      // Goose walks to screen edge first
        case draggingBedIn      // Goose drags bed onto screen
        case walkingToBed
        case gettingInBed
        case sleeping
        case wakingUp
        case pushingBedOut
    }
    
    private var phase: Phase = .walkingToEdge
    private var phaseTimer: TimeInterval = 0
    private var savedGoosePosition: SCNVector3 = SCNVector3Zero
    
    // Bed node
    private var bedNode: SCNNode?
    private var bedFromLeft: Bool = true
    private var bedRestPosition: CGPoint = .zero
    private var edgePosition: CGPoint = .zero  // Where goose goes to drag bed from
    
    init(controller: GooseController) {
        self.controller = controller
    }
    
    func setSceneView(_ sceneView: GooseSceneView?) {
        self.sceneView = sceneView
    }
    
    func enter() {
        phase = .walkingToEdge
        phaseTimer = 0
        
        // Save current position
        if let gooseNode = sceneView?.gooseNode {
            savedGoosePosition = gooseNode.position
        }
        
        // Decide which side the bed comes from
        bedFromLeft = Bool.random()
        
        // Calculate positions
        let screenBounds = controller?.screenManager.primaryScreenBounds ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let bedY = screenBounds.midY
        
        // Edge position where goose will drag bed from
        edgePosition = CGPoint(
            x: bedFromLeft ? screenBounds.minX + 30 : screenBounds.maxX - 30,
            y: bedY
        )
        
        // Where the bed will rest (a bit away from edge)
        bedRestPosition = CGPoint(
            x: bedFromLeft ? screenBounds.minX + 200 : screenBounds.maxX - 200,
            y: bedY
        )
        
        // Start by walking to the edge
        walkToEdge()
    }
    
    private func walkToEdge() {
        guard let gooseNode = sceneView?.gooseNode, let goose = gooseNode as? GooseNode else {
            startSleeping()
            return
        }
        
        NSLog("🦆 Goose walking to edge to get bed...")
        
        // Start walking animation
        goose.startWalkAnimation()
        
        // Rotate to face the edge
        let faceEdge = bedFromLeft ? CGFloat.pi / 2 : -CGFloat.pi / 2  // Face left or right
        let rotate = SCNAction.rotateTo(x: 0, y: faceEdge, z: 0, duration: 0.3)
        rotate.timingMode = .easeInEaseOut
        
        // Walk to the edge of the screen
        let walkToEdge = SCNAction.move(to: SCNVector3(edgePosition.x, edgePosition.y, 0), duration: 2.0)
        walkToEdge.timingMode = .easeInEaseOut
        
        // First rotate, then walk
        let sequence = SCNAction.sequence([rotate, walkToEdge])
        
        gooseNode.runAction(sequence) { [weak self] in
            self?.phase = .draggingBedIn
            self?.phaseTimer = 0
            self?.dragBedIn()
        }
    }
    
    private func dragBedIn() {
        guard let sceneView = sceneView else { return }
        guard let gooseNode = sceneView.gooseNode, let goose = gooseNode as? GooseNode else {
            startSleeping()
            return
        }
        
        // Load the bed model
        guard let bedURL = Bundle.main.url(forResource: "bed", withExtension: "usdz") else {
            NSLog("❌ bed.usdz not found")
            startSleeping()
            return
        }
        
        do {
            let bedScene = try SCNScene(url: bedURL, options: nil)
            bedNode = SCNNode()
            
            for child in bedScene.rootNode.childNodes {
                bedNode?.addChildNode(child.clone())
            }
            
            // Scale the bed appropriately
            let targetSize: CGFloat = 200
            let (minBound, maxBound) = bedNode!.boundingBox
            let modelWidth = CGFloat(maxBound.x - minBound.x)
            let modelHeight = CGFloat(maxBound.y - minBound.y)
            let modelDepth = CGFloat(maxBound.z - minBound.z)
            let maxDimension = max(modelWidth, max(modelHeight, modelDepth))
            
            NSLog("🛏️ Bed bounds: w=\(modelWidth), h=\(modelHeight), d=\(modelDepth), max=\(maxDimension)")
            
            if maxDimension > 0 {
                let scale = targetSize / maxDimension
                bedNode?.scale = SCNVector3(scale, scale, scale)
            }
            
            // Position bed just off-screen at the edge
            let screenBounds = controller?.screenManager.primaryScreenBounds ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
            let bedY = edgePosition.y
            
            if bedFromLeft {
                bedNode?.position = SCNVector3(-150, bedY, 10)  // Just off left edge
            } else {
                bedNode?.position = SCNVector3(screenBounds.maxX + 150, bedY, 10)  // Just off right edge
            }
            
            NSLog("🛏️ Bed starting position: \(bedNode!.position), rest position: \(bedRestPosition)")
            
            // Add bed to scene
            sceneView.gooseScene.rootNode.addChildNode(bedNode!)
            
            // Goose "reaches out" - lean towards the edge slightly
            let leanOut = SCNAction.rotateTo(x: 0.2, y: gooseNode.eulerAngles.y, z: 0.1, duration: 0.3)
            leanOut.timingMode = .easeOut
            goose.stopWalkAnimation()  // Stop to "grab" the bed
            gooseNode.runAction(leanOut)
            
            // Small pause to "grab" the bed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self = self else { return }
                
                // Now drag the bed in while goose walks backward
                let dragDuration: TimeInterval = 2.0
                
                // Bed slides in
                let slideIn = SCNAction.move(to: SCNVector3(self.bedRestPosition.x, self.bedRestPosition.y, 10), duration: dragDuration)
                slideIn.timingMode = .easeOut
                
                // Goose walks backward (toward the bed's rest position)
                // First straighten up
                let straighten = SCNAction.rotateTo(x: 0, y: gooseNode.eulerAngles.y, z: 0, duration: 0.2)
                
                // Walk backward with bed (goose ends up near the bed's final position)
                let pullPosition = SCNVector3(
                    self.bedRestPosition.x + (self.bedFromLeft ? 50 : -50),  // Stay beside the bed
                    self.bedRestPosition.y,
                    0
                )
                let walkBackward = SCNAction.move(to: pullPosition, duration: dragDuration)
                walkBackward.timingMode = .easeOut
                
                let gooseSequence = SCNAction.sequence([straighten, walkBackward])
                
                goose.startWalkAnimation()
                gooseNode.runAction(gooseSequence)
                
                self.bedNode?.runAction(slideIn) { [weak self] in
                    goose.stopWalkAnimation()
                    self?.phase = .walkingToBed
                    self?.phaseTimer = 0
                    self?.walkToBed()
                }
                
                NSLog("🛏️ Goose is dragging the bed onto screen!")
            }
            
        } catch {
            NSLog("❌ Failed to load bed: \(error)")
            startSleeping()
        }
    }
    
    private func walkToBed() {
        guard let gooseNode = sceneView?.gooseNode else {
            startSleeping()
            return
        }
        
        // Walk to the bed
        let bedTop = CGPoint(x: bedRestPosition.x, y: bedRestPosition.y + 30)
        let walkToBed = SCNAction.move(to: SCNVector3(bedTop.x, bedTop.y, 5), duration: 1.5)
        walkToBed.timingMode = .easeInEaseOut
        
        gooseNode.runAction(walkToBed) { [weak self] in
            self?.phase = .gettingInBed
            self?.phaseTimer = 0
            self?.getInBed()
        }
    }
    
    private func getInBed() {
        guard let goose = sceneView?.gooseNode as? GooseNode else {
            startSleeping()
            return
        }
        
        // Stop walking, lie down
        goose.stopWalkAnimation()
        
        // Rotate to lie down (tilt forward)
        let lieDown = SCNAction.rotateTo(x: -.pi / 6, y: 0, z: 0, duration: 0.5)
        lieDown.timingMode = .easeOut
        
        goose.runAction(lieDown) { [weak self] in
            self?.startSleeping()
        }
        
        controller?.honk()  // Sleepy honk
    }
    
    private func startSleeping() {
        phase = .sleeping
        phaseTimer = 0
        
        // Mark as sleeping
        controller?.enterApartmentMode()
        
        if let goose = sceneView?.gooseNode as? GooseNode {
            goose.playSleepAnimation()
        }
        
        NSLog("😴 Goose is sleeping on the bed")
    }
    
    func update(deltaTime: CGFloat) {
        phaseTimer += TimeInterval(deltaTime)
        
        switch phase {
        case .walkingToEdge, .draggingBedIn, .walkingToBed, .gettingInBed:
            // Animations handle these phases
            break
            
        case .sleeping:
            // Zzz... just sleeping peacefully
            break
            
        case .wakingUp:
            // Wait for wake animation
            if phaseTimer > 1.0 {
                pushBedOut()
            }
            
        case .pushingBedOut:
            // Waiting for bed to slide out
            if phaseTimer > 2.0 {
                controller?.exitApartmentMode()
                controller?.requestStateTransition(to: .wandering)
            }
        }
    }
    
    private func pushBedOut() {
        phase = .pushingBedOut
        phaseTimer = 0
        
        guard let bedNode = bedNode else {
            controller?.exitApartmentMode()
            controller?.requestStateTransition(to: .wandering)
            return
        }
        
        // Slide bed back out
        let screenBounds = controller?.screenManager.primaryScreenBounds ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let exitX: CGFloat = bedFromLeft ? -300 : screenBounds.maxX + 300
        
        let slideOut = SCNAction.move(to: SCNVector3(exitX, bedNode.position.y, 10), duration: 1.5)
        slideOut.timingMode = .easeIn
        
        let remove = SCNAction.removeFromParentNode()
        
        bedNode.runAction(SCNAction.sequence([slideOut, remove])) { [weak self] in
            self?.bedNode = nil
        }
        
        // Goose hops off and walks away
        if let gooseNode = sceneView?.gooseNode, let goose = gooseNode as? GooseNode {
            // Stand up
            let standUp = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)
            gooseNode.runAction(standUp)
            
            goose.playHopAnimation()
            
            // Walk back to original position
            let walkBack = SCNAction.move(to: savedGoosePosition, duration: 1.5)
            walkBack.timingMode = .easeInEaseOut
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                goose.startWalkAnimation()
                gooseNode.runAction(walkBack) {
                    goose.stopWalkAnimation()
                }
            }
        }
        
        NSLog("🛏️ Goose is pushing the bed away!")
    }
    
    func exit() {
        // Clean up bed if still present
        bedNode?.removeFromParentNode()
        bedNode = nil
        
        // Stop sleep animations
        if let goose = sceneView?.gooseNode as? GooseNode {
            goose.stopSleepAnimation()
            // Reset rotation
            let reset = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2)
            goose.runAction(reset)
        }
    }
    
    /// Called when mouse moves - wake up!
    func wakeUp() {
        guard phase == .sleeping else { return }
        
        NSLog("🦆 Goose waking up!")
        phase = .wakingUp
        phaseTimer = 0
        
        // Wake up animation
        if let goose = sceneView?.gooseNode as? GooseNode {
            goose.stopSleepAnimation()
            goose.playHopAnimation()
        }
        controller?.honk()
    }
    
    func canTransitionTo(_ state: GooseState) -> Bool {
        return phase == .sleeping || phase == .wakingUp || phase == .pushingBedOut
    }
}
