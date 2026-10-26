<!-- Downstream modification: 2026-10-26 — document downstream features, engineering baseline and Briefwerk presentation. -->
# Briefwerk — independent Convey downstream

Based on Convey 51.0 at `d24c1da859fc9cc2cfb19872b1d8e972d4dc1a20`.
Upstream: https://github.com/donnybeelo/convey

Original authorship, history and LGPL licensing are retained. This is an
independent private repository, not the official Convey release or a GitHub
fork-network member. Upstream updates must be deliberately merged and tested.

## Included changes

- Muted leading recipient-alias badges, up to two plus an overflow indicator.
  Addresses match configured identities in cached To/Cc; they are not verified
  SMTP delivery addresses.
- Existing desktop contact photos or initials. Read-only access to the desktop
  addressbook photo cache; no new external avatar/logo providers.
- Full participant names and email addresses, with literal-text tooltips.
- Absolute received date/time including seconds, using IMAP INTERNALDATE in the
  desktop timezone; the tooltip includes timezone and UTC offset.
- Native StatusNotifierItem/DBusMenu tray with Open, New Message and draft-aware
  Quit. New/unseen arrivals drive a count and up to five clickable message
  summaries; overlapping folders are deduplicated by account-qualified ID.

The tray counts session-new/unseen messages, not every historical unread mail.
Its count starts empty after restarting the application.

## Notification actions — 2026-10-26

Individual new-message popups offer Reply, Archive and Delete (German:
Antworten / Archivieren / Löschen). Reply opens the existing reply-to-sender
composer without sending. Archive moves only that message into an existing
All Mail/archive folder; Delete moves it only into the existing Trash folder.
No permanent-delete or archive/expunge fallback is used. The normal message
move command stack is retained. Summary/group notifications have no destructive
buttons; Unity's existing no-actions behavior is preserved.

Targets bind account, stored message ID and original folder. Malformed,
cross-account, cancelled, missing or moved-away targets fail closed, without
falling back to the selected conversation. Repeated in-flight clicks are
deduplicated. An error notification offers Open rather than silently pretending
success. A missing archive or Trash folder is not created automatically.

## Build and verification

Use the pinned `packaging/net.donnybeelo.Convey.Practice.yml` with GNOME SDK 51
and official Flatpak Builder. Reuse whichever user/system scope already holds
those tools; do not duplicate SDK installations. Standard build instructions
remain in [BUILDING.md](BUILDING.md).

The prior installed tray snapshot passed 327 engine tests and 44 focused helper
cases, including account scoping, late-result rejection, stable menu IDs,
received-time/DST formatting and markup safety. A private D-Bus fixture also
exercises the tray menu and count changes. The focused executable is
`test-recipient-aliases`; the fixture switch `--tray-fixture` uses synthetic mail
only and must not be confused with real mail delivery validation.

The notification-actions engineering snapshot was reported to pass the same 327 engine
cases and 62 focused cases (18 new). The new cases cover actual GNotification
button serialization on a private D-Bus, account/source validation, stale mail,
cancellation, error cleanup and exact single-message archive/Trash moves through
the existing production command. No real mail or accounts are opened by these
tests. Reply-composer and desktop acceptance are separate from these tests.

The independent notification-flag suite records an existing baseline defect:
four of ten cases fail because starring still-unread mail retires session-new
entries. Its production handler is unchanged here; this is not a green release
gate or a regression introduced by the new popup actions.

Keep profiles, credentials, private operational notes, local build directories,
bundles and signing keys outside version control. No release package is published by this preparation; no signing secret or
personal account configuration belongs in this repository.

## Briefwerk presentation — 2026-10-26

Markus selected Briefwerk as the downstream project name. This preparation adds
original logo/hero assets and documentation only; technical IDs, installed icons,
profile paths and repository name remain unchanged. See [BRANDING.md](docs/BRANDING.md)
for a material adjacent-field name collision and the separate migration gates.
