import Foundation

public enum ControlMode: String, Codable, Equatable {
    case armed
    case paused
}

public struct PersistentControlState: Codable, Equatable {
    public var selectedProviderID: String?
    public var schemaVersion: Int
    public var mode: ControlMode
    public var manualStopPending: Bool
    public var updatedAt: Date

    public init(
        selectedProviderID: String? = nil,
        schemaVersion: Int = 1,
        mode: ControlMode,
        manualStopPending: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.selectedProviderID = selectedProviderID
        self.schemaVersion = schemaVersion
        self.mode = mode
        self.manualStopPending = manualStopPending
        self.updatedAt = updatedAt
    }

    public static func armed(at date: Date = Date()) -> PersistentControlState {
        PersistentControlState(mode: .armed, updatedAt: date)
    }
}

public enum VPNConnectionState: String, Codable, Equatable {
    case connected
    case connecting
    case disconnecting
    case disconnected
    case unknown
}

public enum ControllerAction: Equatable {
    case none
    case connect
    case disconnect
    case completePause
    case rearm
}

public enum DecisionEngine {
    public static func action(
        controlState: PersistentControlState,
        vpnState: VPNConnectionState,
        internetAvailable: Bool,
        retryReady: Bool
    ) -> ControllerAction {
        switch controlState.mode {
        case .paused:
            if controlState.manualStopPending {
                switch vpnState {
                case .disconnected:
                    return .completePause
                case .connected, .connecting:
                    return .disconnect
                case .disconnecting, .unknown:
                    return .none
                }
            }

            // A connection initiated outside this controller counts as the
            // user's next manual turn-on and re-arms automatic recovery.
            if vpnState == .connecting || vpnState == .connected {
                return .rearm
            }
            return .none

        case .armed:
            guard internetAvailable, retryReady else {
                return .none
            }
            return vpnState == .disconnected ? .connect : .none
        }
    }
}

public enum RetryPolicy {
    private static let delays: [TimeInterval] = [5, 15, 30, 60, 120, 300]

    public static func delay(afterAttempt attempt: Int) -> TimeInterval {
        delays[min(max(attempt, 0), delays.count - 1)]
    }
}
