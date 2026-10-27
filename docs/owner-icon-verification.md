# Owner-selected closed envelope · native package verification

2026-10-27. This corrects the mistaken local envelope study in package `.3`.
The owner explicitly selected the **closed coloured envelope** supplied in
`design/owner-artwork-20261027/`. No new open/closed design was invented.

## Artifact and original fidelity

- Package: `griabuntu-mail_51.0+griabuntu20261027.4_amd64.deb`.
- SHA-256: `17c140f2b3dbebbea0c72ad79a38fbbf0391a209dcc10607282829726c473d13`.
- All six supplied PNG hashes match their committed `SHA256SUMS`.
- The active app PNG is byte-identical to `envelope-closed-color.png`.
- App/nightly/tray SVGs embed that exact PNG; they are raster wrappers, not
  new editable vector artwork. Eight native PNG sizes are exported.
- The symbolic filled-path mask follows the supplied closed mono alpha at
  threshold 128, with the same canvas. GTK recolours it in light/dark contexts.
- Earlier artwork and provenance are preserved in `brand/history/`.

## Validation

Native `dpkg-buildpackage -b -us -uc` completed with TNEF and libunwind enabled.
The existing isolated suites passed **328 engine + 62 helper + 10 flag cases**,
plus two desktop-file validations, AppStream validation and identity/source
checks. The independent engine attachment fixture now references the preserved
small historical SVG, keeping its original assertions independent of branding.

The extracted final package was exercised in a disposable HOME/XDG namespace,
private bus and Xvfb display without personal state or host network access.
App, tray and symbolic GTK icon lookup passed. Actual fresh-start/About windows
and an icon gallery at 16–128 px with light/dark symbolic swatches were rendered
and inspected. About displayed the exact `.4` revision and selected envelope.

The first GUI fixture run was discarded: overlay ordering had selected the host
`.3` binary while looking up staged icons. The corrected run puts packaged
`/usr` above the host layer and asserts byte equality of both the running
executable path and private client-library path against extracted package files.
This distinction corrects the fixture used by earlier icon reports; icon lookup
alone does not prove which executable/private library was exercised.

The broader WebKit/JS suite remains outside this check: the earlier namespace
restriction was not worked around by weakening the sandbox. No wider GTK
control/theme redesign or personal-profile migration is claimed.

## Installation scope

The package updates the existing native Griabuntu Mail identity and icon paths.
It does not migrate profiles or keyrings or change the default mail handler.
APT simulation showed one upgrade, no dependency installs and no removals.
