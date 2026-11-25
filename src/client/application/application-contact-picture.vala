/* Copyright 2026 Markus Kainer <projekt@kainer.co.at>
 * SPDX-License-Identifier: GPL-3.0-only
 * Downstream addition: 2026-10-27 — consent-controlled contact pictures.
 */

/** One picture policy for list senders, message senders and recipient popovers. */
public class Application.ContactPicture : GLib.Object {
    private weak Adw.Avatar? avatar;
    private Contact? contact;
    private GriabuntuMail.RFC822.MailboxAddress mailbox;
    private Configuration config;
    private GLib.Cancellable? pending;
    private bool closed = false;
    private static Soup.Session? session;
    private static Gee.HashMap<string, Gdk.Texture?>? cache;
    private const size_t MAX_BYTES = 524288;
    private static int64 cache_epoch = 0;
    private const int64 CACHE_TTL_US = 30 * 60 * 1000000;

    public ContactPicture(Adw.Avatar avatar, Contact? contact,
                          GriabuntuMail.RFC822.MailboxAddress mailbox,
                          Configuration config) {
        this.avatar = avatar;
        this.contact = contact;
        this.mailbox = mailbox;
        this.config = config;
        avatar.map.connect(refresh);
        avatar.unmap.connect(cancel);
        if (contact != null) contact.notify["avatar"].connect(refresh);
        config.settings.changed.connect(on_preference_changed);
        refresh();
    }

    public void close() {
        this.closed = true;
        cancel();
        if (this.avatar != null) {
            this.avatar.map.disconnect(refresh);
            this.avatar.unmap.disconnect(cancel);
        }
        if (this.contact != null) this.contact.notify["avatar"].disconnect(refresh);
        this.config.settings.changed.disconnect(on_preference_changed);
    }

    ~ContactPicture() { close(); }

    private void on_preference_changed(string key) {
        if (key == Configuration.REMOTE_CONTACT_PICTURES_KEY ||
            key == Configuration.COMPANY_PICTURES_KEY ||
            key == Configuration.USE_CUSTOM_PROXY || key == Configuration.PROXY_URI) {
            // Revocation also forgets the memory-only remote cache.
            if (cache != null) cache.clear();
            refresh();
        }
    }

    private void cancel() {
        this.pending?.cancel();
        this.pending = null;
    }

    private void refresh() {
        cancel();
        if (this.closed || this.avatar == null) return;
        this.avatar.custom_image = null;
        if (!this.avatar.get_mapped()) return;
        var request = new GLib.Cancellable();
        this.pending = request;
        load.begin(request);
    }

    /** Reject path/header injection, local names and address literals. */
    public static string? company_domain(string address) {
        var parts = address.strip().split("@");
        if (parts.length != 2 || parts[0].length == 0) return null;
        string domain = parts[1].ascii_down();
        if (domain.length > 253 || !domain.contains(".")) return null;
        if (domain.has_suffix(".local") || domain.has_suffix(".localhost") ||
            domain.has_suffix(".internal") || domain.has_suffix(".lan") ||
            domain.has_suffix(".home") || domain.has_suffix(".home.arpa") ||
            domain.has_suffix(".onion") || domain.has_suffix(".test") ||
            domain.has_suffix(".invalid") || domain.has_suffix(".example")) return null;
        foreach (string label in domain.split(".")) {
            if (label.length == 0 || label.length > 63 || label.has_prefix("-") ||
                label.has_suffix("-")) return null;
            foreach (char c in label.to_utf8()) {
                if (!(c >= 'a' && c <= 'z') && !(c >= '0' && c <= '9') && c != '-') return null;
            }
        }
        if (new GLib.InetAddress.from_string(domain) != null) return null;
        return domain;
    }

    public static string gravatar_url(string address) {
        string hash = GLib.Checksum.compute_for_string(
            GLib.ChecksumType.SHA256, address.strip().down()
        );
        return "https://www.gravatar.com/avatar/" + hash + "?s=96&d=404&r=g";
    }

    public static string[] request_urls(string address, bool enabled, bool companies) {
        string[] urls = {};
        string? domain = company_domain(address);
        if (!enabled || domain == null) return urls;
        urls += gravatar_url(address);
        // A free-mail provider's logo does not identify the sender's company.
        string[] providers = { "gmail.com", "googlemail.com", "outlook.com", "hotmail.com",
            "live.com", "yahoo.com", "icloud.com", "aol.com", "gmx.de", "gmx.at", "gmx.net",
            "web.de", "proton.me", "protonmail.com", "pm.me", "mail.com" };
        bool personal = false;
        foreach (string provider in providers) if (domain == provider) personal = true;
        if (companies && !personal) urls += "https://icons.duckduckgo.com/ip3/" + domain + ".ico";
        return urls;
    }

    private async void load(GLib.Cancellable request) {
        Gdk.Texture? picture = null;
        // Desktop photos always win, including when external lookups are off.
        var icon = this.contact != null ? this.contact.avatar : null;
        if (icon != null) {
            GLib.InputStream? stream = null;
            try {
                stream = yield icon.load_async(96, request);
                var pixbuf = yield new Gdk.Pixbuf.from_stream_at_scale_async(
                    stream, 96, 96, true, request
                );
                picture = Gdk.Texture.for_pixbuf(pixbuf);
            } catch (GLib.Error error) {
                // An unreadable local photo must not suppress the fallbacks.
            } finally {
                if (stream != null) {
                    try { yield stream.close_async(GLib.Priority.DEFAULT, null); }
                    catch (GLib.Error error) { }
                }
            }
        }
        if (picture == null && !request.is_cancelled() &&
            this.config.remote_contact_pictures && !this.mailbox.is_spoofed()) {
            foreach (string url in request_urls(this.mailbox.address, true, this.config.company_pictures)) {
                if (picture != null || request.is_cancelled() || !this.config.remote_contact_pictures) break;
                picture = yield fetch(url, this.config, request);
            }
        }
        if (!this.closed && this.avatar != null && this.avatar.get_mapped() &&
            !request.is_cancelled() && this.pending == request) {
            this.avatar.custom_image = picture;
        }
    }

    public static bool is_raster(uint8[] data) {
        if (data.length < 12) return false;
        return (data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4e && data[3] == 0x47 &&
                data[4] == 0x0d && data[5] == 0x0a && data[6] == 0x1a && data[7] == 0x0a) ||
               (data[0] == 0xff && data[1] == 0xd8 && data[2] == 0xff) ||
               (data[0] == 0 && data[1] == 0 && data[2] == 1 && data[3] == 0) ||
               (data[0] == 'R' && data[1] == 'I' && data[2] == 'F' && data[3] == 'F' &&
                data[8] == 'W' && data[9] == 'E' && data[10] == 'B' && data[11] == 'P');
    }

    private static async Gdk.Texture? fetch(string url, Configuration config, GLib.Cancellable cancellable) {
        if (cache == null) cache = new Gee.HashMap<string, Gdk.Texture?>();
        if (GLib.get_monotonic_time() - cache_epoch > CACHE_TTL_US) {
            cache.clear();
            cache_epoch = GLib.get_monotonic_time();
        }
        if (cache.has_key(url)) return cache.get(url);
        if (session == null) {
            session = (Soup.Session) GLib.Object.new(typeof(Soup.Session),
                "timeout", 8u, "max-conns", 4, "max-conns-per-host", 2,
                "user-agent", "Griass-di-Mail/" + Config.VERSION
            );
        }
        session.proxy_resolver = config.get_proxy_resolver() ?? GLib.ProxyResolver.get_default();
        Gdk.Texture? result = null;
        GLib.InputStream? stream = null;
        try {
            var message = new Soup.Message("GET", url);
            message.flags = Soup.MessageFlags.NO_REDIRECT;
            message.request_headers.append("Accept", "image/png,image/jpeg,image/webp,image/x-icon,image/vnd.microsoft.icon");
            stream = yield session.send_async(message, GLib.Priority.DEFAULT, cancellable);
            if (message.status_code == 404) {
                if (cache.size >= 128) cache.clear();
                cache.set(url, null);
                return null;
            }
            if (message.status_code != 200 || message.response_headers.get_content_length() > MAX_BYTES) return null;
            string? mime = message.response_headers.get_content_type(null);
            if (mime != "image/png" && mime != "image/jpeg" && mime != "image/webp" &&
                mime != "image/x-icon" && mime != "image/vnd.microsoft.icon") return null;
            var data = new GLib.ByteArray();
            while (true) {
                var chunk = yield stream.read_bytes_async(8192, GLib.Priority.DEFAULT, cancellable);
                if (chunk.get_size() == 0) break;
                if (data.len + chunk.get_size() > MAX_BYTES) return null;
                data.append(chunk.get_data());
            }
            // MIME headers are not enough: do not hand an SVG/XML payload to a
            // vector loader even when a provider labels it as a raster image.
            if (!is_raster(data.data)) return null;
            var loader = new Gdk.PixbufLoader();
            bool oversized = false;
            loader.size_prepared.connect((width, height) => {
                oversized = width < 1 || height < 1 || width > 2048 || height > 2048;
                loader.set_size(96, 96);
            });
            loader.write(data.data);
            loader.close();
            if (!oversized && loader.get_pixbuf() != null) result = Gdk.Texture.for_pixbuf(loader.get_pixbuf());
            if (!cancellable.is_cancelled()) {
                if (cache.size >= 128) cache.clear();
                cache.set(url, result);
            }
        } catch (GLib.Error error) {
            // No email addresses, hashes or URLs in logs. Initials remain usable.
        } finally {
            if (stream != null) {
                try { yield stream.close_async(GLib.Priority.DEFAULT, null); }
                catch (GLib.Error error) { }
            }
        }
        return result;
    }
}
