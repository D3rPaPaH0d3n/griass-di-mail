# Artwork inventory and retained attribution · 2026-10-28

Scope: all 23 installed/GResource action SVGs, current app/tray/banner, sent sound,
and retained historical source artwork/screenshots. This is a practical licence
inventory based on upstream published grants and Git evidence, not a warranty
of title or a claim that the importing committer created every geometric path.

Original `COPYING.icons` / `COPYING.sounds`, SVG metadata and full source history
are retained. This mapping fixes renamed/plural/RTL paths absent from the old
list. Unheaded project contributions use the project's original root COPYING at
the import commits (LGPL-2.1-or-later), followed by this copy's recorded LGPL §3
GPLv3 election. An absent individual header alone does not negate that project
grant. No contrary file-specific terms were found in those listed project SVGs.

GNOME's 3.8.0 COPYING (before the 2013 edit import) and 3.14.1 COPYING explicitly
offer LGPLv3 or CC BY-SA 3.0. Both original notices, LGPL text and collective
AUTHORS are supplied. GNOME's attribution instruction is **GNOME Project** with
https://www.gnome.org. Keep the explicit inherited CC-BY-SA exception for detach
and drafts; the LGPLv3 option is retained for other GNOME-derived work alongside
project adaptations. These theme notices establish grants, not an assertion of
byte identity to every adapted historical icon or a blanket relicensing.

## Installed action icons

Paths are relative to `icons/`. Original Noun Project creator URLs remain in
`COPYING.icons`. Import/contribution commits are evidence, not sole authorship.

| File | Retained licence basis | Attribution / adaptation credits | Addition record |
| --- | --- | --- | --- |
| `mail-archive-symbolic.svg` | CC-BY-3.0 base; retain later project modification credits | Sam Hewitt (2013); Tobias Bernard refinements | `86316e18` |
| `close-symbolic.svg` | CC-BY-3.0 base; retain later project modification credits | Icomatic | `bb72647b` |
| `detach-symbolic.svg` | CC-BY-SA-3.0, including adaptation/RTL | GNOME Project; Robert Schroll adaptation | `bc296521` |
| `text-x-generic-symbolic.svg` | CC-BY-3.0 base; retain later project modification credits | Edward Boatman / The Noun Project | `86316e18` |
| `edit-symbolic.svg` | GNOME LGPL-3.0 option; retain project adaptation terms | GNOME Project; Alexander Wilms import / Tobias Bernard refinement | `83306674` |
| `font-size-symbolic.svg` | Project LGPL-2.1-or-later origin → elected GPL-3.0-only copy | James Westman | `0eed1bb2` |
| `font-color-symbolic.svg` | Project LGPL-2.1-or-later origin → elected GPL-3.0-only copy | James Westman | `0eed1bb2` |
| `format-ordered-list-symbolic.svg` | GNOME LGPL-3.0 option; retain project adaptation terms | GNOME Project; Nikolas Tapia adaptation | `63521d85` |
| `format-ordered-list-symbolic-rtl.svg` | GNOME LGPL-3.0 option; retain project adaptation terms | GNOME Project; Nikolas Tapia / Michael Gratton adaptations | `2642119c` |
| `format-text-remove-symbolic.svg` | CC-BY-3.0 base; retain later project modification credits | Sam Hewitt (Moka Symbolic Icon Theme) | `bb72647b` |
| `format-toolbar-toggle-symbolic.svg` | Project LGPL-2.1-or-later origin → elected GPL-3.0-only copy | James Westman | `c53b1b0a` |
| `format-unordered-list-symbolic.svg` | GNOME LGPL-3.0 option; retain project adaptation terms | GNOME Project; Nikolas Tapia adaptation | `63521d85` |
| `format-unordered-list-symbolic-rtl.svg` | GNOME LGPL-3.0 option; retain project adaptation terms | GNOME Project; Nikolas Tapia / Michael Gratton adaptations | `2642119c` |
| `mail-drafts-symbolic.svg` | CC-BY-SA-3.0, including adaptation/RTL | GNOME Project; Michael Gratton adaptation | `095049f8` |
| `mail-drafts-symbolic-rtl.svg` | CC-BY-SA-3.0, including adaptation/RTL | GNOME Project; Michael Gratton / Jeremy Bicha adaptations | `509b6695` |
| `mail-inbox-symbolic.svg` | CC-BY-3.0 base; retain later project modification credits | Edward Boatman / The Noun Project; Tobias Bernard refinements | `86316e18` |
| `mail-outbox-symbolic.svg` | CC-BY-3.0 base; retain later project modification credits | Edward Boatman / The Noun Project, Inbox derivative; Tobias Bernard refinements | `86316e18` |
| `mail-reply-list-symbolic.svg` | Project LGPL-2.1-or-later origin → elected GPL-3.0-only copy | Daniel Elia (Dan), Convey | `7d685ccc` |
| `mail-reply-list-symbolic-rtl.svg` | Project LGPL-2.1-or-later origin → elected GPL-3.0-only copy | Daniel Elia (Dan), Convey | `7d685ccc` |
| `mail-sent-symbolic.svg` | CC-BY-3.0 base; retain later project modification credits | Sam Hewitt; Tobias Bernard refinements | `86316e18` |
| `mail-sent-symbolic-rtl.svg` | CC-BY-3.0 base; retain later project modification credits | Sam Hewitt; Jeremy Bicha / Tobias Bernard adaptations | `509b6695` |
| `tag-symbolic.svg` | Ian Hamilton original public domain; later project adaptations retain GPLv3-copy terms | Ian Hamilton (2012); Jeremy Bicha / Tobias Bernard adaptations | `bb72647b` |
| `tag-symbolic-rtl.svg` | Ian Hamilton original public domain; later project adaptations retain GPLv3-copy terms | Ian Hamilton (2012); Jeremy Bicha / Tobias Bernard adaptations | `509b6695` |

All action SVG bytes remain unchanged from the inherited code. CC-BY base credits
and links remain on adaptations; CC-BY-SA icons/sound remain under their separate
asset terms. Application GPL election does not overwrite these terms. Full CC
BY/SA 3.0 legal codes are supplied as well as original notice URLs. The older
`mail-draft-symbolic.svg` notice corresponds to the plural current draft files.

## Current app artwork and sound

- App/tray/symbolic icon and title banner: see
  [ARTWORK-PROVENANCE.md](ARTWORK-PROVENANCE.md). The standalone selected envelope
  is byte-identical to the original; the banner is a documented AI-edited
  derivative. All six supplied originals retain their hashes. Earlier CC0 studies
  are separate works under their own original terms.
- `src/client/plugin/sent-sound/message.oga`: Ivica Bukvic, “Borealis” sound theme,
  CC-BY-SA-3.0 as recorded in original `COPYING.sounds`. The file is unchanged
  from upstream; the original notice and full CC legal code are supplied.

## Historical/source-only material

- Historical Convey/Geary app SVGs and `icons/gitlab-icon.svg` are retained source
  records, not active installed app icons. Keep their original project
  LGPL-2.1-or-later distribution basis, authorship and metadata. The original
  LGPL text is also supplied separately for those source records. Historical
  product names/logos describe the inherited source, not an endorsement claim.
- `desktop/screenshots/{main-window,conversation,composer}.png` are byte-identical
  to the public Convey source commit below and were visually inspected. They
  show demo/example accounts and no newly introduced owner mailbox data. They
  are not current Griaß di Mail marketing screenshots. The composer screenshot's
  street photograph is retained as part of that upstream-provided screenshot
  under its original project distribution basis; no separate stock-photo
  ownership or independent rights investigation is claimed.
- Existing test images retain their original project/file terms and sources.

## Primary provenance

- Public Convey base and original project grant:
  https://github.com/donnybeelo/convey/tree/d24c1da859fc9cc2cfb19872b1d8e972d4dc1a20
- Original explicit asset grants: `COPYING.icons` and `COPYING.sounds` in that
  source/history; reproduced before the new filename/RTL mapping addendum.
- GNOME original grants and attribution:
  https://github.com/GNOME/adwaita-icon-theme/blob/3.8.0/COPYING
  https://github.com/GNOME/adwaita-icon-theme/blob/3.14.1/COPYING
  https://github.com/GNOME/adwaita-icon-theme/blob/3.14.1/AUTHORS
- CC terms: https://creativecommons.org/licenses/by/3.0/ and
  https://creativecommons.org/licenses/by-sa/3.0/ . Full legal texts use the
  official SPDX text mirror; original GNOME wording is preserved separately.
  Later Moka releases do not revoke these copies' original recorded grants.

## Evidence boundary

This review supplies the applicable project/work grants, credits, source and
modification notices. No exact unrecorded historic import revision is invented.
An incomplete earlier inventory is not itself proof that inherited distribution
is forbidden. The release may rely on published upstream grants, while retaining
those precise historical limits. This does not establish universal trademark
clearance or independently guarantee every upstream contributor's underlying
rights. Record concrete contrary evidence if it arises; do not substitute an
unbounded audit for actual source and notice obligations.
