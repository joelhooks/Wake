import Foundation
import Combine

/// Manages macOS sleep prevention via pmset.
/// Requires passwordless sudo configured for pmset via visudo.
final class WakeManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = WakeManager()
    
    // MARK: - Published State
    
    /// Whether sleep prevention is currently enabled
    @Published private(set) var isEnabled = false
    
    // MARK: - Private
    
    private init() {}
    
    // MARK: - Public API
    
    /// Enable sleep prevention (runs: sudo -n pmset disablesleep 1)
    func enable() {
        let success = runPmset(disableSleep: true)
        if success {
            isEnabled = true
        }
    }
    
    /// Disable sleep prevention (runs: sudo -n pmset disablesleep 0)
    func disable() {
        let success = runPmset(disableSleep: false)
        if success {
            isEnabled = false
        }
    }
    
    /// Toggle sleep prevention state
    func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }
    
    // MARK: - Private Helpers
    
    /// Runs pmset disablesleep command via sudo -n (non-interactive)
    /// - Parameter disableSleep: true to disable sleep (keep awake), false to allow sleep
    /// - Returns: true if command succeeded, false otherwise
    @discardableResult
    private func runPmset(disableSleep: Bool) -> Bool {
        let value = disableSleep ? "1" : "0"
        return runShellCommand("/usr/bin/sudo", arguments: ["-n", "/usr/bin/pmset", "disablesleep", value])
    }
    
    /// Executes a shell command via Process
    /// - Parameters:
    ///   - command: Path to executable
    ///   - arguments: Command arguments
    /// - Returns: true if exit code is 0, false otherwise
    private func runShellCommand(_ command: String, arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        
        // Suppress output - we only care about exit code
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let success = process.terminationStatus == 0
            if !success {
                print("[WakeManager] Command failed with exit code: \(process.terminationStatus)")
            }
            return success
        } catch {
            print("[WakeManager] Failed to run command: \(error.localizedDescription)")
            return false
        }
    }
}
