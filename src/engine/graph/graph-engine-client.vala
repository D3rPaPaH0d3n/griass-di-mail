/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

internal class Geary.Graph.Client : Geary.BaseObject {

    private const string BASE_URI = "https://graph.microsoft.com/v1.0";
    private const uint REQUEST_TIMEOUT_SEC = 30;
    private const int REQUEST_RETRIES = 1;


    internal class Message : Geary.BaseObject {
        public string id = "";
        public string conversation_id = "";
        public Geary.RFC822.MailboxAddresses? from = null;
        public Geary.RFC822.MailboxAddresses? to = null;
        public Geary.RFC822.MailboxAddresses? cc = null;
        public Geary.RFC822.MailboxAddresses? bcc = null;
        public string subject = "";
        public string internet_message_id = "";
        public string body_preview = "";
        public string? body = null;
        public string body_content_type = "text";
        public bool is_read = true;
        public bool is_flagged = false;
        public GLib.DateTime? received_at = null;
        public int64 size = 0;
    }

    internal class MailFolder : Geary.BaseObject {
        public string id = "";
        public string display_name = "";
    }


    private Geary.AccountInformation account;
    private Soup.Session session;


    public Client(Geary.AccountInformation account) {
        this.account = account;
        this.session = new Soup.Session();
        this.session.timeout = REQUEST_TIMEOUT_SEC;
        this.session.idle_timeout = REQUEST_TIMEOUT_SEC;
    }

    public async void ping(GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        yield request_json(
            "GET",
            "/me",
            "$select=id",
            cancellable
        );
    }

    public async Gee.List<Message> list_messages(string folder_id,
                                                 int limit,
                                                 int prefetch_period_days,
                                                 GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        if (limit < 1) {
            limit = 1;
        }
        string filter = "";
        if (prefetch_period_days > 0) {
            GLib.DateTime utc_now = new GLib.DateTime.now_utc();
            GLib.DateTime since = utc_now.add_days(0 - prefetch_period_days);
            filter = "&$filter=receivedDateTime%%20ge%%20%s".printf(
                GLib.Uri.escape_string(
                    since.format("%Y-%m-%dT%H:%M:%SZ"),
                    null,
                    false
                )
            );
        }
        string path = "/me/mailFolders/%s/messages".printf(
            GLib.Uri.escape_string(folder_id, null, false)
        );
        Json.Object root;
        try {
            root = yield request_json(
                "GET",
                path,
                (
                    "$top=%d"
                + "&$orderby=receivedDateTime%%20desc"
                + "&$select=id,conversationId,subject,internetMessageId,receivedDateTime,from,bodyPreview,isRead,flag,size"
                + "%s"
                ).printf(limit, filter),
                cancellable
            );
        } catch (Geary.EngineError.SERVER_UNAVAILABLE err) {
            if (!err.message.contains("(400)")) {
                throw err;
            }
            try {
                root = yield request_json(
                    "GET",
                    path,
                    (
                        "$top=%d"
                        + "&$orderby=receivedDateTime%%20desc"
                        + "&$select=id,conversationId,subject,receivedDateTime,from,bodyPreview,isRead,flag,size"
                        + "%s"
                    ).printf(limit, filter),
                    cancellable
                );
            } catch (Geary.EngineError.SERVER_UNAVAILABLE retry_err) {
                if (!retry_err.message.contains("(400)")) {
                    throw retry_err;
                }
                root = yield request_json(
                    "GET",
                    path,
                    "$top=%d%s".printf(limit, filter),
                    cancellable
                );
            }
        }

        Gee.ArrayList<Message> messages = new Gee.ArrayList<Message>();
        if (root.has_member("value")) {
            Json.Array values = root.get_array_member("value");
            for (uint i = 0; i < values.get_length(); i++) {
                Json.Node value = values.get_element(i);
                if (value.get_node_type() != Json.NodeType.OBJECT) {
                    continue;
                }
                Message parsed = parse_message(values.get_object_element(i), false);
                if (!String.is_empty(parsed.id)) {
                    messages.add(parsed);
                }
            }
        }
        return messages;
    }

    public async Message fetch_message(string message_id,
                                       GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        string path = "/me/messages/%s".printf(
            GLib.Uri.escape_string(message_id, null, false)
        );
        Json.Object root;
        try {
            root = yield request_json(
                "GET",
                path,
                "$select=id,conversationId,subject,internetMessageId,receivedDateTime,"
                + "from,toRecipients,ccRecipients,bccRecipients,bodyPreview,isRead,flag,size,body",
                cancellable
            );
        } catch (Geary.EngineError.SERVER_UNAVAILABLE err) {
            if (!err.message.contains("(400)")) {
                throw err;
            }
            root = yield request_json("GET", path, null, cancellable);
        }
        return parse_message(root, true);
    }

    public async Geary.Memory.Buffer fetch_message_rfc822(
        string message_id,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        string path = "/me/messages/%s/$value".printf(
            GLib.Uri.escape_string(message_id, null, false)
        );
        GLib.Bytes body = yield request_bytes(
            "GET",
            path,
            null,
            cancellable,
            "message/rfc822"
        );
        return new Geary.Memory.ByteBuffer(
            body.get_data(),
            (size_t) body.get_size()
        );
    }

    public async void send_composed_email(Geary.ComposedEmail composed,
                                          bool save_to_sent_items,
                                          GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        Json.Builder builder = new Json.Builder();
        builder.begin_object();
        builder.set_member_name("message");
        builder.begin_object();
        if (composed.subject != null) {
            builder.set_member_name("subject");
            builder.add_string_value(composed.subject.to_string());
        }
        builder.set_member_name("body");
        builder.begin_object();
        if (!String.is_empty(composed.body_html)) {
            builder.set_member_name("contentType");
            builder.add_string_value("HTML");
            builder.set_member_name("content");
            builder.add_string_value(composed.body_html);
        } else {
            builder.set_member_name("contentType");
            builder.add_string_value("Text");
            builder.set_member_name("content");
            builder.add_string_value(composed.body_text ?? "");
        }
        builder.end_object();

        append_mailbox_addresses_to_builder(
            builder, "toRecipients", composed.to
        );
        append_mailbox_addresses_to_builder(
            builder, "ccRecipients", composed.cc
        );
        append_mailbox_addresses_to_builder(
            builder, "bccRecipients", composed.bcc
        );
        append_mailbox_addresses_to_builder(
            builder, "replyTo", composed.reply_to
        );
        builder.end_object();
        builder.set_member_name("saveToSentItems");
        builder.add_boolean_value(save_to_sent_items);
        builder.end_object();

        yield request_no_content(
            "POST",
            "/me/sendMail",
            null,
            cancellable,
            to_json(builder)
        );
    }

    public async void update_message_state(string message_id,
                                           bool? is_read,
                                           bool? is_flagged,
                                           GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        if (is_read == null && is_flagged == null) {
            return;
        }
        string path = "/me/messages/%s".printf(
            GLib.Uri.escape_string(message_id, null, false)
        );
        Json.Builder builder = new Json.Builder();
        builder.begin_object();
        if (is_read != null) {
            builder.set_member_name("isRead");
            builder.add_boolean_value(is_read);
        }
        if (is_flagged != null) {
            builder.set_member_name("flag");
            builder.begin_object();
            builder.set_member_name("flagStatus");
            builder.add_string_value(is_flagged ? "flagged" : "notFlagged");
            builder.end_object();
        }
        builder.end_object();
        yield request_no_content(
            "PATCH",
            path,
            null,
            cancellable,
            to_json(builder)
        );
    }

    public async string move_message(string message_id,
                                     string destination_id,
                                     GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        string path = "/me/messages/%s/move".printf(
            GLib.Uri.escape_string(message_id, null, false)
        );
        Json.Builder builder = new Json.Builder();
        builder.begin_object();
        builder.set_member_name("destinationId");
        builder.add_string_value(destination_id);
        builder.end_object();
        Json.Object moved = yield request_json(
            "POST",
            path,
            null,
            cancellable,
            to_json(builder)
        );
        return get_string_member(moved, "id") ?? "";
    }

    public async void copy_message(string message_id,
                                   string destination_id,
                                   GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        string path = "/me/messages/%s/copy".printf(
            GLib.Uri.escape_string(message_id, null, false)
        );
        Json.Builder builder = new Json.Builder();
        builder.begin_object();
        builder.set_member_name("destinationId");
        builder.add_string_value(destination_id);
        builder.end_object();
        yield request_json(
            "POST",
            path,
            null,
            cancellable,
            to_json(builder)
        );
    }

    public async void delete_message(string message_id,
                                     GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        string path = "/me/messages/%s".printf(
            GLib.Uri.escape_string(message_id, null, false)
        );
        yield request_no_content("DELETE", path, null, cancellable);
    }

    public async MailFolder create_mail_folder(string display_name,
                                               GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        Json.Builder builder = new Json.Builder();
        builder.begin_object();
        builder.set_member_name("displayName");
        builder.add_string_value(display_name);
        builder.end_object();
        Json.Object root = yield request_json(
            "POST",
            "/me/mailFolders",
            null,
            cancellable,
            to_json(builder)
        );
        MailFolder folder = new MailFolder();
        folder.id = get_string_member(root, "id") ?? "";
        folder.display_name = get_string_member(root, "displayName") ?? display_name;
        return folder;
    }

    private async Json.Object request_json(string method,
                                           string path,
                                           string? query,
                                           GLib.Cancellable? cancellable,
                                           string? request_body = null)
        throws GLib.Error {
        yield this.account.load_incoming_credentials(cancellable);

        Geary.Credentials? credentials = this.account.incoming.credentials;
        if (credentials == null || String.is_empty(credentials.token)) {
            throw new Geary.EngineError.SERVER_UNAVAILABLE(
                "No Graph OAuth token available"
            );
        }

        string uri = BASE_URI + path;
        if (!String.is_empty(query)) {
            uri += "?" + query;
        }

        for (int attempt = 0; attempt <= REQUEST_RETRIES; attempt++) {
            var request = new Soup.Message(method, uri);
            request.set_force_http1(true);
            request.request_headers.append(
                "Authorization", "Bearer %s".printf(credentials.token)
            );
            request.request_headers.append("Accept", "application/json");
            request.request_headers.append("Accept-Encoding", "identity");
            request.request_headers.append("Connection", "close");
            if (!String.is_empty(request_body)) {
                uint8[] bytes = request_body.data;
                request.set_request_body_from_bytes(
                    "application/json",
                    new GLib.Bytes(bytes)
                );
            }

            GLib.Bytes body;
            try {
                body = yield this.session.send_and_read_async(
                    request,
                    GLib.Priority.DEFAULT,
                    cancellable
                );
            } catch (GLib.IOError.TIMED_OUT err) {
                if (attempt < REQUEST_RETRIES) {
                    debug("Graph request timed out, retrying: %s", uri);
                    continue;
                }
                throw new Geary.EngineError.SERVER_UNAVAILABLE(
                    "Graph request timed out (%s)",
                    uri
                );
            }

            if (request.status_code < 200 || request.status_code >= 300) {
                throw new Geary.EngineError.SERVER_UNAVAILABLE(
                    "Graph request failed (%u): %s (%s)",
                    request.status_code,
                    request.reason_phrase,
                    uri
                );
            }

            var parser = new Json.Parser();
            try {
                parser.load_from_data(
                    (string) body.get_data(),
                    (ssize_t) body.get_size()
                );
            } catch (GLib.Error err) {
                if (attempt < REQUEST_RETRIES) {
                    debug("Graph response decode failed, retrying: %s", uri);
                    continue;
                }
                throw new Geary.EngineError.SERVER_UNAVAILABLE(
                    "Graph response decode failed (%s): %s",
                    uri,
                    err.message
                );
            }
            Json.Node root = parser.get_root();
            if (root == null || root.get_node_type() != Json.NodeType.OBJECT) {
                throw new Geary.EngineError.SERVER_UNAVAILABLE(
                    "Invalid Graph response payload"
                );
            }
            return root.get_object();
        }

        throw new Geary.EngineError.SERVER_UNAVAILABLE(
            "Graph request failed (%s)",
            uri
        );
    }

    private async GLib.Bytes request_bytes(string method,
                                           string path,
                                           string? query,
                                           GLib.Cancellable? cancellable,
                                           string accept = "application/octet-stream")
        throws GLib.Error {
        yield this.account.load_incoming_credentials(cancellable);

        Geary.Credentials? credentials = this.account.incoming.credentials;
        if (credentials == null || String.is_empty(credentials.token)) {
            throw new Geary.EngineError.SERVER_UNAVAILABLE(
                "No Graph OAuth token available"
            );
        }

        string uri = BASE_URI + path;
        if (!String.is_empty(query)) {
            uri += "?" + query;
        }

        for (int attempt = 0; attempt <= REQUEST_RETRIES; attempt++) {
            var request = new Soup.Message(method, uri);
            request.set_force_http1(true);
            request.request_headers.append(
                "Authorization", "Bearer %s".printf(credentials.token)
            );
            request.request_headers.append("Accept", accept);
            request.request_headers.append("Accept-Encoding", "identity");
            request.request_headers.append("Connection", "close");

            GLib.Bytes body;
            try {
                body = yield this.session.send_and_read_async(
                    request,
                    GLib.Priority.DEFAULT,
                    cancellable
                );
            } catch (GLib.IOError.TIMED_OUT err) {
                if (attempt < REQUEST_RETRIES) {
                    debug("Graph request timed out, retrying: %s", uri);
                    continue;
                }
                throw new Geary.EngineError.SERVER_UNAVAILABLE(
                    "Graph request timed out (%s)",
                    uri
                );
            }

            if (request.status_code < 200 || request.status_code >= 300) {
                throw new Geary.EngineError.SERVER_UNAVAILABLE(
                    "Graph request failed (%u): %s (%s)",
                    request.status_code,
                    request.reason_phrase,
                    uri
                );
            }
            return body;
        }

        throw new Geary.EngineError.SERVER_UNAVAILABLE(
            "Graph request failed (%s)",
            uri
        );
    }

    private async void request_no_content(string method,
                                          string path,
                                          string? query,
                                          GLib.Cancellable? cancellable,
                                          string? request_body = null)
        throws GLib.Error {
        yield this.account.load_incoming_credentials(cancellable);

        Geary.Credentials? credentials = this.account.incoming.credentials;
        if (credentials == null || String.is_empty(credentials.token)) {
            throw new Geary.EngineError.SERVER_UNAVAILABLE(
                "No Graph OAuth token available"
            );
        }

        string uri = BASE_URI + path;
        if (!String.is_empty(query)) {
            uri += "?" + query;
        }

        for (int attempt = 0; attempt <= REQUEST_RETRIES; attempt++) {
            var request = new Soup.Message(method, uri);
            request.set_force_http1(true);
            request.request_headers.append(
                "Authorization", "Bearer %s".printf(credentials.token)
            );
            request.request_headers.append("Accept", "application/json");
            request.request_headers.append("Accept-Encoding", "identity");
            request.request_headers.append("Connection", "close");
            if (!String.is_empty(request_body)) {
                uint8[] bytes = request_body.data;
                request.set_request_body_from_bytes(
                    "application/json",
                    new GLib.Bytes(bytes)
                );
            }

            try {
                yield this.session.send_and_read_async(
                    request,
                    GLib.Priority.DEFAULT,
                    cancellable
                );
            } catch (GLib.IOError.TIMED_OUT err) {
                if (attempt < REQUEST_RETRIES) {
                    debug("Graph request timed out, retrying: %s", uri);
                    continue;
                }
                throw new Geary.EngineError.SERVER_UNAVAILABLE(
                    "Graph request timed out (%s)",
                    uri
                );
            }

            if (request.status_code < 200 || request.status_code >= 300) {
                throw new Geary.EngineError.SERVER_UNAVAILABLE(
                    "Graph request failed (%u): %s (%s)",
                    request.status_code,
                    request.reason_phrase,
                    uri
                );
            }
            return;
        }

        throw new Geary.EngineError.SERVER_UNAVAILABLE(
            "Graph request failed (%s)",
            uri
        );
    }

    private Message parse_message(Json.Object object, bool include_body)
        throws GLib.Error {
        var parsed = new Message();
        parsed.id = get_string_member(object, "id") ?? "";
        parsed.conversation_id = get_string_member(object, "conversationId") ?? "";
        parsed.subject = get_string_member(object, "subject") ?? "";
        parsed.internet_message_id = get_string_member(object, "internetMessageId") ?? "";
        parsed.body_preview = get_string_member(object, "bodyPreview") ?? "";
        parsed.is_read = get_bool_member(object, "isRead", true);
        parsed.is_flagged = get_flagged_member(object, "flag");
        parsed.received_at = parse_datetime(get_string_member(object, "receivedDateTime"));
        parsed.size = get_int_member(object, "size", 0);
        parsed.from = parse_address_member(object, "from");
        parsed.to = parse_addresses_member(object, "toRecipients");
        parsed.cc = parse_addresses_member(object, "ccRecipients");
        parsed.bcc = parse_addresses_member(object, "bccRecipients");

        if (include_body &&
            object.has_member("body") &&
            object.get_member("body").get_node_type() == Json.NodeType.OBJECT) {
            Json.Object body = object.get_object_member("body");
            parsed.body = get_string_member(body, "content");
            parsed.body_content_type = get_string_member(body, "contentType") ?? "text";
        }

        return parsed;
    }

    private static Geary.RFC822.MailboxAddresses? parse_address_member(Json.Object object,
                                                                        string key) {
        Geary.RFC822.MailboxAddress? mailbox = null;
        if (object.has_member(key) &&
            object.get_member(key).get_node_type() == Json.NodeType.OBJECT) {
            Json.Object wrapper = object.get_object_member(key);
            mailbox = parse_email_address_wrapper(wrapper);
        }
        return mailbox == null ? null : new Geary.RFC822.MailboxAddresses.single(mailbox);
    }

    private static Geary.RFC822.MailboxAddresses? parse_addresses_member(Json.Object object,
                                                                          string key) {
        if (!object.has_member(key) ||
            object.get_member(key).get_node_type() != Json.NodeType.ARRAY) {
            return null;
        }
        Json.Array values = object.get_array_member(key);
        Gee.ArrayList<Geary.RFC822.MailboxAddress> addresses =
            new Gee.ArrayList<Geary.RFC822.MailboxAddress>();
        for (uint i = 0; i < values.get_length(); i++) {
            Json.Node value = values.get_element(i);
            if (value.get_node_type() != Json.NodeType.OBJECT) {
                continue;
            }
            Geary.RFC822.MailboxAddress? mailbox =
                parse_email_address_wrapper(values.get_object_element(i));
            if (mailbox != null) {
                addresses.add(mailbox);
            }
        }
        return addresses.is_empty ? null : new Geary.RFC822.MailboxAddresses(addresses);
    }

    private static Geary.RFC822.MailboxAddress? parse_email_address_wrapper(Json.Object wrapper) {
        if (!wrapper.has_member("emailAddress") ||
            wrapper.get_member("emailAddress").get_node_type() != Json.NodeType.OBJECT) {
            return null;
        }
        Json.Object email = wrapper.get_object_member("emailAddress");
        string? address = get_string_member(email, "address");
        if (String.is_empty(address)) {
            return null;
        }
        return new Geary.RFC822.MailboxAddress(get_string_member(email, "name"), address);
    }

    private static string? get_string_member(Json.Object object, string key) {
        if (!object.has_member(key)) {
            return null;
        }
        Json.Node member = object.get_member(key);
        if (member == null ||
            member.get_node_type() == Json.NodeType.NULL ||
            member.get_node_type() != Json.NodeType.VALUE ||
            member.get_value_type() != typeof(string)) {
            return null;
        }
        return member.get_string().make_valid();
    }

    private static bool get_bool_member(Json.Object object,
                                        string key,
                                        bool default_value) {
        bool value = default_value;
        if (object.has_member(key)) {
            Json.Node member = object.get_member(key);
            if (member != null &&
                member.get_node_type() == Json.NodeType.VALUE &&
                member.get_value_type() == typeof(bool)) {
                value = member.get_boolean();
            }
        }
        return value;
    }

    private static bool get_flagged_member(Json.Object object, string key) {
        if (!object.has_member(key) ||
            object.get_member(key).get_node_type() != Json.NodeType.OBJECT) {
            return false;
        }
        Json.Object flag = object.get_object_member(key);
        return (get_string_member(flag, "flagStatus") ?? "") == "flagged";
    }

    private static int64 get_int_member(Json.Object object,
                                        string key,
                                        int64 default_value) {
        int64 value = default_value;
        if (object.has_member(key)) {
            Json.Node member = object.get_member(key);
            if (member != null &&
                member.get_node_type() == Json.NodeType.VALUE &&
                (member.get_value_type() == typeof(int64) ||
                 member.get_value_type() == typeof(int))) {
                value = member.get_int();
            }
        }
        return value;
    }

    private static GLib.DateTime? parse_datetime(string? value) {
        if (String.is_empty(value)) {
            return null;
        }
        return new GLib.DateTime.from_iso8601(value, null);
    }

    private static string to_json(Json.Builder builder) {
        Json.Node node = builder.get_root();
        Json.Generator generator = new Json.Generator();
        generator.set_root(node);
        return generator.to_data(null);
    }

    private static void append_mailbox_addresses_to_builder(
        Json.Builder builder,
        string name,
        Geary.RFC822.MailboxAddresses? addresses
    ) {
        if (addresses == null || addresses.size == 0) {
            return;
        }
        builder.set_member_name(name);
        builder.begin_array();
        foreach (Geary.RFC822.MailboxAddress address in addresses) {
            if (String.is_empty(address.address)) {
                continue;
            }
            builder.begin_object();
            builder.set_member_name("emailAddress");
            builder.begin_object();
            if (!String.is_empty(address.name)) {
                builder.set_member_name("name");
                builder.add_string_value(address.name);
            }
            builder.set_member_name("address");
            builder.add_string_value(address.address);
            builder.end_object();
            builder.end_object();
        }
        builder.end_array();
    }

}
