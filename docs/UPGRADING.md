# Ubuntu 26.10 upgrades / Aktualisieren

The package name remains `griabuntu-mail`; the next version is
`51.0+griassdi20261028.8`, greater than the `.5`/`.6`/`.7` native previews. The executable,
application ID, GSettings path, data directories and secret schema established
by that preview remain unchanged. No package script launches the app, copies
profiles, rewrites accounts or removes personal data.

Close the application before installing. Preserve a backup of its configuration
and data while it is closed. Then install the local package using Ubuntu's
package manager, so missing distribution dependencies are resolved:

```sh
sudo apt install ./griabuntu-mail_51.0+griassdi20261028.8_amd64.deb
```

This is an update of an existing **native Griaß di Mail** installation. It is
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

## Display-name change · 2026-10-28

The app is now **Griaß di Mail**, as selected by the owner. The ASCII repository
name is `griass-di-mail`. The existing `griabuntu-mail` package/executable,
`io.github.d3rpapah0d3n.GriabuntuMail` ID, settings paths, database filenames and
keyring schemas remain compatibility identifiers. Keeping these stable makes
this an ordinary upgrade of the existing native installation, with no second
profile or secret migration. The launcher, windows, menus and artwork show the
new name. Original dated release records retain their historical names.

Die App heißt jetzt **Griaß di Mail**. Der bisherige technische Paketname und
die Profilpfade bleiben für das Update erhalten; vorhandene Konten benötigen
wegen der sichtbaren Umbenennung keine neue Einrichtung.
