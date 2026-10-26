# Convey — private downstream

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
Its count starts empty after restarting the application. Popup notification
Reply / Archive / Trash buttons are **not implemented**.

## Build and verification

Use the pinned `packaging/net.donnybeelo.Convey.Practice.yml` with GNOME SDK 51
and official Flatpak Builder. Reuse whichever user/system scope already holds
those tools; do not duplicate SDK installations. Standard build instructions
remain in [BUILDING.md](BUILDING.md).

The installed source snapshot passes 327 engine tests and 44 focused helper
cases, including account scoping, late-result rejection, stable menu IDs,
received-time/DST formatting and markup safety. A private D-Bus fixture also
exercises the tray menu and count changes. The focused executable is
`test-recipient-aliases`; the fixture switch `--tray-fixture` uses synthetic mail
only and must not be confused with real mail delivery validation.

Keep profiles, credentials, private operational notes, local build directories,
bundles and signing keys outside version control. Signed installation packages
are distributed separately; no signing secret or personal account configuration
belongs in this repository.
