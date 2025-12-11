import Cocoa

// Ensure we have a proper application
let app = NSApplication.shared

// Set activation policy - we're a regular app that just hides from dock
app.setActivationPolicy(.accessory)

// Create and set delegate
let delegate = AppDelegate()
app.delegate = delegate

// Activate the app
app.activate(ignoringOtherApps: true)

// Run the app
app.run()
