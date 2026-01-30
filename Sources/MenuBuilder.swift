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
    ///   - isOnACPower: Whether the Mac is plugged in
    ///   - target: The target for menu item actions
    /// - Returns: Configured NSMenu
    static func buildMenu(
        isEnabled: Bool,
        timeRemaining: String,
        isTimerActive: Bool,
        isOnACPower: Bool,
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
        
        // Power source indicator
        let powerItem = NSMenuItem(
            title: isOnACPower ? "Power: Plugged In" : "Power: Battery (Wake Disabled)",
            action: nil,
            keyEquivalent: ""
        )
        powerItem.isEnabled = false
        powerItem.image = NSImage(
            systemSymbolName: isOnACPower ? "powerplug.fill" : "battery.50",
            accessibilityDescription: nil
        )
        menu.addItem(powerItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Toggle item - disabled when on battery
        let toggleItem = NSMenuItem(
            title: isEnabled ? "Deactivate Wake" : "Activate Wake",
            action: isOnACPower ? #selector(StatusItemController.toggleWake) : nil,
            keyEquivalent: isOnACPower ? "w" : ""
        )
        toggleItem.target = target
        toggleItem.image = NSImage(
            systemSymbolName: isEnabled ? "moon.zzz" : "bolt",
            accessibilityDescription: nil
        )
        if !isOnACPower {
            toggleItem.isEnabled = false
        }
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Timer submenu - disabled when on battery
        let timerSubmenu = buildTimerSubmenu(target: target, isOnACPower: isOnACPower)
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
        if !isOnACPower {
            timerItem.isEnabled = false
        }
        menu.addItem(timerItem)
        
        // Custom timer - disabled when on battery
        let customTimerItem = NSMenuItem(
            title: "Custom Duration...",
            action: isOnACPower ? #selector(StatusItemController.showCustomTimerDialog) : nil,
            keyEquivalent: ""
        )
        customTimerItem.target = target
        customTimerItem.image = NSImage(
            systemSymbolName: "clock.badge.questionmark",
            accessibilityDescription: nil
        )
        if !isOnACPower {
            customTimerItem.isEnabled = false
        }
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
        launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
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
    private static func buildTimerSubmenu(target: AnyObject, isOnACPower: Bool) -> NSMenu {
        let submenu = NSMenu()
        
        for duration in WakeDuration.allCases {
            let item = NSMenuItem(
                title: duration.title,
                action: isOnACPower ? #selector(StatusItemController.selectTimerDuration(_:)) : nil,
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
            
            if !isOnACPower {
                item.isEnabled = false
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
