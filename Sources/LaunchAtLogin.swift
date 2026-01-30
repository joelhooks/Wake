import ServiceManagement

/// Manages launch at login functionality using SMAppService (macOS 13+).
/// This provides a clean API for enabling/disabling automatic launch when the user logs in.
final class LaunchAtLogin {
    
    // MARK: - Properties
    
    /// Whether the app is currently registered to launch at login.
    /// Returns `true` if the app is enabled in Login Items, `false` otherwise.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
    
    /// The current registration status of the app.
    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }
    
    // MARK: - Public API
    
    /// Enables or disables launch at login.
    /// - Parameter enabled: `true` to register the app to launch at login, `false` to unregister.
    /// - Throws: An error if registration/unregistration fails.
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
    
    /// Enables or disables launch at login, returning success/failure instead of throwing.
    /// - Parameter enabled: `true` to register the app to launch at login, `false` to unregister.
    /// - Returns: `true` if the operation succeeded, `false` otherwise.
    @discardableResult
    static func setEnabledSafely(_ enabled: Bool) -> Bool {
        do {
            try setEnabled(enabled)
            return true
        } catch {
            print("LaunchAtLogin: Failed to \(enabled ? "enable" : "disable"): \(error.localizedDescription)")
            return false
        }
    }
    
    /// Toggles the launch at login state.
    /// - Returns: The new state after toggling, or `nil` if the operation failed.
    @discardableResult
    static func toggle() -> Bool? {
        let newState = !isEnabled
        return setEnabledSafely(newState) ? newState : nil
    }
    
    /// A human-readable description of the current status.
    static var statusDescription: String {
        switch status {
        case .notRegistered:
            return "Not registered"
        case .enabled:
            return "Enabled"
        case .requiresApproval:
            return "Requires approval in System Settings"
        case .notFound:
            return "App not found"
        @unknown default:
            return "Unknown status"
        }
    }
}
