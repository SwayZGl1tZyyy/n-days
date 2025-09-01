## Summary

Upscayl’s Electron configuration allows local attackers to trigger misleading macOS permission prompts by running malicious code under the identity of the trusted app. This is caused by the `RunAsNode` fuse being enabled, allowing `Node.js` code execution with full inherited app entitlements.

An attacker can leverage this to request any sensitive permissions e.g. `sensitive hardware (camera, microphone`) and `tcc protected files` through a subprocess, causing the TCC system prompt to appear as if the request came from Upscayl, not the attacker’s code.

The root cause is that the `RunAsNode` fuse allows launching the app in a special `Node.js` mode using `-e`, executing arbitrary system commands with Upscayl’s permissions and identity.
```sh
swayzgl1tzyyy@SwayZGl1tZyyys-Mac ~ % npx @electron/fuses read --app /Applications/Upscayl.app/Contents/MacOS/Upscayl 

Analyzing app: Upscayl
Fuse Version: v1
  RunAsNode is Enabled
  EnableCookieEncryption is Disabled
  EnableNodeOptionsEnvironmentVariable is Enabled
  EnableNodeCliInspectArguments is Enabled
  EnableEmbeddedAsarIntegrityValidation is Disabled
  OnlyLoadAppFromAsar is Disabled
  LoadBrowserProcessSpecificV8Snapshot is Disabled
```
## Technical Details

Electron apps that enable the `RunAsNode` fuse can be launched in a special `Node.js` mode. When this is combined with the `-e`flag and used to execute system commands, macOS treats the subprocess as part of the parent application.

## How to Reproduce the TCC Prompt Spoofing

The tool [electroniz3r](https://github.com/r3ggi/electroniz3r) can automate the process:

```sh
swayzgl1tzyyy@SwayZGl1tZyyys-Mac ~ % electroniz3r inject /Applications/Upscayl.app --predefined-script screenshot

/Applications/Upscayl.app started the debug WebSocket server
The webSocketDebuggerUrl is: ws://127.0.0.1:13337/65ebc839-aed9-4c19-bc0a-3395b8513286
Check /tmp/screenshot.jpg
```

This payload triggers a macOS TCC prompt for camera access. But instead of showing the request as coming from the Terminal (which executed the code), the system displays:

>"Upscayl" would like to record this computer's screen and audio.
>Grant access to this application in Privacy & Security settings, located in System Settings.

<img width="2190" height="1762" alt="pocupscal" src="https://github.com/user-attachments/assets/64fc8955-75f9-4b7c-b003-6f7830501062" />

This tricks the user into thinking a trusted app is requesting access, when in fact it's attacker-controlled code running inside a subprocess. If the user approves the request, the attack succeeds for example, a screenshot is taken and saved.

<img width="2908" height="1786" alt="proof2" src="https://github.com/user-attachments/assets/3299d8b8-e27c-43be-a9b6-bdd2c257ca66" />

## Impact

A TCC bypass is particularly useful in post-exploitation scenarios where an attacker already has code execution on the system but is limited by macOS privacy restrictions. For example, even if an attacker has root access, macOS still enforces TCC rules unless explicitly overridden.

This vulnerability allows:

- TCC prompt spoofing: System prompts for sensitive access appear under a trusted app's identity. 
- Misuse of system UI: Deceptive behavior that undermines informed decision-making by users.
- Social engineering advantage: Increases likelihood of user consent due to app trust. 
- Access to TCC-protected resources e.g. `sensitive hardware` (i.e. screen, camera microphone) and protected folders like `~/Documents, ~/Downloads etc`. 

Even though user interaction (clicking “Allow”) is required, the decision is based on false information, which violates the macOS security model and UI integrity.

## Suggested Fix

This fuse controls whether the app respects the `ELECTRON_RUN_AS_NODE` environment variable. When enabled, it allows the app to run as a standalone Node.js binary, which is **not sandboxed** and **inherits all macOS TCC permissions** previously granted to the app.

According to [Electron’s official documentation](https://www.electronjs.org/docs/latest/tutorial/fuses), these fuses are intended for development and debugging, and should be disabled in production environments. Leaving them enabled undermines key security features, such as hardened runtime and the deliberate exclusion of risky entitlements, and may introduce unnecessary attack surface.

- Disable the `runAsNode` fuse within your Electron app, disabling this fuse prevents abuse of the `-e` flag and arbitrary `Node.js` execution.


References:
- https://github.com/upscayl/upscayl/security/advisories/GHSA-mgm3-77w7-3jvv
