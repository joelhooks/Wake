import Foundation
import Combine

/// Preset durations for keeping the Mac awake.
enum WakeDuration: CaseIterable {
    case thirtyMinutes
    case oneHour
    case twoHours
    case fourHours
    case eightHours
    case indefinite
}

extension WakeDuration {
    /// Display title for menu items.
    var title: String {
        switch self {
        case .thirtyMinutes: return "30 Minutes"
        case .oneHour: return "1 Hour"
        case .twoHours: return "2 Hours"
        case .fourHours: return "4 Hours"
        case .eightHours: return "8 Hours"
        case .indefinite: return "Indefinitely"
        }
    }
    
    /// Duration in seconds. Returns nil for indefinite.
    var seconds: TimeInterval? {
        switch self {
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        case .fourHours: return 4 * 60 * 60
        case .eightHours: return 8 * 60 * 60
        case .indefinite: return nil
        }
    }
}

/// Manages countdown timers for wake duration tracking.
/// Uses Combine Timer.publish for reactive countdown updates.
final class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    /// Remaining time in seconds. 0 when inactive or indefinite.
    @Published private(set) var timeRemaining: TimeInterval = 0
    
    /// Whether a timer is currently active.
    @Published private(set) var isActive = false
    
    /// The currently selected duration, if any.
    @Published private(set) var currentDuration: WakeDuration?
    
    /// Called when a timed duration expires. Hook this to disable wake.
    var onTimerExpired: (() -> Void)?
    
    private var cancellable: AnyCancellable?
    private var endTime: Date?
    
    private init() {}
    
    /// Starts a wake timer with the specified duration.
    /// - Parameter duration: The duration to keep awake.
    func start(duration: WakeDuration) {
        stop()
        
        currentDuration = duration
        isActive = true
        
        guard let seconds = duration.seconds else {
            // Indefinite - no countdown needed
            timeRemaining = 0
            return
        }
        
        endTime = Date().addingTimeInterval(seconds)
        timeRemaining = seconds
        
        // Publish every second for countdown updates
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    /// Stops the current timer and resets state.
    func stop() {
        cancellable?.cancel()
        cancellable = nil
        endTime = nil
        timeRemaining = 0
        isActive = false
        currentDuration = nil
    }
    
    /// Formatted time remaining for display (e.g., "1:30:00" or "∞").
    var formattedTimeRemaining: String {
        guard let duration = currentDuration else {
            return ""
        }
        
        if duration == .indefinite {
            return "∞"
        }
        
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func tick() {
        guard let endTime = endTime else { return }
        
        let remaining = endTime.timeIntervalSinceNow
        
        if remaining <= 0 {
            timeRemaining = 0
            stop()
            onTimerExpired?()
        } else {
            timeRemaining = remaining
        }
    }
}
