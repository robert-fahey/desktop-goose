import Cocoa

class SettingsWindowController: NSWindowController {
    
    private var chaosSlider: NSSlider!
    private var speedSlider: NSSlider!
    private var cursorGrabCheckbox: NSButton!
    private var memeDragCheckbox: NSButton!
    private var windowPerchCheckbox: NSButton!
    private var honkCheckbox: NSButton!
    private var volumeSlider: NSSlider!
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Desktop Goose Settings"
        window.center()
        
        self.init(window: window)
        setupUI()
        loadPreferences()
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])
        
        // Title
        let titleLabel = NSTextField(labelWithString: "🦆 Desktop Goose Settings")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        stackView.addArrangedSubview(titleLabel)
        
        // Chaos Level
        let chaosLabel = NSTextField(labelWithString: "Chaos Level:")
        chaosLabel.font = NSFont.systemFont(ofSize: 14)
        stackView.addArrangedSubview(chaosLabel)
        
        chaosSlider = NSSlider(value: 0.7, minValue: 0, maxValue: 1, target: self, action: #selector(chaosChanged))
        chaosSlider.widthAnchor.constraint(equalToConstant: 350).isActive = true
        stackView.addArrangedSubview(chaosSlider)
        
        let chaosDescLabel = NSTextField(labelWithString: "How chaotic should the goose be?")
        chaosDescLabel.font = NSFont.systemFont(ofSize: 11)
        chaosDescLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(chaosDescLabel)
        
        // Speed
        let speedLabel = NSTextField(labelWithString: "Goose Speed:")
        speedLabel.font = NSFont.systemFont(ofSize: 14)
        stackView.addArrangedSubview(speedLabel)
        
        speedSlider = NSSlider(value: 150, minValue: 50, maxValue: 300, target: self, action: #selector(speedChanged))
        speedSlider.widthAnchor.constraint(equalToConstant: 350).isActive = true
        stackView.addArrangedSubview(speedSlider)
        
        // Behavior toggles
        let behaviorsLabel = NSTextField(labelWithString: "Behaviors:")
        behaviorsLabel.font = NSFont.boldSystemFont(ofSize: 14)
        stackView.addArrangedSubview(behaviorsLabel)
        
        cursorGrabCheckbox = NSButton(checkboxWithTitle: "Grab Cursor (annoying!)", target: self, action: #selector(toggleChanged))
        stackView.addArrangedSubview(cursorGrabCheckbox)
        
        memeDragCheckbox = NSButton(checkboxWithTitle: "Drag Memes", target: self, action: #selector(toggleChanged))
        stackView.addArrangedSubview(memeDragCheckbox)
        
        windowPerchCheckbox = NSButton(checkboxWithTitle: "Perch on Windows", target: self, action: #selector(toggleChanged))
        stackView.addArrangedSubview(windowPerchCheckbox)
        
        honkCheckbox = NSButton(checkboxWithTitle: "Honk", target: self, action: #selector(toggleChanged))
        stackView.addArrangedSubview(honkCheckbox)
        
        // Volume
        let volumeLabel = NSTextField(labelWithString: "Honk Volume:")
        volumeLabel.font = NSFont.systemFont(ofSize: 14)
        stackView.addArrangedSubview(volumeLabel)
        
        volumeSlider = NSSlider(value: 0.7, minValue: 0, maxValue: 1, target: self, action: #selector(volumeChanged))
        volumeSlider.widthAnchor.constraint(equalToConstant: 350).isActive = true
        stackView.addArrangedSubview(volumeSlider)
        
        // Reset button
        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetToDefaults))
        stackView.addArrangedSubview(resetButton)
        
        // Accessibility note
        let accessNote = NSTextField(wrappingLabelWithString: "Note: Some features require Accessibility permission in System Settings → Privacy & Security → Accessibility.")
        accessNote.font = NSFont.systemFont(ofSize: 11)
        accessNote.textColor = .secondaryLabelColor
        accessNote.preferredMaxLayoutWidth = 350
        stackView.addArrangedSubview(accessNote)
    }
    
    private func loadPreferences() {
        let prefs = Preferences.shared
        chaosSlider.doubleValue = prefs.chaosLevel
        speedSlider.doubleValue = prefs.gooseSpeed
        cursorGrabCheckbox.state = prefs.enableCursorGrab ? .on : .off
        memeDragCheckbox.state = prefs.enableMemeDrag ? .on : .off
        windowPerchCheckbox.state = prefs.enableWindowPerch ? .on : .off
        honkCheckbox.state = prefs.enableHonk ? .on : .off
        volumeSlider.floatValue = prefs.honkVolume
    }
    
    @objc private func chaosChanged() {
        Preferences.shared.chaosLevel = chaosSlider.doubleValue
    }
    
    @objc private func speedChanged() {
        Preferences.shared.gooseSpeed = speedSlider.doubleValue
    }
    
    @objc private func toggleChanged(_ sender: NSButton) {
        let prefs = Preferences.shared
        let isOn = sender.state == .on
        
        switch sender {
        case cursorGrabCheckbox:
            prefs.enableCursorGrab = isOn
        case memeDragCheckbox:
            prefs.enableMemeDrag = isOn
        case windowPerchCheckbox:
            prefs.enableWindowPerch = isOn
        case honkCheckbox:
            prefs.enableHonk = isOn
        default:
            break
        }
    }
    
    @objc private func volumeChanged() {
        Preferences.shared.honkVolume = volumeSlider.floatValue
    }
    
    @objc private func resetToDefaults() {
        Preferences.shared.resetToDefaults()
        loadPreferences()
    }
}

