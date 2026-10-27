# Contact pictures and privacy / Kontaktbilder und Datenschutz

## English

Local desktop contact photos always take priority. Both external-picture
settings are **off by default**. Enabling pictures inside emails is unrelated
and has not been changed by this feature.

1. With **Allow Gravatar contact pictures** enabled, displayed sender/recipient
   addresses are trimmed, lowercased and SHA-256 hashed. Only that hash goes to
   `www.gravatar.com`, together with the connection's IP address and a generic
   Griabuntu Mail user agent. Email hashes are pseudonymous, not anonymous:
   common addresses can be guessed. No name, subject or message body is sent.
2. With the additional **Allow company and website icons** setting enabled,
   and only when a local/Gravatar picture is unavailable, the address's domain
   goes to `icons.duckduckgo.com`. That service also receives the connection's
   IP address. No full address or email hash goes to the icon provider.
   Common personal-mail providers keep initials instead of their provider's logo.
3. Icons can be absent, outdated or inaccurate. They do not authenticate a
   sender, company or message. Website icons are a best-effort fallback, not
   a verified company-logo directory.

Only visible contact widgets perform lookups. Requests use HTTPS, fixed
provider hosts, no cookies, no HTTP redirects, the app's configured proxy,
an eight-second timeout and bounded raster responses. Local/domain literals
and injected paths/headers are rejected. There are no direct requests to
sender-controlled websites. Email HTML resource permissions are unchanged.

Images are cached only in memory (maximum 128 entries, refreshed on subsequent
lookups after 30 minutes). A readable policy is available from the main menu
under **Contact pictures and privacy**, without enabling external lookups. Switching off a
permission cancels the affected lookups, removes displayed external pictures,
clears the cache and leaves local photos or initials. Restarting forgets the
cache. Withdrawal cannot retract a request already received by a provider.
Provider URLs, hashes and addresses are not written to diagnostic logs.

Provider information:
- [Gravatar image API](https://docs.gravatar.com/sdk/images/)
- [Automattic privacy policy](https://automattic.com/privacy/)
- [Gravatar API responsible-use guidelines](https://developer.wordpress.com/docs/api/guidelines-for-responsible-use-of-automattics-apis/)
- [DuckDuckGo favicon service](https://duckduckgo.com/duckduckgo-help-pages/privacy/favicons)
- [DuckDuckGo privacy policy](https://duckduckgo.com/privacy)

## Deutsch

Lokale Kontaktfotos haben Vorrang. Externe Abrufe sind standardmäßig aus.
In den Einstellungen lassen sich Gravatar-Personenbilder und anschließend
Firmen-/Website-Symbole getrennt freigeben. Gravatar erhält den SHA-256-Hash
der angezeigten Mailadresse; DuckDuckGo erhält beim zusätzlichen Symbolabruf
nur die Domain. Beide Anbieter sehen die IP-Adresse der Verbindung.
Ein Hash ist keine vollständige Anonymisierung. Mailtext, Betreff und Name
werden nicht übertragen. Der konfigurierte App-Proxy wird berücksichtigt.

Reihenfolge: lokales Foto → freigegebenes Gravatar-Bild → zusätzlich
freigegebenes Website-Symbol → Initialen. Bei allgemeinen Mailanbietern
wie Gmail und Outlook wird deren Logo nicht als Firmenzugehörigkeit angezeigt.
Die Bilder bestätigen keine Identität. Ein Website-Symbol kann fehlen oder
ungenau sein. Ohne Freigabe bleiben ausschließlich lokale Fotos und Initialen.

Die App hält nur einen begrenzten Arbeitsspeicher-Cache. Beim Abschalten werden
laufende Abrufe abgebrochen, der Cache gelöscht und externe Bilder entfernt.
Bereits beim Anbieter angekommene Abrufe lassen sich nicht zurückholen.
Die bestehenden Einstellungen für Bilder im eigentlichen Mailtext bleiben
unverändert. Für Tests werden ausschließlich synthetische Adressen verwendet.
