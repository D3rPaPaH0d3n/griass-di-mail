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
        public bool has_attachments = false;
        public bool is_read = true;
        public bool is_flagged = false;
        public GLib.DateTime? received_at = null;
        public int64 size = 0;
        public Gee.HashMap<string,string> internet_message_headers =
            new Gee.HashMap<string,string>();
    }

    internal class MailFolder : Geary.BaseObject {
        public string id = "";
        public string display_name = "";
        public string well_known_name = "";
        public bool is_hidden = false;
    }

    internal class DeltaResult : Geary.BaseObject {
        // Messages that were added or updated
        public Gee.List<Message> changed = new Gee.ArrayList<Message>();
        // Graph message IDs that were deleted/moved out of the folder
        public Gee.Set<string> removed = new Gee.HashSet<string>();
        // The deltaLink to use on the next poll call
        public string delta_link = "";
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
        string path = "/me/mailFolders/%s/messages".printf(
            GLib.Uri.escape_string(folder_id, null, false)
        );
        Json.Object root;
        string[] queries = {
            (
                "$top=%d"
              + "&$orderby=receivedDateTime%%20desc"
              + "&$select=id,conversationId,subject,internetMessageId,receivedDateTime,from,bodyPreview,isRead,flag,size"
            ).printf(limit),
            (
                "$top=%d"
              + "&$select=id,conversationId,subject,internetMessageId,receivedDateTime,from,bodyPreview,isRead,flag,size"
            ).printf(limit),
            "$top=%d".printf(limit),
        };

        root = null;
        foreach (string query in queries) {
            try {
                root = yield request_json("GET", path, query, cancellable);
                break;
            } catch (Geary.EngineError.SERVER_UNAVAILABLE err) {
                if (!err.message.contains("(400)")) {
                    throw err;
                }
            }
        }
        if (root == null) {
            throw new Geary.EngineError.SERVER_UNAVAILABLE(
                "Graph request failed (%s)",
                path
            );
        }

        Gee.ArrayList<Message> messages = new Gee.ArrayList<Message>();
        int total_fetched = 0;
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
                    total_fetched++;
                    if (total_fetched >= limit) {
                        break;
                    }
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
                + "from,toRecipients,ccRecipients,bccRecipients,bodyPreview,hasAttachments,isRead,flag,size,body",
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

    /**
     * Polls the inbox for changes since the last delta call.
     *
     * On the first call pass null for delta_link; the method will issue a
     * full delta sync to establish a baseline and return a delta_link for
     * future calls.  On subsequent calls pass the delta_link from the
     * previous result; only changes since that point are returned.
     *
     * The returned DeltaResult.delta_link must be saved and passed back
     * on the next call.
     */
    public async DeltaResult delta_messages(
        string folder_id,
        string? delta_link,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        // Build the initial URL: either the saved deltaLink or a fresh
        // delta request that selects only the fields we need.
        string url;
        if (!String.is_empty(delta_link)) {
            url = delta_link;
        } else {
            url = BASE_URI
                + "/me/mailFolders/%s/messages/delta".printf(
                    GLib.Uri.escape_string(folder_id, null, false))
                + "?$select=id,conversationId,subject,internetMessageId,"
                + "receivedDateTime,from,toRecipients,ccRecipients,"
                + "bccRecipients,bodyPreview,isRead,flag,size"
                + "&$orderby=receivedDateTime%%20desc"
                + "&changeType=created";
        }

        DeltaResult result = new DeltaResult();

        // Follow nextLink pages until we get a deltaLink.
        // The deltaLink signals that we have consumed all pending changes.
        int page = 0;
        int max_pages = 50;
        while (!String.is_empty(url) && page < max_pages) {
            page++;
            Json.Object root;
            try {
                root = yield request_json_url(url, cancellable);
            } catch (Geary.EngineError.SERVER_UNAVAILABLE err) {
                if (err.message.contains("(410)")) {
                    result.delta_link = "";
                    return result;
                }
                throw err;
            }

            if (root.has_member("value")) {
                Json.Array values = root.get_array_member("value");
                for (uint i = 0; i < values.get_length(); i++) {
                    Json.Node node = values.get_element(i);
                    if (node.get_node_type() != Json.NodeType.OBJECT) {
                        continue;
                    }
                    Json.Object obj = values.get_object_element(i);

                    // Deleted / moved-out items carry @removed instead of
                    // normal message fields.
                    if (obj.has_member("@removed")) {
                        string? removed_id = get_string_member(obj, "id");
                        if (!String.is_empty(removed_id)) {
                            result.removed.add(removed_id);
                        }
                        continue;
                    }

                    Message parsed = parse_message(obj, false);
                    if (!String.is_empty(parsed.id)) {
                        result.changed.add(parsed);
                    }
                }
            }

            // Prefer deltaLink (end of changes) over nextLink (more pages).
            string? next = null;
            if (root.has_member("@odata.deltaLink")) {
                next = get_string_member(root, "@odata.deltaLink");
                if (!String.is_empty(next)) {
                    result.delta_link = next;
                    break;
                }
            }
            if (root.has_member("@odata.nextLink")) {
                next = get_string_member(root, "@odata.nextLink");
            }
            url = String.is_empty(next) ? "" : next;
        }

        return result;
    }

    /**
     * Creates a message and stages it in Outlook's Outbox without sending it.
     *
     * Returns the Graph message ID of the staged message, which can
     * later be passed to {@link send_message} to deliver it, or to
     * {@link delete_message} to discard it (undo).
     */
    public async string create_message_in_folder(
        string folder_id,
        Geary.RFC822.Message rfc822,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        string encoded = GLib.Base64.encode(
            rfc822.get_rfc822_buffer().get_bytes().get_data()
        );

        Json.Object result = yield request_json(
            "POST",
            "/me/messages",
            null,
            cancellable,
            encoded,
            "text/plain"
        );
        string? id = get_string_member(result, "id");
        if (String.is_empty(id)) {
            throw new Geary.EngineError.SERVER_UNAVAILABLE(
                "Graph: create_message_in_folder returned no message id"
            );
        }

        id = yield move_message(id, folder_id, cancellable);
        yield patch_message_recipients(
            id,
            message_to_composed_email(rfc822),
            cancellable
        );
        return id;
    }

    public async string create_message_in_outbox(
        Geary.ComposedEmail composed,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        string domain = this.account.primary_mailbox.domain;
        if (!composed.from.is_empty) {
            domain = composed.from[0].domain;
        }
        Geary.RFC822.Message rfc822 =
            yield new Geary.RFC822.Message.from_composed_email(
                composed,
                GMime.utils_generate_message_id(domain),
                GMime.EncodingConstraint.8BIT,
                cancellable
            );
        string encoded = GLib.Base64.encode(
            rfc822.get_rfc822_buffer().get_bytes().get_data()
        );

        Json.Object result = yield request_json(
            "POST",
            "/me/messages",
            null,
            cancellable,
            encoded,
            "text/plain"
        );
        string? id = get_string_member(result, "id");
        if (String.is_empty(id)) {
            throw new Geary.EngineError.SERVER_UNAVAILABLE(
                "Graph: create_message_in_outbox returned no message id"
            );
        }
        // Graph preserves the MIME body, but the saved draft can lose the
        // explicit recipient envelope unless it is patched separately.
        yield patch_message_recipients(id, composed, cancellable);
        return yield move_message(id, "outbox", cancellable);
    }

    /**
     * Sends a message that was previously staged in the Outbox.
     *
     * The message is delivered and automatically moved to Sent Items
     * by the server.
     */
    public async void send_message(string message_id,
                                   GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        string path = "/me/messages/%s/send".printf(
            GLib.Uri.escape_string(message_id, null, false)
        );
        yield request_no_content("POST", path, null, cancellable);
    }

    public async void send_composed_email(Geary.ComposedEmail composed,
                                          bool save_to_sent_items,
                                          GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        string message_id = yield create_message_in_outbox(composed, cancellable);
        string path = "/me/messages/%s/send".printf(
            GLib.Uri.escape_string(message_id, null, false)
        );
        yield request_no_content("POST", path, null, cancellable);
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

    public async Gee.List<MailFolder> list_mail_folders(
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        // Try progressively simpler queries, as not all tenants/API versions
        // support $select with wellKnownName/isHidden.
        string[] queries = {
            "$top=100&$select=id,displayName,wellKnownName,isHidden",
            "$top=100&$select=id,displayName,wellKnownName",
            "$top=100&$select=id,displayName",
            "$top=100",
        };

        Json.Object? root = null;
        foreach (string query in queries) {
            try {
                root = yield request_json(
                    "GET",
                    "/me/mailFolders",
                    query,
                    cancellable
                );
                break;
            } catch (Geary.EngineError.SERVER_UNAVAILABLE err) {
                if (!err.message.contains("(400)")) {
                    throw err;
                }
                continue;
            }
        }

        if (root == null) {
            throw new Geary.EngineError.SERVER_UNAVAILABLE(
                "Graph: all list_mail_folders queries failed"
            );
        }

        Gee.ArrayList<MailFolder> folders = new Gee.ArrayList<MailFolder>();

        do {
            if (root.has_member("value")) {
                Json.Array values = root.get_array_member("value");
                for (uint i = 0; i < values.get_length(); i++) {
                    Json.Node node = values.get_element(i);
                    if (node.get_node_type() != Json.NodeType.OBJECT) {
                        continue;
                    }
                    Json.Object obj = values.get_object_element(i);
                    string? id = get_string_member(obj, "id");
                    if (String.is_empty(id)) {
                        continue;
                    }
                    MailFolder folder = new MailFolder();
                    folder.id = id;
                    folder.display_name = get_string_member(obj, "displayName") ?? "";
                    folder.well_known_name = get_string_member(obj, "wellKnownName") ?? "";
                    folder.is_hidden = get_bool_member(obj, "isHidden", false);
                    folders.add(folder);
                }
            }

            string? next_link = null;
            if (root.has_member("@odata.nextLink")) {
                next_link = get_string_member(root, "@odata.nextLink");
            }
            if (!String.is_empty(next_link)) {
                try {
                    root = yield request_json_url(next_link, cancellable);
                } catch (GLib.Error err) {
                    break;
                }
            } else {
                root = null;
            }
        } while (root != null);

        return folders;
    }

    private async Json.Object request_json_url(string url,
                                               GLib.Cancellable? cancellable)
        throws GLib.Error {
        yield this.account.load_incoming_credentials(cancellable);

        Geary.Credentials? credentials = this.account.incoming.credentials;
        if (credentials == null || String.is_empty(credentials.token)) {
            throw new Geary.EngineError.SERVER_UNAVAILABLE(
                "No Graph OAuth token available"
            );
        }

        for (int attempt = 0; attempt <= REQUEST_RETRIES; attempt++) {
            var request = create_request_message("GET", url);
            request.set_force_http1(true);
            request.request_headers.append(
                "Authorization", "Bearer %s".printf(credentials.token)
            );
            request.request_headers.append("Accept", "application/json");
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
                    continue;
                }
                throw new Geary.EngineError.SERVER_UNAVAILABLE(
                    "Graph request timed out (%s)",
                    url
                );
            }

            if (request.status_code < 200 || request.status_code >= 300) {
                throw new Geary.EngineError.SERVER_UNAVAILABLE(
                    "Graph request failed (%u): %s (%s)",
                    request.status_code,
                    request.reason_phrase,
                    url
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
                    continue;
                }
                throw new Geary.EngineError.SERVER_UNAVAILABLE(
                    "Graph response decode failed (%s): %s",
                    url,
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
            url
        );
    }

    private async Json.Object request_json(string method,
                                           string path,
                                           string? query,
                                           GLib.Cancellable? cancellable,
                                           string? request_body = null,
                                           string content_type = "application/json")
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
            var request = create_request_message(method, uri);
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
                    content_type,
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
            var request = create_request_message(method, uri);
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

    private static Soup.Message create_request_message(string method,
                                                       string uri_string)
        throws GLib.Error {
        try {
            GLib.Uri uri = GLib.Uri.parse(
                uri_string,
                GLib.UriFlags.PARSE_RELAXED
            );
            return new Soup.Message.from_uri(method, uri);
        } catch (GLib.UriError err) {
            throw new Geary.EngineError.SERVER_UNAVAILABLE(
                "Invalid Graph request URI (%s): %s",
                uri_string,
                err.message
            );
        }
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
            var request = create_request_message(method, uri);
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
        parsed.has_attachments = get_bool_member(object, "hasAttachments", false);
        parsed.is_read = get_bool_member(object, "isRead", true);
        parsed.is_flagged = get_flagged_member(object, "flag");
        parsed.received_at = parse_datetime(get_string_member(object, "receivedDateTime"));
        parsed.size = get_int_member(object, "size", 0);
        parsed.internet_message_headers = parse_internet_message_headers(
            object,
            "internetMessageHeaders"
        );
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

    private static Gee.HashMap<string,string> parse_internet_message_headers(
        Json.Object object,
        string key
    ) {
        Gee.HashMap<string,string> headers = new Gee.HashMap<string,string>();
        if (!object.has_member(key) ||
            object.get_member(key).get_node_type() != Json.NodeType.ARRAY) {
            return headers;
        }

        Json.Array values = object.get_array_member(key);
        for (uint i = 0; i < values.get_length(); i++) {
            Json.Node value = values.get_element(i);
            if (value.get_node_type() != Json.NodeType.OBJECT) {
                continue;
            }
            Json.Object header = values.get_object_element(i);
            string? name = get_string_member(header, "name");
            string? header_value = get_string_member(header, "value");
            if (String.is_empty(name) || String.is_empty(header_value)) {
                continue;
            }
            headers.set(name.down(), header_value);
        }
        return headers;
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

    private Geary.ComposedEmail message_to_composed_email(Geary.RFC822.Message message) {
        GLib.DateTime date = message.date != null
            ? message.date.value
            : new GLib.DateTime.now_local();
        Geary.RFC822.MailboxAddresses from = (
            message.from != null && !message.from.is_empty
            ? message.from
            : new Geary.RFC822.MailboxAddresses.single(
                this.account.primary_mailbox
            )
        );

        Geary.ComposedEmail composed = new Geary.ComposedEmail(date, from);
        if (message.to != null) {
            composed.set_to(message.to);
        }
        if (message.cc != null) {
            composed.set_cc(message.cc);
        }
        if (message.bcc != null) {
            composed.set_bcc(message.bcc);
        }
        if (message.reply_to != null) {
            composed.set_reply_to(message.reply_to);
        }
        if (message.subject != null) {
            composed.set_subject(message.subject.value);
        }
        if (message.in_reply_to != null) {
            composed.set_in_reply_to(message.in_reply_to);
        }
        if (message.references != null) {
            composed.set_references(message.references);
        }
        return composed;
    }

    private async void patch_message_recipients(string message_id,
                                                Geary.ComposedEmail composed,
                                                GLib.Cancellable? cancellable)
        throws GLib.Error {
        Json.Builder builder = new Json.Builder();
        builder.begin_object();
        bool has_recipient_fields = false;
        has_recipient_fields |= append_mailbox_addresses_to_builder(
            builder,
            "toRecipients",
            composed.to
        );
        has_recipient_fields |= append_mailbox_addresses_to_builder(
            builder,
            "ccRecipients",
            composed.cc
        );
        has_recipient_fields |= append_mailbox_addresses_to_builder(
            builder,
            "bccRecipients",
            composed.bcc
        );
        has_recipient_fields |= append_mailbox_addresses_to_builder(
            builder,
            "replyTo",
            composed.reply_to
        );
        builder.end_object();

        if (has_recipient_fields) {
            string path = "/me/messages/%s".printf(
                GLib.Uri.escape_string(message_id, null, false)
            );
            yield request_json(
                "PATCH",
                path,
                null,
                cancellable,
                to_json(builder)
            );
        }
    }

    private static bool append_mailbox_addresses_to_builder(
        Json.Builder builder,
        string name,
        Geary.RFC822.MailboxAddresses? addresses
    ) {
        if (addresses == null || addresses.size == 0) {
            return false;
        }
        Gee.ArrayList<Geary.RFC822.MailboxAddress> valid_addresses =
            new Gee.ArrayList<Geary.RFC822.MailboxAddress>();
        foreach (Geary.RFC822.MailboxAddress address in addresses) {
            if (!String.is_empty(address.address)) {
                valid_addresses.add(address);
            }
        }
        if (valid_addresses.is_empty) {
            return false;
        }
        builder.set_member_name(name);
        builder.begin_array();
        foreach (Geary.RFC822.MailboxAddress address in valid_addresses) {
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
        return true;
    }

}
