# Native Griaß di Mail corresponding-source delivery · 2026-10-28

The current distribution is a native Ubuntu 26.10 amd64 .deb, not a Flatpak
runtime bundle. The historical procedure below describes earlier private work.
The source-delivery route for the public preview is GPLv3 §6(d): equivalent
machine-readable source access next to the binary, including clear locations
where exact distribution dependency sources are available on other servers.

Each release carries the exact complete application `.tar.xz` plus `.dsc`,
source commit/BUILD-MANIFEST.json, binary/source SHA256SUMS, buildinfo/changes,
Dark Reader preferred-source companion and native libytnef source companion.
The application archive includes all preferred-form Vala/C/JS/CSS/VAPI/resources,
translations, vendored subprojects, original notices and Debian build/test rules.
No generated-C-only substitution, private Git URL, signing key or mail profile
is used as source delivery. The public source tree retains full upstream history.

## Exact native library sources

`NATIVE-SOURCES.json` beside the binary records 134 resolved Ubuntu runtime
binary packages, their exact versions, and 104 source packages (351 source-file
URLs, approximately 632 MB). It was derived from the actual native application,
plugin and WebKit-extension ELF dependency closure, using Ubuntu's cached source
metadata. The available strong archive checksums are SHA-512 or SHA-256 as
explicitly labelled in each entry. This is a source-location index, not a copied
runtime or a claim that every `/usr` library is automatically exempt.

All 351 HTTPS source-file locations were checked reachable before publication.
The adjacent `fetch-native-sources.py` downloads and verifies exact size/checksum
without executing inputs; the real libytnef source-fetch/checksum path was tested.
A copy of the index and helper is also in the application source archive:

```sh
python3 build-aux/fetch-native-sources.py docs/release/NATIVE-SOURCES-20261028.json --list
python3 build-aux/fetch-native-sources.py docs/release/NATIVE-SOURCES-20261028.json native-dependency-sources
```

Or use the standalone `fetch-native-sources.py NATIVE-SOURCES.json` release
assets. `--package libytnef` limits a download; `--verify-existing` verifies local
files without network. Ubuntu source packages preserve original component
notices and Debian patches; do not replace them with a generic top-level licence.
Maintainers must keep corresponding-source access available alongside continued
binary distribution, checking/mirroring sources if upstream locations change.

## Rebuilding and replacing libraries

The release's normal instructions use `sudo apt-get build-dep .` and
`DEB_BUILD_OPTIONS=parallel=6 dpkg-buildpackage -b -us -uc` on Ubuntu 26.10.
The maintainer's rootless environment limitations and separate tests are recorded
honestly in the release manifest. Source/headers/VAPI/build rules are available;
there is no requirement to use the maintainer's signing key, account or service
to build/install a modified app. Native shared libraries remain ordinary distro
libraries; modified user builds are not forbidden or tied to a signature check.
No OS/runtime image, hardware product or anti-tamper installation restriction is
being distributed. These practical controls do not promise bitwise reproduction.

## Historical private Flatpak preparation procedure

# Corresponding source and internal build controls

This is a preparation procedure, **not a public source offer or download**.
The elected application copy is GPL-3.0-only; components retain their own terms.
The intended distribution method is **GPLv3 §6(d): equivalent machine-readable
source access at the same place as each eventual binary**, at no further charge.
Do not distribute a binary with only a private GitHub URL or a moving upstream.

## Freeze and rebuild an exact copy

1. Select the tested application **source commit**, not merely the reporting
   branch tip; use the exact value recorded in `VERIFICATION.md`. Preserve it
   and the complete inherited history. Produce a clean archive with
   `git archive --format=tar --prefix=convey-source/ <source-commit>` and record
   its SHA-256 separately from binary hashes and OSTree commits. Git exports
   exclude ignored logs, credentials, profiles, build output and signing keys.
2. Preserve the exact practice recipe, generated build-input manifest and its
   SHA-256. For internal package inspection, replace only the application's
   mutable `type: dir` source with that local archive, `strip-components: 1` and
   its SHA-256. Retain all pinned dependency commits/archive checksums and make
   TNEF explicitly `enabled`. Record every option and resolved Platform/SDK
   commit, not just GNOME branch 51. No technical app-ID migration is implied.
3. Reuse the official system Flatpak Builder and GNOME SDK 51. Do not duplicate
   SDKs, update dependencies or use production signing/repository directories.
   Build in fresh source/stage/log directories with `--disable-rofiles-fuse
   --disable-updates --build-only`. Run focused synthetic tests in that staged
   dependency environment, with temporary HOME/XDG, memory GSettings, no network,
   no host buses/display and a private `dbus-run-session`. Keep known-red flag
   cases separate; do not weaken GTK/WebKit isolation to force a green result.
4. To inspect an internal package, **finish/export the same tested stage** with
   `--finish-only --repo=<separate-temporary-repo>` and the same immutable input
   manifest. Inspect the resulting OSTree tree and metadata. If making an unsigned
   internal bundle, use that repo/commit only; hash the bundle file separately.
   Do not install, launch, sign, upload or call the practice signing homedir.

The actual frozen source, manifest/runtime revisions and evidence are in
[VERIFICATION.md](VERIFICATION.md). A reporting-only descendant does not make a
binary built from a different source commit; describe that distinction plainly.

## What a recipient must receive before public binary distribution

- The complete exact application source archive: Vala/C/JS/CSS, VAPI/interface
  definitions, resources, translations, data/schema files, test subprojects,
  original notices, generated-source origins and scripts controlling compilation
  and installation. Do not substitute generated C alone or a patch against a
  moving upstream. Provide readable modification/election records and GPL text.
- Exact sources for the app-specific linked components in the manifest (GOA,
  libical, EDS, folks, GMime, libpeas, libytnef and Snowball), including any
  applied patches, generator inputs/build recipes, their authorship and licence
  exceptions. Preserve the original complete upstream archive/Git snapshots;
  do not remove OpenLDAP-source notices just because that backend is disabled.
  The Builder download/Git caches are inputs to assembling delivery, **not** a
  recipient-accessible source service and not yet a complete public source set.
- Dark Reader's exact npm 4.9.105 API file and MIT notice, plus the corresponding
  exact `51f97ccd34ed0a70832421c2768a19bc46fcec4d` source/build recipe and relevant
  build inputs. The included generated JS's byte identity is established; that
  alone is not the full preferred-form source/build-input delivery.
- Resolved runtime/SDK identities and their source availability. Determine the
  actual distribution boundary and GPL System Library applicability; do not
  automatically label everything in `/usr` exempt. If distributing a runtime
  too, meet its independent corresponding-source/notice obligations.
- Instructions enabling a recipient to rebuild, relink/replace applicable
  LGPL libraries and install a modified **user build without the maintainer's
  signing key**. Do not impose restrictions on modification/reverse engineering
  for debugging. Verify that mechanism before publication; a `.so` suffix or
  signature alone is not proof. Review GPLv3 §6 Installation Information if a
  qualifying User Product transaction is involved; never disclose signing keys.
- A mapping record containing source archive/manifest SHA-256, source commit,
  options, dependency/runtime revisions, unsigned/signed binary file SHA-256
  (as applicable) and exported OSTree application commit as **different fields**.
  Source and binary access must remain equivalent for the actual distribution.

No complete recipient source bundle, rebuild/replacement acceptance, public
hosting or legal-compliance certification is claimed by this private work.
Asset/provenance, desktop engineering, name/identity/privacy and explicit
publication gates in `RELEASE-CHECKLIST.md` still apply. No Canonical contact,
repository visibility change, public artifact or application install is authorised.
