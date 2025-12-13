import Cocoa
import SceneKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var overlayWindows: [OverlayWindow] = []
    private var menuBarController: MenuBarController?
    private var gooseController: GooseController?
    private var screenManager: ScreenManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("🦆 Desktop Goose starting...")
        
        // Initialize screen manager for multi-monitor support
        screenManager = ScreenManager()
        NSLog("Screen bounds: \(screenManager?.primaryScreenBounds ?? .zero)")
        
        // Create overlay windows for each screen
        createOverlayWindows()
        
        // Initialize goose controller
        if let primaryWindow = overlayWindows.first,
           let sceneView = primaryWindow.contentView as? GooseSceneView {
            NSLog("SceneView created, initializing goose...")
            gooseController = GooseController(sceneView: sceneView, screenManager: screenManager!)
            gooseController?.start()
            NSLog("Goose controller started!")
        } else {
            NSLog("ERROR: Failed to get scene view from window")
        }
        
        // Set up menu bar
        menuBarController = MenuBarController(
            onPauseToggle: { [weak self] isPaused in
                self?.gooseController?.isPaused = isPaused
            },
            onSettingsOpen: { [weak self] in
                self?.openSettings()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )
        NSLog("Menu bar controller initialized")
        
        // Listen for screen configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        NSLog("🦆 Desktop Goose ready!")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        gooseController?.stop()
    }
    
    private func createOverlayWindows() {
        overlayWindows.forEach { $0.close() }
        overlayWindows.removeAll()
        
        // Create an overlay window for the main screen
        if let mainScreen = NSScreen.main {
            NSLog("Creating overlay window for screen: \(mainScreen.frame)")
            let window = OverlayWindow(screen: mainScreen)
            
            // Set up goose click handler
            window.onGooseClicked = { [weak self] in
                self?.handleGooseClicked()
            }
            
            window.orderFrontRegardless()
            overlayWindows.append(window)
            NSLog("Overlay window created and shown")
        } else {
            NSLog("ERROR: No main screen found!")
        }
    }
    
    @objc private func screenConfigurationChanged() {
        createOverlayWindows()
        
        // Reinitialize goose on new primary window
        if let primaryWindow = overlayWindows.first,
           let sceneView = primaryWindow.contentView as? GooseSceneView {
            gooseController?.updateSceneView(sceneView)
        }
    }
    
    private var settingsWindowController: SettingsWindowController?
    
    private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// Handle when the goose is clicked
    private func handleGooseClicked() {
        // Trigger honking behavior
        gooseController?.requestStateTransition(to: .honking)
    }
}
