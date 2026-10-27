# Griabuntu Mail · owner-selected closed envelope

On 2026-10-27 the owner selected the **closed coloured envelope** from their six
supplied originals in [design/owner-artwork-20261027](../design/owner-artwork-20261027/).
The open-envelope variants are preserved but are not installed as the app icon.

- App: exact `envelope-closed-color.png`, plus 16, 24, 32, 48, 64, 128, 256 and
  512 pixel exports. The SVG is a self-contained wrapper embedding the exact
  original PNG, **not an editable vector recreation**. Nightly uses the same
  approved art; no alternative palette has been invented.
- Tray: same closed coloured artwork.
- Symbolic: filled silhouette of the supplied `envelope-closed-mono.png` alpha
  mask at threshold 128. GTK applies foreground colour for light/dark themes.
- Help: exact copy of the app SVG wrapper.
- About banner: the exact supplied `brand-banner.png` is embedded in GResource
  and displayed at 480 × 160 logical pixels in the native About dialog.
  Credits, licence and version remain native GTK content.
- Logo lockup: preserved presentation original; no new lockup drawn.

Regenerate technical exports with `/usr/bin/python3 build-aux/render-brand.py`.
The originals remain byte for byte intact with their recorded SHA-256 hashes.

The supplied files came from the owner's separate design chat. No licence or
human authorship is inferred from the older artwork's CC0 notices. `COPYING`
remains the historical CC0 text for earlier studies only; it does not establish
terms for these newly supplied images. The installed artwork notice preserves
this distinction.

The mistakenly substituted local envelope study is preserved under
`history/superseded-envelope-20261027/`; the earlier folded-G study is under
`history/folded-g-20261026/`. Their original provenance and grants remain intact.
The `.3` package verification describes the superseded study, not this icon.
