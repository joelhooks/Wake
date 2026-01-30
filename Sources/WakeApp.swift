import AppKit

/// Main entry point for Wake - a menubar-only app that prevents Mac sleep.
/// Uses .accessory activation policy to hide from dock.
@main
struct WakeApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        
        // Hide from dock - menubar only
        app.setActivationPolicy(.accessory)
        
        app.run()
    }
}
