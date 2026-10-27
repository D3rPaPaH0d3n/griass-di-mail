# Ubuntu 26.10 upgrades / Aktualisieren

The package name remains `griabuntu-mail`; the next version is
`51.0+griabuntu20261027.6`, greater than the `.5` native preview. The executable,
application ID, GSettings path, data directories and secret schema established
by that preview remain unchanged. No package script launches the app, copies
profiles, rewrites accounts or removes personal data.

Close the application before installing. Preserve a backup of its configuration
and data while it is closed. Then install the local package using Ubuntu's
package manager, so missing distribution dependencies are resolved:

```sh
sudo apt install ./griabuntu-mail_51.0+griabuntu20261027.6_amd64.deb
```

This is an update of an existing **native Griabuntu Mail** installation. It is
not an automatic migration from Convey, Geary or a Flatpak profile. Matching
the package version and stable paths supports continuity, but an end-to-end
upgrade of a personal laptop is only confirmed after that laptop is tested.
No personal mail account is used for build or package acceptance tests.

## Deutsch

Die neue `.deb` aktualisiert das vorhandene native Paket `griabuntu-mail`.
Die bestehenden Griabuntu-Mail-Konten, Einstellungen, Datenpfade und
Schlüsselbund-IDs bleiben erhalten. Vor der Installation die App vollständig
beenden und die geschlossenen Datenverzeichnisse sichern. Anschließend den
obigen `sudo apt install`-Befehl ausführen. Das Paket startet die App nicht
automatisch und verändert keine persönlichen Nachrichten.

Konten aus Convey, Geary oder Flatpak werden nicht stillschweigend übernommen.
Ein Paket-Upgrade mit synthetischen Daten ersetzt keine Prüfung des konkreten
OmniLinux-Laptops. Unterstütztes Ziel dieser Version: Ubuntu 26.10, amd64.
