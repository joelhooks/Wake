import AppKit

/// Application delegate that manages the menubar status item and coordinates
/// with WakeManager and TimerManager for sleep prevention functionality.
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    /// Controls the menubar status item and menu
    private var statusItemController: StatusItemController?
    
    // MARK: - NSApplicationDelegate
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the status item controller - it handles all menu UI
        statusItemController = StatusItemController()
        statusItemController?.requestNotificationPermissions()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Ensure wake is disabled on quit
        WakeManager.shared.disable()
        TimerManager.shared.stop()
    }
}
