# Private preparation record · 2026-10-26

This record describes source preparation only. It is not a release manifest,
binary verification report or publication approval. Branch:
`openclaw/convey-publication-prep`. Repository visibility stays private; no
release/tag/PR/package/Pages publication or default-branch merge is performed.

## Captured engineering input

Base `5834da28091fb951ba3f53dd610d2f30fa352135`, retaining complete upstream
history. A binary tracked diff against that base was inspected and applied to
this isolated worktree. The canonical development checkout was not written,
staged, committed, switched or deployed from this task.

Tracked paths captured before publication work:

- `CUSTOMIZATIONS.md`
- `meson.build`
- `packaging/net.donnybeelo.Convey.Practice.yml`
- `po/de.po`
- `src/client/application/application-client.vala`
- `src/client/client-action.vala`
- `src/client/meson.build`
- `src/client/plugin/desktop-notifications/desktop-notifications.vala`
- `test/README.md`
- `test/meson.build`
- `test/test-recipient-aliases.vala`

Only these allowed new input files were copied:

- `RELEASE-CHECKLIST.md`
- `src/client/application/application-notification-actions.vala`
- `test/client/application/application-notification-actions-test.vala`
- `test/client/application/application-notification-plugin-context-test.vala`
- `test/mock/notification-context.vala`
- `test/test-notification-flags.vala`

Snapshot commit: `5b532fc43` (“Snapshot in-flight notification engineering for
private publication preparation”). This includes a deliberately red regression
suite and must not be described as release-ready. No random ignored/untracked
files, installed profiles or build artifacts were copied.

## Dates and file-level notices

The original downstream engineering commit `5834da280` has author/committer date
**2026-10-26T18:02:02Z**. Captured notification-action/flag work is documented as
created/modified **2026-10-26** in its engineering notes and this day's task
handoff. Preparation modifications (docs/art/licence packaging/comment notices)
also occurred **2026-10-26**. File-level notices use that evidenced calendar date;
they do not claim an earlier creation date, an exact unrecorded start time or new
ownership of inherited files. No earlier downstream dates are established by
this snapshot, and none are invented. Original headers remain intact.

Changed inherited source, schema, UI, build and translation files carry format-
appropriate dated comments; new downstream source has explicit LGPL notices.
Documentation notices and this record describe presentation edits. New original
hero/brand files carry CC0 provenance. The notice on the existing notification
flag handler describes prior tray integration only: the current flag bug is
not fixed by adding a comment. Engineering semantics are unchanged after capture.

## Preparation checks and boundaries

- Original `COPYING*`, `AUTHORS`, `THANKS`, vendored JS/ValaUnit and upstream
  history are preserved. Added dependency texts are verbatim versioned reads.
- New art is rendered by the existing system GdkPixbuf SVG decoder; actual hero,
  light/dark board and small exports inspected. No external render service.
- Local Markdown relative targets and SVG/XML/YAML syntax checked; no remote
  README link validation is claimed.
- Source delta after snapshot is comments/docs/art plus explicit licence install
  rules. No feature/flag-handler refactor, identity migration or live-mail test.
- This Gateway lacks Meson, Vala and Flatpak Builder; a fresh full application
  build/test/staged-package check cannot be performed here. Earlier engineering
  test counts are explicitly attributed, not re-certified.
- Inherited tracked `ct.out` is an upstream test log containing personal path
  strings. It is removed from the prepared current tree and ignored; historical
  occurrences remain in preserved history. Before making history public, review
  privacy/security implications with the owner; do not rewrite history silently.

See [release gates](../../RELEASE-CHECKLIST.md), [licensing](../../THIRD-PARTY-NOTICES.md)
and [name collision / identity plan](../BRANDING.md).

## Presentation follow-up · Griabuntu Mail

Owner update **2026-10-26, 19:25 UTC**: **Griabuntu Mail** replaces Briefwerk /
Griabu as the chosen private working name. The earlier Briefwerk identity is
superseded, not a parallel current brand. Its vectors remain in prior Git
history; current assets are newly drawn folded-G/mail-slot geometry, not a B
with a different caption. Pastel teal/petrol and peach/copper tonal surfaces
implement the presentation brief, not a runtime application redesign.

The earlier candidate `f97005840cea5034201f6ae021996b6eb05597e5` was confirmed
present on the private remote preparation branch before this follow-up. This
follow-up changes only presentation/docs/new brand art; captured engineering,
source IDs, profiles, installed icons, build settings and dependency/licence
choices remain unchanged. No canonical development checkout is modified.

Exact/broad web searches and a GitHub-name search produced no identifiable
Griabuntu Mail project in the returned set. Canonical's current policy was read
on 2026-10-26: the similar-BUNTU-mark/software-title permission question is an
explicit public-name gate, not cleared or declared automatically prohibited.
An enquiry draft is **unsent**. No Canonical contact, public write or new name
permission was obtained. The future native desktop direction was incorporated
as an input brief, not as an implemented redesign.

New SVGs/PNGs retain explicit original CC0 provenance. Actual hero/identity and
16/24/32px renders are inspected, local relative links/SVG syntax checked, and
representative foreground/tonal-surface contrast measured. These are artwork
checks, not real UI accessibility acceptance. No binary rebuild is needed for
this presentation-only follow-up. All GPL-libytnef, dependency/assets, source-
binary/runtime mapping, red flag-suite, UI acceptance, privacy/history and
technical identity/publication gates above remain open.
