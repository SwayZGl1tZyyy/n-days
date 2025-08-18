# TCC Bypass via Misconfigured Node Fuses (macOS)

## Summary

DeltaChat Desktop for macOS is vulnerable to a **TCC bypass**, allowing an attacker to access the camera and microphone without proper user consent.  

By abusing unsafe `Node.js` fuse settings and the exposed Electron, local code execution is possible from an unprivileged terminal, granting access to TCC-protected hardware (_camera_ and _microphone_), even if Terminal itself lacks permission.

The app grants camera access during legitimate flows such as:  
`Add Profile` → `I Already Have a Profile` → `Add as Second Device` or adding a `New Contact`. 

However, a local attacker can leverage this trust to capture images records silently.

## Technical Details

Inspecting the Electron fuses with:

```sh
npx @electron/fuses read --app /Applications/DeltaChat.app/Contents/MacOS/DeltaChat 

Analyzing app: DeltaChat
Fuse Version: v1
  RunAsNode is Enabled
  EnableCookieEncryption is Disabled
  EnableNodeOptionsEnvironmentVariable is Enabled
  EnableNodeCliInspectArguments is Enabled
  EnableEmbeddedAsarIntegrityValidation is Disabled
  OnlyLoadAppFromAsar is Disabled
  LoadBrowserProcessSpecificV8Snapshot is Disabled
  GrantFileProtocolExtraPrivileges is Enabled
```

These settings together mean the app is fully injectable from a process (like Terminal) that has no camera access of its own.

## Impact

1. **Privacy Breach** 
    Attackers can gain access to **TCC-protected hardware** such as the **camera and microphone** without user interaction or additional permission prompts. The code runs invisibly and inherits all permissions granted to DeltaChat.

2. **Security Compromise**  
    Malicious JavaScript can be injected and executed inside the **Node.js runtime** context of the app. bypassing macOS's built-in security controls

3. **Data Security Risk**  
    Once injected, unauthorized access to hardware enables covert surveillance, potentially compromising user privacy at any time.

## Mitigation

**Disable the risky Electron fuses while maintaining the application's core functionality**

This fuse controls whether the app respects the `ELECTRON_RUN_AS_NODE` environment variable. When enabled, it allows the app to run as a standalone `Node.js` binary, which is not sandboxed and inherits all macOS TCC permissions previously granted to the app.

- Disable the `runAsNode` fuse within the Electron app (disabling this fuse prevents abuse of the `-e` flag and arbitrary `Node.js` execution).

Reference: https://www.electronjs.org/docs/latest/tutorial/fuses#runasnode

- proof-of-concept is coming up.