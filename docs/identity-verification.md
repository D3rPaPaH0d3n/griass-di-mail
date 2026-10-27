# Identity refactor verification · 2026-10-27

This record is the **name-only `.2` candidate before the new envelope icons**.
Its original icon-byte claims and package hash are historical evidence for that
exact artifact. The subsequent `.3` icon candidate has separate verification.

Private native Ubuntu 26.10/amd64 candidate:
`griabuntu-mail_51.0+griabuntu20261027.2_amd64.deb`

SHA-256: `aee50cc4218f5029cb0b6ef305e17a1a3a5f04ee9fa56c480fb8104634cd7715`.

## Actual checks

- Complete native Debian package build succeeds with TNEF enabled.
- **328 engine + 62 focused helper + 10 notification-flag cases pass.**
  The extra engine case exercises old/new SQLite tokenizer aliases with
  synthetic text. The renamed loadable SQLite extension is also loaded and
  queried successfully in an isolated in-memory database.
- Both desktop-file validators, AppStream validation and the cross-component
  `build-aux/check-identity.py` check pass. The check covers application/schema/
  resource names, account/database filenames, desktop/D-Bus activation, engine
  namespace, translation paths and the JS/native bridge.
- The packaged desktop name and all **51** installed gettext catalogs identify
  the product as Griabuntu Mail. All packaged private shared libraries resolve
  their native dependencies; no old Convey executable/desktop file is shipped.
- The actual package payload starts with disposable HOME/XDG, memory GSettings,
  private process/network namespaces, a private D-Bus and Xvfb. Fresh-start and
  mapped About windows are rendered and visually inspected. They show the new
  application name and repository link with the preserved original author and
  licence credits. The inherited icon is displayed under its new identity.
  A disposable icon cache emulates the normal native icon-theme trigger; public
  CA certificates are mounted read-only, while personal profiles, host buses
  and the host display remain inaccessible.
- Original COPYRIGHT/licence/author/history texts, original SVG artwork and
  vendored Dark Reader bytes are preserved. Dark Reader extracted from the
  compiled package resource matches the original vendored file byte-for-byte.
- APT's installation simulation upgrades only the existing `griabuntu-mail`
  package. No personal profile has been copied or migrated by this source work.
- The private GitHub repository is renamed to
  `D3rPaPaH0d3n/griabuntu-mail`; repository ID, privacy and default branch remain.
  Source modifications are local and have not been pushed or merged.

## Limits

An additional JavaScript/WebKit suite was attempted under the same isolation.
It aborts before completing the first case because the nested WebKit/dbus-proxy
sandbox cannot create another namespace (`bwrap: No permissions to create a new
namespace`). **It is not counted as passed.** No sandbox-disabling flag, host
bus/display or access to personal state was granted to get a green result.
The headless suites, identity check and fresh-start/About render do not establish
complete composer, message-rendering or real-mail acceptance.

Raw logs, synthetic screenshots, source snapshot and artifact mapping are
retained outside version control. This is a report-only document added after
the tested source snapshot, not an unsupported assertion that its own report
text was compiled into the package. Frozen 2026-10-26 package hashes and licence
inventories retain their original source/identity context.

See [IDENTITY.md](IDENTITY.md) for the naming map and intentional historical
lookup exceptions. Installing this new identity and handling the owner's current
native accounts is a separate, explicitly selected deployment/migration step.
