<!-- Downstream modification: 2026-10-26 — extend preliminary audit into actionable Griabuntu Mail preparation gates. -->
# Griabuntu Mail · release preparation checklist

Prepared **2026-10-26**. **Private candidate only — no release approval or legal
assurance.** Private working name selected by Markus: **Griabuntu Mail** (supersedes Briefwerk/Griabu). Repository name/visibility,
technical IDs, installed profiles/icons and default branch remain unchanged.
Publication, release/package upload and technical migration need separate owner
approval. Distribution to other people can trigger obligations even if GitHub
remains private.

## Captured source and completed preparation

- [x] Preserve full Convey/Geary history and original authorship/licence files.
  Upstream base: `d24c1da859fc9cc2cfb19872b1d8e972d4dc1a20` (Convey 51.0).
  Downstream base: `5834da28091fb951ba3f53dd610d2f30fa352135`.
- [x] Inspect/capture only authorized in-flight source/test changes on the
  isolated preparation branch. Engineering snapshot: `5b532fc43`; complete
  included-path/date record in [PREPARATION.md](docs/release/PREPARATION.md).
- [x] Add real **2026-10-26** dated downstream notices to changed inherited
  source, translations, schemas, UI and build files; retain existing headers.
  History/operational notes establish that date; no unestablished authors/dates
  are invented. New source has explicit origin/LGPL notices.
- [x] Confirm COPYING/Meson/AppStream declare LGPL-2.1-or-later, metadata CC0-1.0;
  preserve the additional CC-BY-3.0, CC-BY-SA-3.0 and work-specific public-domain
  notices in [COPYING.icons](COPYING.icons)/[COPYING.sounds](COPYING.sounds).
- [x] Prepare explicit Meson install rules for COPYING*, AUTHORS, THANKS and
  third-party notices/texts; add Snowball COPYING installation to practice recipe.
  **This checks the rules, not a staged or exported package.**
- [x] Include exact-reference MIT Dark Reader and manifest dependency licence
  texts, including GPL `libytnef`; document version/source references and limits
  in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
- [x] Prepare modern English README + concise German summary, real feature scope,
  safe build guidance, contribution/security routes and honest test status.
  Remove misleading official Convey install commands.
- [x] Create original Griabuntu Mail logo/wordmark/app-icon candidates, light/dark/mono
  SVGs + PNGs and synthetic hero art; label concepts, licence/provenance explicit.
  Render and inspect the images and small exports; check local README targets.
- [x] Brief current Griabuntu/Griabuntu Mail exact/broad web and GitHub-name
  search: no identifiable exact-name project surfaced. This is not clearance.
  Record Canonical’s material similar-BUNTU/software-title permission question.
- [x] Prepare an **unsent** Canonical enquiry draft and future native/pastel
  desktop design brief; neither contact nor app redesign has occurred.
- [x] Remove inherited tracked test log `ct.out` from the prepared current tree;
  keep source/build files and preserve history. Historical privacy review is open.

## 1 · Engineering acceptance — open, not all green

- [ ] Resolve the known notification-flag defect in its separately approved
  engineering change, then rerun all ten flag cases. Captured baseline has
  **4/10 failing** (starring still-unread mail can retire tray entries); production
  handler is unchanged by this preparation. Do not mark as expected-pass/green.
- [ ] Fresh build/test from the exact final candidate commit in supported SDK.
  Prior engineering report: **327 engine + 62 focused cases** passed in dev/
  release and against staged release client library. These are not new results
  for the preparation commit. No real mail was tested.
- [ ] Synthetic desktop acceptance: individual popup Reply opens the existing
  REPLY_SENDER composer **without sending**; Archive/Delete move exactly the
  target message into existing archive/All Mail or Trash. No expunge fallback.
  Verify stale/moved/missing/account-cancelled targets and in-flight dedup.
- [ ] Confirm visible grouped notifications remain Open-only; shell-specific
  action support and tray count/menu work on supported desktops. Verify restart
  starts empty; tray is session-new/unseen, not historical unread.
- [ ] Record support scope, package version and known limitations for the actual
  release. No deployment or profile migration is part of this preparation.

## 2 · Licences, complete assets and package contents

- [ ] **Critical: settle libytnef GPL-2.0-or-later combined-binary obligations.**
  Its exact library header was inspected; it is not LGPL. Choose/review combined-
  work terms/metadata/source delivery, or explicitly approve and test disabling
  TNEF plus removing its module. No silent feature/licence change in this branch.
- [ ] Audit every shipped file/component, transitive dependency and exception.
  Practice sources are pinned: GOA 3.58.1, libical 3.0.20, EDS 3.60.2, folks
  0.15.12, GMime 3.2.15, libpeas 2.2.1, libytnef 1.9.3, Snowball 3.1.1.
  Verify notices against actual checksum-verified archives/build inputs; top-
  level licence texts alone do not establish all file/copyright obligations.
- [ ] Establish EDS component/file version options and any exceptions; retain
  all component copyright notices, not just generic LGPL/GPL texts.
- [ ] Verify bundled Dark Reader 4.9.105 generated API file corresponds to exact
  source/build and inspect bundled subcomponents; preserve MIT notice in source
  and installed package. Record the vendored hash (inventory has current hash).
- [ ] Confirm ValaUnit is test-only in the exported binary (install=false), or
  account for any shipped pieces under its LGPL and original authorship.
- [ ] Finish full inherited asset audit: icon/sound attribution, modification
  history, ShareAlike where applicable, application icons and legacy screenshots.
  Public README uses only new original art; unused historical images are not
  thereby cleared. Verify public-data suitability before displaying them.
- [ ] Inspect staged install and final exported package: accessible COPYING*,
  third-party texts/attributions, resource/plugin/shared-library inventory,
  Snowball notice and runtime licensing/source availability. Check relevant LGPL
  relinking/replacement obligations and static/embedded code. Do not infer binary
  compliance from repository notices or install-rule inspection.

## 3 · Exact binary ↔ source and distribution records

- [ ] Freeze final source commit and clean source archive; inventory with
  `git diff --name-status d24c1da859fc9cc2cfb19872b1d8e972d4dc1a20 <candidate>`.
  Recheck every later changed/new file and dated notice.
- [ ] Record package version, manifest, all build options, dependency revisions,
  resolved GNOME Platform/SDK **51 commit IDs**, architecture, build tool versions
  and final binary/source hashes. A branch name or `-Drevno` string is not enough.
- [ ] Replace local `type: dir` with a reviewed immutable candidate source or
  clean export. Include all corresponding source, bindings/interface definitions,
  resources, subprojects and scripts controlling compilation/installation.
  Exclude credentials, profiles, signing keys, build outputs and private logs.
- [ ] Rebuild that clean snapshot, test/accept it and prove it maps to the exact
  distributed artifact. **No existing package is certified by this preparation.**
- [ ] Provide complete machine-readable corresponding source with equivalent
  access next to any binary download, with an unambiguous version/commit mapping.
  An inaccessible private repo, moving branch, upstream source or bundle alone
  is not the chosen source-delivery plan.

## 4 · Identity, privacy and explicit publication decisions

- [x] Owner selected **Griabuntu Mail** as private working identity; new original
  folded-G assets replace the superseded B-study at the tip (history retained).
- [ ] Resolve Canonical’s potentially confusingly similar BUNTU-mark/software-title
  permission question and public-name clearance before public branding. Obtain
  any necessary written permission; an independence disclaimer is insufficient.
  Review relevant registers/markets, domains and app stores as appropriate; no
  automatic prohibition or clearance is asserted.
- [ ] Separately approve and implement the future native GTK4/libadwaita visual
  direction, then accept-test actual controls, states, contrast and scaling.
  Current pastel hero/logo studies are not proof of a completed redesign.
- [ ] Choose an owner-controlled application namespace, then separately approve
  the [safe identity/migration plan](docs/BRANDING.md): schemas, D-Bus, desktop/
  AppStream, icons, resources, portals, sandbox and profile/keyring references.
  Do not silently distribute a new independent app as `net.donnybeelo.Convey`.
- [ ] Review entire retained history for secrets/private data and legacy asset
  suitability before changing visibility. The inherited historical `ct.out`
  contains personal path strings despite removal from this branch's tip;
  preservation of history is not a completed privacy audit. Ask owner to decide
  any remediation; do not rewrite or force-push history automatically.
- [ ] Decide supported desktop scope and finish visible UI acceptance.
- [ ] Obtain explicit owner go-ahead for **source visibility**, any **repository
  rename**, **release/tag** and **binary/source publication destination** separately.
  No workflow is enabled and no public write/release/merge is performed here.

## Primary references

[COPYING](COPYING), especially 0, 1, 2(b), 4 and where applicable 6;
[COPYING.icons](COPYING.icons), [COPYING.sounds](COPYING.sounds),
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md), [BUILDING.md](BUILDING.md),
[CUSTOMIZATIONS.md](CUSTOMIZATIONS.md), [test/README.md](test/README.md),
[BRANDING.md](docs/BRANDING.md), [unsent permission enquiry](docs/CANONICAL-NAME-PERMISSION-DRAFT.md).
