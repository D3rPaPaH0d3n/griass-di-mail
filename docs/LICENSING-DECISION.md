# Licensing decision · 2026-10-26

**Recommendation: keep TNEF and prepare a GPLv3-compliant combined application
release; keep the independently available LGPL source grants.** Disabling
winmail.dat support is an alternative product decision, not a legal necessity.
This is a sourced technical/licence interpretation, not legal advice or release
approval. No code, feature, operative licence declaration, installed app or
branding has been changed by this audit.

Scope: preparation source `9183cc8d3d49b2463ad033203719c08afbe19552`, derived
from Convey `d24c1da859fc9cc2cfb19872b1d8e972d4dc1a20`. Earlier preparation
records remain historical; findings below supersede their identified open
licence/provenance questions, not their engineering gates.

## Rights matrix

| Use | Finding / condition |
| --- | --- |
| Own private use/builds | Permitted by the code licences; no obligation to publish private modifications merely because they are run. Giving copies to others can trigger distribution obligations, even from a private repository. |
| Public application source | Existing LGPL-2.1-or-later grant permits modified source distribution with copyright/licence notices and dated changes. Optional calls to an external GPL library do not automatically relicense every source file. Honour separate assets/MIT terms; name/privacy/publication gates remain. No new upstream consent is needed for the existing code grant. |
| Binary, TNEF **on** | A linked GPL combination, not an LGPL-only application package. Distribution **is possible** on compatible GPL terms, with corresponding source, notices and accurate package metadata. Recommended election: GPLv3 for the combined application. |
| Binary, TNEF **off** | LGPL application route is available after an explicitly approved `-Dtnef=disabled` build, removal of the libytnef module/tools from that package, and verification of the result. Still needs LGPL source/relinking and all other component obligations. |
| Artwork/resources | New original brand/hero files: CC0, no bundled font files. Inherited icons/sound keep their own CC/other rights; attribution coverage has concrete gaps below. No whole-repository CC0 or GPL claim. |
| **Griabuntu Mail** name | Private working name, **not cleared for public branding**. Canonical's similarity/software-title policy is material; no permission obtained and no contact made. Code/CC0 grants do not grant trademark rights. |

## Why TNEF is a combination, and why GPL distribution is possible

**Measured facts.** `meson.options` defaults `tnef` to **enabled** (not merely
“auto if found”). `meson.build` requires libytnef accordingly; the practice
manifest pins 1.9.3 at `d9b2f01d125c9b178f7a00ec397cc2a9f258e8e1`.
Its `lib/Makefile.am` builds the library from `ytnef.c`; both that file and
`ytnef.h` say GPL version 2 **or any later version**, copyright 2003 Randall E.
Hand. [Exact source](https://github.com/Yeraze/ytnef/tree/d9b2f01d125c9b178f7a00ec397cc2a9f258e8e1/lib).

`src/engine/meson.build:378–396` adds libytnef and `WITH_TNEF_SUPPORT` to the
static engine; the client shared library incorporates that engine.
`rfc822-message.vala:1323–1364` directly calls the parser and traverses its
attachment structures through `bindings/vapi/libytnef.vapi`. Read-only `readelf`
inspection of the existing staged client confirms `NEEDED libytnef.so.0` and
undefined `TNEFParseMemory`, `TNEFInitialize`, `TNEFFree` symbols. The executable
requires that client library. This is neither a separate-process interface nor
mere side-by-side aggregation; dynamic linking does not avoid the issue.

**Licence interpretation.** [GPLv2 §§2(b), 3, 9][gpl2] require the covered whole
on GPL terms and give libytnef's later-version option. [LGPLv2.1 §3][lgpl]
expressly permits applying GPLv2, or a newer published GPL, to a given copy;
§6 also provides compatible linking permissions subject to its conditions.
The [FSF compatibility guidance][compat] identifies LGPLv2.1 as compatible with
GPLv2 and GPLv3; its [linking FAQ][linking] treats static and dynamic linking as
a combined work. Thus **both GPLv2 and GPLv3 are available for this particular
LGPL/libytnef pairing**. GPLv3 is recommended for the future combined release;
GPLv2 is not an interchangeable substitute if the final dependency closure
contains GPLv3-only/otherwise GPLv2-incompatible material. No such separate
GPLv2-only blocker has been established here. Future GPL versions must not be
promised without checking the grants then applicable.

This does **not** turn MIT JavaScript, independent CC images, every source file,
or the entire Flatpak runtime into GPL-only works. Original independently
received LGPL grants remain available; [GPLv3 §5(c)][gpl3] does not invalidate
separately received permissions.

### Two practical release paths — owner chooses, neither implemented

1. **Recommended: retain TNEF; distribute the combined application under GPLv3.**
   Keep the normal source repository's original LGPL notices/grants. Document
   whole-work GPL terms and component exceptions in the release. One explicit,
   licence-text-backed implementation is a **separate release source copy**
   exercising LGPL §3 for the relevant LGPL-derived application code: change
   its operative LGPL references to GPLv3 as §3 directs, retaining copyright,
   change dates and LGPL-origin provenance. That conversion is irreversible
   **for that copy**, not a revocation of other LGPL copies or rights. It is not
   permission to overwrite third-party MIT/CC/dependency licences. A compatible
   linking arrangement retaining component LGPL terms must instead meet the
   applicable LGPL linking conditions. Neither approach requires asking upstream
   for a permission already granted by these licences.

   Include the **GPLv3 text**, original component texts/notices and complete
   corresponding source; make the combined-build AppStream/package/About licence
   description accurately say GPLv3, with component/source distinctions. The
   present `project_license=LGPL-2.1-or-later` alone is misleading for this binary.
   Keep `metadata_license=CC0-1.0`: it concerns metadata, not executable licensing.
   Elect/document the exact release expression; do not silently change the
   repository's source grant or assert that original LGPL rights disappeared.

2. **Alternative: preserve an LGPL-focused application build, without TNEF.**
   Only after owner approval, set **`-Dtnef=disabled`**, omit libytnef and its
   utility programs from the release manifest, rebuild cleanly and verify no
   `libytnef` dependency/parser symbols/payload remain. Leaving a GPL tool in the
   package still creates obligations for that tool, although it need not relicense
   an independent application. Explain loss of decoding attachments inside
   winmail.dat and test the ordinary attachment fallback. Keep original LGPL
   notices; fulfil LGPL requirements below. No feature has been disabled here.

## Source delivery, notices and replacement: concrete release work

For either path freeze one clean application source commit, exact dependency
inputs/patches, generated-source origins, build options and scripts, then map
those to the actual exported binary hash. Include Vala sources/bindings,
resources, subprojects and compilation/installation scripts, not just generated
C, a patch against a moving upstream, or a private repository URL.

For the GPLv3 route use **§6(d) equivalent source access** beside the binary:
complete machine-readable corresponding source, free to copy, with clear exact
version mapping and continued availability. Include the app-specific linked
libraries' required source, especially libytnef; preserve dependency copyright
notices and original licence options. For GPLv2 the analogous route is §3(a)
with its designated-place paragraph; a §3(b) written offer entails at least
three years and rights for **any third party**. Prefer actual source downloads,
not an unsupported offer or an inaccessible private branch.

For LGPL binaries shipped in either package, retain notices/texts and provide
corresponding library source. LGPLv2.1 §§4/6 require the appropriate source and
relink/replacement mechanism: supply application source/object material and
build instructions sufficient to relink (§6(a)/(d)), or demonstrate a suitable
replaceable shared-library mechanism (§6(b)); prohibit neither private
modification nor reverse engineering for debugging it. **A `.so` filename or a
Flatpak signature alone does not establish this.** Explain rebuilding and
installing a modified user build without the maintainer's signing key. GPLv3
§6 Installation Information has an additional condition when conveying in/with
a qualifying User Product transaction; an ordinary standalone software download
is not automatically such a transaction. Never disclose signing secrets.

Record runtime/SDK revisions and source locations too. Do not assume every
GNOME `/usr` library qualifies for the GPL System Library exception. The app
bundle and separately obtained runtime have different distribution boundaries;
if also distributing runtime binaries, account for their own sources/notices.

## Evidence closed, and actual limits

- **Exact dependency texts:** all five cached Git-pinned COPYING files (GOA,
  folks, libpeas, libytnef, Snowball) hash-match the prepared texts. EDS COPYING
  also matches its exact commit. Both cached libical/GMime release archives
  match the manifest SHA-256; all five prepared archive licence files match
  their actual archive members byte-for-byte. Their source/notice correspondence
  is no longer an open question. See [inventory](../THIRD-PARTY-NOTICES.md).
- **EDS terms are not uniformly “LGPL-2.1”.** Exact source headers include
  version-unspecified LGPL (`e-source.c`, `e-book-client.c`, Camel), explicit
  LGPL-2.1-or-later (`e-gdata-query.c`), and LGPL-2.0-or-later
  (`camel-mime-filter-preview.c/.h`). [Exact source][eds]. Version-unspecified
  GNU LGPL grants allow choosing a published version (LGPL §13); they do not
  mean “LGPL-2.0-only” because COPYING prints the 1991 text. The OpenLDAP extract
  has separate OpenLDAP terms, but its backend is disabled by
  `-DWITH_OPENLDAP=OFF`; preserve that exception if providing the full source.
  Keep individual authors/headers, not a fabricated uniform licence label.
- **Dark Reader is resolved:** `ui/darkreader.js` is **byte-identical** to the
  official npm 4.9.105 `package/darkreader.js`; SHA-256
  `310eb026e5c44872cfe0a17e2ed4922904875416311adfcdac3da111a757ecad`.
  Download integrity matches the registry's SHA-512; `gitHead` is
  `51f97ccd34ed0a70832421c2768a19bc46fcec4d`. Its MIT text exactly matches our
  prepared text. The inspected API recipe builds UMD from `src/api/index.ts`;
  the six-file npm API archive has no browser-extension fonts/assets. Its
  manifest lists Malevic, but the shipped API JS has no Malevic/external module
  loader reference; do not invent a bundled font/Malevic payload from that list.
  No downloaded script was run. [Registry record][npm], [API recipe][api].
- **Existing staged package, not this source release:** it contains the dynamic
  TNEF link and original COPYING files, but its licence directory has **no Dark
  Reader MIT notice**. It has no test/ValaUnit-named payload in the inspected
  stage. Static archives and auxiliary tools are present before final cleanup;
  those facts must not be projected onto an uninspected final export. The new
  preparation licence install rules were not present in its exported source
  directory. That directory has no `.git` and the manifest uses mutable
  `type: dir`; it does not establish a clean exact-source mapping.
- The resolved staged manifest records Platform commit
  `aed50acfdad2e6c6c05e1595ddbde3c9e642f967bde41bfa70e3a8d962408541`
  and SDK `8787593c4d75cbdd277a91945eab9185e18de537479eb8401f852d3f746c49c1`.
  The signed `.flatpak` **file SHA-256** is
  `cd4f9d28e7cf635871020ac560c76740a71794d6d47f012e4a366c327f6c00a2`.
  The previously recorded exported/installed **Flatpak OSTree application commit**
  is `7cb988bbfea070a42d0638a9bc132f02f2f007eac1216b48d42cd9f378548f8a`.
  These identify different objects (bundle file versus application tree), were
  recorded together and are consistent; comparing them is **not evidence of
  artifact drift**. No mail/account/profile data or installed application payload
  was read or altered by this audit (only runtime revision metadata). Neither
  the earlier stage nor bundle proves a binary newly built from `9183cc8d3`;
  exact-source mapping and final package inspection remain required. No fresh
  build, exported-package certification or new engineering acceptance is claimed.

## Assets and history: specific findings

`COPYING.icons`/`COPYING.sounds` are preserved **verbatim**. All inherited icons,
screenshots and the sent sound are unchanged versus the public upstream base;
the only added runtime icon is the original LGPL-noticed tray SVG. The sound
`src/client/plugin/sent-sound/message.oga` is installed by that plugin's recipe.

[CC-BY-3.0 §§3(b), 4][by] and [CC-BY-SA-3.0 §§3(b), 4][bysa] require the supplied
author/title/source/license credits, retained notices, and identification of
adaptations; ShareAlike applies to adapted assets, not automatically the whole
independent application collection. Preserve the Noun Project/Sam Hewitt,
GNOME-derivative and Ivica Bukvic credits and links already supplied. Do not
infer a modern GNOME LGPL/CC dual grant for an old asset without its evidence.

The old notice list includes some removed names and does **not** cover every
currently installed icon/RTL variant. In particular, font/format/edit icons,
RTL variants and Convey application icons need a complete path→licence/author
supplement before binary release. History establishes contributors (e.g. Tobias
Bernard's `a69b00ee`, James Westman's `0eed1bb2`, Daniel Elia's app-icon commits),
not by itself a distinct asset-specific grant. Legacy screenshots are in source
history, not README/installed by the icon recipe; their visible-data and complete
per-image rights remain unverified. These are specific attribution/provenance
gaps, **not** evidence that all inherited art is unlicensed or needs new consent.

New brand/hero SVG metadata and provenance records describe original geometry,
synthetic content, local DejaVu rendering and CC0. No stock/Ubuntu art or font
file is bundled; the font licence is not transferred to every rendered image.
CC0 §4(a) expressly excludes trademark rights. This audit changes no artwork.

Historical `ct.out` is the **identical public upstream blob**
`9720a9e06eb5f2a9ef5ea7443c01529c909702c4` at the Convey base and captured
engineering snapshot; GitHub's public upstream contents API confirms that blob.
The reviewed build paths and test-certificate strings are upstream material,
not newly introduced owner secrets. Narrow inspection found no private-key PEM
or credential-assignment markers; this is not a whole-history secret audit.
Removal from the prepared tip does not require an automatic history rewrite.
No private values or personal path strings are reproduced here.

## Name and the only owner/permission decisions

[Canonical policy §§2–4][canonical] keeps component open-source rights separate.
This project is an independent mail app, **not a modified Ubuntu distribution**;
the policy's Ubuntu-image redistribution/recompilation rules are not the code
licence for this app. Section 4 nevertheless claims permission for sufficiently
similar UBUNTU/BUNTU-ending or confusingly similar marks, and restricts actual
Canonical trademarks in software titles. **Griabuntu** ends in BUNTU; adding
“Mail” does not decide similarity. The policy does not establish that every
word containing “buntu” is automatically forbidden, nor does our independence
or a missing exact-name search result establish clearance. No comprehensive
register/territory/domain clearance is claimed.

Owner decisions remaining:

1. Approve **TNEF-on / GPLv3 combined release policy** (recommended), or explicitly
   accept TNEF-off and its feature loss. This is a product/licence-release choice,
   not a request for new Convey/libytnef permission.
2. Authorise sending the [unsent Canonical enquiry](CANONICAL-NAME-PERMISSION-DRAFT.md)
   for a written applicability/permission answer, **or choose another public name**.
   Only Canonical/qualified trademark assessment can settle that unresolved
   name question; this audit cannot promise an answer or legal guarantee.
3. Separately approve eventual public source/binary destinations and identity
   migration after the concrete package/source/asset gates are completed.

Meanwhile private development and compliant source preparation may continue.
Code copyright does not require waiting for a TNEF permission; public branding
still must not be represented as cleared. No publication/contact/merge was done.

[lgpl]: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html
[gpl2]: https://www.gnu.org/licenses/old-licenses/gpl-2.0.html
[gpl3]: https://www.gnu.org/licenses/gpl-3.0.html
[compat]: https://www.gnu.org/licenses/license-list.en.html#LGPLv2.1
[linking]: https://www.gnu.org/licenses/gpl-faq.en.html#GPLStaticVsDynamic
[eds]: https://github.com/GNOME/evolution-data-server/tree/242c81196daf074cdc4c224e48b7b4319985b589/src
[npm]: https://registry.npmjs.org/darkreader/4.9.105
[api]: https://github.com/darkreader/darkreader/blob/51f97ccd34ed0a70832421c2768a19bc46fcec4d/tasks/bundle-api.js
[by]: https://creativecommons.org/licenses/by/3.0/legalcode
[bysa]: https://creativecommons.org/licenses/by-sa/3.0/legalcode
[canonical]: https://canonical.com/legal/intellectual-property-policy
