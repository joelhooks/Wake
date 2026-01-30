import AppKit
import Combine
import UserNotifications

/// Controls the NSStatusItem and its menu, observing WakeManager and TimerManager
/// state changes via Combine to keep the UI in sync.
final class StatusItemController: NSObject {
    
    // MARK: - Properties
    
    /// The menubar status item
    private var statusItem: NSStatusItem?
    
    /// Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Cached state for menu rebuilding
    private var isWakeEnabled = false
    private var isTimerActive = false
    private var formattedTime = ""
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupStatusItem()
        setupObservers()
        setupTimerExpiredCallback()
    }
    
    // MARK: - Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem?.button else {
            fatalError("Failed to create status item button")
        }
        
        // Initial icon - inactive state
        button.image = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: "Wake")
        
        // Build initial menu
        rebuildMenu()
    }
    
    private func setupObservers() {
        // Observe WakeManager.isEnabled
        WakeManager.shared.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.isWakeEnabled = isEnabled
                self?.updateStatusIcon()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
        
        // Observe TimerManager.isActive
        TimerManager.shared.$isActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                self?.isTimerActive = isActive
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
        
        // Observe TimerManager.timeRemaining for countdown updates
        TimerManager.shared.$timeRemaining
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.formattedTime = TimerManager.shared.formattedTimeRemaining
                self?.updateStatusTitle()
            }
            .store(in: &cancellables)
    }
    
    private func setupTimerExpiredCallback() {
        TimerManager.shared.onTimerExpired = { [weak self] in
            // When timer expires, disable wake
            WakeManager.shared.disable()
            self?.showTimerExpiredNotification()
        }
    }
    
    // MARK: - UI Updates
    
    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        
        // bolt.fill when active, moon.zzz.fill when inactive
        let symbolName = isWakeEnabled ? "bolt.fill" : "moon.zzz.fill"
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Wake")
    }
    
    private func updateStatusTitle() {
        // Update just the first menu item (status display) without full rebuild
        guard let menu = statusItem?.menu,
              let statusMenuItem = menu.items.first else { return }
        
        if isWakeEnabled {
            if formattedTime.isEmpty {
                statusMenuItem.title = "Wake: Active"
            } else {
                statusMenuItem.title = "Wake: Active (\(formattedTime))"
            }
        } else {
            statusMenuItem.title = "Wake: Inactive"
        }
    }
    
    private func rebuildMenu() {
        statusItem?.menu = MenuBuilder.buildMenu(
            isEnabled: isWakeEnabled,
            timeRemaining: formattedTime,
            isTimerActive: isTimerActive,
            target: self
        )
    }
    
    // MARK: - Menu Actions
    
    @objc func toggleWake() {
        if isWakeEnabled {
            WakeManager.shared.disable()
            TimerManager.shared.stop()
        } else {
            WakeManager.shared.enable()
        }
    }
    
    @objc func selectTimerDuration(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? WakeDuration else { return }
        
        // Enable wake and start timer
        WakeManager.shared.enable()
        TimerManager.shared.start(duration: duration)
    }
    
    @objc func stopTimer() {
        TimerManager.shared.stop()
        // Keep wake enabled, just stop the countdown
    }
    
    @objc func showCustomTimerDialog() {
        let alert = NSAlert()
        alert.messageText = "Custom Duration"
        alert.informativeText = "Enter duration in minutes:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        inputField.placeholderString = "e.g., 45"
        inputField.stringValue = ""
        alert.accessoryView = inputField
        
        // Make the input field first responder
        alert.window.initialFirstResponder = inputField
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let minutesString = inputField.stringValue.trimmingCharacters(in: .whitespaces)
            if let minutes = Double(minutesString), minutes > 0 {
                let seconds = minutes * 60
                startCustomTimer(seconds: seconds)
            } else {
                showInvalidInputAlert()
            }
        }
    }
    
    private func startCustomTimer(seconds: TimeInterval) {
        // Enable wake
        WakeManager.shared.enable()
        
        // Start a custom timer by directly manipulating TimerManager
        // We'll need to add a method for custom duration, or use a workaround
        // For now, we'll create a simple timer ourselves
        startCustomCountdown(seconds: seconds)
    }
    
    private var customTimerCancellable: AnyCancellable?
    private var customEndTime: Date?
    
    private func startCustomCountdown(seconds: TimeInterval) {
        // Stop any existing timer
        TimerManager.shared.stop()
        customTimerCancellable?.cancel()
        
        customEndTime = Date().addingTimeInterval(seconds)
        isTimerActive = true
        
        // Update formatted time
        updateCustomFormattedTime(remaining: seconds)
        rebuildMenu()
        
        customTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tickCustomTimer()
            }
    }
    
    private func tickCustomTimer() {
        guard let endTime = customEndTime else { return }
        
        let remaining = endTime.timeIntervalSinceNow
        
        if remaining <= 0 {
            customTimerCancellable?.cancel()
            customTimerCancellable = nil
            customEndTime = nil
            isTimerActive = false
            formattedTime = ""
            WakeManager.shared.disable()
            showTimerExpiredNotification()
            rebuildMenu()
        } else {
            updateCustomFormattedTime(remaining: remaining)
        }
    }
    
    private func updateCustomFormattedTime(remaining: TimeInterval) {
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        
        if hours > 0 {
            formattedTime = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            formattedTime = String(format: "%d:%02d", minutes, seconds)
        }
        
        updateStatusTitle()
    }
    
    private func showInvalidInputAlert() {
        let alert = NSAlert()
        alert.messageText = "Invalid Input"
        alert.informativeText = "Please enter a valid number of minutes (e.g., 45)."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func toggleLaunchAtLogin() {
        // TODO: Implement launch at login using SMAppService (macOS 13+)
        // or LSSharedFileList for older macOS versions
        print("[StatusItemController] Launch at Login toggle - not yet implemented")
    }
    
    @objc func quitApp() {
        // Ensure wake is disabled before quitting
        WakeManager.shared.disable()
        TimerManager.shared.stop()
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Notifications
    
    private func showTimerExpiredNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Wake Timer Expired"
        content.body = "Your Mac can now sleep normally."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[StatusItemController] Failed to deliver notification: \(error)")
            }
        }
    }
    
    /// Request notification permissions (call once at app startup)
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("[StatusItemController] Notification permission error: \(error)")
            }
        }
    }
}
