import Cocoa

class MenuBarController {
    
    private var statusItem: NSStatusItem?
    private var isPaused = false
    
    private let onPauseToggle: (Bool) -> Void
    private let onSettingsOpen: () -> Void
    private let onQuit: () -> Void
    
    init(onPauseToggle: @escaping (Bool) -> Void,
         onSettingsOpen: @escaping () -> Void,
         onQuit: @escaping () -> Void) {
        self.onPauseToggle = onPauseToggle
        self.onSettingsOpen = onSettingsOpen
        self.onQuit = onQuit
        
        setupStatusItem()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bird.fill", accessibilityDescription: "Desktop Goose")
            button.image?.isTemplate = true
        }
        
        let menu = NSMenu()
        
        let pauseItem = NSMenuItem(title: "Pause Goose", action: #selector(togglePause), keyEquivalent: "p")
        pauseItem.target = self
        menu.addItem(pauseItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Desktop Goose", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func togglePause(_ sender: NSMenuItem) {
        isPaused.toggle()
        sender.title = isPaused ? "Resume Goose" : "Pause Goose"
        onPauseToggle(isPaused)
        
        // Update icon to show paused state
        if let button = statusItem?.button {
            let symbolName = isPaused ? "bird" : "bird.fill"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Desktop Goose")
            button.image?.isTemplate = true
        }
    }
    
    @objc private func openSettings() {
        onSettingsOpen()
    }
    
    @objc private func quit() {
        onQuit()
    }
}


