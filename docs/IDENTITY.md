<!-- Current icon correction, 2026-10-27: The owner selected the CLOSED COLOURED
ENVELOPE in design/owner-artwork-20261027/. Active exports in brand/ preserve
that supplied PNG. The previously installed .3 icon study was a mistaken
substitution and is superseded. Do not reuse its CC0 claim for owner originals.
See brand/README.md. Broader UI theming remains separate. -->

# Griabuntu Mail identity · 2026-10-27

The owner requested a complete project naming change after choosing native
Ubuntu packaging. This is the current identity; the 2026-10-26 handoff/release
records describe earlier named commits and packages. The repository remains
private; naming work is not public-release or Canonical-contact approval.

| Component | Current name |
| --- | --- |
| Product / translated launcher name | **Griabuntu Mail** |
| Private repository | `D3rPaPaH0d3n/griabuntu-mail` |
| Native package, Meson project, executable, gettext and help domain | `griabuntu-mail` |
| Desktop file, D-Bus service, portal identity and icon basename | `io.github.d3rpapah0d3n.GriabuntuMail` |
| GSettings schema and secret-service schema | `io.github.d3rpapah0d3n.GriabuntuMail` |
| GSettings path / GResource prefix | `/io/github/d3rpapah0d3n/GriabuntuMail/` (resource prefix without trailing slash) |
| Vala engine namespace / generated C prefix | `GriabuntuMail` / `griabuntu_mail_` |
| Private engine/client library basename | `griabuntu-mail-engine` / `griabuntu-mail-client-51.0` |
| Native private library/plugin directory | `/usr/lib/<multiarch>/griabuntu-mail/` |
| Account settings / mail database filename | `griabuntu-mail.ini` / `griabuntu-mail.db` |
| Release config/data/cache basename | `griabuntu-mail` below the corresponding XDG directories |
| Internal WebKit scheme | `griabuntu-mail:` |
| JavaScript state object / native bridge | `griabuntu_mail` / `_GriabuntuMailWebExtension` |

The GitHub account part of the reverse-DNS ID uses lowercase; the product part
is `GriabuntuMail`. Development/beta app IDs retain their `.Devel`/`.Beta`
suffixes. The repository URL, About/support links, desktop actions, autostart
template, help figures, translation references and optional local Flatpak
practice recipe use the same current identity. The GitHub repository rename
keeps its repository ID, privacy, default branch and existing history.

## Compatibility and provenance

- `Convey` and `Geary` remain in authorship/origin descriptions and original
  copyright/licence texts. Upstream project URLs and the historical release
  records are evidence, not this project's current support or publishing route.
- `org.yorba.convey` remains an inherited legacy schema/keyring lookup key;
  changing its spelling would stop recognising that historical key. It is not
  the application ID or the schema for newly saved credentials/preferences.
- SQLite registers the old `convey_tokeniser` and `convey_matches` names as
  aliases alongside the new functions. Persisted FTS5 definitions can contain
  those names. An isolated database regression test exercises old/new tokenizer
  names. Registering an alias never opens or copies a personal database.
- Runtime app/tray/symbolic icons derive from the owner's selected closed
  envelope in `design/owner-artwork-20261027/`, with technical exports in
  `brand/`. The SVG wrapper embeds the exact supplied PNG; the symbolic mask
  comes from the supplied mono variant. Earlier local studies and inherited
  aliases remain archived with original provenance. See `brand/README.md`.
  GTK toolbar icons remain native/system icons.
- `docs/history/` and `packaging/historical/` contain explicitly archived upstream
  templates, metadata and publishing material. No publishing workflow is enabled.
- `docs/release/`, `docs/licenses/`, the original conversion inventory, AUTHORS,
  THANKS, NEWS, COPYING* and third-party sources keep their original evidence.
  [The path map](identity-path-map.tsv) connects renamed source/asset paths to
  the originals; frozen old hashes are not attributed to the new build.

## Profiles and deployment

The new app uses separate release paths, normally `~/.config/griabuntu-mail`,
`~/.local/share/griabuntu-mail` and `~/.cache/griabuntu-mail`. It does not search
the old native/Flatpak Convey directories as its own profile, and package
scripts do not copy or delete them. Existing migration helpers retain explicitly
historical lookup keys; no personal migration is performed by this source work.

Installing an upgraded `griabuntu-mail` package replaces old package-owned
`convey` executables and desktop files. Existing per-user overrides may still
refer to those old files and must be handled when deploying. A running old
process also retains its old identity until it exits. Preserve stopped-app
backups and choose fresh setup or deliberate migration separately; do not
silently symlink two installations to the same live mail store.

## Checks

`python3 build-aux/check-identity.py` checks the schema, desktop activation,
resource prefix, namespace, translation source paths, product-name translations
and JavaScript/native bridge wiring. The native package test runner includes it
before the isolated headless suites. GTK/WebKit and visible fresh-start checks
use synthetic state, a private bus/display and no access to personal profiles.

Neither a successful identity build nor native package installation resolves
the separate public-name, inherited-asset/source-delivery or release decisions.
