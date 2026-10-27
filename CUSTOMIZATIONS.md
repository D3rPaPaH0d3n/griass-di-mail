<!-- Downstream modification: 2026-10-26 — document downstream features, engineering baseline and Griabuntu Mail presentation. -->
# Griabuntu Mail — independent Convey downstream

Based on Convey 51.0 at `d24c1da859fc9cc2cfb19872b1d8e972d4dc1a20`.
Upstream: https://github.com/donnybeelo/convey

Original authorship/history and independently preserved LGPL sources are
retained. This separate release copy elects GPL-3.0-only under LGPL §3; see
[the licence-copy record](docs/release/GPLV3-COPY.md). This is an
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

## Current build and identity

Native Ubuntu 26.10 packaging is in `debian/`. The application is Griabuntu Mail,
executable/gettext/data basename `griabuntu-mail`, independent ID
`io.github.d3rpapah0d3n.GriabuntuMail`, engine namespace `GriabuntuMail`.
See [IDENTITY.md](docs/IDENTITY.md) for all naming and provenance boundaries.
The current candidate also installs the original CC0 envelope app/tray/symbolic
icon family from `brand/`, with native raster sizes. The wider theme is separate.
No personal data is copied by this source change or by package installation.

The original flag bug was reproduced and fixed on 2026-10-27: all ten unchanged
flag cases pass. The first full renamed build passes 328 engine cases (including
one new legacy-tokeniser alias case), 62 focused helpers and the ten flag cases,
plus three desktop/AppStream validators. Synthetic tests are not personal-mail,
composer or end-to-end desktop acceptance. Native GUI smoke checks use isolated
state and a private virtual display; no installed personal profile is opened.

Earlier GPL-copy build/package evidence remains in `docs/release/VERIFICATION.md`
with its original hashes, names and baseline failures. It does not certify this
new identity build. Keep profiles, credentials, logs, local build directories,
bundles and signing material outside version control. No public release or
signing is authorised by this private refactor.
