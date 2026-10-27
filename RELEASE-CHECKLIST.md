<!-- Downstream modification: 2026-10-26 — extend preliminary audit into actionable Griabuntu Mail preparation gates. -->
# Griabuntu Mail · release preparation checklist

## Current development candidate · 2026-10-27

This checklist retains the dated preparation history below. The current native
candidate is `51.0+griabuntu20261027.6` on `work/griabuntu-ubuntu-deb`.
Identity, selected owner envelope/banner, consent-controlled pictures, native
teal/peach styling, bilingual presentation and package notices are implemented.
See [current validation](docs/VALIDATION-20261027.md) for actual passing checks
and their limits; historical red flag tests below were subsequently fixed.
The owner authorised pushes, .deb creation, public visibility when complete,
and setting the finished branch as default while preserving main/history.

**Publication remains pending:** no written name permission or qualified name
review exists, and inherited per-asset provenance gaps are recorded rather than
certified away. The current candidate remains private; no external permission
request has been sent. Original author/licence notices remain accessible.
A passing engineering build is not a name clearance or full desktop acceptance.

## Historical preparation record

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
- [x] Original preparation recorded LGPL-2.1-or-later; this separate owner-elected
  copy now declares GPL-3.0-only in COPYING/Meson/AppStream/About, metadata CC0-1.0;
  preserve the additional CC-BY-3.0, CC-BY-SA-3.0 and work-specific public-domain
  notices in [COPYING.icons](COPYING.icons)/[COPYING.sounds](COPYING.sounds).
- [x] Prepare explicit Meson install rules for COPYING*, AUTHORS, THANKS and
  third-party notices/texts; add Snowball COPYING installation to practice recipe.
  **Original audit checked rules only; actual follow-up evidence is in
  [VERIFICATION.md](docs/release/VERIFICATION.md).**
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
  keep source/build files and preserve history. Follow-up verifies the identical
  blob is already public upstream, with build/test paths rather than newly
  introduced owner secrets. Whole-history review remains distinct.
- [x] Establish a sourced [licensing decision](docs/LICENSING-DECISION.md):
  retaining TNEF permits compatible GPL combined-binary distribution; no new
  upstream conversion permission is needed. Recommendation: GPLv3 combined
  release, preserving independent LGPL source grants. **Follow-up: owner approved
  at 19:56 UTC; this separate branch implements GPL-3.0-only under LGPL §3.**
- [x] Verify exact cached dependency COPYING hashes and checksum-verified
  libical/GMime archive licence members. Verify Dark Reader JS/MIT byte-identical
  to official npm 4.9.105, matching registry integrity and source gitHead.

## 1 · Engineering acceptance — open, not all green

- [ ] Resolve the known notification-flag defect in its separately approved
  engineering change, then rerun all ten flag cases. Captured baseline has
  **4/10 failing** (starring still-unread mail can retire tray entries); production
  handler is unchanged by this preparation. Do not mark as expected-pass/green.
- [ ] Public-candidate acceptance remains open. Fresh private GPL-copy build/test
  evidence is separated from baseline in [VERIFICATION.md](docs/release/VERIFICATION.md).
  Do not infer all-suite or real-desktop acceptance from the focused checks.
  Historical engineering report:
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

- [x] Owner elected **TNEF-on / GPLv3** on 2026-10-26 at 19:56 UTC; implement
  LGPL-2.1 §3 in this separate release-source copy as **GPL-3.0-only** (not later).
  Original independent LGPL sources/history remain intact. Operative notices,
  full text, metadata and component references are prepared; no feature/artwork
  change or public release approval. See [GPLV3-COPY.md](docs/release/GPLV3-COPY.md).
- [ ] Audit every shipped file/component, transitive dependency and exception.
  Practice sources are pinned: GOA 3.58.1, libical 3.0.20, EDS 3.60.2, folks
  0.15.12, GMime 3.2.15, libpeas 2.2.1, libytnef 1.9.3, Snowball 3.1.1.
  Input/notice correspondence is verified above; top-level texts alone still
  do not establish all file/copyright obligations of the final shipped closure.
- [ ] Carry EDS's now-identified mixed LGPL version options and OpenLDAP-source
  exception into the final inventory; retain all component copyright headers,
  not just generic texts or a false uniform LGPL version. OpenLDAP backend is
  disabled in this manifest; full-source delivery still retains its terms.
- [ ] Public final export must retain the **installed/exported** Dark Reader
  MIT copyright/permission notice verified in the private follow-up record.
  API provenance is resolved above; the inspected older stage lacks this notice.
- [ ] Public final export still needs its own check; the private follow-up
  inspection is recorded separately. ValaUnit remains test-only (install=false).
  No test/ValaUnit-named payload was found in the inspected existing stage;
  account for any pieces actually shipped under their original LGPL/authorship.
- [ ] Finish full inherited asset audit: icon/sound attribution, modification
  history, ShareAlike where applicable, application icons and legacy screenshots.
  Public README uses only new original art; unused historical images are not
  thereby cleared. Add path-to-author/licence coverage for installed font/format/
  edit icons, RTL variants and inherited Convey application icons missing from
  the old list. Mark adaptations and retain ShareAlike for adapted CC assets.
  Verify legacy screenshots' public-data suitability before displaying them.
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
  and final binary/source hashes for the **final release**. Existing stage's
  resolved commits are now recorded in the decision, not recertified for this
  unbuilt preparation. A branch name or `-Drevno` string is not enough.
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
  blob is identical to the already-public upstream build/test log, not a newly
  introduced owner secret. Its paths alone do not justify a history rewrite;
  this narrow result is not a whole-history privacy audit. No sensitive values
  are reproduced; do not rewrite or force-push history automatically.
- [ ] Decide supported desktop scope and finish visible UI acceptance.
- [ ] Obtain explicit owner go-ahead for **source visibility**, any **repository
  rename**, **release/tag** and **binary/source publication destination** separately.
  No workflow is enabled and no public write/release/merge is performed here.

## Primary references

[COPYING](COPYING) (GPLv3), especially §§4–6; the preserved
[COPYING.LGPL-2.1-original](COPYING.LGPL-2.1-original), especially §3 and
applicable LGPL component obligations;
[COPYING.icons](COPYING.icons), [COPYING.sounds](COPYING.sounds),
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md),
[LICENSING-DECISION.md](docs/LICENSING-DECISION.md), [BUILDING.md](BUILDING.md),
[CUSTOMIZATIONS.md](CUSTOMIZATIONS.md), [test/README.md](test/README.md),
[BRANDING.md](docs/BRANDING.md), [unsent permission enquiry](docs/CANONICAL-NAME-PERMISSION-DRAFT.md).


## Separate private GPLv3 copy — evidence boundary

The owner licence election is complete, not a pending upstream permission.
See [conversion scope](docs/release/GPLV3-COPY.md),
[fresh verification](docs/release/VERIFICATION.md) and
[corresponding-source delivery controls](docs/release/CORRESPONDING-SOURCE.md).
Baseline `465e0c6` has a real Meson nested-subproject notice-install failure;
the follow-up corrects that packaging rule without changing ValaUnit's grant.
The raw baseline failure, packaging-only baseline workaround and GPL results
must be reported separately. Known 4/10 red flag cases remain unresolved.
Add the exact Dino binding and historical Dovecot MIT-fragment provenance
checks to the still-open inherited asset/component closure; no invented grant.


### Completed private follow-up checks (not public acceptance)

- [x] Build the actual GPL copy from clean source commit `a4774cb9e390a3d55efa6636c9f2f3b12fcc3f88`
  via SHA-pinned archive; preserve independent raw/baseline-workaround sources.
- [x] Fresh baseline-workaround and GPL-copy 327 engine + 62 focused tests pass;
  both keep the same 4/10 red flag cases. Exact staged-client retest also passes.
- [x] Finish/export the same tested GPL stage into a separate unsigned repo;
  inspect actual exported GPL/MIT/CC/component notices, metadata and TNEF.
  Hash an internal unsigned inspection bundle separately from OSTree commits.
- [x] Record exact source/archive/manifest/runtime identities, package contents
  and source-delivery instructions. Static archives/tools remain in this
  internal export; public cleanup/source/asset obligations are still open.

The completed verification is a reporting-only descendant, not a false claim
that the later report commit itself was compiled into the inspection bundle.
