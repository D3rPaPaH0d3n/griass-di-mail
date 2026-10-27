# Native development validation · 2026-10-27

This records the current development candidate, not acceptance of personal mail,
a trademark clearance, or a production support promise. Base: `feaa8e26` from
`handoff/griabuntu-ai`; work is on `work/griabuntu-ubuntu-deb`.

## Actual checks

| Check | Result |
| --- | --- |
| Native Ubuntu 26.10 compilation | Passed, using Ubuntu distribution libraries |
| Engine | 328 synthetic cases passed, including existing FTS/TNEF coverage |
| Focused recipients/status/actions/picture policy | 69 cases passed; seven new picture-policy cases |
| Notification flags | All 10 unchanged cases passed |
| Desktop launchers | Both validation targets passed |
| AppStream | Validation passed |
| Real client-library, GTK and local HTTPS picture fixtures | Eight checks passed |
| Native preferences template and stylesheet | Instantiated and rendered in a private Xvfb display |
| Identity and original icon export checks | Passed |
| Upgrade unpack transaction | Synthetic `.5` → `.6`; configuration, data and cache fixtures unchanged |
| Installed native executable | Runs from the package payload with Ubuntu libraries |
| Git history secret scan | Gitleaks 8.30.1 scanned 6,953 commits / about 56 MB; no detections |

The HTTPS/widget fixtures exercise the actual client library and Soup transport,
with private synthetic TLS trust, fixed-host DNS, and a local HTTP CONNECT proxy.
They verify no pre-consent request, personal consent without company consent,
404-to-company fallback with a decoded picture, withdrawal, SVG/mislabeled data,
redirects, oversized responses and cancellation of delayed responses. No external
network or personal mailbox is used. The fixture refuses a non-loopback network.
The native helper's proxy path is exercised, not replaced with a fake callback.

## Isolation and build limits

Development builds use an official, checksum-verified Ubuntu Base 26.10 rootfs
in the user's build cache. Compiler/development files are installed only there;
no host system packages, personal accounts or mail stores are used.

The rootless bootstrap cannot assign every service-owned system UID/GID, so
some unrelated build-root package configuration remains incomplete. The package
build uses `-d` to bypass dpkg's configuration-status check and `nocheck` to avoid
nested namespace restrictions. **These flags are not evidence of passing tests.**
The named headless suites and the real HTTPS/widget fixtures were instead run
independently in fresh outer Bubblewrap user/network/PID namespaces, disposable
HOME/XDG and private buses/displays. They passed with the actual Ubuntu library
files. Ordinary native builds keep both isolated test commands enabled in
`debian/rules` and declare their build dependencies.

The synthetic display has no GPU acceleration. Glycin reports that it cannot
create a nested decoder sandbox there; the enclosing fixture remains isolated
from host files, buses, display and network. No production isolation setting or
TLS verification was disabled. This is not an acceptance claim for rendering
untrusted real mail.

The `.deb` includes no copied Flatpak runtimes or development archives. Its
original authors, GPL/third-party notices, artwork provenance and picture privacy
policy are installed alongside the program. The source archive must accompany
any distributed binary; build controls and test sources are part of it.

## Remaining limits

- The upgrade check uses a synthetic previous package and unowned profile files;
  it is an unpack/retention check, not an end-to-end upgrade of OmniLinux.
- Real personal mail, contacts, account keyrings and the reply/send/move workflow
  were not used for acceptance. No automatic update of the laptop was performed.
- A native settings-template screenshot is a synthetic fixture, not a screenshot
  of a personal inbox. System light/dark/high-contrast hooks are implemented;
  full inbox accessibility and cross-desktop acceptance remain separate work.
- Contact/provider availability varies. Website icons are not verified company
  identities, and missing images retain initials.
- The owner confirmed there is no written name permission or qualified name
  review yet. No Canonical approval is claimed. See `BRANDING.md` and the unsent
  inquiry draft. Copyright/source licensing does not grant trademark rights.
- Historical exact Dino import revision and inherited per-icon attribution
  inventory are documented precisely; the existing notices are retained and no
  new broad claim of legal certification is made.
