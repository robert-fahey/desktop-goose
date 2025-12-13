import Foundation

enum GooseState: CaseIterable {
    case idle
    case wandering
    case honking
    case grabbingCursor
    case draggingMeme
    case perchingOnWindow
    case chasingBall
    case sleeping
    case movingFurniture
    case chasingMouse
    case playingWithBall
    case pooping
    case watchingTV
    case fleeingFromDroid
    case plantChaos
    case bowling
    case dodgeball
}

protocol GooseBehavior: AnyObject {
    var minimumDuration: TimeInterval { get }
    var maximumDuration: TimeInterval { get }
    var weight: Double { get }
    var cooldown: TimeInterval { get }
    
    func enter()
    func update(deltaTime: CGFloat)
    func exit()
    func canTransitionTo(_ state: GooseState) -> Bool
}

// Default implementations
extension GooseBehavior {
    var cooldown: TimeInterval { 5.0 }
    
    func canTransitionTo(_ state: GooseState) -> Bool {
        return true
    }
}

class BehaviorStateMachine {
    
    private(set) var currentState: GooseState = .idle
    private var currentBehavior: GooseBehavior?
    
    private weak var controller: GooseController?
    private let behaviors: [GooseState: GooseBehavior]
    
    // Timing
    private var stateStartTime: Date = Date()
    private var stateDuration: TimeInterval = 0
    private var lastTransitionTimes: [GooseState: Date] = [:]
    
    // Chaos level affects behavior frequency (0.0 - 1.0)
    var chaosLevel: Double = 0.7
    
    init(controller: GooseController, behaviors: [GooseState: GooseBehavior]) {
        self.controller = controller
        self.behaviors = behaviors
    }
    
    func transitionTo(_ newState: GooseState) {
        guard newState != currentState else { return }
        guard let newBehavior = behaviors[newState] else { return }
        
        // Check cooldown
        if let lastTime = lastTransitionTimes[newState] {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < newBehavior.cooldown {
                return // Still on cooldown
            }
        }
        
        // Check if current behavior allows transition
        if let current = currentBehavior, !current.canTransitionTo(newState) {
            return
        }
        
        // Exit current behavior
        currentBehavior?.exit()
        
        // Update state
        lastTransitionTimes[currentState] = Date()
        currentState = newState
        currentBehavior = newBehavior
        stateStartTime = Date()
        
        // Determine how long to stay in this state
        let minDuration = newBehavior.minimumDuration
        let maxDuration = newBehavior.maximumDuration
        stateDuration = Double.random(in: minDuration...maxDuration)
        
        // Enter new behavior
        newBehavior.enter()
    }
    
    func update(deltaTime: CGFloat) {
        // Update current behavior
        currentBehavior?.update(deltaTime: deltaTime)
        
        // Check if it's time to transition
        let elapsed = Date().timeIntervalSince(stateStartTime)
        if elapsed >= stateDuration {
            selectNextState()
        }
    }
    
    private func selectNextState() {
        // Calculate weights for each possible state
        var candidates: [(state: GooseState, weight: Double)] = []
        
        for (state, behavior) in behaviors {
            guard state != currentState else { continue }
            
            // Check cooldown
            if let lastTime = lastTransitionTimes[state] {
                let elapsed = Date().timeIntervalSince(lastTime)
                if elapsed < behavior.cooldown {
                    continue
                }
            }
            
            // Check if transition is allowed
            if let current = currentBehavior, !current.canTransitionTo(state) {
                continue
            }
            
            // Adjust weight based on chaos level
            var weight = behavior.weight
            
            // Chaos behaviors get boosted by chaos level
            switch state {
            case .grabbingCursor, .draggingMeme:
                weight *= chaosLevel * 2
            case .honking:
                weight *= 0.5 + chaosLevel
            case .wandering:
                weight *= 1.0 // Base wandering
            case .perchingOnWindow:
                weight *= 0.8 + chaosLevel * 0.5
            case .idle:
                weight *= 1.0 - chaosLevel * 0.5 // Less idle when chaotic
            case .chasingBall:
                weight = 0 // Not randomly selected, only triggered explicitly
            case .sleeping:
                weight = 0 // Not randomly selected, only triggered by idle timeout
            case .movingFurniture:
                weight *= 0.5 + chaosLevel  // More likely when chaotic
            case .chasingMouse:
                weight = 0  // Not randomly selected, triggered by idle timeout
            case .playingWithBall:
                weight *= 1.0 + chaosLevel  // More likely when chaotic
            case .pooping:
                weight *= 0.8  // Natural behavior
            case .watchingTV:
                weight *= 1.0  // Regular chance
            case .fleeingFromDroid:
                weight = 0  // Not randomly selected, triggered when droid spawns
            case .plantChaos:
                weight *= 1.0 + chaosLevel  // More likely when chaotic, only triggers if plants clustered
            case .bowling:
                weight *= 1.0  // Regular chance if conditions met
            case .dodgeball:
                weight = 0  // Not randomly selected, triggered when droid spawns
            }
            
            candidates.append((state, weight))
        }
        
        // Weighted random selection
        let totalWeight = candidates.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            transitionTo(.wandering) // Fallback
            return
        }
        
        var random = Double.random(in: 0..<totalWeight)
        for (state, weight) in candidates {
            random -= weight
            if random <= 0 {
                transitionTo(state)
                return
            }
        }
        
        // Fallback
        transitionTo(.wandering)
    }
    
    func forceTransitionTo(_ state: GooseState) {
        // Bypass cooldown and permission checks
        currentBehavior?.exit()
        lastTransitionTimes[currentState] = Date()
        currentState = state
        currentBehavior = behaviors[state]
        stateStartTime = Date()
        
        if let behavior = currentBehavior {
            stateDuration = Double.random(in: behavior.minimumDuration...behavior.maximumDuration)
            behavior.enter()
        }
    }
}


