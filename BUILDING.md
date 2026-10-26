<!-- Downstream modification: 2026-10-26 — fork-specific development, manifest and source-mapping guidance. -->
# Building this independent downstream

This is a source preview, not an independently installable public release.
The inherited `net.donnybeelo.Convey` / `.Devel` IDs and profile locations still
overlap upstream. Use a disposable test environment and synthetic data; do not
launch it against a valuable existing account/profile. See [BRANDING.md](docs/BRANDING.md).

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

The aggregate test run is currently expected to fail the four known
notification-flag baseline cases, not to be fully green. See [test/README.md](test/README.md).
Client tests need a display; engine and flag tests can run headless. Test
infrastructure should isolate HOME/XDG, buses and network from personal mail.

The built executable is `build/src/convey`. A full install is required for some
desktop integrations, but **do not install this preview into an existing upstream
profile or system prefix**. No new install/run action is performed by these docs.
Meson's `development`, `beta` and `release` profiles affect identity/data paths;
`meson.options` is the source of truth. `release` is not an approval to publish.

## Flatpak practice build

The current downstream manifest is
[`packaging/net.donnybeelo.Convey.Practice.yml`](packaging/net.donnybeelo.Convey.Practice.yml).
It uses GNOME Platform/SDK **51**, pins eight dependency sources and builds this
checkout via `type: dir`, `path: ..`. Use the official Flatpak Builder already
available in your chosen user/system scope; do not install duplicate SDKs.
For a sandboxed build without installing or running the app:

```sh
flatpak-builder --user --force-clean build-flatpak packaging/net.donnybeelo.Convey.Practice.yml
```

`--force-clean` replaces only the designated build directory: choose a fresh one
with no useful contents. The practice build retains the inherited app ID and
is **not a release manifest**. Its local-directory source can include unwanted
untracked files: build only from a reviewed clean export. Never bundle signing
keys, profiles, logs or credentials. Runtime/SDK branch `51` is not an immutable
commit; record both resolved commits for a candidate build.

The top-level `net.donnybeelo.Convey.yml` is an inherited upstream template with
`INSERT_COMMIT_SHA_HERE` and an upstream source URL; it does **not** build this
fork. `net.donnybeelo.Convey.Devel.json` has moving dependencies/master runtime,
broader permissions and test sandbox overrides; do not use it as a public
release recipe. They are retained for history, not advertised as downloads.

The practice sandbox adds read-only access to the desktop Evolution addressbook
photo cache, not a new avatar provider. Review all final permissions, including
network, desktop files and bus access, before distribution.

## Before distributing any binary

Use [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md) and
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). Resolve the GPL-licensed
`libytnef` combination or explicitly approved feature/build choice; preserve all
original notices. Record the final source commit, manifest/build options,
dependency revisions, runtime/SDK commits and binary hashes. Provide complete
corresponding source with equivalent access next to the binary. Inspect the
actual staged and exported package for installed notices and shipped libraries.
No existing binary is certified by this source-preparation work.

## Updating vendored Dark Reader

`ui/darkreader.js` identifies Dark Reader 4.9.105. Do not replace it with an
unversioned CDN download. Select a reviewed exact release, retain its MIT notice
and source/build provenance, verify the generated API file and update
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). Correspondence of the existing
vendored generated file to its claimed release remains an explicit audit gate.

---
Original notices retained:
Copyright © 2016 Software Freedom Conservancy Inc.
Copyright © 2018–2020 Michael Gratton <mike@vee.net>
