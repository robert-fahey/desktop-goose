import SceneKit
import Cocoa

class GooseController {
    
    // Scene components
    private weak var sceneView: GooseSceneView?
    private let gooseNode: GooseNode
    private let screenManager: ScreenManager
    
    // State machine for behaviors
    private var behaviorStateMachine: BehaviorStateMachine!
    
    // Update timer
    private var displayLink: CVDisplayLink?
    private var updateTimer: Timer?
    
    // Goose state
    var isPaused = false {
        didSet {
            if isPaused {
                gooseNode.stopWalkAnimation()
            }
        }
    }
    
    // Position and movement
    var position: CGPoint {
        get { CGPoint(x: gooseNode.position.x, y: gooseNode.position.y) }
        set { 
            gooseNode.position.x = newValue.x
            gooseNode.position.y = newValue.y
        }
    }
    
    var targetPosition: CGPoint?
    var moveSpeed: CGFloat = 150.0 // pixels per second
    
    init(sceneView: GooseSceneView, screenManager: ScreenManager) {
        self.sceneView = sceneView
        self.screenManager = screenManager
        self.gooseNode = GooseNode()
        
        // Add goose to scene
        sceneView.gooseScene.rootNode.addChildNode(gooseNode)
        
        // Position goose in center of screen initially
        let screenBounds = screenManager.primaryScreenBounds
        gooseNode.position = SCNVector3(
            x: screenBounds.midX,
            y: screenBounds.midY,
            z: 0
        )
        
        // Initialize behavior state machine
        setupBehaviors()
    }
    
    private func setupBehaviors() {
        let wanderBehavior = WanderBehavior(controller: self, screenManager: screenManager)
        let honkBehavior = HonkBehavior(controller: self, gooseNode: gooseNode)
        let cursorGrabBehavior = CursorGrabBehavior(controller: self)
        let memeDragBehavior = MemeDragBehavior(controller: self, sceneView: sceneView)
        
        // Window observer for perching
        let windowObserver = WindowObserver()
        let windowPerchBehavior = WindowPerchBehavior(controller: self, windowObserver: windowObserver)
        
        behaviorStateMachine = BehaviorStateMachine(
            controller: self,
            behaviors: [
                .wandering: wanderBehavior,
                .honking: honkBehavior,
                .grabbingCursor: cursorGrabBehavior,
                .draggingMeme: memeDragBehavior,
                .perchingOnWindow: windowPerchBehavior
            ]
        )
    }
    
    func start() {
        // Use a timer for updates (simpler than CVDisplayLink for this use case)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.update()
        }
        
        // Start with wandering behavior
        behaviorStateMachine.transitionTo(.wandering)
    }
    
    func stop() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    func updateSceneView(_ newSceneView: GooseSceneView) {
        // Remove from old scene
        gooseNode.removeFromParentNode()
        
        // Add to new scene
        newSceneView.gooseScene.rootNode.addChildNode(gooseNode)
    }
    
    private func update() {
        guard !isPaused else { return }
        
        let deltaTime: CGFloat = 1.0 / 60.0
        
        // Update movement toward target
        if let target = targetPosition {
            moveTowardTarget(target, deltaTime: deltaTime)
        }
        
        // Update behavior state machine
        behaviorStateMachine.update(deltaTime: deltaTime)
    }
    
    private func moveTowardTarget(_ target: CGPoint, deltaTime: CGFloat) {
        let current = position
        let dx = target.x - current.x
        let dy = target.y - current.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance < 5 {
            // Reached target
            targetPosition = nil
            gooseNode.stopWalkAnimation()
            return
        }
        
        // Calculate movement
        let moveDistance = min(moveSpeed * deltaTime, distance)
        let ratio = moveDistance / distance
        
        position = CGPoint(
            x: current.x + dx * ratio,
            y: current.y + dy * ratio
        )
        
        // Update facing direction
        let angle = atan2(dy, dx)
        gooseNode.facingDirection = angle - .pi / 2 // Adjust for model orientation
        
        // Start walking animation if not already
        gooseNode.startWalkAnimation()
    }
    
    // MARK: - Public API for behaviors
    
    func moveTo(_ target: CGPoint) {
        targetPosition = target
    }
    
    func stopMoving() {
        targetPosition = nil
        gooseNode.stopWalkAnimation()
    }
    
    func honk() {
        gooseNode.playHonkAnimation()
    }
    
    func playIdleAnimation() {
        gooseNode.playIdleAnimation()
    }
    
    func stopIdleAnimation() {
        gooseNode.stopIdleAnimation()
    }
    
    var isMoving: Bool {
        targetPosition != nil
    }
    
    var currentState: GooseState {
        behaviorStateMachine.currentState
    }
    
    func requestStateTransition(to state: GooseState) {
        behaviorStateMachine.transitionTo(state)
    }
}

