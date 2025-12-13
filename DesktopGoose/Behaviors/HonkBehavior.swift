import Foundation
import AVFoundation
import SceneKit

class HonkBehavior: GooseBehavior {
    
    private weak var controller: GooseController?
    private weak var gooseNode: GooseNode?
    
    // Audio
    private var audioPlayer: AVAudioPlayer?
    private var honkSounds: [URL] = []
    
    // Behavior configuration
    var minimumDuration: TimeInterval { 0.5 }
    var maximumDuration: TimeInterval { 2.0 }
    var weight: Double { 1.5 }
    var cooldown: TimeInterval { 8.0 }
    
    // State
    private var honkCount = 0
    private var maxHonks = 1
    private var honkTimer: TimeInterval = 0
    
    init(controller: GooseController, gooseNode: GooseNode) {
        self.controller = controller
        self.gooseNode = gooseNode
        loadHonkSounds()
    }
    
    private func loadHonkSounds() {
        // Try to load honk sounds from bundle
        if let soundURL = Bundle.main.url(forResource: "honk", withExtension: "mp3") {
            honkSounds.append(soundURL)
        }
        if let soundURL = Bundle.main.url(forResource: "honk2", withExtension: "mp3") {
            honkSounds.append(soundURL)
        }
        
        // If no sounds found, we'll use system sound as fallback
    }
    
    func enter() {
        controller?.stopMoving()
        honkCount = 0
        maxHonks = Int.random(in: 1...3)
        honkTimer = 0
        
        performHonk()
    }
    
    func update(deltaTime: CGFloat) {
        if honkTimer > 0 {
            honkTimer -= TimeInterval(deltaTime)
        } else if honkCount < maxHonks {
            performHonk()
        }
    }
    
    func exit() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    private func performHonk() {
        honkCount += 1
        honkTimer = Double.random(in: 0.3...0.6)
        
        // Play animation
        gooseNode?.playHonkAnimation()
        
        // Play sound
        playHonkSound()
    }
    
    private func playHonkSound() {
        // Try to play from loaded sounds
        if !honkSounds.isEmpty, let soundURL = honkSounds.randomElement() {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.volume = 0.7
                audioPlayer?.play()
                return
            } catch {
                // Fall through to system sound
            }
        }
        
        // Fallback: Use system sound
        NSSound.beep()
    }
}



