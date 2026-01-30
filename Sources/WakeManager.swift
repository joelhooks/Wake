import Foundation
import Combine
import IOKit.ps

/// Manages macOS sleep prevention via pmset.
/// Only operates when plugged in - automatically disables on battery power.
/// Requires passwordless sudo configured for pmset via visudo.
final class WakeManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = WakeManager()
    
    // MARK: - Published State
    
    /// Whether sleep prevention is currently enabled
    @Published private(set) var isEnabled = false
    
    /// Whether the Mac is currently on AC power
    @Published private(set) var isOnACPower = true
    
    // MARK: - Private
    
    private var powerSourceCallback: IOPowerSourceCallbackType?
    private var runLoopSource: CFRunLoopSource?
    
    private init() {
        updatePowerSourceState()
        setupPowerSourceMonitoring()
    }
    
    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
    }
    
    // MARK: - Power Source Monitoring
    
    private func setupPowerSourceMonitoring() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        runLoopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let manager = Unmanaged<WakeManager>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                manager.handlePowerSourceChange()
            }
        }, context).takeRetainedValue()
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
    }
    
    private func handlePowerSourceChange() {
        let wasOnAC = isOnACPower
        updatePowerSourceState()
        
        // If we switched to battery and wake is enabled, disable it
        if wasOnAC && !isOnACPower && isEnabled {
            print("[WakeManager] Switched to battery power - disabling wake")
            disable()
        }
    }
    
    private func updatePowerSourceState() {
        isOnACPower = checkIfOnACPower()
    }
    
    private func checkIfOnACPower() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            // If we can't determine power state, assume AC (desktop Mac or error)
            return true
        }
        
        // No power sources means desktop Mac (always on AC)
        if sources.isEmpty {
            return true
        }
        
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            // Check power source state
            if let powerSourceState = info[kIOPSPowerSourceStateKey as String] as? String {
                if powerSourceState == kIOPSACPowerValue as String {
                    return true
                }
            }
        }
        
        return false
    }
    
    // MARK: - Public API
    
    /// Enable sleep prevention (runs: sudo -n pmset disablesleep 1)
    /// Will fail silently if on battery power.
    func enable() {
        guard isOnACPower else {
            print("[WakeManager] Cannot enable wake on battery power")
            return
        }
        
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
