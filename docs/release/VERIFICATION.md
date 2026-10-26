# Private GPLv3 copy verification · 2026-10-26

**Real build/test/internal-export evidence, not a public release, full licence
certification, installation or visible desktop/mail acceptance.** The tested
application source is frozen at **`a4774cb9e390a3d55efa6636c9f2f3b12fcc3f88`**.
This completed report is a **reporting-only descendant** of that source commit;
its later Git tip is not falsely claimed to be the bundled source. The archive
and package contain the source commit's pre-verification record, not this later
report. No application/build/installed notice changed after the tested commit.

## Isolation and build identity

Authorised Terra buildhost: Ubuntu 26.10, x86_64, about 1.4 TiB free at preflight;
no active Builder/Meson/Ninja build was observed. User/system Flatpak scopes
were inspected; Builder and GNOME SDK 51 are **system** installations. No SDK
was duplicated or updated. No installed mail was launched, no real account,
profile/contact cache, host session bus/display, signing keys or production
repository was read/modified. No root, installation, public upload or contact.

- Flatpak **1.18.4**; official system Builder **1.4.9**, installed app commit
  `f6832dfc6c181e2ca493aa0efd0190a06a05adff70e10b7f0973d6dbb5343e89`.
- Meson **1.12.0**, Vala **0.56.19**, GCC **16.2.0**.
- Platform 51: `aed50acfdad2e6c6c05e1595ddbde3c9e642f967bde41bfa70e3a8d962408541`.
- SDK 51: `8787593c4d75cbdd277a91945eab9185e18de537479eb8401f852d3f746c49c1`.
- App version **51.0**, `--libdir=lib`, `-Dprofile=release`,
  `-Drevno=gplv3-private-copy-1`, **`-Dtnef=enabled`**, `-Dlibunwind=disabled`.
  Other options retain repository defaults, including `nightly=false`,
  `ref_tracking=disabled`, `contractor=disabled`, `delayed_replay_queue=false`
  and `valadoc=auto` (not found, no API docs). Package prefix `/app`,
  `wrap_mode=nodownload`; test-target prefix `/usr/local` (nothing installed).
  No Meson `buildtype` override is made: its default is **debug** (test
  introspection confirms `optimization=0`, debug on, LTO off). `profile=release`
  means the application identity/profile, **not** a claim of an optimised
  compiler build. Pinned Builder/SDK defaults and the preserved manifest/log
  govern the package compiler environment. No feature was removed; libunwind matches the established
  practice build setting, not a new licensing-driven disablement.

Both builds reuse existing dependency/cache inputs, never overwrite prior
`build-baseline`/`build-notification-actions-v1` environments, and use
`--disable-rofiles-fuse --disable-updates --build-only`. All eight exact dependency
revisions/archive checksums match the practice manifest and
[third-party inventory](../../THIRD-PARTY-NOTICES.md), including libytnef
`d9b2f01d125c9b178f7a00ec397cc2a9f258e8e1`. The final resolved manifest records
those actual inputs, not merely branch labels.

## Baseline versus actual elected GPL copy

| Source / check | Actual result |
| --- | --- |
| Unmodified audit baseline `465e0c6c15233009a7e84ab60a783a3a1fb4a4e0` | **Configuration fails**: Meson nested-subproject notice-install rule |
| Distinct baseline-buildable copy, packaging correction only | Build succeeds; **327/327 engine + 62/62 focused pass** |
| Same baseline, separate notification-flag suite | **6 pass, 4 fail** (10 cases), exit 1 |
| Final elected GPL source `a4774cb9e…` | Build succeeds; **327/327 engine + 62/62 focused pass** |
| Final GPL source, separate notification-flag suite | **6 pass, same 4 fail** (10 cases), exit 1 |
| Final same-stage/installed-client retest | **327 engine + 62 focused pass**; exact staged client loader path verified |

The raw baseline error is:
`Sandbox violation: Tried to grab file COPYING from a nested subproject` at
`meson.build:170`. The baseline-buildable copy differs **only** by removing that
cross-subproject `install_data` rule and placing the identical ValaUnit COPYING
at `docs/licenses/vala-unit-LGPL-2.1.txt` for the existing directory install rule.
It retains LGPL metadata and `revno=notification-actions-1`. It is not described
as an unmodified baseline success; original baseline source is separately kept.
The GPL copy incorporates that packaging correction, not a ValaUnit relicense.

Known red cases, unchanged production handler:
`unread_star_added_stays_new`, `unread_star_removed_stays_new`,
`unread_other_flag_stays_new`, `mixed_flags_retire_only_read_or_deleted`.
No expected-failure masking or unrelated flag fix. Full GTK/WebKit/provider
suites and real desktop/composer moves were **not** run; their known sandbox/
desktop acceptance limitations are not worked around by granting host access.

Tests use temporary HOME/XDG, memory GSettings, `GIO_USE_PROXY_RESOLVER=dummy`,
network unshared, no host session/system buses or display, and private
`dbus-run-session`. The focused runner selects `GNOTIFICATION_BACKEND=gtk` on
its private fixture bus. Targets are configured separately with the same
release/TNEF options; no installed app is executed.

The focused executable has **DT_RPATH**: merely setting LD_LIBRARY_PATH still
selects its build-tree client. That is **not** counted as staged-client proof.
The final staged retest explicitly uses the SDK loader:

```sh
L=/lib64/ld-linux-x86-64.so.2
P=/app/lib/convey:/app/lib:/run/build/convey/_test_build/subprojects/vala-unit
"$L" --inhibit-rpath '' --library-path "$P" --list \
  _test_build/test/test-recipient-aliases
dbus-run-session -- "$L" --inhibit-rpath '' --library-path "$P" \
  _test_build/test/test-engine --keep-going
dbus-run-session -- "$L" --inhibit-rpath '' --library-path "$P" \
  _test_build/test/test-recipient-aliases --keep-going
```

Loader output proves `libconvey-client-51.0.so =>
/app/lib/convey/libconvey-client-51.0.so`. The engine target compiles its engine
statically from the same frozen source; the focused target loads the actual
staged shared client. Both fresh engine runs include **passing TNEF attachment
extraction**, case `/engine/Convey.RFC822.MessageTest/tnef_extract_attachments`.

## Immutable inputs and same-stage unsigned export

A clean `git archive --format=tar --prefix=convey-source/ <source-commit>` is
the actual build input. The external manifest replaces only the final module's
mutable directory with that local archive and its SHA-256 (`strip-components: 1`).
The final build is not from the dirty/test-output source directory. The tested
stage is subsequently finished/exported with the **same manifest** and
`--finish-only --repo=<separate-unsigned-inspection-repo>`; it is not rebuilt in
a different production/signing stage. No signing options or signing homedir.
An unsigned bundle is created from that same exported application ref for
**internal inspection only**, never installed or offered as a download.

Distinct identifiers (SHA-256 file digests are **not** OSTree commits):

```text
application_source_commit = a4774cb9e390a3d55efa6636c9f2f3b12fcc3f88
source_archive_sha256      = 56e5607771fa052396767e3b4c718077e9b0e398714a83994b42aec3d5da7acd
input_manifest_sha256      = 95d2b7466c7016bded70698c8c94c8d944ae4040cca275fe2769bf2b3fb95e63
resolved_manifest_sha256   = 1dc219f8742e94e01f715031371e6eafa54a908ba870a3efed576f9ebb734425
unsigned_bundle_sha256     = 307aa6034ef68d4590754d0e31aab345345bbb5ecc6941f89c26dee29cbcef3e
ostree_application_commit  = b7c4ad02461f3f65ea063cba1ec729a5fc51c8c8d5cea8e9385184975427ba36
ostree_debug_commit        = 5a8cb39dd12d4594b3adb0d5a8f80272fd6dbb86f267c7fb02ea7e1981553ca7
```

Ref: `app/net.donnybeelo.Convey/x86_64/master` (internal inherited ID only).
The debug ref is separate, not the application/bundle file identity. Earlier
trial `74a530aa7` inputs/stage/export are retained but are **not** the final
package evidence above.

## Actual exported package inspection

A fresh OSTree checkout of the **final exported application commit**, not just
staging, was inspected. It contains **2,385 regular-file entries (including
resolved symlink targets)**. Complete path inventory and raw inspection output
remain on the buildhost, not committed as private logs.

- Root application COPYING is official GPLv3, SHA-256
  `3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986`.
  Original LGPL reference, AUTHORS, THANKS, unchanged CC icon/sound notices and
  GPL-copy explanation are present under `share/licenses/net.donnybeelo.Convey/`.
- **All prepared component text files byte-match the frozen source**, including
  Dark Reader MIT (`a9c57a1a33a7f5ebabf3495e11de3b6e92c70f68dcec75b529f6ab4bfb223f5a`),
  CC0, ValaUnit's unchanged LGPL text, Snowball BSD, the exact Giulio Paci binding
  BSD notice, libytnef GPL, GOA, EDS, folks, GMime, libpeas and libical options.
  Auto-installed component COPYING files for all eight modules are present too.
  CC-BY/CC-BY-SA credits/licence links remain in the unchanged COPYING.icons and
  COPYING.sounds; **this is not complete clearance of every inherited asset**.
- Untouched LGPL tray SVG and its colocated LGPL COPYING are actually installed;
  no logo/art was modified. Metadata is **GPL-3.0-only**, metadata licence
  **CC0-1.0**. Offline AppStream validation succeeds (one pedantic item).
- No runtime test/ValaUnit-named artifacts were found outside the deliberately
  installed licence notices. Seven application plugins, the WebKit process
  extension, sound, UI resources, font/format/RTL/app icons remain present.
- Export still includes **eight static archives** (GMime, six libical variants,
  libytnef), dependency headers/development payload and the `ytnef`, `ytnefprint`,
  `ytnefprocess` tools. `--finish-only` export is **not** claimed to have applied
  the practice manifest's cleanup. Review actual public-package cleanup and
  re-inspect/retest it separately; do not pretend these were absent.
- New exported client has `NEEDED libytnef.so.0` and undefined parser symbols
  `TNEFParseMemory`, `TNEFInitialize`, `TNEFFree`. TNEF is linked **and** its
  synthetic extraction test passes. No TNEF-off route or feature removal.

The executable/client/libytnef/GPL text bytes match the same tested final stage:

```text
bin/convey                         f6cb09e7754ad73cc7f8297e96a538c2f940c0ab88e1ecf2ea3b39b2d08a8ff3
lib/convey/libconvey-client-51.0.so  48e3e5ba65dd2f63120b9ab87c89a6561f0b3d4315f8bf948ece5f8040a218f0
lib/libytnef.so.0.0.0               49c1824406ffd5e32186ed69f04f07b7201d09d32dd6613a892177daf871acab
```

## Preserved controls and actual remaining gates

On the authorised buildhost, all work is isolated under
`~/Projects/convey-alias-build/gplv3-prep-20261026/`: original `baseline-source`,
`baseline-buildable-source`/stage, final `inputs-final`, `gpl-source-final`,
`gpl-stage-final`, `unsigned-final-inspection-repo`, `exported-final-inspection`,
internal unsigned bundle and `logs`. Input archives/manifests, source trees,
build/test controls and raw baseline/final logs are preserved. No such logs,
profiles, credentials, binaries or signing artifacts are committed to Git.

This closes **internal exact application-source → tested stage → inspected
unsigned export/bundle** mapping, not reproducible-build certification or the
full corresponding-source distribution closure. Still open before any public
release: the four flag defects/visible desktop acceptance; actual final cleanup
and full shipped/transitive/static component and asset attribution; Dino binding
and Dovecot MIT-fragment provenance checks; runtime/source availability and
verified LGPL replacement/relinking; complete recipient source delivery with
preferred-form Dark Reader/dependency sources; privacy/history review; Canonical
name clearance (inquiry **unsent**); separately approved app-ID/profile migration
and explicit repository/source/binary publication decisions. The GPLv3/TNEF owner
election itself is **complete**, not a pending permission request.
