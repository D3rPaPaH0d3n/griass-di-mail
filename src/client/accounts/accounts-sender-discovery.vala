/* New downstream file: 2026-10-28. GPL-3.0-only; see COPYING. */

/** Result of the optional, read-only provider identity lookup. */
public enum Accounts.SenderDiscoveryStatus {
    UNSUPPORTED,
    IDLE,
    LOADING,
    READY,
    UNAVAILABLE,
    API_DISABLED;
}

internal errordomain Accounts.SenderDiscoveryError {
    API_DISABLED,
    UNAVAILABLE,
    INVALID_RESPONSE;
}

/**
 * Reads explicitly verified send-as identities, never inferred recipients.
 *
 * Google's existing mail.google.com OAuth scope permits sendAs.list. Some
 * desktop OAuth clients do not have the Gmail REST API enabled, however; this
 * is distinct from expired credentials and must not prompt a re-login loop.
 */
internal class Accounts.SenderDiscovery : GLib.Object {
    private const string GMAIL_URI =
        "https://gmail.googleapis.com/gmail/v1/users/me/settings/sendAs" +
        "?fields=sendAs(sendAsEmail,displayName,isPrimary,verificationStatus)";
    private const size_t MAX_RESPONSE_BYTES = 512 * 1024;

    internal static async Gee.List<GriabuntuMail.RFC822.MailboxAddress> fetch_gmail(
        string token, GLib.Cancellable? cancellable
    ) throws GLib.Error {
        var session = new Soup.Session() { timeout = 20, idle_timeout = 20 };
        if (GriabuntuMail.Endpoint.proxy_resolver != null) {
            session.proxy_resolver = GriabuntuMail.Endpoint.proxy_resolver;
        }
        var request = new Soup.Message("GET", GMAIL_URI);
        // Never forward a credential to a redirected origin.
        request.flags = Soup.MessageFlags.NO_REDIRECT;
        request.request_headers.replace("Authorization", "Bearer " + token);
        request.request_headers.replace("Accept", "application/json");
        GLib.InputStream? stream = null;
        try {
            stream = yield session.send_async(request, GLib.Priority.DEFAULT, cancellable);
            var body = new GLib.ByteArray();
            while (true) {
                var chunk = yield stream.read_bytes_async(8192, GLib.Priority.DEFAULT, cancellable);
                if (chunk.get_size() == 0) break;
                if (body.len + chunk.get_size() > MAX_RESPONSE_BYTES) {
                    throw new SenderDiscoveryError.INVALID_RESPONSE("Identity response is too large");
                }
                body.append(chunk.get_data());
            }
            // The response and OAuth token must never appear in logs.
            body.append(new uint8[] { 0 });
            string json = (string) body.data;
            if (request.status_code != Soup.Status.OK) {
                if (request.status_code == Soup.Status.FORBIDDEN && is_api_disabled(json)) {
                    throw new SenderDiscoveryError.API_DISABLED("Gmail API is disabled for this sign-in client");
                }
                throw new SenderDiscoveryError.UNAVAILABLE("Provider identity lookup is unavailable");
            }
            return parse_gmail(json);
        } finally {
            request.request_headers.remove("Authorization");
            if (stream != null) {
                try { yield stream.close_async(GLib.Priority.DEFAULT, null); }
                catch (GLib.Error err) { /* Best effort cleanup. */ }
            }
            session.abort();
        }
    }

    internal static bool is_api_disabled(string json) {
        try {
            var parser = new Json.Parser();
            parser.load_from_data(json);
            var root = parser.get_root();
            if (root == null || root.get_node_type() != Json.NodeType.OBJECT) return false;
            var error_node = root.get_object().get_member("error");
            if (error_node == null || error_node.get_node_type() != Json.NodeType.OBJECT) return false;
            var error = error_node.get_object();
            foreach (string member in new string[] { "errors", "details" }) {
                var list_node = error.get_member(member);
                if (list_node == null || list_node.get_node_type() != Json.NodeType.ARRAY) continue;
                foreach (var item in list_node.get_array().get_elements()) {
                    if (item.get_node_type() != Json.NodeType.OBJECT) continue;
                    string? reason = get_string(item.get_object(), "reason");
                    if (reason == "accessNotConfigured" || reason == "SERVICE_DISABLED") return true;
                }
            }
        } catch (GLib.Error err) { /* Unrecognised failures remain unavailable. */ }
        return false;
    }

    internal static Gee.List<GriabuntuMail.RFC822.MailboxAddress> parse_gmail(
        string json
    ) throws GLib.Error {
        var parser = new Json.Parser();
        parser.load_from_data(json);
        var root = parser.get_root();
        if (root == null || root.get_node_type() != Json.NodeType.OBJECT) {
            throw new SenderDiscoveryError.INVALID_RESPONSE("Invalid identity response");
        }
        var list_node = root.get_object().get_member("sendAs");
        if (list_node == null || list_node.get_node_type() != Json.NodeType.ARRAY) {
            throw new SenderDiscoveryError.INVALID_RESPONSE("Missing identity list");
        }
        var result = new Gee.ArrayList<GriabuntuMail.RFC822.MailboxAddress>();
        var seen = new Gee.HashSet<string>();
        foreach (var item in list_node.get_array().get_elements()) {
            if (item.get_node_type() != Json.NodeType.OBJECT) continue;
            var identity = item.get_object();
            var primary = identity.get_member("isPrimary");
            bool is_primary = primary != null &&
                primary.get_node_type() == Json.NodeType.VALUE &&
                primary.get_value_type() == typeof(bool) && primary.get_boolean();
            if (!is_primary && get_string(identity, "verificationStatus") != "accepted") continue;
            string? address = get_string(identity, "sendAsEmail");
            if (address == null || address != address.strip() ||
                address.contains("\r") || address.contains("\n") ||
                !GriabuntuMail.RFC822.MailboxAddress.is_valid_address(address)) continue;
            try {
                var parsed = new GriabuntuMail.RFC822.MailboxAddresses.from_rfc822_string(address);
                if (parsed.size != 1 || parsed.get(0).address != address) continue;
            } catch (GLib.Error err) { continue; }
            if (!seen.add(address.casefold())) continue;
            string? name = get_string(identity, "displayName");
            if (name != null) name = name.replace("\r", " ").replace("\n", " ").strip();
            result.add(new GriabuntuMail.RFC822.MailboxAddress(name, address));
        }
        return result;
    }

    /** Add only missing identities; preserve local names, ordering and settings. */
    internal static bool merge(
        GriabuntuMail.AccountInformation account,
        Gee.List<GriabuntuMail.RFC822.MailboxAddress> identities
    ) {
        bool changed = false;
        foreach (var identity in identities) {
            changed = account.append_sender(identity) || changed;
        }
        return changed;
    }

    private static string? get_string(Json.Object object, string member) {
        var node = object.get_member(member);
        return node != null && node.get_node_type() == Json.NodeType.VALUE &&
            node.get_value_type() == typeof(string) ? node.get_string() : null;
    }
}
