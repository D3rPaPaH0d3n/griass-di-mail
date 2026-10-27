> Correction recorded during `.4` validation: the old GUI overlay fixture
> selected host executable/library paths while using staged icon lookup. Its
> icon-rendering evidence remains useful, but its assertion of running the
> staged application binary was not established. The corrected byte-checked
> fixture and selected-owner-artwork evidence are in
> [owner-icon-verification.md](owner-icon-verification.md). This `.3` record
> describes the superseded local design, not the owner-selected icon.

# Envelope icon candidate verification · 2026-10-27

Candidate: `griabuntu-mail_51.0+griabuntu20261027.3_amd64.deb`. SHA-256:
`4db3eb4d75c22f457e783a53ec12c9419bd3b024470bc15f30ad5a656f653ac7`.

The owner requested new icons/symbols before system deployment. The package now
uses the original CC0 envelope family from `brand/`, under the independent app
ID `io.github.d3rpapah0d3n.GriabuntuMail`. Older folded-G and inherited artwork
remain archived with their original terms. No production-logo approval is
inferred from implementing this reviewable candidate.

## Actual validation

- Native package build, **328 engine + 62 focused + 10 flag cases**, both desktop
  validators and AppStream validation pass. The cross-component identity check
  also verifies self-contained SVGs, CC0 metadata, all raster dimensions, help
  artwork and filled-path symbolic-source requirements.
- The first engine run exposed its outdated removed-icon fixture path. The
  attachment filename tests now read the canonical SVG; all original filename
  expectations remain unchanged. No failure was marked expected or suppressed.
- The finished package's scalable app/tray/symbolic SVGs, **16/24/32/48/64/128/
  256/512px** app PNGs and installed CC0 notice match their canonical sources
  byte-for-byte. `librsvg2-common` is a declared runtime dependency for SVG lookup.
- The staged payload starts with disposable HOME/XDG, memory GSettings, private
  network/process namespaces, private D-Bus and Xvfb. Its mapped About dialog
  renders the new app icon and name. Actual GTK theme lookup finds all three
  icon names; a gallery renders native app sizes and symbolic/tray variants on
  light/dark swatches. Screenshots are visually inspected.
- That render caught the initial stroke-based symbolic source being filled by
  GTK's symbolic recolouring. It was converted to filled paths with interior
  cutouts; the final real GTK render correctly shows the envelope outline on
  both backgrounds. The package was rebuilt and all tests passed afterward.
- A disposable icon-theme cache emulates native install triggers. Only generic
  read-only system libraries/fonts/CA trust and the staged package are mounted;
  personal mail, accounts, keyrings, host buses and the host display are absent.

The existing nested WebKit/dbus-proxy namespace limitation documented for `.2`
remains outside these icon checks; no WebKit sandbox was disabled. A successful
icon render is not full composer/real-mail or GNOME Shell tray acceptance.

Logs, snapshots and screenshots remain outside version control. This is a
report-only addition after the tested package source snapshot. No live package
installation, host icon/theme setting change or personal-profile migration was
performed. The wider control/theme redesign is separate from this icon family.
