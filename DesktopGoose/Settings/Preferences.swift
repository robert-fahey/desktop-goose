import Foundation

class Preferences {
    
    static let shared = Preferences()
    
    private let defaults = UserDefaults.standard
    
    // Keys
    private enum Keys {
        static let chaosLevel = "chaosLevel"
        static let gooseSpeed = "gooseSpeed"
        static let enableCursorGrab = "enableCursorGrab"
        static let enableMemeDrag = "enableMemeDrag"
        static let enableWindowPerch = "enableWindowPerch"
        static let enableHonk = "enableHonk"
        static let honkVolume = "honkVolume"
        static let launchAtLogin = "launchAtLogin"
        static let enableBalls = "enableBalls"
        static let enablePlants = "enablePlants"
        static let enableFurniture = "enableFurniture"
        static let enableDroid = "enableDroid"
    }
    
    // MARK: - Chaos Level (0.0 - 1.0)
    
    var chaosLevel: Double {
        get {
            if defaults.object(forKey: Keys.chaosLevel) == nil {
                return 0.7 // Default
            }
            return defaults.double(forKey: Keys.chaosLevel)
        }
        set {
            defaults.set(newValue.clamped(to: 0...1), forKey: Keys.chaosLevel)
        }
    }
    
    // MARK: - Goose Speed (50 - 300 pixels per second)
    
    var gooseSpeed: Double {
        get {
            if defaults.object(forKey: Keys.gooseSpeed) == nil {
                return 150 // Default
            }
            return defaults.double(forKey: Keys.gooseSpeed)
        }
        set {
            defaults.set(newValue.clamped(to: 50...300), forKey: Keys.gooseSpeed)
        }
    }
    
    // MARK: - Behavior Toggles
    
    var enableCursorGrab: Bool {
        get {
            if defaults.object(forKey: Keys.enableCursorGrab) == nil {
                return true // Default enabled
            }
            return defaults.bool(forKey: Keys.enableCursorGrab)
        }
        set {
            defaults.set(newValue, forKey: Keys.enableCursorGrab)
        }
    }
    
    var enableMemeDrag: Bool {
        get {
            if defaults.object(forKey: Keys.enableMemeDrag) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.enableMemeDrag)
        }
        set {
            defaults.set(newValue, forKey: Keys.enableMemeDrag)
        }
    }
    
    var enableWindowPerch: Bool {
        get {
            if defaults.object(forKey: Keys.enableWindowPerch) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.enableWindowPerch)
        }
        set {
            defaults.set(newValue, forKey: Keys.enableWindowPerch)
        }
    }
    
    var enableHonk: Bool {
        get {
            if defaults.object(forKey: Keys.enableHonk) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.enableHonk)
        }
        set {
            defaults.set(newValue, forKey: Keys.enableHonk)
        }
    }
    
    // MARK: - Honk Volume (0.0 - 1.0)
    
    var honkVolume: Float {
        get {
            if defaults.object(forKey: Keys.honkVolume) == nil {
                return 0.7
            }
            return defaults.float(forKey: Keys.honkVolume)
        }
        set {
            defaults.set(newValue.clamped(to: 0...1), forKey: Keys.honkVolume)
        }
    }
    
    // MARK: - Launch at Login
    
    var launchAtLogin: Bool {
        get {
            return defaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin(newValue)
        }
    }
    
    // MARK: - Object Toggles
    
    var enableBalls: Bool {
        get {
            if defaults.object(forKey: Keys.enableBalls) == nil {
                return true // Default enabled
            }
            return defaults.bool(forKey: Keys.enableBalls)
        }
        set {
            defaults.set(newValue, forKey: Keys.enableBalls)
        }
    }
    
    var enablePlants: Bool {
        get {
            if defaults.object(forKey: Keys.enablePlants) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.enablePlants)
        }
        set {
            defaults.set(newValue, forKey: Keys.enablePlants)
        }
    }
    
    var enableFurniture: Bool {
        get {
            if defaults.object(forKey: Keys.enableFurniture) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.enableFurniture)
        }
        set {
            defaults.set(newValue, forKey: Keys.enableFurniture)
        }
    }
    
    var enableDroid: Bool {
        get {
            if defaults.object(forKey: Keys.enableDroid) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.enableDroid)
        }
        set {
            defaults.set(newValue, forKey: Keys.enableDroid)
        }
    }
    
    private func updateLaunchAtLogin(_ enabled: Bool) {
        // Use SMAppService for modern macOS (13+) or SMLoginItemSetEnabled for older
        // This is a simplified implementation
        // Full implementation would use ServiceManagement framework
    }
    
    // MARK: - Reset
    
    func resetToDefaults() {
        chaosLevel = 0.7
        gooseSpeed = 150
        enableCursorGrab = true
        enableMemeDrag = true
        enableWindowPerch = true
        enableHonk = true
        honkVolume = 0.7
        launchAtLogin = false
        enableBalls = true
        enablePlants = true
        enableFurniture = true
        enableDroid = true
    }
}

// MARK: - Helpers

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}



