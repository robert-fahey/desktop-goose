import Cocoa
import SceneKit

class GooseSceneView: SCNView {
    
    let gooseScene: SCNScene
    let cameraNode: SCNNode
    
    /// Callback when the goose is clicked
    var onGooseClicked: (() -> Void)?
    
    /// Callback when a ball is picked up (returns the ball node)
    var onBallPickedUp: ((DesktopObject) -> Void)?
    
    /// Callback when a ball is thrown (ball, throw velocity)
    var onBallThrown: ((DesktopObject, CGPoint) -> Void)?
    
    /// Callback when goose is picked up
    var onGoosePickedUp: (() -> Void)?
    
    /// Callback when goose is placed (position)
    var onGoosePlaced: ((CGPoint) -> Void)?
    
    /// Callback when furniture is moved (object, new position)
    var onFurnitureMoved: ((DesktopObject, CGPoint) -> Void)?
    
    /// Reference to the goose node for hit testing
    weak var gooseNode: SCNNode?
    
    /// All desktop objects for hit testing
    var desktopObjects: [DesktopObject] = []
    
    /// Currently dragged ball
    private var draggedBall: DesktopObject?
    
    /// Whether we're dragging the goose
    private var isDraggingGoose: Bool = false
    
    private var lastMousePosition: CGPoint = .zero
    private var mouseVelocity: CGPoint = .zero
    private var lastMouseTime: TimeInterval = 0
    
    /// Event monitors
    private var mouseDownMonitor: Any?
    private var mouseDragMonitor: Any?
    private var mouseUpMonitor: Any?
    
    override init(frame: NSRect, options: [String: Any]? = nil) {
        // Create the scene
        gooseScene = SCNScene()
        
        // IMPORTANT: Set scene background to transparent
        gooseScene.background.contents = NSColor.clear
        
        // Set up orthographic camera for 2.5D desktop feel
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = frame.height / 2
        camera.zNear = 0.1
        camera.zFar = 2000
        
        cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: frame.width / 2, y: frame.height / 2, z: 500)
        cameraNode.look(at: SCNVector3(x: frame.width / 2, y: frame.height / 2, z: 0))
        
        gooseScene.rootNode.addChildNode(cameraNode)
        
        // Add ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 800
        ambientLight.light?.color = NSColor.white
        gooseScene.rootNode.addChildNode(ambientLight)
        
        // Add directional light
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.intensity = 1000
        directionalLight.light?.color = NSColor.white
        directionalLight.position = SCNVector3(x: 100, y: 200, z: 300)
        directionalLight.look(at: SCNVector3Zero)
        gooseScene.rootNode.addChildNode(directionalLight)
        
        super.init(frame: frame, options: options)
        
        // Configure view for transparency
        self.backgroundColor = .clear
        self.allowsCameraControl = false
        self.autoenablesDefaultLighting = true
        self.scene = gooseScene
        
        // Rendering settings
        self.antialiasingMode = .multisampling4X
        self.preferredFramesPerSecond = 60
        
        // Make the view layer-backed for transparency
        self.wantsLayer = true
        self.layer?.isOpaque = false
        self.layer?.backgroundColor = CGColor.clear
        
        // Enable scene rendering
        self.isPlaying = true
        
        // Set up mouse monitoring
        setupMouseMonitors()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let monitor = mouseDownMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = mouseDragMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = mouseUpMonitor { NSEvent.removeMonitor(monitor) }
    }
    
    // MARK: - Mouse Monitoring
    
    private func setupMouseMonitors() {
        // Mouse down - check for goose or ball click
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleMouseDown(event)
        }
        
        // Mouse drag - move ball if dragging
        mouseDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            self?.handleMouseDragged(event)
        }
        
        // Mouse up - throw ball if dragging
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.handleMouseUp(event)
        }
    }
    
    private func getViewLocation(from event: NSEvent) -> CGPoint? {
        guard let window = self.window else { return nil }
        let screenLocation = NSEvent.mouseLocation
        let windowLocation = window.convertPoint(fromScreen: screenLocation)
        let viewLocation = self.convert(windowLocation, from: nil)
        guard self.bounds.contains(viewLocation) else { return nil }
        return viewLocation
    }
    
    private func handleMouseDown(_ event: NSEvent) {
        guard let viewLocation = getViewLocation(from: event) else { return }
        
        // Perform SceneKit hit test
        let hitResults = self.hitTest(viewLocation, options: [
            .searchMode: SCNHitTestSearchMode.all.rawValue,
            .ignoreHiddenNodes: true,
            .boundingBoxOnly: false
        ])
        
        // Check if we hit the goose - start dragging!
        if hitResults.contains(where: { isPartOfGoose($0.node) }) {
            isDraggingGoose = true
            lastMousePosition = viewLocation
            lastMouseTime = event.timestamp
            mouseVelocity = .zero
            onGoosePickedUp?()
            return
        }
        
        // Check if we hit a ball
        for result in hitResults {
            if let ball = findBallForNode(result.node) {
                // Start dragging the ball
                draggedBall = ball
                lastMousePosition = viewLocation
                lastMouseTime = event.timestamp
                mouseVelocity = .zero
                ball.velocity = .zero  // Stop the ball
                onBallPickedUp?(ball)
                return
            }
        }
    }
    
    private func handleMouseDragged(_ event: NSEvent) {
        guard let viewLocation = getViewLocation(from: event) else { return }
        
        // Calculate velocity from mouse movement
        let currentTime = event.timestamp
        let dt = currentTime - lastMouseTime
        
        let dx = viewLocation.x - lastMousePosition.x
        let dy = viewLocation.y - lastMousePosition.y
        
        // Handle goose dragging
        if isDraggingGoose, let goose = gooseNode {
            goose.position.x += dx
            goose.position.y += dy
            
            lastMousePosition = viewLocation
            lastMouseTime = currentTime
            return
        }
        
        guard let ball = draggedBall else { return }
        
        if dt > 0 {
            mouseVelocity = CGPoint(
                x: dx / CGFloat(dt),
                y: dy / CGFloat(dt)
            )
        }
        
        // Move ball to mouse position
        ball.position.x = viewLocation.x
        ball.position.y = viewLocation.y
        
        // Rotate non-throwable objects (like plants) based on movement
        if !ball.isThrowable {
            let speed = sqrt(mouseVelocity.x * mouseVelocity.x + mouseVelocity.y * mouseVelocity.y)
            ball.rotateTowardMovement(dx: dx, dy: dy, speed: speed)
        }
        
        lastMousePosition = viewLocation
        lastMouseTime = currentTime
    }
    
    private func handleMouseUp(_ event: NSEvent) {
        // Handle goose being placed
        if isDraggingGoose, let goose = gooseNode {
            isDraggingGoose = false
            let placedPosition = CGPoint(x: goose.position.x, y: goose.position.y)
            onGoosePlaced?(placedPosition)
            return
        }
        
        guard let ball = draggedBall else { return }
        
        // Only throw if the object is throwable
        if ball.isThrowable {
            // Throw the ball with mouse velocity
            let throwMultiplier: CGFloat = 0.5  // Adjust throw power
            let throwVelocity = CGPoint(
                x: mouseVelocity.x * throwMultiplier,
                y: mouseVelocity.y * throwMultiplier
            )
            
            ball.velocity = throwVelocity
            onBallThrown?(ball, throwVelocity)
            
            // Reset rotation if this object has that flag set
            if ball.resetsRotation {
                ball.resetRotation()
            }
        } else {
            // Non-throwable objects (furniture) - reset rotation to upright when user places them
            ball.resetRotation()
            
            // Add wobble effect when placed
            ball.applySpin(mouseVelocity: mouseVelocity)
            
            // If it was knocked over, stand it back up
            if ball.isKnockedOver {
                ball.standUp()
            }
            
            // Notify that furniture was moved
            let newPosition = CGPoint(x: ball.position.x, y: ball.position.y)
            onFurnitureMoved?(ball, newPosition)
        }
        
        draggedBall = nil
        mouseVelocity = .zero
    }
    
    /// Find the DesktopObject that contains this node
    private func findBallForNode(_ node: SCNNode) -> DesktopObject? {
        var currentNode: SCNNode? = node
        while let n = currentNode {
            if let ball = n as? DesktopObject {
                return ball
            }
            if desktopObjects.contains(where: { $0 === n }) {
                return n as? DesktopObject
            }
            currentNode = n.parent
        }
        // Also check if any parent is a DesktopObject
        currentNode = node
        while let n = currentNode {
            for obj in desktopObjects {
                if n === obj || isDescendant(of: obj, node: n) {
                    return obj
                }
            }
            currentNode = n.parent
        }
        return nil
    }
    
    private func isDescendant(of parent: SCNNode, node: SCNNode) -> Bool {
        var current: SCNNode? = node
        while let n = current {
            if n === parent { return true }
            current = n.parent
        }
        return false
    }
    
    /// Check if a node is part of the goose hierarchy
    private func isPartOfGoose(_ node: SCNNode) -> Bool {
        var currentNode: SCNNode? = node
        while let n = currentNode {
            if n === gooseNode {
                return true
            }
            currentNode = n.parent
        }
        return false
    }
    
    // MARK: - Coordinate Conversion
    
    func screenToScene(_ point: CGPoint) -> SCNVector3 {
        return SCNVector3(x: point.x, y: point.y, z: 0)
    }
    
    func sceneToScreen(_ point: SCNVector3) -> CGPoint {
        return CGPoint(x: point.x, y: point.y)
    }
}
