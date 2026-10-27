<!-- Downstream modification: 2026-10-26 — fork-specific development, manifest and source-mapping guidance. -->
<!-- Downstream modification: 2026-10-27 — update notification-flag test expectations. -->
# Building this independent downstream

The primary target is a native Ubuntu 26.10/amd64 `.deb`, with independent
`io.github.d3rpapah0d3n.GriabuntuMail` desktop, D-Bus, GSettings and resource IDs.
Executable/project/gettext domain: `griabuntu-mail`. Engine: `GriabuntuMail`.
Read [the identity map](docs/IDENTITY.md) and [native package instructions](debian/README).
Installation does not copy existing Convey/Flatpak data. Use disposable state
for tests; choose any personal-profile migration separately.

## Native Debian package

```sh
sudo apt-get build-dep .
DEB_BUILD_OPTIONS=parallel=6 dpkg-buildpackage -b -us -uc
```

The private `.deb` is written to the parent directory. `debian/rules` enables
TNEF, uses system libraries, checks the cross-component identity wiring and runs
headless engine/helper/flag tests plus desktop/AppStream validation with isolated
HOME/XDG, network and buses. GTK/WebKit/desktop acceptance is recorded separately.

## Native development

Use [Meson](https://mesonbuild.com/) ≥ 1.7, Ninja, Vala ≥ 0.56 and a recent
Linux development environment. The complete dependency list and minimum
versions are in [meson.build](meson.build): notably GLib ≥ 2.80, GTK ≥ 4.16,
libadwaita ≥ 1.7 and WebKitGTK 6.0 ≥ 2.40. Older distro packages may not suffice.
SQLite needs FTS3 and FTS5. Also install the development packages for the
secondary libraries, gettext, itstool and desktop-file-utils.

From a clean checkout of the **chosen preparation commit**:

```sh
meson setup build -Dprofile=development -Dlibunwind=disabled
meson compile -C build
meson test -C build --print-errorlogs
```

The notification-flag suite now passes all ten cases after the 2026-10-27 fix;
the earlier baseline's four failures are preserved in [test/README.md](test/README.md).
This focused result does not establish that the aggregate test run is green.
Client tests need a display; engine and flag tests can run headless. Test
infrastructure should isolate HOME/XDG, buses and network from personal mail.

The built executable is `build/src/griabuntu-mail`. A full install is required for some
desktop integrations, but **do not install this preview into an existing profile without an explicit migration plan or system prefix**. No new install/run action is performed by these docs.
Meson's `development`, `beta` and `release` profiles affect identity/data paths;
`meson.options` is the source of truth. `release` is not an approval to publish.

## Flatpak practice build

The current downstream manifest is
[`packaging/io.github.d3rpapah0d3n.GriabuntuMail.Practice.yml`](packaging/io.github.d3rpapah0d3n.GriabuntuMail.Practice.yml).
It uses GNOME Platform/SDK **51**, pins eight dependency sources and builds this
checkout via `type: dir`, `path: ..`. Use the official Flatpak Builder already
available in your chosen user/system scope; do not install duplicate SDKs.
For a sandboxed build without installing or running the app:

```sh
flatpak-builder --user --force-clean build-flatpak packaging/io.github.d3rpapah0d3n.GriabuntuMail.Practice.yml
```

`--force-clean` replaces only the designated build directory: choose a fresh one
with no useful contents. The practice build retains the inherited app ID and
is **not a release manifest**. Its local-directory source can include unwanted
untracked files: build only from a reviewed clean export. Never bundle signing
keys, profiles, logs or credentials. Runtime/SDK branch `51` is not an immutable
commit; record both resolved commits for a candidate build.

Original upstream Flatpak templates and publishing automation are archived under
`packaging/historical/` and `docs/history/`; they are not the active downstream
build/publish route. No remote publishing workflow is enabled.

The practice sandbox adds read-only access to the desktop Evolution addressbook
photo cache, not a new avatar provider. Review all final permissions, including
network, desktop files and bus access, before distribution.

## Before distributing any binary

Use [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md) and
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). The owner-approved GPL-3.0-only/TNEF-on release-copy election is implemented;
preserve all application/component notices and close the remaining source/asset
and package-delivery obligations. Record the final source commit, manifest/build options,
dependency revisions, runtime/SDK commits and binary hashes. Provide complete
corresponding source with equivalent access next to the binary. Inspect the
actual staged and exported package for installed notices and shipped libraries.
No existing binary is certified by this source-preparation work.

## Updating vendored Dark Reader

`ui/darkreader.js` identifies Dark Reader 4.9.105. Do not replace it with an
unversioned CDN download. Select a reviewed exact release, retain its MIT notice
and source/build provenance, verify the generated API file and update
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). The existing JS is already verified byte-identical to official npm 4.9.105;
retain that exact provenance when changing it.

---
Original notices retained:
Copyright © 2016 Software Freedom Conservancy Inc.
Copyright © 2018–2020 Michael Gratton <mike@vee.net>


## Separate GPLv3 release-copy preparation

This branch is not the original LGPL preparation and does not certify the old
private prototype bundles. See [GPLV3-COPY.md](docs/release/GPLV3-COPY.md),
[VERIFICATION.md](docs/release/VERIFICATION.md) and
[CORRESPONDING-SOURCE.md](docs/release/CORRESPONDING-SOURCE.md). TNEF is explicitly
`enabled`; release metadata is GPL-3.0-only, metadata CC0 unchanged. The corrected
notice-install rule copies ValaUnit's original COPYING into `docs/licenses/`
without changing ValaUnit or trying to access files across Meson subproject scope.
