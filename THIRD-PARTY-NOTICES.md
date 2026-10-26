# Licensing and third-party notices

Prepared **2026-10-26** for the private Griabuntu Mail preparation branch. This is an
evidence-based inventory, not legal advice or a certificate for an existing or
future binary. Original licences, notices, authorship and full history remain.
The [licensing decision](docs/LICENSING-DECISION.md) establishes the TNEF/GPL
distribution route and separates remaining release work from new permissions.

## Application and assets

- This **separate elected release-source copy** of the LGPL-derived application
  is **GPL-3.0-only** under LGPL-2.1 §3, approved by Markus on 2026-10-26 at
  19:56 UTC. [COPYING](COPYING), Meson, AppStream and About now agree. Copyright,
  actual change dates and historical origin are retained; consult [AUTHORS](AUTHORS),
  [THANKS](THANKS) and the [conversion inventory](docs/release/GPLV3-COPY.md).
  `COPYING.LGPL-2.1-original` is an unchanged historical reference, not an
  alternative grant for the elected copy. Independently preserved original
  LGPL source/main and preparation commits remain under their original terms.
- AppStream metadata separately declares **CC0-1.0**. Do not apply that to all
  application code or third-party resources.
- [COPYING.icons](COPYING.icons) retains work-specific **CC-BY-3.0** attributions
  (including the named Noun Project creators and Sam Hewitt), **CC-BY-SA-3.0**
  derivatives from GNOME and the specific `tag-symbolic.svg` public-domain
  exception. [COPYING.sounds](COPYING.sounds) credits **Ivica Bukvic** for
  `message.oga` under **CC-BY-SA-3.0**. Those lists are retained verbatim.
- The new downstream tray SVG is original geometry introduced on 2026-10-26,
  marked LGPL-2.1-or-later in-file and remains byte-identical. A colocated
  `icons/hicolor/scalable/apps/COPYING` retains its correct LGPL reference and
  is installed beside it. No logo or inherited artwork was modified.
- New Griabuntu Mail brand vectors and synthetic hero artwork: **CC0-1.0**, explicitly
  limited to those new files; see [brand/README.md](brand/README.md) and
  [docs/images/README.md](docs/images/README.md). No trademark rights are granted
  or claimed by that copyright dedication.
- Legacy screenshots in `desktop/screenshots/` are not used in the README:
  their per-image provenance, licensing and visible-data suitability have not
  been independently established. The inherited upstream application icons are
  also retained unchanged but not appropriated as Griabuntu Mail's brand. Finish the
  per-asset audit before choosing public screenshots or distributing packages.
  Specifically, the current COPYING.icons list omits installed font/format/edit
  icons, some RTL variants and Convey application icons. Historical contributor
  commits are identified in the decision; they are not a complete path-to-grant
  supplement. All inherited assets/sound are unchanged versus the upstream base.
  CC-BY/CC-BY-SA 3.0 require supplied attribution/title/source/licence notices and
  identification of adaptations; ShareAlike covers adapted assets, not
  automatically the whole independent application collection.

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
`efc10cd504f4506193acc12cc86ac966a0ca09a9` (2025-06-10). It is now verified
**byte-identical** to `package/darkreader.js` in the official npm 4.9.105
[artifact](https://registry.npmjs.org/darkreader/-/darkreader-4.9.105.tgz).
The [registry record](https://registry.npmjs.org/darkreader/4.9.105) has the same
`gitHead`; downloaded bytes match its SHA-512 integrity. The npm LICENSE is also
byte-identical to our prepared MIT text. The API recipe at that commit builds
UMD from `src/api/index.ts`; the six-file API archive contains no extension
fonts/assets. Although package.json lists Malevic, this API JS contains no
Malevic/external module-loader reference. No downloaded build script was run.
The provenance gate is closed; the JS is unchanged. Actual new GPL-copy package verification is recorded in
[VERIFICATION.md](docs/release/VERIFICATION.md), separately from older stages.

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
| evolution-data-server 3.60.2 | `242c81196daf074cdc4c224e48b7b4319985b589` | [COPYING](docs/licenses/evolution-data-server-COPYING.txt) contains LGPL-2.0 text; e-source.c/e-book-client.c/Camel have version-unspecified LGPL grants (version choice allowed), newer files SPDX LGPL-2.1-or-later or LGPL-2.0-or-later. OpenLDAP extract has separate terms, with its backend disabled by this recipe. Preserve individual headers; no uniform LGPL-2.0-only/2.1 label |
| folks 0.15.12 | `1157825538e3d565a4e9c519ac5fedd97ea10d00` | Sampled folks/individual.vala says LGPL-2.1-or-later; [COPYING](docs/licenses/folks-COPYING.txt) |
| GMime 3.2.15 | archive SHA-256 `84cd2a481a27970ec39b5c95f72db026722904a2ccf3fdbd57b280cf2d02b5c4` | Versioned gmime/gmime.c says LGPL-2.1-or-later; [COPYING](docs/licenses/GMime-COPYING.txt) |
| libpeas 2.2.1 | `744430715e619069b3fcb6c994f2c09257700d05` | peas-engine.c LGPL-2.1-or-later; [COPYING](docs/licenses/libpeas-COPYING.txt), exact [upstream relicensing record](docs/licenses/libpeas-license_change.txt) retained verbatim |
| libytnef 1.9.3 | `d9b2f01d125c9b178f7a00ec397cc2a9f258e8e1` | **GPL-2.0-or-later** in lib/ytnef.c and ytnef.h, Copyright (C) 2003 Randall E. Hand; [GPL text](docs/licenses/ytnef-GPL-2.0.txt). Compatible GPL combined-binary route below |
| Snowball 3.1.1 | `cd195b51e948a902a4312f023f4a14392516a543` | [COPYING](docs/licenses/Snowball-COPYING.txt): 3-clause BSD-style terms, copyright Dr Martin Porter, Richard Boulton, Yoshiki Shibukawa and Olly Betts. Explicit notice install added for the manually built shared lib |

Git-source URLs are in the manifest; corresponding upstream licence paths and
version selectors are recorded in [docs/licenses/README.md](docs/licenses/README.md).
The exact cached Git-pinned COPYING texts hash-match the prepared files,
including EDS. The libical/GMime cached release archives were read without
running them: their SHA-256 values match the manifest, and all five prepared
archive licence files match the actual members byte-for-byte. Archive/notice
correspondence is closed, not a remaining gate. This verifies these inputs/texts,
not every transitive component in a future exported package.

### libytnef: GPL combination is distributable, not an LGPL-only binary

`meson.options` defaults TNEF to **enabled**; Meson requires libytnef accordingly.
The engine calls TNEFParseMemory and traverses library structures, and is linked
into the shared client. Nonexecuting `readelf` inspection of the existing stage
confirms `NEEDED libytnef.so.0` and TNEF parser/initialise/free symbols. Dynamic
linking is not mere aggregation.

**Owner election implemented: retain TNEF, GPL-3.0-only application release
copy under LGPL-2.1 §3.** libytnef retains GPL-2.0-or-later; it is not relabelled.
The combination uses its GPLv3 option, without revoking independent LGPL
application copies. No feature was disabled and no new upstream permission is
needed. See [the operative election](docs/release/GPLV3-COPY.md).

## What is prepared, and what still needs inspection

Meson now installs application COPYING/COPYING.icons/COPYING.sounds, AUTHORS,
THANKS, this notice and the prepared dependency licence texts under
`share/licenses/<application-id>/`. The practice Snowball recipe separately
installs its COPYING. This addresses the missing explicit top-level licence
install rules; actual staging/export inspection of this preparation remains
mandatory. The independently inspected existing stage has original COPYING
texts but **no Dark Reader MIT notice**; its source export predates these rules.
No test/ValaUnit-named payload was found in that stage, not a certified final
export. Static archives/tools in staging may be removed by final cleanup.

The existing staged manifest now establishes GNOME 51 Platform commit
`aed50acfdad2e6c6c05e1595ddbde3c9e642f967bde41bfa70e3a8d962408541` and SDK
`8787593c4d75cbdd277a91945eab9185e18de537479eb8401f852d3f746c49c1`;
these are evidence for that build only, not for an unbuilt preparation release.
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

## New release-copy evidence and exact unresolved provenance

The original audit/stage paragraphs above remain historical input evidence,
not certification of this copy. [GPLV3-COPY.md](docs/release/GPLV3-COPY.md) defines
its component boundaries; [VERIFICATION.md](docs/release/VERIFICATION.md) records
new baseline/build/test/export evidence and exact source mapping. The ValaUnit
notice is now installed from a byte-identical standalone reference copy, because
the original nested-subproject `install_data` rule fails Meson configuration.

The original Giulio Paci BSD-style binding notice from
`bindings/vapi/libstemmer.vapi` is now reproduced verbatim as
`docs/licenses/libstemmer-vapi-BSD.txt` and installed; no authorship is inferred.

Unheaded `bindings/vapi/icu-uc.vapi` records Dino origin without an exact imported
revision/file-specific grant. `util-imap-utf7.vala` records a Dovecot 2.1.15 MIT
fragment but no accompanying original MIT text, with upstream's historical
substantiality comment retained. These are precise remaining provenance checks,
not licence grants invented here. The listed inherited icon/RTL/application-icon
and screenshot gaps also remain open; not every asset is declared cleared.
