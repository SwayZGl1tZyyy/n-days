#### Cloudflare WARP privilege escalation 

**URLs:** https://one.one.one.one (1.1.1.1) `https://1111-releases.cloudflareclient.com/mac/latest`

**Affected package installer**: package installer: `Cloudflare_WARP_2025.9.558.0.pkg`

#### description of problem:

The Cloudflare WARP macOS installer can be abused to achieve local privilege escalation from an attacker-controlled application bundle in `/Applications` to arbitrary code execution as root.
The issue stems from how the installer trusts the path `${INSTALL_DIR}/Cloudflare WARP.app/Contents/Resources/CloudflareWARP` inside its `postinstall` script, combined with macOS Installer’s behavior when there is a bundle identifier mismatch. If an attacker is able to pre-place a fake `Cloudflare WARP.app` in `/Applications` with a different `CFBundleIdentifier` from the legitimate app, macOS will not overwrite it during install. Instead, due to the known "`rdar://33005768`" behavior, the real app is placed under a `.localized` subdirectory, while the attacker’s bundle remains at `/Applications/Cloudflare WARP.app`.

The `postinstall` script assumes `${INSTALL_DIR}/Cloudflare WARP.app` points to the freshly installed, trusted app. Uses that path to set `ProgramArguments[0]` in a LaunchDaemon plist:
line 21: (`/usr/libexec/PlistBuddy -c "Set :ProgramArguments:0 ${INSTALL_DIR}/Cloudflare\ WARP.app/Contents/Resources/CloudflareWARP" $DAEMON_PLIST_PATH`) Loads the daemon with `sudo launchctl load -w $DAEMON_PLIST_PATH`, causing that CloudflareWARP binary to run as root.

Because macOS has relocated the legitimate app into `/Applications/Cloudflare WARP.localized/Cloudflare WARP.app`, and the attacker controls `/Applications/Cloudflare WARP.app`, the
LaunchDaemon ends up executing arbitrary attacker code as root on every load. The `preinstall` script does not perform a deep cleanup of existing `Cloudflare WARP.app` bundles in `/Applications`; it only removes an older `Cloudflare 1.1.1.1.app`. This leaves room for a malicious bundle with the correct name but wrong bundle ID to persist and be referenced later.
attack scenario

#### A plausible attack scenario is:

an attacker with code execution as a regular macOS administrator user (able to write into `/Applications`) drops a malicious `Cloudflare WARP.app` with a crafted Info.plist and a custom `Contents/Resources/CloudflareWARP` binary,
a real administrator later downloads and installs the official `Cloudflare WARP .pkg` to install or update the VPN client.
macOS installer, seeing a bundle ID mismatch, installs the genuine WARP app under `/Applications/Cloudflare WARP.localized/Cloudflare WARP.app` and leaves the attacker’s bundle at `/Applications/Cloudflare WARP.app`,
the `postinstall` script configures a LaunchDaemon whose `ProgramArguments[0]` points at `${INSTALL_DIR}/Cloudflare WARP.app/Contents/Resources/CloudflareWARP` and then loads it with launchctl as root,
the attacker’s CloudflareWARP binary is now executed with full root privileges, giving the attacker a reliable LPE and persistence.

>please note: having admin privileges (a user account inside the `admin` group) is not the same as an root user and counts as an local privilege escalation on macOS. 

