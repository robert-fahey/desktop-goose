import Cocoa
import SceneKit

class OverlayWindow: NSWindow {
    
    /// Callback when goose is clicked
    var onGooseClicked: (() -> Void)?
    
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        configureWindow()
        setupSceneView(for: screen)
    }
    
    private func configureWindow() {
        // Transparency settings
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        
        // Always on top - use a very high level
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 1000)
        
        // Window behavior for Spaces and fullscreen
        self.collectionBehavior = [
            .canJoinAllSpaces,          // Appear on all Spaces/Desktops
            .fullScreenAuxiliary,       // Stay visible when other apps go fullscreen
            .stationary,                // Don't move during Space transitions
            .ignoresCycle               // Don't appear in Cmd+Tab
        ]
        
        // Click-through - let clicks pass to apps underneath
        // We use a global event monitor to detect goose clicks instead
        self.ignoresMouseEvents = true
        
        // Don't show in window lists
        self.isExcludedFromWindowsMenu = true
    }
    
    private func setupSceneView(for screen: NSScreen) {
        // Use bounds (0,0 origin) for the content view, not screen frame
        let viewFrame = NSRect(x: 0, y: 0, width: screen.frame.width, height: screen.frame.height)
        let sceneView = GooseSceneView(frame: viewFrame)
        sceneView.onGooseClicked = { [weak self] in
            self?.onGooseClicked?()
        }
        self.contentView = sceneView
    }
}
