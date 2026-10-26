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
