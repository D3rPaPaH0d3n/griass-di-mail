<div align="center">

![Griaß di Mail](brand/brand-banner-griass-di-mail.png)

# A calmer place for your mail.

**Griaß di Mail · native Linux email · Ubuntu 26.10**

Pastel teal and warm peach. Clear conversations. Your contacts, your choice.

[Deutsch](README.de.md) · [Build](BUILDING.md) · [Privacy](docs/PRIVACY.md) · [Contribute](CONTRIBUTING.md) · [Licences](THIRD-PARTY-NOTICES.md)

</div>

## Made for the Linux desktop

An independent **Convey/Geary fork**, built with GTK4 and libadwaita. Native
menus, keyboard navigation and desktop integration, with restrained petrol/teal
and copper/peach surfaces. System light, dark and high-contrast modes stay in control.

Maintained by **Markus Kainer · [D3rPaPaH0d3n](https://github.com/D3rPaPaH0d3n)**.
Contact: **[projekt@kainer.co.at](mailto:projekt@kainer.co.at)** or
[GitHub Issues](https://github.com/D3rPaPaH0d3n/griass-di-mail/issues).

## Useful details, close at hand

| Feature | What it does |
| --- | --- |
| Conversations | Read and write mail with native controls and WebKit rendering |
| Contact pictures | Local photo → opt-in Gravatar → separately opt-in website icon → initials |
| Recipient aliases | Show which configured identities appear in To/Cc, with overflow badges |
| Precise received time | IMAP received timestamp with seconds and timezone details |
| New-mail tray | Session-new arrivals, deduplicated across accounts and folders |
| Attachments | TNEF/winmail.dat support remains enabled |
| Native package | A `.deb` built against Ubuntu 26.10 libraries |

External contact pictures are **off by default**. Separate consent switches
explain what goes to Gravatar and DuckDuckGo; no message content is sent.
Pictures do not verify a sender. Permissions for images inside email messages
are unchanged. Read [the full picture policy](docs/PRIVACY.md).

The tray counts new mail this session, not all historical unread mail, and starts
empty after restart. Reply opens a draft, never auto-sends. Archive and Delete
target one message using existing archive/Trash folders. Shell support affects
notification behaviour; synthetic tests do not establish personal-mail acceptance.

<details>
<summary>See the contact-picture privacy settings</summary>

![Native contact-picture settings](docs/images/contact-picture-settings.png)

*Native preferences template rendered with synthetic state; no real accounts.*

</details>

## Download the development preview

[Ubuntu 26.10 · amd64 · .deb](https://github.com/D3rPaPaH0d3n/griass-di-mail/releases/download/v51.0-griassdi20261028.8/griabuntu-mail_51.0%2Bgriassdi20261028.8_amd64.deb) · [Source and checksums](https://github.com/D3rPaPaH0d3n/griass-di-mail/releases/tag/v51.0-griassdi20261028.8)

Free of charge. Close the app and read the [upgrade guide](docs/UPGRADING.md)
before updating. The compatibility package remains `griabuntu-mail`, keeping
existing native profiles in their established locations.

## Build and update

Supported package target: **Ubuntu 26.10, amd64**. From the current development branch:

```sh
sudo apt-get build-dep .
DEB_BUILD_OPTIONS=parallel=6 dpkg-buildpackage -b -us -uc
```

Install the inspected package with `sudo apt install ./griabuntu-mail_<version>_amd64.deb`.
Close the app and back up its closed data before updating. Do not run it as root.
The package does not start the app or copy accounts. Native Griaß di Mail package,
app-ID and profile paths remain stable; Convey/Geary/Flatpak migration is separate.

[Build guide](BUILDING.md) · [Packaging](debian/README) · [Upgrading](docs/UPGRADING.md) ·
[Current validation](docs/release/PUBLIC-PREVIEW-20261028.md)

This is a development preview. Review [release requirements](RELEASE-CHECKLIST.md)
and provide corresponding source before distributing a binary.

## A fork with its history intact

Griaß di Mail is **not official Convey, Geary or Ubuntu**, and does not claim
endorsement by their authors, GNOME or Canonical. The elected application copy
is **GPL-3.0-only**, with TNEF retained. Libraries, icons, sounds and vendored
resources retain their individual terms. Original authors and full history remain.
Maintainer credit does not replace upstream copyright.

The original closed-envelope icon and banner were generated with ChatGPT from
text prompts, as confirmed by the owner. The current banner adapts that supplied
artwork to the selected Griaß di Mail name; the app icon remains unchanged. [Artwork provenance](docs/ARTWORK-PROVENANCE.md).

[COPYING](COPYING) · [AUTHORS](AUTHORS) · [Third-party notices](THIRD-PARTY-NOTICES.md) ·
[Name and trademark review](docs/BRANDING.md) · [Source delivery](docs/release/CORRESPONDING-SOURCE.md)

## Join in

Bug reports, translations and scoped improvements are welcome. Include your
Ubuntu/app version and a synthetic example. Never post credentials, personal
messages or mail databases. See [CONTRIBUTING.md](CONTRIBUTING.md),
[SECURITY.md](SECURITY.md) and, for coding agents, [AGENTS.md](AGENTS.md).

---
Original README notices retained:

Copyright © 2016 Software Freedom Conservancy Inc.
Copyright © 2017–2020 Michael Gratton <mike@vee.net>
Copyright © 2026 Daniel Elia <d.elia@outlook.com>
Downstream changes © 2026 Markus Kainer <projekt@kainer.co.at>

Current name / Aktueller Name: **Griaß di Mail** (2026-10-28).
The native package remains `griabuntu-mail` for existing-profile upgrades;
der technische Paketname bleibt für Updates erhalten. The app remains free;
a voluntary donation button may be considered in future.
