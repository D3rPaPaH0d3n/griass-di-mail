# Griaß di Mail

![Griaß di Mail](brand/brand-banner-griass-di-mail.png)

A native GTK4/libadwaita mail client for Linux, derived from Convey and Geary. [Deutsch](README.de.md)

The `51.0+griassdi20261028.14` source targets native Ubuntu 26.10 packaging. The panel badge follows the live **All Inboxes** sidebar count; the envelope and recent-arrivals menu track new messages separately. A nonzero badge can therefore appear next to a closed envelope. The menu retrieves missing sender and subject information without downloading message bodies for display.

Configure sender aliases and optional account or address colors, or use verified Google send-as identities where the provider permits it. Received times remain visible in selection mode. Contact pictures use local photos first; Gravatar and company-icon lookups require separate consent. TNEF (`winmail.dat`) remains enabled.

[Build from source](BUILDING.md) · [Changes](debian/changelog) · [Upgrade](docs/UPGRADING.md) · [Privacy](docs/PRIVACY.md) · [Earlier .8 preview and checksums](https://github.com/D3rPaPaH0d3n/griass-di-mail/releases/tag/v51.0-griassdi20261028.8)

The package name `griabuntu-mail` and desktop ID `io.github.d3rpapah0d3n.GriabuntuMail` are unchanged. No existing Convey or Flatpak profile is migrated automatically.

Maintained by Markus Kainer. This independent project is not endorsed by Convey, Geary, GNOME or Ubuntu. The application copy is GPL-3.0-only; separate component and artwork licences remain in force. See [AUTHORS](AUTHORS), [notices](THIRD-PARTY-NOTICES.md), [contributing](CONTRIBUTING.md) and [security](SECURITY.md).

Copyright © 2016 Software Freedom Conservancy Inc.
Copyright © 2017–2020 Michael Gratton <mike@vee.net>
Copyright © 2026 Daniel Elia <d.elia@outlook.com>
Downstream changes © 2026 Markus Kainer <projekt@kainer.co.at>
