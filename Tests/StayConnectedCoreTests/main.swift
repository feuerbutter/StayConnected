import Darwin
import Foundation
import StayConnectedCore

struct CheckRunner {
    private(set) var checks = 0
    private(set) var failures = 0

    mutating func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
        checks += 1
        if condition() {
            print("PASS \(name)")
        } else {
            failures += 1
            print("FAIL \(name)")
        }
    }
}

func decide(
    mode: ControlMode,
    vpn: VPNConnectionState,
    online: Bool,
    retryReady: Bool
) -> ControllerAction {
    DecisionEngine.action(
        controlState: PersistentControlState(mode: mode),
        vpnState: vpn,
        internetAvailable: online,
        retryReady: retryReady
    )
}

var runner = CheckRunner()
runner.expect(
    decide(mode: .armed, vpn: .disconnected, online: true, retryReady: true) == .connect,
    "armed disconnected online connects"
)
runner.expect(
    decide(mode: .armed, vpn: .disconnected, online: false, retryReady: true) == .none,
    "armed offline waits"
)
runner.expect(
    decide(mode: .armed, vpn: .disconnected, online: true, retryReady: false) == .none,
    "armed honors retry backoff"
)
runner.expect(
    decide(mode: .armed, vpn: .connected, online: true, retryReady: true) == .none,
    "armed connected is stable"
)
runner.expect(
    decide(mode: .paused, vpn: .disconnected, online: true, retryReady: true) == .none,
    "stable pause stays off"
)

let pendingPause = PersistentControlState(mode: .paused, manualStopPending: true)
runner.expect(
    DecisionEngine.action(
        controlState: pendingPause,
        vpnState: .connected,
        internetAvailable: true,
        retryReady: true
    ) == .disconnect,
    "manual pause disconnects before settling"
)
runner.expect(
    DecisionEngine.action(
        controlState: pendingPause,
        vpnState: .disconnected,
        internetAvailable: true,
        retryReady: true
    ) == .completePause,
    "manual pause settles once disconnected"
)
runner.expect(
    decide(mode: .paused, vpn: .connecting, online: true, retryReady: true) == .rearm,
    "external manual turn-on while connecting re-arms"
)
runner.expect(
    decide(mode: .paused, vpn: .connected, online: true, retryReady: true) == .rearm,
    "external manual turn-on when connected re-arms"
)
runner.expect(RetryPolicy.delay(afterAttempt: 0) == 5, "initial retry is five seconds")
runner.expect(RetryPolicy.delay(afterAttempt: 3) == 60, "retry grows to sixty seconds")
runner.expect(RetryPolicy.delay(afterAttempt: 100) == 300, "retry is capped at five minutes")

runControlStateStoreChecks(&runner)

let successful = BoundedCommand.run(executable: "/usr/bin/printf", arguments: ["connected\n"])
runner.expect(successful.exitCode == 0 && successful.standardOutput == "connected\n", "command captures output")
let started = Date()
let stalled = BoundedCommand.run(executable: "/bin/sleep", arguments: ["60"], timeout: 0.2)
runner.expect(stalled.exitCode == 124 && Date().timeIntervalSince(started) < 4, "stalled command releases worker within deadline")
let following = BoundedCommand.run(executable: "/usr/bin/printf", arguments: ["recovered"])
runner.expect(following.exitCode == 0 && following.standardOutput == "recovered", "commands still run after timeout")
let noisy = BoundedCommand.run(executable: "/bin/sh", arguments: ["-c", "awk 'BEGIN {for(i=0;i<20000;i++) print \"status detail\"}'"])
runner.expect(noisy.exitCode == 0 && noisy.standardOutput.count > 200000, "large status output does not deadlock pipe")

runProviderChecks(&runner)

print("CHECKS \(runner.checks) FAILURES \(runner.failures)")
if runner.failures > 0 {
    exit(1)
}
