# Licensing and third-party notices

Prepared **2026-10-26** for the private Griabuntu Mail preparation branch. This is an
evidence-based inventory, not legal advice or a certificate for an existing or
future binary. Original licences, notices, authorship and full history remain.

## Application and assets

- Convey/Geary-derived application code: **LGPL-2.1-or-later**, as declared by
  [COPYING](COPYING), Meson and AppStream. Consult individual headers and
  [AUTHORS](AUTHORS)/[THANKS](THANKS); Griabuntu Mail does not own upstream work.
- AppStream metadata separately declares **CC0-1.0**. Do not apply that to all
  application code or third-party resources.
- [COPYING.icons](COPYING.icons) retains work-specific **CC-BY-3.0** attributions
  (including the named Noun Project creators and Sam Hewitt), **CC-BY-SA-3.0**
  derivatives from GNOME and the specific `tag-symbolic.svg` public-domain
  exception. [COPYING.sounds](COPYING.sounds) credits **Ivica Bukvic** for
  `message.oga` under **CC-BY-SA-3.0**. Those lists are retained verbatim.
- The new downstream tray SVG is original geometry introduced on 2026-10-26,
  marked LGPL-2.1-or-later in-file. No inherited asset was modified for branding.
- New Griabuntu Mail brand vectors and synthetic hero artwork: **CC0-1.0**, explicitly
  limited to those new files; see [brand/README.md](brand/README.md) and
  [docs/images/README.md](docs/images/README.md). No trademark rights are granted
  or claimed by that copyright dedication.
- Legacy screenshots in `desktop/screenshots/` are not used in the README:
  their per-image provenance, licensing and visible-data suitability have not
  been independently established. The inherited upstream application icons are
  also retained unchanged but not appropriated as Griabuntu Mail's brand. Finish the
  per-asset audit before choosing public screenshots or distributing packages.

## Vendored resources

### Dark Reader

`ui/darkreader.js` identifies **4.9.105** and is bundled in application resources.
Its SHA-256 is
`310eb026e5c44872cfe0a17e2ed4922904875416311adfcdac3da111a757ecad`.
The upstream `v4.9.105` tag resolves to
`51f97ccd34ed0a70832421c2768a19bc46fcec4d`. Its
[MIT licence](docs/licenses/DarkReader-MIT.txt), copyright **2025 Dark Reader
Ltd.**, is now included verbatim and scheduled for installation. Source:
https://github.com/darkreader/darkreader/blob/51f97ccd34ed0a70832421c2768a19bc46fcec4d/LICENSE

The existing generated JS was introduced by upstream commit
`efc10cd504f4506193acc12cc86ac966a0ca09a9` (2025-06-10). The version banner is
not enough to establish exact build provenance: compare the vendored API output
to the versioned source/build and check bundled subcomponents before release.
The JS itself is unchanged here.

### ValaUnit

`subprojects/vala-unit` identifies version **2.0**, LGPL-2.1-or-later; its own
[COPYING](subprojects/vala-unit/COPYING) and individual copyright headers are
preserved (including Julien Peeters and Michael Gratton). Snapshot tree:
`0682d990c012ba4947a0136e8141ae92a06feac1`. It is configured with `install=false`
and used by the test targets, not intentionally installed as an app dependency.
Verify the final package rather than assuming it is absent. Its licence is also
scheduled for installation as a conservative source/test-component notice.

## Exact practice-manifest dependency inventory

Applies to `packaging/net.donnybeelo.Convey.Practice.yml`, **not** the moving
upstream Devel manifest. Licence texts below were retrieved from these exact
upstream references on 2026-10-26. Top-level terms are only the starting point:
audit source-file exceptions, transitive content and what is actually shipped.

| Module | Exact manifest source | Inspected terms / prepared notice |
| --- | --- | --- |
| gnome-online-accounts 3.58.1 | `c1fd9e58b8e4559e690ab96a191304a6660fba97` | COPYING explicitly says LGPL-2.0-or-later with per-file headers; [text](docs/licenses/gnome-online-accounts-COPYING.txt) |
| libical 3.0.20 | archive SHA-256 `e73de92f5a6ce84c1b00306446b290a2b08cdf0a80988eca0a2c9d5c3510b4c2` | Versioned LICENSE offers MPL-2.0 **or** LGPL-2.1; [choice notice](docs/licenses/libical-LICENSE.txt), [COPYING](docs/licenses/libical-COPYING.txt), [LGPL](docs/licenses/libical-LGPL21.txt), [MPL](docs/licenses/libical-MPL2.txt) |
| evolution-data-server 3.60.2 | `242c81196daf074cdc4c224e48b7b4319985b589` | [COPYING](docs/licenses/evolution-data-server-COPYING.txt) contains LGPL-2.0 text; sampled e-source.c refers to LGPL without a version. Component/file/version-option audit remains open; do not blanket-label all EDS LGPL-2.1 |
| folks 0.15.12 | `1157825538e3d565a4e9c519ac5fedd97ea10d00` | Sampled folks/individual.vala says LGPL-2.1-or-later; [COPYING](docs/licenses/folks-COPYING.txt) |
| GMime 3.2.15 | archive SHA-256 `84cd2a481a27970ec39b5c95f72db026722904a2ccf3fdbd57b280cf2d02b5c4` | Versioned gmime/gmime.c says LGPL-2.1-or-later; [COPYING](docs/licenses/GMime-COPYING.txt) |
| libpeas 2.2.1 | `744430715e619069b3fcb6c994f2c09257700d05` | Sampled peas-engine.c SPDX LGPL-2.1-or-later; [COPYING](docs/licenses/libpeas-COPYING.txt) |
| libytnef 1.9.3 | `d9b2f01d125c9b178f7a00ec397cc2a9f258e8e1` | **GPL-2.0-or-later** in lib/ytnef.c, copyright 2003 Randall E. Hand; [GPL text](docs/licenses/ytnef-GPL-2.0.txt). Critical combined-binary gate below |
| Snowball 3.1.1 | `cd195b51e948a902a4312f023f4a14392516a543` | [COPYING](docs/licenses/Snowball-COPYING.txt): 3-clause BSD-style terms, copyright Dr Martin Porter, Richard Boulton, Yoshiki Shibukawa and Olly Betts. Explicit notice install added for the manually built shared lib |

Git-source URLs are in the manifest; corresponding upstream licence paths and
version selectors are recorded in [docs/licenses/README.md](docs/licenses/README.md).
Archive notices were checked at matching version tags, **not** independently
extracted from freshly downloaded checksum-verified tarballs in this task.
That archive/source correspondence is a remaining gate.

### libytnef is not LGPL

The practice build enables TNEF by default; `src/engine/meson.build` adds
`libytnef` and `WITH_TNEF_SUPPORT` when found. The exact library source header
and GPL text were inspected, not inferred from package metadata. An LGPL label
on our source is not a licence audit of a linked GPL combination. Before binary
distribution, choose and review the applicable combined-work obligations and
metadata/source delivery, or explicitly approve and test a TNEF-disabled build
(`-Dtnef=disabled`, with corresponding manifest dependency removal). **No licence
switch or feature disablement is silently made here.** Simply including GPL text
does not settle this gate.

## What is prepared, and what still needs inspection

Meson now installs application COPYING/COPYING.icons/COPYING.sounds, AUTHORS,
THANKS, this notice and the prepared dependency licence texts under
`share/licenses/<application-id>/`. The practice Snowball recipe separately
installs its COPYING. This addresses the missing explicit top-level licence
install rules; actual staging/export inspection remains mandatory.

The GNOME 51 runtime/SDK and transitive components are not completely identified
by a branch label. Record resolved commits and enumerate shipped `/app` files,
linked/shared libraries, plugin modules, web resources and any static/embedded
code (including whether test/ValaUnit artifacts escaped). Review runtime/source
availability and LGPL relinking/replacement requirements where applicable.
Keep final dependency copyright notices, not only generic licence texts.

For every distributable record final source commit, manifest/build options,
resolved dependency/runtime revisions, exported binary hashes and complete source
location. Deliver source with equivalent access at the binary's download point;
a private branch unavailable to recipients is not source delivery. See
[RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md). No package-content/source mapping was
established by this preparation.
