import AppKit

/// Builds and configures the NSMenu for the Wake menubar app.
/// Provides static methods to construct menu items with proper targets and actions.
enum MenuBuilder {
    
    // MARK: - Menu Construction
    
    /// Builds the complete menu for the status item.
    /// - Parameters:
    ///   - isEnabled: Whether wake prevention is currently active
    ///   - timeRemaining: Formatted time remaining string (e.g., "1:30:00" or "∞")
    ///   - isTimerActive: Whether a timer is currently running
    ///   - target: The target for menu item actions
    /// - Returns: Configured NSMenu
    static func buildMenu(
        isEnabled: Bool,
        timeRemaining: String,
        isTimerActive: Bool,
        target: AnyObject
    ) -> NSMenu {
        let menu = NSMenu()
        
        // Status display (disabled, informational only)
        let statusItem = NSMenuItem(
            title: statusTitle(isEnabled: isEnabled, timeRemaining: timeRemaining),
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Toggle item
        let toggleItem = NSMenuItem(
            title: isEnabled ? "Deactivate Wake" : "Activate Wake",
            action: #selector(StatusItemController.toggleWake),
            keyEquivalent: "w"
        )
        toggleItem.target = target
        toggleItem.image = NSImage(
            systemSymbolName: isEnabled ? "moon.zzz" : "bolt",
            accessibilityDescription: nil
        )
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Timer submenu
        let timerSubmenu = buildTimerSubmenu(target: target)
        let timerItem = NSMenuItem(
            title: "Set Timer",
            action: nil,
            keyEquivalent: ""
        )
        timerItem.submenu = timerSubmenu
        timerItem.image = NSImage(
            systemSymbolName: "timer",
            accessibilityDescription: nil
        )
        menu.addItem(timerItem)
        
        // Custom timer
        let customTimerItem = NSMenuItem(
            title: "Custom Duration...",
            action: #selector(StatusItemController.showCustomTimerDialog),
            keyEquivalent: ""
        )
        customTimerItem.target = target
        customTimerItem.image = NSImage(
            systemSymbolName: "clock.badge.questionmark",
            accessibilityDescription: nil
        )
        menu.addItem(customTimerItem)
        
        // Stop timer (only show if timer is active)
        if isTimerActive {
            let stopTimerItem = NSMenuItem(
                title: "Stop Timer",
                action: #selector(StatusItemController.stopTimer),
                keyEquivalent: ""
            )
            stopTimerItem.target = target
            stopTimerItem.image = NSImage(
                systemSymbolName: "stop.circle",
                accessibilityDescription: nil
            )
            menu.addItem(stopTimerItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Launch at Login
        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(StatusItemController.toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = target
        // TODO: Check actual launch at login state
        launchAtLoginItem.state = .off
        menu.addItem(launchAtLoginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Wake",
            action: #selector(StatusItemController.quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = target
        menu.addItem(quitItem)
        
        return menu
    }
    
    // MARK: - Timer Submenu
    
    /// Builds the timer preset submenu with all WakeDuration cases.
    private static func buildTimerSubmenu(target: AnyObject) -> NSMenu {
        let submenu = NSMenu()
        
        for duration in WakeDuration.allCases {
            let item = NSMenuItem(
                title: duration.title,
                action: #selector(StatusItemController.selectTimerDuration(_:)),
                keyEquivalent: ""
            )
            item.target = target
            item.representedObject = duration
            
            // Add checkmark for indefinite since it's the "always on" option
            if duration == .indefinite {
                item.image = NSImage(
                    systemSymbolName: "infinity",
                    accessibilityDescription: nil
                )
            }
            
            submenu.addItem(item)
        }
        
        return submenu
    }
    
    // MARK: - Helpers
    
    /// Generates the status title string.
    private static func statusTitle(isEnabled: Bool, timeRemaining: String) -> String {
        if isEnabled {
            if timeRemaining.isEmpty {
                return "Wake: Active"
            } else {
                return "Wake: Active (\(timeRemaining))"
            }
        } else {
            return "Wake: Inactive"
        }
    }
}
