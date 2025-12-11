import Cocoa
import SceneKit

class GooseSceneView: SCNView {
    
    let gooseScene: SCNScene
    let cameraNode: SCNNode
    
    override init(frame: NSRect, options: [String: Any]? = nil) {
        // Create the scene
        gooseScene = SCNScene()
        
        // IMPORTANT: Set scene background to transparent
        gooseScene.background.contents = NSColor.clear
        
        // Set up orthographic camera for 2.5D desktop feel
        // orthographicScale determines how many scene units fit in half the view height
        // We want the goose (~80 units) to be reasonable size on screen
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = frame.height / 2  // 1:1 mapping - scene units = screen points
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
        self.autoenablesDefaultLighting = true  // Enable default lighting as backup
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
        
        print("GooseSceneView initialized with frame: \(frame)")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Convert screen coordinates to scene coordinates
    func screenToScene(_ point: CGPoint) -> SCNVector3 {
        return SCNVector3(x: point.x, y: point.y, z: 0)
    }
    
    /// Convert scene coordinates to screen coordinates
    func sceneToScreen(_ point: SCNVector3) -> CGPoint {
        return CGPoint(x: point.x, y: point.y)
    }
}
