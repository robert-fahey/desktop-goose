import Foundation
import SceneKit
import Cocoa

class MemeDragBehavior: GooseBehavior {
    
    private weak var controller: GooseController?
    private weak var sceneView: GooseSceneView?
    
    // Behavior configuration
    var minimumDuration: TimeInterval { 5.0 }
    var maximumDuration: TimeInterval { 10.0 }
    var weight: Double { 0.15 }
    var cooldown: TimeInterval { 45.0 }
    
    // Meme node
    private var memeNode: SCNNode?
    private var memeImages: [NSImage] = []
    
    // State
    private enum Phase {
        case pickingUp
        case dragging
        case dropping
    }
    
    private var phase: Phase = .pickingUp
    private var dragTarget: CGPoint = .zero
    
    init(controller: GooseController, sceneView: GooseSceneView?) {
        self.controller = controller
        self.sceneView = sceneView
        loadMemeImages()
    }
    
    private func loadMemeImages() {
        // Try to load meme images from bundle
        let memeNames = ["meme1", "meme2", "meme3", "deal_with_it", "trollface"]
        
        for name in memeNames {
            if let image = NSImage(named: name) {
                memeImages.append(image)
            }
        }
        
        // Create default meme if none found
        if memeImages.isEmpty {
            memeImages.append(createDefaultMeme())
        }
    }
    
    private func createDefaultMeme() -> NSImage {
        // Create a simple "HONK" text meme
        let size = NSSize(width: 200, height: 100)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Background
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        
        // Border
        NSColor.black.setStroke()
        let borderPath = NSBezierPath(rect: NSRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4))
        borderPath.lineWidth = 3
        borderPath.stroke()
        
        // Text
        let text = "HONK!" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 36),
            .foregroundColor: NSColor.black
        ]
        let textSize = text.size(withAttributes: attributes)
        let textPoint = NSPoint(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2
        )
        text.draw(at: textPoint, withAttributes: attributes)
        
        image.unlockFocus()
        
        return image
    }
    
    func enter() {
        phase = .pickingUp
        createMemeNode()
        
        // Pick a random target on screen
        if let screen = NSScreen.main {
            dragTarget = CGPoint(
                x: CGFloat.random(in: 100...(screen.frame.width - 100)),
                y: CGFloat.random(in: 100...(screen.frame.height - 100))
            )
        }
        
        // Start moving toward target
        controller?.moveTo(dragTarget)
    }
    
    func update(deltaTime: CGFloat) {
        guard let controller = controller, let memeNode = memeNode else { return }
        
        switch phase {
        case .pickingUp:
            // Meme follows goose during pickup
            updateMemePosition(behind: controller.position)
            
            if !controller.isMoving {
                phase = .dragging
                // Pick new random target
                if let screen = NSScreen.main {
                    dragTarget = CGPoint(
                        x: CGFloat.random(in: 100...(screen.frame.width - 100)),
                        y: CGFloat.random(in: 100...(screen.frame.height - 100))
                    )
                }
                controller.moveTo(dragTarget)
            }
            
        case .dragging:
            updateMemePosition(behind: controller.position)
            
            if !controller.isMoving {
                phase = .dropping
            }
            
        case .dropping:
            // Leave meme where it is
            break
        }
    }
    
    func exit() {
        // Remove meme after a delay (or leave it for chaos!)
        if let meme = memeNode {
            // Fade out and remove
            let fadeOut = SCNAction.fadeOut(duration: 2.0)
            let remove = SCNAction.removeFromParentNode()
            meme.runAction(SCNAction.sequence([
                SCNAction.wait(duration: 5.0),
                fadeOut,
                remove
            ]))
        }
        memeNode = nil
        phase = .pickingUp
    }
    
    private func createMemeNode() {
        guard let sceneView = sceneView else { return }
        
        guard let image = memeImages.randomElement() else {
            NSLog("⚠️ No meme images available")
            return
        }
        
        // Create a plane with the meme texture
        let plane = SCNPlane(width: 150, height: 100)
        plane.firstMaterial?.diffuse.contents = image
        plane.firstMaterial?.isDoubleSided = true
        
        memeNode = SCNNode(geometry: plane)
        memeNode?.position = SCNVector3(x: 100, y: 100, z: -10) // Behind goose
        
        sceneView.gooseScene.rootNode.addChildNode(memeNode!)
    }
    
    private func updateMemePosition(behind goosePosition: CGPoint) {
        // Position meme slightly behind and below the goose
        memeNode?.position = SCNVector3(
            x: goosePosition.x - 80,
            y: goosePosition.y - 30,
            z: -10
        )
    }
    
    func canTransitionTo(_ state: GooseState) -> Bool {
        // Don't interrupt while actively dragging
        return phase != .dragging
    }
}

