import SceneKit
import Cocoa
import AVFoundation

class GooseController {
    
    // Scene components
    private weak var sceneView: GooseSceneView?
    let gooseNode: GooseNode
    let screenManager: ScreenManager
    
    // Object manager for interactive objects
    private var objectManager: ObjectManager?
    
    // State machine for behaviors
    private var behaviorStateMachine: BehaviorStateMachine!
    
    // Update timer
    private var displayLink: CVDisplayLink?
    private var updateTimer: Timer?
    
    // Audio for honking
    private var honkPlayer: AVAudioPlayer?
    private var honkSoundURL: URL?
    
    // Sleep tracking
    private var lastMousePosition: CGPoint = .zero
    private var mouseIdleTime: TimeInterval = 0
    private let sleepAfterIdleTime: TimeInterval = 120  // 10 seconds for testing (change to 120 for 2 minutes)
    private var isSleeping: Bool = false
    private var mouseMonitor: Any?
    private var sleepBehavior: SleepBehavior?
    private var furnitureMoveBehavior: FurnitureMoveBehavior?
    private var mouseChaseBehavior: MouseChaseBehavior?
    private var playWithBallBehavior: PlayWithBallBehavior?
    private var poopBehavior: PoopBehavior?
    private var watchTVBehavior: WatchTVBehavior?
    private var fleeFromDroidBehavior: FleeFromDroidBehavior?
    private var plantChaosBehavior: PlantChaosBehavior?
    
    // Poops on the screen
    private var poops: [Poop] = []
    private var lastPoopTime: Date = Date()
    private let minPoopInterval: TimeInterval = 60.0  // At least one poop per minute
    
    // TV watching timer
    private var lastTVWatchTime: Date = Date()
    private let tvWatchInterval: TimeInterval = 600.0  // Watch TV every 10 minutes
    
    // Interaction tracking for attention-seeking behavior
    private var lastInteractionTime: Date = Date()
    private let attentionSeekingTimeout: TimeInterval = 60.0  // 1 minute
    
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
        
        // Set goose reference for hit testing
        sceneView.gooseNode = gooseNode
        
        // Set up goose pick up/place handlers
        sceneView.onGoosePickedUp = { [weak self] in
            self?.handleGoosePickedUp()
        }
        sceneView.onGoosePlaced = { [weak self] position in
            self?.handleGoosePlaced(at: position)
        }
        
        // Set up furniture move handler
        sceneView.onFurnitureMoved = { [weak self] object, position in
            self?.reactToFurnitureMoved(object)
        }
        
        // Position goose in center of screen initially
        let screenBounds = screenManager.primaryScreenBounds
        gooseNode.position = SCNVector3(
            x: screenBounds.midX,
            y: screenBounds.midY,
            z: 0
        )
        
        // Initialize object manager and spawn some objects
        objectManager = ObjectManager(sceneView: sceneView, screenManager: screenManager)
        spawnInitialObjects()
        
        // Set up droid spawn callback
        objectManager?.onDroidSpawned = { [weak self] droid in
            self?.handleDroidSpawned(droid)
        }
        
        // Load honk sound
        honkSoundURL = Bundle.main.url(forResource: "honk", withExtension: "mp3")
        
        // Initialize behavior state machine
        setupBehaviors()
        
        // Start tracking mouse movement for sleep
        setupMouseTracking()
    }
    
    deinit {
        // Clean up mouse monitor to prevent memory leak
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Invalidate timers
        panicHonkTimer?.invalidate()
        updateTimer?.invalidate()
    }
    
    private func setupMouseTracking() {
        lastMousePosition = NSEvent.mouseLocation
        
        // Monitor mouse movement
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            self?.handleMouseMoved()
        }
    }
    
    private func handleMouseMoved() {
        let currentPos = NSEvent.mouseLocation
        let dx = currentPos.x - lastMousePosition.x
        let dy = currentPos.y - lastMousePosition.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance > 5 {
            // Mouse moved significantly
            lastMousePosition = currentPos
            mouseIdleTime = 0
            
            // Wake up if sleeping
            if isSleeping {
                wakeUp()
            }
        }
    }
    
    private func spawnInitialObjects() {
        // Spawn pool ball and football
        if Preferences.shared.enableBalls {
            objectManager?.spawnPoolBall()
            objectManager?.spawnFootball()
        }
        
        // Spawn all 4 plants in corners
        if Preferences.shared.enablePlants {
            objectManager?.spawnAllPlants()
        }
        
        // Spawn furniture
        if Preferences.shared.enableFurniture {
            objectManager?.spawnCouch()
            objectManager?.spawnTV()
            objectManager?.spawnBox()
        }
        
        // Set up ball interaction - goose chases thrown balls
        objectManager?.setupBallInteraction()
        objectManager?.onBallThrown = { [weak self] ball in
            self?.resetInteractionTime()  // User is interacting!
            // Goose gets excited and chases the ball!
            self?.startChasingBall()
        }
    }
    
    /// Start chasing a thrown ball
    private func startChasingBall() {
        // Interrupt current behavior to chase the ball
        behaviorStateMachine.transitionTo(.chasingBall)
    }
    
    /// Get the current chase target (thrown ball position)
    func getChaseBallTarget() -> CGPoint? {
        return objectManager?.getThrownBallPosition()
    }
    
    /// Stop the ball the goose is chasing
    func stopBall() {
        objectManager?.stopThrownBall()
    }
    
    /// Throw the ball back with given velocity
    func throwBallBack(velocity: CGPoint) {
        objectManager?.throwBallBack(velocity: velocity)
    }
    
    /// Get a hiding spot (behind plant) for sleeping
    func getHidingSpot() -> CGPoint? {
        return objectManager?.getRandomHidingSpot()
    }
    
    /// Get the plant position (for aiming the ball)
    func getPlantPosition() -> CGPoint? {
        return objectManager?.getPlantPosition()
    }
    
    /// Get a hiding spot behind the couch
    func getCouchHidingSpot() -> CGPoint? {
        return objectManager?.getCouchPosition()
    }
    
    /// Get a random piece of furniture to move
    func getRandomFurniture() -> DesktopObject? {
        return objectManager?.getRandomFurniture()
    }
    
    /// React to user moving furniture
    func reactToFurnitureMoved(_ object: DesktopObject) {
        resetInteractionTime()
        
        // 50% chance to go "fix" the furniture
        if CGFloat.random(in: 0...1) < 0.5 {
            furnitureMoveBehavior?.setTargetObject(object)
            requestStateTransition(to: .movingFurniture)
        }
    }
    
    /// Reset the interaction timer (called when user interacts with goose or objects)
    func resetInteractionTime() {
        lastInteractionTime = Date()
    }
    
    /// Get the position of a ball to play with
    func getBallPosition() -> CGPoint? {
        return objectManager?.getAnyBallPosition()
    }
    
    /// Kick a ball with the given velocity
    func kickBall(velocity: CGPoint) {
        objectManager?.kickBall(velocity: velocity)
    }
    
    /// Get the droid (for flee behavior)
    func getDroid() -> Droid? {
        return objectManager?.getDroid()
    }
    
    /// Get clustered plants (for plant chaos behavior)
    func getClusteredPlants() -> [DesktopObject]? {
        return objectManager?.getPlantsClusteredTogether()
    }
    
    /// Get the center of a plant cluster
    func getPlantClusterCenter() -> CGPoint? {
        return objectManager?.getPlantClusterCenter()
    }
    
    /// Knock over all clustered plants
    func knockOverClusteredPlants(from direction: CGPoint) {
        objectManager?.knockOverClusteredPlants(from: direction)
    }
    
    /// Handle when droid spawns - goose should flee!
    private func handleDroidSpawned(_ droid: Droid) {
        NSLog("🦆😱 Droid spotted! Goose is fleeing!")
        honk()  // Panic honk!
        requestStateTransition(to: .fleeingFromDroid)
    }
    
    /// Get the TV position
    func getTVPosition() -> CGPoint? {
        return objectManager?.getTVPosition()
    }
    
    /// Drop a poop at the given position
    func dropPoop(at position: CGPoint) {
        let poop = Poop()
        poop.position = SCNVector3(x: position.x, y: position.y - 20, z: -20)  // Behind goose, slightly offset
        
        sceneView?.gooseScene.rootNode.addChildNode(poop)
        poops.append(poop)
        
        // Reset the poop timer
        lastPoopTime = Date()
        
        NSLog("💩 Poop dropped! Total poops: \(poops.count)")
    }
    
    // MARK: - Goose Pickup
    
    private var isBeingCarried: Bool = false
    
    private func handleGoosePickedUp() {
        resetInteractionTime()  // User is interacting!
        isBeingCarried = true
        isPaused = true  // Pause behavior while being carried
        
        // Panic! Legs flailing, honking!
        gooseNode.playPanicAnimation()
        honk()
        
        // Keep honking while being carried
        startPanicHonking()
    }
    
    private var panicHonkTimer: Timer?
    
    private func startPanicHonking() {
        panicHonkTimer?.invalidate()
        panicHonkTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            guard let self = self, self.isBeingCarried else {
                self?.panicHonkTimer?.invalidate()
                return
            }
            self.honk()
        }
    }
    
    private func handleGoosePlaced(at position: CGPoint) {
        isBeingCarried = false
        isPaused = false
        panicHonkTimer?.invalidate()
        panicHonkTimer = nil
        
        // Stop panicking
        gooseNode.stopPanicAnimation()
        
        // Check if placed on couch
        if let couchPos = objectManager?.getCouchPosition() {
            let dx = position.x - couchPos.x
            let dy = position.y - couchPos.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance < 80 {  // Near the couch
                // Snap to couch and sit!
                gooseNode.position.x = couchPos.x
                gooseNode.position.y = couchPos.y
                gooseNode.playIdleAnimation()
                NSLog("🛋️ Goose placed on couch!")
                return
            }
        }
        
        // Otherwise just resume normal behavior
        gooseNode.playIdleAnimation()
    }
    
    // MARK: - Sleep
    
    private func goToSleep() {
        requestStateTransition(to: .sleeping)
    }
    
    private func wakeUp() {
        if isSleeping {
            sleepBehavior?.wakeUp()
        }
        mouseIdleTime = 0
    }
    
    func startSleeping() {
        isSleeping = true
        gooseNode.playSleepAnimation()
    }
    
    func stopSleeping() {
        isSleeping = false
        gooseNode.stopSleepAnimation()
    }
    
    /// Enter apartment mode (goose walks around in apartment, but can be woken by mouse)
    func enterApartmentMode() {
        isSleeping = true  // So mouse movement can wake us
    }
    
    /// Exit apartment mode
    func exitApartmentMode() {
        isSleeping = false
    }
    
    private func setupBehaviors() {
        let wanderBehavior = WanderBehavior(controller: self, screenManager: screenManager)
        let honkBehavior = HonkBehavior(controller: self, gooseNode: gooseNode)
        let cursorGrabBehavior = CursorGrabBehavior(controller: self)
        let memeDragBehavior = MemeDragBehavior(controller: self, sceneView: sceneView)
        let chaseBallBehavior = ChaseBallBehavior(controller: self)
        sleepBehavior = SleepBehavior(controller: self)
        sleepBehavior?.setSceneView(sceneView)
        
        furnitureMoveBehavior = FurnitureMoveBehavior(controller: self)
        mouseChaseBehavior = MouseChaseBehavior(controller: self)
        playWithBallBehavior = PlayWithBallBehavior(controller: self)
        poopBehavior = PoopBehavior(controller: self)
        watchTVBehavior = WatchTVBehavior(controller: self)
        fleeFromDroidBehavior = FleeFromDroidBehavior(controller: self)
        plantChaosBehavior = PlantChaosBehavior(controller: self)
        
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
                .perchingOnWindow: windowPerchBehavior,
                .chasingBall: chaseBallBehavior,
                .sleeping: sleepBehavior!,
                .movingFurniture: furnitureMoveBehavior!,
                .chasingMouse: mouseChaseBehavior!,
                .playingWithBall: playWithBallBehavior!,
                .pooping: poopBehavior!,
                .watchingTV: watchTVBehavior!,
                .fleeingFromDroid: fleeFromDroidBehavior!,
                .plantChaos: plantChaosBehavior!
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
    
    // Track velocity for object pushing
    private var lastPosition: CGPoint = .zero
    private var currentVelocity: CGPoint = .zero
    
    private func update() {
        guard !isPaused else { return }
        
        let deltaTime: CGFloat = 1.0 / 60.0
        
        // Track mouse idle time
        mouseIdleTime += TimeInterval(deltaTime)
        
        // Check if goose should seek attention (no interaction for 1 minute)
        let timeSinceInteraction = Date().timeIntervalSince(lastInteractionTime)
        if timeSinceInteraction >= attentionSeekingTimeout && 
           currentState != .chasingMouse && 
           currentState != .sleeping &&
           !isSleeping {
            // Chase the mouse for attention!
            requestStateTransition(to: .chasingMouse)
            lastInteractionTime = Date()  // Reset so it doesn't keep triggering
        }
        
        // Check if goose needs to poop (at least once per minute)
        let timeSincePoop = Date().timeIntervalSince(lastPoopTime)
        if timeSincePoop >= minPoopInterval && 
           currentState != .pooping && 
           currentState != .sleeping &&
           !isBeingCarried {
            requestStateTransition(to: .pooping)
        }
        
        // Check if goose should watch TV (every 10 minutes)
        let timeSinceTVWatch = Date().timeIntervalSince(lastTVWatchTime)
        if timeSinceTVWatch >= tvWatchInterval && 
           currentState != .watchingTV && 
           currentState != .sleeping &&
           !isBeingCarried {
            requestStateTransition(to: .watchingTV)
            lastTVWatchTime = Date()
        }
        
        // Check if should go to sleep
        // Don't sleep if droid is active or goose is fleeing
        let droidActive = objectManager?.getDroid()?.isActive ?? false
        if !isSleeping && mouseIdleTime >= sleepAfterIdleTime && currentState != .sleeping &&
           !droidActive && currentState != .fleeingFromDroid {
            goToSleep()
        }
        
        // Calculate velocity from position change
        let currentPos = position
        currentVelocity = CGPoint(
            x: (currentPos.x - lastPosition.x) / deltaTime,
            y: (currentPos.y - lastPosition.y) / deltaTime
        )
        lastPosition = currentPos
        
        // Update movement toward target
        if let target = targetPosition {
            moveTowardTarget(target, deltaTime: deltaTime)
        }
        
        // Update behavior state machine
        behaviorStateMachine.update(deltaTime: deltaTime)
        
        // Update interactive objects
        objectManager?.update(deltaTime: deltaTime, goosePosition: position, gooseVelocity: currentVelocity)
        
        // Check for ball-poop collisions
        checkBallPoopCollisions()
    }
    
    /// Check if any balls are hitting poops and smear them
    private func checkBallPoopCollisions() {
        guard let ballPos = objectManager?.getAnyBallPosition(),
              let ballVelocity = objectManager?.getBallVelocity() else { return }
        
        let ballSpeed = sqrt(ballVelocity.x * ballVelocity.x + ballVelocity.y * ballVelocity.y)
        
        // Only check if ball is moving
        guard ballSpeed > 20 else { return }
        
        let ballRadius: CGFloat = 25
        
        for poop in poops {
            if poop.checkCollision(with: ballPos, radius: ballRadius) {
                // Normalize velocity for direction
                let direction = CGPoint(
                    x: ballVelocity.x / ballSpeed,
                    y: ballVelocity.y / ballSpeed
                )
                poop.smear(direction: direction, force: ballSpeed)
            }
        }
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
        playHonkSound()
    }
    
    private func playHonkSound() {
        guard let url = honkSoundURL else { return }
        do {
            honkPlayer = try AVAudioPlayer(contentsOf: url)
            honkPlayer?.volume = 0.7
            honkPlayer?.play()
        } catch {
            // Silently fail if sound can't play
        }
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

