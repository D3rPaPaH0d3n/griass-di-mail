# Private downstream — release preparation

Prepared on 2026-10-26. **Pending preparation only; not release approval or a
legal assurance.** Keep repository visibility unchanged. Publishing source,
uploading packages, creating releases or changing branding requires a new,
explicit instruction from Markus.

This checklist does not certify an existing package. Distribution to other
people can trigger licence obligations even when the repository stays private.

## Inspected baseline

- Downstream: `5834da28091fb951ba3f53dd610d2f30fa352135` on `main`.
- Upstream base documented in [CUSTOMIZATIONS.md](CUSTOMIZATIONS.md):
  `d24c1da859fc9cc2cfb19872b1d8e972d4dc1a20` (Convey 51.0).
- That committed delta contains 24 modified and 10 added files. This is not a
  frozen release inventory: later commits and uncommitted changes need review.
- Uncommitted test/build work was present during inspection and was not edited
  for this preparation. This document does not validate that work.

Confirmed from repository files:

- [x] [COPYING](COPYING), `meson.build` and
  `desktop/net.donnybeelo.Convey.metainfo.xml.in.in` declare LGPL-2.1-or-later.
  AppStream's separate metadata licence is CC0-1.0.
- [x] `COPYING`, [COPYING.icons](COPYING.icons),
  [COPYING.sounds](COPYING.sounds) and `AUTHORS` are unchanged between the
  upstream base and the inspected downstream commit.
- [x] Asset-specific notices are present: CC-BY-3.0, CC-BY-SA-3.0 and the listed
  public-domain icon exception. They are not all covered by the code licence.

## Open release gates

### 1. File-level change notices and retained notices

- [ ] Review the complete delta from the documented base to the eventual release
  commit, including build files, translations, schemas, UI files and assets.
  Obtain the inventory with `git diff --name-status <base> <release-commit>`;
  check newly added files as well as modifications to inherited files.
- [ ] Add prominent in-file notices describing downstream changes and their
  actual dates, using the file format's comment syntax (LGPL 2.1 section 2(b)).
  For example: `Downstream modification: YYYY-MM-DD — <description>.`
  Establish dates from the change history; do not invent authorship or dates.
  Existing inherited headers, Git history and `CUSTOMIZATIONS.md` alone are not
  the planned file-level notices. The inspected code mostly retains its
  original headers; this gate remains open.
- [ ] Preserve original copyright, licence and no-warranty notices. Give new
  downstream files clear licence/origin information without claiming ownership
  of upstream work or relicensing third-party assets.
- [ ] Check the actual distributable for accessible licence texts and required
  notices. The inspected Meson install rules do not explicitly install the
  top-level `COPYING*` files; their presence in Git is not a package-content
  check. Add packaging support if the release format needs it.

### 2. Source corresponding to the exact binary

- [ ] Select and record the final release commit, package version, build options,
  manifest, dependency revisions and runtime/SDK refs and commits. The current
  practice manifest uses a local directory source (`path: ..`), so its version
  label alone does not identify the compiled source snapshot.
- [ ] Prepare complete corresponding machine-readable source, including all
  downstream changes, interface definitions and scripts needed to control
  compilation and installation (COPYING sections 0 and 4). Include relevant
  Meson files, bindings, resources, subprojects and packaging/build instructions.
  Exclude credentials, personal mail/configuration and signing secrets.
- [ ] Rebuild and run the relevant tests from that source snapshot; verify that
  it corresponds to the binary being distributed. Do not inherit prior test
  counts as evidence for a different release candidate.
- [ ] For a downloadable binary release, provide equivalent access to its source
  at the same download location, with an unambiguous commit/version mapping.
  A private repository inaccessible to recipients is not that source delivery.
  Do not rely only on a moving branch, upstream source or a binary bundle.

### 3. Assets and bundled dependencies

- [ ] Preserve the per-work attribution and licence references in
  `COPYING.icons` and `COPYING.sounds`. For modified CC-BY/CC-BY-SA works, identify
  the changes and satisfy the applicable attribution/ShareAlike requirements.
  Do not generalise the listed public-domain exception to other assets.
- [ ] Audit each dependency actually shipped, its exact version, licence texts,
  attribution and any source/relinking obligations. Use the final package
  contents as well as the manifest; do not assume LGPL for every dependency.
  The practice manifest currently builds `gnome-online-accounts`, `libical`,
  `evolution-data-server`, `folks`, `gmime`, `libpeas`, `libytnef` and `snowball`.
- [ ] Include vendored code/resources in that audit, notably
  `ui/darkreader.js` (header: Dark Reader 4.9.105) and
  `subprojects/vala-unit` (contains its own LGPL-2.1-or-later `COPYING`). This is
  an initial inventory, not a completed third-party licence review.

### 4. Identity and explicit publication decision

- [ ] Decide on independent branding and an application ID before a public
  release. The current practice build still uses `net.donnybeelo.Convey`.
  Renaming must account for application IDs, icons, desktop/AppStream metadata,
  D-Bus names, schemas and existing user-data locations; do not rename ad hoc.
- [ ] Retain truthful upstream attribution and avoid implying upstream/GNOME
  endorsement. LGPL permission is not a blanket trademark permission.
- [ ] Obtain Markus' explicit instruction for the concrete publication scope
  and destination. Source publication, repository visibility and binary upload
  are separate choices; this document authorises none of them.

## References

Primary terms are in [COPYING](COPYING), especially sections 0, 1, 2(b), 4 and,
where applicable to linked dependencies, 6; asset notices are in
[COPYING.icons](COPYING.icons) and [COPYING.sounds](COPYING.sounds).
Build context: [BUILDING.md](BUILDING.md), [CUSTOMIZATIONS.md](CUSTOMIZATIONS.md)
and `packaging/net.donnybeelo.Convey.Practice.yml`.
