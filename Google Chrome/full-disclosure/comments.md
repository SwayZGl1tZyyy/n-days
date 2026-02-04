
Chromium - EB 2, 2026 | 16:57: 
```
This attack requires admin access to the user's machine, so setting severity as S2. @ma...@chromium.org can you PTAL?
```

me - FEB 2, 2026 | 19:01:
```
Hi Chromium team,

I forgot to clarify an important note in my report; on macOS an user with admin privileges is not the same as root those are different trust boundaries. So admin to root privileges is a valid privilege escalation scenario. (for if you didn't knew this already)

Best, Kun Peeks
```

Chromium - FEB 3, 2026 | 15:00:
```
#comment3:

on macOS an user with admin privileges is not the same as root those are different trust boundaries.

A user with admin privileges is assumed to have an unabridged capability to act as root. On a properly configured system where /Applications is root:admin 0o0775, this bug does not confer any additional privilege on a user in group admin.

That said, we should still fix it.

.pkg → avi.
```


me - FEB 3, 2026 | 17:22:
```
Hi,

The statement "admins have an unabridged capability to act as root" is an assumption, not a property. Admin group membership alone does not grant arbitrary root actions without an explicit authorization step (password or Touch ID).

In this case, an attacker can run code as an admin user without knowing the admin password, plant a fake /Applications/Google Chrome.app, and then piggyback on the legitimate installer’s authorization to get attacker-controlled code executed as root. That is an admin->root elevation via a bug in a trusted installer.
```

Chromium - EB 3, 2026 | 22:19:
```
Thank you for bringing this issue to our attention.

First, you note that, while installing a .pkg, if an app with the same name already exists but has a different bundle ID, the installer will install the package’s app with a different name. The problem is that Installer.app does not inform the postinstall script of the fact that this situation arose, not to say anything of informing it of where it actually installed the app. Therefore, this issue cannot be handled at the postinstall script level, as the script is unaware of this and does not have the information to act any differently.

Second, while you haven’t mentioned this, it is clear that this issue applies to any package installed by Installer.app, not just that of Chrome.

Therefore, we request that you bring this to Apple’s attention as being a security issue with Installer.app. When you do so, you may want to be clear that this is a general issue with the installer rather than with just Chrome’s package, as that would be more accurate as well as help Apple’s security team understand the scope. Once you’ve reported this, would you be so kind as to share the reference number?

Thank you again.
```

me - FEB 3, 2026 | 23:43:
```
Hi,

Thanks for clarifying.

Per your request, I reported this to Apple as a security issue in Installer.app. Apple reference number: OE110492457079. I also referenced prior public research (Csaba Fitzl’s “localized” writeup and p1tsi’s related pkg LPE post) and an older Radar/OpenRadar report (OpenRadar 33005768).

I’ll share any comments from Apple if I receive them.
```


Chromium - FEB 4, 2026 | 15:31:
```
Thank you.

The extent of this bug is that an admin’s authorization to elevate to root can be “stolen” to execute an arbitrary payload controllable by anything running as an admin. This does not circumvent the authorization step, but it does make it appear to the user that they’re authorizing something trustworthy (in this case, the installation of Chrome from a .pkg) when in fact they’re getting something unexpected on top of thast.

To get from there to an exploit, something still needs to place a malicious payload in that admin-controlled path. The admin user themselves clearly has no interest in that, since their own password already provides them the ability to run as root. All that’s left is that some malicious code that manages to execute as an admin user could leave this payload on disk, and then cross its fingers and hope that the user installs Chrome from a .pkg, authenticating in the process and executing the payload as root.

This is not our bug, it’s Apple’s. As pointed out in #comment9 and the documents it references, it’s already been reported to Apple in 2017–2018 and perhaps earlier. We may be able to cook up further mitigations, and we will investigate that possibility. Our mitigations may not be able to achieve full coverage without changes on Apple’s side. The blog post you cited even spells out:

I truly believe that this is an Apple problem and third parties should rightfully expect being installed properly, without going the extra mile of verification.

before curiously suggesting:

If you are a security researcher:
If you find a vulnerable package, and I can assure you there are a ton of these, report it to the vendor, maybe you will also get some bounty.
As it stands, whatever security concern remains is limited to a spoof, and at that, a substantially mitigated one in that the malicious code will need to have found its way onto the system and executed, leaving something bogus in a fairly visible path on the filesystem (/Applications), and that Chrome would subsequently be installed from a .pkg. Further, most Chrome installs are not performed from a .pkg installer. Those that do are targeted to enterprise scenarios and tend to occur on fresh OS installs.
```

Chromium - FEB 4, 2026 | 16:28:
```
I have reported this to Apple as FB21869775. Even though, in our opinion, this doesn’t qualify as a security issue, the fact that Installer.app is installing the package in a condition where it should not be installed (because there’s weird detritus already in /Applications) as well as passing incorrect information to the post-install script, is a bug and should be addressed.
```

Chromium - FEB 4, 2026 | 16:47:
```
We’re going to leave this bug alone, and split mitigating this non-security issue into bug 481590122.
```
