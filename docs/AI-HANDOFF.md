# AI handoff — Griabuntu Mail

**Consolidated on 2026-10-26.** This is the entry point for another AI agent to
continue the project. It consolidates source, original graphics, decisions,
licensing work, test evidence and pending work; it does not authorise a public
release or a production deployment.

## Find the right state

- Repository: **D3rPaPaH0d3n/convey**, currently private.
- Continue from **`handoff/griabuntu-ai`**. Default `main` is the earlier original
  LGPL downstream checkpoint, not the latest consolidated development state.
- This branch descends from the tested **GPL-3.0-only release-source copy**.
  Do not merge all preparation branches together: their work is already in this
  ancestry. Preserve independent original LGPL copies and upstream history.
- An ordinary private clone can select this branch explicitly:

  ```sh
  git clone --branch handoff/griabuntu-ai https://github.com/D3rPaPaH0d3n/convey.git
  ```

Read [the repository instructions](../AGENTS.md), inspect live Git/GitHub state,
and review the relevant implementation before choosing a next change. If an
assumption is stale, a proposal is unnecessary or a smaller fix is better, say so.
Do not repeat the entire completed audit just to begin a narrow task.

## Product and implemented behaviour

Independent Linux desktop email client derived from **Convey 51.0**, itself
Geary-derived. Upstream base:
`d24c1da859fc9cc2cfb19872b1d8e972d4dc1a20`. Working identity is
**Griabuntu Mail**, not an official Convey/Geary/Ubuntu product.

Already in source:

- Leading, muted recipient-alias badges: up to two plus overflow, matching
  configured identities in cached To/Cc, not verified SMTP delivery addresses.
- Existing local desktop contact photos, otherwise initials; no new external
  avatar/logo providers.
- Full sender/participant name and address, literal tooltips, markup protection.
- Absolute received date and seconds from IMAP INTERNALDATE in local timezone,
  with timezone/offset detail; not the sender's Date header.
- Native StatusNotifierItem/DBusMenu tray: background presence, session-new/unseen
  count and up to five clickable sender/subject entries. Restart starts empty;
  overlapping folders/accounts are handled deliberately, not summed blindly.
- Individual popup Reply / Archive / Delete: reply-to-sender composer without
  sending; exact-message move into an existing All Mail/archive or Trash folder.
  No permanent-delete/expunge fallback or automatic destination creation.
  Account, message and original folder are validated; stale/in-flight clicks are
  guarded. Group popups remain Open-only. Desktop/composer acceptance is pending.

[Engineering scope](../CUSTOMIZATIONS.md) · [Build guide](../BUILDING.md)

## Owner decisions — do not ask the same questions again

1. **Name:** Griabuntu Mail, exact spelling, selected on 2026-10-26. Briefwerk
   was an earlier study rejected after an adjacent mailing-services collision;
   Griabu/Stibu were interim suggestions. Public name clearance is **not** done.
2. **Future design:** seamless Ubuntu/GNOME integration, native icons/buttons/
   menus/dialogs, GTK4/libadwaita rather than Android/web widgets. Keep petrol/teal
   and copper, softened into pastel/Material-inspired tonal surfaces. Respect
   system light/dark, high contrast, scaling, focus and semantic error colours.
3. **Latest logo correction:** more recognisable **mail/envelope**, not merely a
   G with a folded corner. Colours stay. We discussed closed versus open envelope
   and a secondary/negative-space G; **no final variant was selected**. Existing
   SVG/PNG artwork must be labelled a prior candidate, not approved production art.
4. **Licence route:** on 2026-10-26 the owner approved keeping **all functions,
   including TNEF**, and a GPLv3 combined release. This branch implements the
   elected **GPL-3.0-only** application copy under LGPL-2.1 section 3. Do not remove
   winmail.dat support or re-open the election as an unanswered question.
5. **Still not authorised:** public visibility/releases, repository/default-branch
   changes, Canonical contact, main merge, installation/signing, technical app-ID
   or profile migration. The inquiry draft is **unsent**. Ask before those actions.

[Design brief](desktop-design-direction.md) · [Brand/name findings](BRANDING.md) ·
[Editable artwork and provenance](../brand/README.md) ·
[Recorded GPL approval](gplv3-release-policy.md)

## Exact source and test evidence

| State | Reference / meaning |
| --- | --- |
| Original LGPL downstream | `5834da28091fb951ba3f53dd610d2f30fa352135`, preserved `main` |
| Captured popup/flag engineering | `5b532fc43c94f881ebc4ce602f08e3ac4749afa2` |
| Griabuntu artwork / LGPL preparation | `9183cc8d3d49b2463ad033203719c08afbe19552` |
| Corrected licence audit | `465e0c6c15233009a7e84ab60a783a3a1fb4a4e0` |
| **Actually built GPL source** | **`a4774cb9e390a3d55efa6636c9f2f3b12fcc3f88`** |
| Reporting-only descendant | `7c3f99880d85634eb0c0998fdad450a8bfb782a4` |
| This handoff | Documentation-only descendant of the reporting commit |

Fresh GPL-copy results: **327/327 engine + 62/62 focused tests passed**, including
TNEF extraction, also with the actual staged client library loaded. Separate
notification-flag suite: **6 pass / 4 fail**, unchanged from the buildable baseline.
The untouched audit baseline first failed a Meson nested-subproject notice install;
its distinct packaging-only correction is recorded, not hidden as a green baseline.

The tested stage was exported to an **internal unsigned inspection package**.
GPL/MIT/CC/component notices and metadata were inspected. The bundle digest is
`307aa6034ef68d4590754d0e31aab345345bbb5ecc6941f89c26dee29cbcef3e`;
its different **OSTree application commit** is
`b7c4ad02461f3f65ea063cba1ec729a5fc51c8c8d5cea8e9385184975427ba36`.
These are different identifiers, not an inconsistency. The bundle/build-host logs
are deliberately **not committed** here. Do not claim this documentation-only
handoff tip was itself newly built or that a signed public release exists.

[Full fresh verification](release/VERIFICATION.md) ·
[GPL-copy rules and inventory](release/GPLV3-COPY.md) ·
[Corresponding-source work](release/CORRESPONDING-SOURCE.md)

## Where to investigate

| Concern | Starting points |
| --- | --- |
| Native tray / counts | `Application.StatusIcon`, `TrayItem`, `TrayMenu`, `TrayMailModel` |
| Popup validation / moves | `Application.NotificationActions`, `Application.Client`, `MoveEmailCommand` |
| Popup creation | `Plugin.DesktopNotifications` |
| Known flag bug | `Application.NotificationPluginContext.on_email_flags_changed` and its synthetic regression suite |
| Aliases / photo refresh / participant text | conversation-list row/participant, email utilities and contact store |
| Exact received time | received-time helpers in date utilities and their focused tests |
| Licence/install metadata | Meson, AppStream, application About, notice-install rules and GPL conversion inventory |

## Pending work — choose a bounded next task with the owner

- **Logo/design:** continue the envelope discussion and produce genuinely mail-
  recognisable concepts, keeping originals/provenance and small-size readability.
  Only after design agreement implement actual native controls/styles and test
  rendered light/dark/high-contrast states. The current hero is synthetic artwork.
- **Flag regression:** starring/un-starring a still-unread new arrival retires
  it because the current handler retires all changed IDs. The proposed minimal
  direction is to retire only read or deleted IDs (`!is_unread() || is_deleted()`),
  but it is **not implemented or approved by this handoff**. Re-check semantics
  and the mixed-batch/old-unread cases, then keep the fix scoped to the agreed task.
- **Visible acceptance:** popup buttons, actual reply composer, exact desktop
  moves, tray/login lifecycle and real user acceptance remain unverified. Do not
  test by opening, sending, moving or deleting personal mail without permission.
- **Release closure:** complete inherited icon/RTL/app-icon attribution and
  Dino/Dovecot component provenance; retain verified Dark Reader MIT/npm and
  archive provenance. Public-package cleanup must deal with eight static archives,
  development payload and TNEF utilities, preserving functional TNEF and notices.
- **Source obligations:** finish complete recipient-accessible preferred-form
  application/dependency sources, build controls, runtime/source references and
  LGPL replacement/relinking evidence. Internal app-source-to-package mapping is
  verified; complete public corresponding-source delivery is not.
- **Name/identity:** resolve the Canonical/buntu question separately. The absence
  of exact-name hits is not clearance. Do not contact Canonical from the unsent
  draft without approval. Plan owner-controlled app-ID, profile/keyring/GOA
  migration and rollback before an independent public install; no mechanical rename.
- **Publication:** explicit owner instruction is still required. Personal prototype
  deployment/access details are outside this repository; do not infer deployment
  from a successful build or copy a profile between machines.

[Complete release checklist](../RELEASE-CHECKLIST.md) ·
[Licence decision](LICENSING-DECISION.md) ·
[Component notices](../THIRD-PARTY-NOTICES.md) ·
[Unsent Canonical request](CANONICAL-NAME-PERMISSION-DRAFT.md)

## Verification discipline

Use the build guide and named suites `engine-tests`, `recipient-alias-tests`,
`notification-flag-tests`. Isolate HOME/XDG, buses, network and display from
personal state. Reuse the supported SDK/Builder installation scope. Read the
verification record before staged-client tests: executable DT_RPATH can select
the build-tree library despite LD_LIBRARY_PATH; the documented ELF-loader method
proves the intended package library. Report the known flag failures honestly.

This handoff changes documents only. Existing source, tests, editable graphics,
licence texts and build controls are inherited intact from the reviewed branch.
A fresh agent should report findings, a recommended next task, scoped changes and
actual proof—not an unsupported statement that the whole app is release-ready.
