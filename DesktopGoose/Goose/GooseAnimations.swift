import SceneKit

/// Manages loading and playing animations for the goose
class GooseAnimations {
    
    private weak var gooseNode: GooseNode?
    
    // Cached animation players
    private var walkAnimation: SCNAnimationPlayer?
    private var idleAnimation: SCNAnimationPlayer?
    private var honkAnimation: SCNAnimationPlayer?
    private var grabAnimation: SCNAnimationPlayer?
    
    init(gooseNode: GooseNode) {
        self.gooseNode = gooseNode
        loadAnimations()
    }
    
    private func loadAnimations() {
        // Try to load animations from files
        walkAnimation = loadAnimation(named: "goose_walk")
        idleAnimation = loadAnimation(named: "goose_idle")
        honkAnimation = loadAnimation(named: "goose_honk")
        grabAnimation = loadAnimation(named: "goose_grab")
    }
    
    private func loadAnimation(named name: String) -> SCNAnimationPlayer? {
        // Try different file extensions
        let extensions = ["scn", "dae", "usdz"]
        
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let sceneSource = SCNSceneSource(url: url, options: nil) {
                
                // Get animation identifiers
                let animationIds = sceneSource.identifiersOfEntries(withClass: CAAnimation.self)
                
                if let animationId = animationIds.first,
                   let animation = sceneSource.entryWithIdentifier(animationId, withClass: CAAnimation.self) {
                    let scnAnimation = SCNAnimation(caAnimation: animation)
                    return SCNAnimationPlayer(animation: scnAnimation)
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Animation Playback
    
    func playWalk() {
        if let player = walkAnimation {
            gooseNode?.addAnimationPlayer(player, forKey: "walk")
            player.play()
        } else {
            // Use procedural animation fallback
            gooseNode?.startWalkAnimation()
        }
    }
    
    func stopWalk() {
        if walkAnimation != nil {
            gooseNode?.removeAnimation(forKey: "walk")
        } else {
            gooseNode?.stopWalkAnimation()
        }
    }
    
    func playIdle() {
        if let player = idleAnimation {
            gooseNode?.addAnimationPlayer(player, forKey: "idle")
            player.play()
        } else {
            gooseNode?.playIdleAnimation()
        }
    }
    
    func stopIdle() {
        if idleAnimation != nil {
            gooseNode?.removeAnimation(forKey: "idle")
        } else {
            gooseNode?.stopIdleAnimation()
        }
    }
    
    func playHonk() {
        if let player = honkAnimation {
            gooseNode?.addAnimationPlayer(player, forKey: "honk")
            player.play()
        } else {
            gooseNode?.playHonkAnimation()
        }
    }
    
    func playGrab() {
        if let player = grabAnimation {
            gooseNode?.addAnimationPlayer(player, forKey: "grab")
            player.play()
        }
        // No procedural fallback for grab - it's optional
    }
    
    func stopAllAnimations() {
        stopWalk()
        stopIdle()
        gooseNode?.removeAnimation(forKey: "honk")
        gooseNode?.removeAnimation(forKey: "grab")
    }
}

