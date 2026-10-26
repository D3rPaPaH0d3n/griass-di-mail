# Separate GPLv3 release-source copy · 2026-10-26

**Private preparation, not a public release or permission to install.** Markus
approved the TNEF-on/GPLv3 route (“Ja passt!”) on **2026-10-26 at 19:56 UTC**.
This branch implements that election; it is no longer awaiting an owner licence
choice. The exact application release-copy expression is **GPL-3.0-only**, not
GPL-3.0-or-later. All functions, including Outlook/winmail.dat (TNEF), remain.

## Election, scope and independently preserved originals

Under **LGPL version 2.1 §3**, this given copy of the LGPL-derived application
is placed under **GNU GPL version 3 only**. The operative application licence
notices, translation grants and release metadata have been changed accordingly;
original copyright/author names and historical change dates are retained. New
notice/metadata changes are dated **2026-10-26**. The election is irreversible
**for this elected copy**. It does not withdraw rights already granted in other,
independently received LGPL copies, nor relicense unrelated components.

Original independently preserved sources in the private repository:

- original downstream/main: `5834da28091fb951ba3f53dd610d2f30fa352135`;
- original LGPL preparation: `9183cc8d3d49b2463ad033203719c08afbe19552`, branch
  `openclaw/convey-publication-prep`;
- corrected audit input to this separate branch:
  `465e0c6c15233009a7e84ab60a783a3a1fb4a4e0`;
- elected copy branch: `openclaw/griabuntu-gplv3-release-prep`.

These histories are not merged, rewritten or revoked. Their independent LGPL
permissions remain available to their recipients. Before public distribution,
make the original version references accessible if describing them as public
source; private repository URLs are not delivery to unauthorised recipients.

`COPYING` is the unmodified official GPLv3 text, copied from the system
`/usr/share/common-licenses/GPL-3` (FSF version 3, 29 June 2007), SHA-256
`3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986`.
`COPYING.LGPL-2.1-original` preserves the **entire original root COPYING
byte-for-byte**, including its historical LGPL grant preamble. It is an origin
reference, **not an alternative operative grant for this elected application
copy**. The GPL text's illustrative “or any later version” example is not an
application grant: our operative notices and metadata specify version 3 only.

## Notice inventory and component boundaries

Before editing, the original operative grants and Git blobs were inventoried
in [LGPL3-CONVERSION.tsv](LGPL3-CONVERSION.tsv): **552** application/binding/test/
JavaScript/CSS files and **40** translation files. The uniform short LGPL
notices, the full Nokia/Tracker LGPL boilerplate, and downstream SPDX-style
notices permit §3. Translation notices granting LGPL 2.1 likewise permit §3;
no later-LGPL grant is invented. The TSV records original blobs at `465e0c6`.
Other operative changes are root COPYING, Meson `license`, AppStream
`project_license`, the About dialog (`GPL_3_0_ONLY`) and the practice recipe's
own grant. AppStream `metadata_license` remains **CC0-1.0**.

This is **not** a blanket relabelling of every repository file:

- `ui/darkreader.js` remains byte-identical **MIT**, 4.9.105; its MIT copyright
  and permission text is installed under `licenses/DarkReader-MIT.txt`.
- `subprojects/vala-unit` remains LGPL-2.1-or-later, unmodified and `install=false`.
  Its own COPYING still applies locally. The identical installed copy is
  `licenses/vala-unit-LGPL-2.1.txt` (avoids Meson's nested-subproject access error).
- Dependency texts/options remain unchanged. In particular libytnef remains
  **GPL-2.0-or-later**; this combination uses the allowed GPLv3 route. LGPL-linked
  libraries retain their grants and replacement/relinking obligations.
- `bindings/vapi/libstemmer.vapi` keeps its BSD-style copyright/terms; the exact
  Giulio Paci notice is installed as `licenses/libstemmer-vapi-BSD.txt`;
  SQLite-origin code and its provenance in `imap-db-sqlite.c` are not relabelled.
  The historical Dovecot LGPL/MIT-origin comments in `util-imap-utf7.vala` stay
  historical; its application grant alone is elected under §3.
- CC assets, original brand/hero CC0, existing `COPYING.icons` and
  `COPYING.sounds`, AUTHORS and THANKS are unchanged. **No logo/art is modified.**
  The original LGPL tray SVG stays byte-identical; its “see COPYING” now has an
  identical LGPL COPYING **colocated** in `icons/hicolor/scalable/apps/` and
  installed beside the SVG. The root GPL text does not overwrite that asset grant.
- Unheaded bindings `config.vapi`, `enchant.vapi`, `enchant-2.vapi`, `icu-uc.vapi`
  and application CSS retain their existing content, not invented new individual
  grants/authors. `icu-uc.vapi` identifies a Dino origin without a file-specific
  licence notice; the exact imported revision/grant and the Dovecot MIT fragment
  attribution remain **narrow provenance checks before public distribution**.
  No incompatible grant has been established or silently overwritten here.

The known incomplete inherited icon/path/author coverage and legacy screenshot
rights/data review remain in [THIRD-PARTY-NOTICES.md](../../THIRD-PARTY-NOTICES.md).
Adding a GPL root text does not clear those assets. The original CC notice lists
retain their supplied licence links; no fabricated author or blanket CC grant
is added.

## Build/package meaning and remaining decisions

The practice manifest explicitly enables TNEF and retains all eight pinned
application dependencies. It is still an **internal practice recipe**, not a
public installer; app ID/profile paths and runtime UI names are unchanged.
See [VERIFICATION.md](VERIFICATION.md) for actual baseline/GPL-copy build and
package evidence, including the baseline Meson notice-install defect and its
packaging-only workaround. Older prototype binaries are not GPL-copy evidence.

See [CORRESPONDING-SOURCE.md](CORRESPONDING-SOURCE.md) for the chosen GPLv3 §6(d)
source-delivery method and source/artifact mapping. Source must accompany any
future binary with equivalent access; neither this private branch nor an
unsigned internal export is a public release or source-delivery service.

Still separate: notification-flag fix/desktop acceptance, component/asset
closure, runtime/source and LGPL replacement information, Canonical/name
clearance, technical identity/profile migration, full-history privacy review,
and explicit source/binary publication approvals. Griabuntu Mail remains a
**private working name**. The Canonical inquiry remains **unsent**; this work
neither contacts Canonical nor changes the logo, repository name/visibility,
application ID, installed mail/profile, signing configuration or default branch.
