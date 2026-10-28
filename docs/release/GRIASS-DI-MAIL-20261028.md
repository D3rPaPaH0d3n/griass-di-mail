# Griaß di Mail · native preview .7

Owner-selected display name: **Griaß di Mail**, exact spelling with ß and spaces.
The current repository is [D3rPaPaH0d3n/griass-di-mail](https://github.com/D3rPaPaH0d3n/griass-di-mail).
GitHub redirects preserve previous links and the full fork history. The default
branch remains `work/griabuntu-ubuntu-deb`; main/history were not rewritten.

The built application source is **`7a9d873e6f30a7e9813529a7155da1c8ad994765`**,
version **`51.0+griassdi20261028.7`**, Ubuntu 26.10 amd64. This reporting-only
follow-up does not change the source compiled into that package.

[Private release draft](https://github.com/D3rPaPaH0d3n/griass-di-mail/releases/tag/untagged-27bceefaeb3dc830a1b5) includes the .deb, exact clean source
archive/.dsc, buildinfo/changes, dependency sources, manifest and SHA256SUMS.
All 12 uploaded asset digests were compared with their local final counterparts.

| Artifact | SHA-256 |
| --- | --- |
| griabuntu-mail_51.0+griassdi20261028.7_amd64.deb | `f8a2387de093201d03f1e35540c854a65605cdd8f04ab96607faf7cd52a487af` |
| griabuntu-mail_51.0+griassdi20261028.7.tar.xz | `5b62b1cb8862a75040f4116f5f6b78deb8e2498509dc8f5b044c3737f9f6afd5` |

## Changes

- Windows, menus, tray/notifications, launchers, AppStream, translated labels,
  help, current project presentation and URLs use the selected display name.
- The original closed-envelope/G app/tray icon remains byte-identical. All six
  supplied originals pass their existing SHA256SUMS. A separately named AI-edited
  banner replaces the title and removes the old Ubuntu annotation while keeping
  the composition/palette. See [artwork provenance](../ARTWORK-PROVENANCE.md).
- Stable compatibility identifiers remain `griabuntu-mail`, the existing app ID,
  namespace/gettext, data/config/cache/database paths and keyring schema.
  This is an ordinary native update, not a second profile or automatic migration.
  See [upgrade guidance](../UPGRADING.md).
- Free-of-charge distribution is confirmed. Possible future Revolut donations
  are recorded, with no payment UI added now. Required upstream author/licence
  notices remain accessible. The superseded-name Canonical inquiry is archived
  unsent; no universal trademark clearance is asserted.

## Final checks

All final named checks passed after the final source changes and clean build:

| Check | Result |
| --- | --- |
| Engine | 328 cases |
| Focused recipients/status/actions/picture policy | 69 cases, including updated tray-title expectations |
| Notification flags | 10 unchanged cases |
| Desktop/AppStream | Three validation targets |
| Real HTTPS/widget tests with final package library | All eight scenarios |
| Packaged banner | Byte-identical to selected new PNG resource |
| Packaged desktop launcher and live app window | Exact Griaß di Mail display name, including ß |
| Revision/build configuration | deb-51.0+griassdi20261028.7 |
| Native unpack upgrade | Actual .6→.7 packages; synthetic config/data/cache hashes retained |
| Source snapshot scan | Gitleaks: 15.85 MB, no detections |
| GitHub source checks | Passed for the exact source commit |

The packaging helper previously reused debhelper's completed-build stamp, and
Meson retained configuration/linker metadata from earlier versions. The initial
intermediate .7 candidate was caught by extracting/comparing its actual banner
and was discarded before upload. The local helper now uses the normal dpkg
pre-clean; the final package was built cleanly with current configuration,
revision and resources. No reproducible-bit-identity claim is made.

## Acceptance limits and repository state

This remains a private preview. Rootless builds still use `-d` and `nocheck`
because of bootstrap/nested-namespace constraints; these flags are not test
results. Tests ran independently in fresh outer isolation with synthetic HOME,
private buses/display and loopback-only networking. Software rendering and the
nested Glycin warning remain; the minimal fixture cannot activate its EDS source
registry. No personal accounts, system-wide TerraLinux install or configured
OmniLinux upgrade acceptance is claimed. Local administrator authentication is
unavailable and was not bypassed.

Current inherited per-asset provenance and broader desktop acceptance limits
remain documented. The owner has already authorised publication when complete;
no repeated publication permission is needed. No public visibility change,
Canonical outreach or real-message action occurred in this rename.
