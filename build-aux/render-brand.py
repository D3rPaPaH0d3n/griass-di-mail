#!/usr/bin/python3
"""Export the owner's chosen closed-envelope PNG without redrawing it.

Downstream code: 2026-10-27. GPL-3.0-only; see COPYING.
Artwork provenance is separate; see brand/README.md.
"""
from pathlib import Path
import base64
import shutil
import gi
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf
ROOT = Path(__file__).resolve().parent.parent
BRAND = ROOT / "brand"
ORIGINALS = ROOT / "design/owner-artwork-20261027"
SIZES = (16, 24, 32, 48, 64, 128, 256, 512)


def main():
    source = ORIGINALS / "envelope-closed-color.png"
    encoded = base64.b64encode(source.read_bytes()).decode("ascii")
    # A self-contained raster wrapper, explicitly not a newly drawn vector.
    wrapper = ('<svg xmlns="http://www.w3.org/2000/svg" '
               'xmlns:xlink="http://www.w3.org/1999/xlink" '
               'width="1254" height="1254" viewBox="0 0 1254 1254">'
               '<title>Owner-selected closed Griabuntu Mail envelope</title>'
               '<metadata>Unmodified owner-supplied PNG, 2026-10-27. '
               'Raster wrapper; see Griabuntu-Mail-Artwork.md for provenance. '
               'No inherited CC0 claim.</metadata>'
               '<image width="1254" height="1254" xlink:href="data:image/png;base64,'
               + encoded + '"/></svg>')
    pixbuf = GdkPixbuf.Pixbuf.new_from_file(str(source))
    for basename in ("griabuntu-mail-app-icon", "griabuntu-mail-app-icon-nightly"):
        (BRAND / (basename + ".svg")).write_text(wrapper)
        shutil.copyfile(source, BRAND / (basename + ".png"))
        for size in SIZES:
            scaled = pixbuf.scale_simple(size, size, GdkPixbuf.InterpType.HYPER)
            scaled.savev(str(BRAND / f"{basename}-{size}.png"), "png", [], [])
    (BRAND / "griabuntu-mail-tray.svg").write_text(wrapper)
    # Use the supplied mono artwork's alpha silhouette. Each run follows the
    # original pixel mask; filled geometry lets GTK recolour the symbolic icon.
    mono = GdkPixbuf.Pixbuf.new_from_file(str(ORIGINALS / "envelope-closed-mono.png"))
    assert mono.get_has_alpha() and mono.get_n_channels() == 4
    pixels = mono.get_pixels(); stride = mono.get_rowstride()
    paths = []
    for y in range(mono.get_height()):
        start = None
        for x in range(mono.get_width() + 1):
            filled = x < mono.get_width() and pixels[y * stride + x * 4 + 3] >= 128
            if filled and start is None:
                start = x
            elif not filled and start is not None:
                paths.append(f"M{start} {y}h{x-start}v1H{start}z")
                start = None
    symbolic = ('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" '
                'viewBox="0 0 1254 1254"><title>Closed Griabuntu Mail symbolic envelope</title>'
                '<metadata>Alpha silhouette of owner-supplied envelope-closed-mono.png; '
                'threshold 128, unchanged canvas. See Griabuntu-Mail-Artwork.md.</metadata>'
                '<path fill="#2e3436" d="' + ''.join(paths) + '"/></svg>')
    (BRAND / "griabuntu-mail-symbolic.svg").write_text(symbolic)
    shutil.copyfile(BRAND / "griabuntu-mail-app-icon.svg",
                    ROOT / "help/C/figures/io.github.d3rpapah0d3n.GriabuntuMail.svg")
    print("Exported chosen owner PNG, native sizes, tray and theme-aware mono silhouette.")

if __name__ == "__main__":
    main()
