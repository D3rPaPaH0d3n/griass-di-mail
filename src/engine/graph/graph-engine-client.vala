/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

internal class Convey.Graph.Client : Convey.BaseObject {

    public const string DEFAULT_BASE_URI = "https://graph.microsoft.com/v1.0";
    private const uint REQUEST_TIMEOUT_SEC = 30;
    private const int REQUEST_RETRIES = 1;
    private const uint MAX_THROTTLE_RETRIES = 5;
    private const uint MAX_RETRY_AFTER_SEC = 60;
    private const string EXPAND_THREADING_HEADERS =
        "$expand=singleValueExtendedProperties($filter=" +
        "id%20eq%20'String%200x1042'%20or%20id%20eq%20'String%200x1039')";


    internal class Message : Convey.BaseObject {
        public string id = "";
        public string conversation_id = "";
        public Convey.RFC822.MailboxAddresses? from = null;
        public Convey.RFC822.MailboxAddresses? to = null;
        public Convey.RFC822.MailboxAddresses? cc = null;
        public Convey.RFC822.MailboxAddresses? bcc = null;
        public string subject = "";
        public string internet_message_id = "";
        public string in_reply_to = "";
        public string references = "";
        public string body_preview = "";
        public string? body = null;
        public string body_content_type = "text";
        public bool has_attachments = false;
        public bool is_encrypted = false;
        public bool is_read = true;
        public bool is_flagged = false;
        public bool load_remote_images = false;
        public GLib.DateTime? received_at = null;
        public int64 size = 0;
        public Gee.HashMap<string,string> internet_message_headers =
            new Gee.HashMap<string,string>();
    }

    internal class MailFolder : Convey.BaseObject {
        public string id = "";
        public string display_name = "";
        public string well_known_name = "";
        public bool is_hidden = false;
        public string parent_id = "";
        public int64 child_folder_count = 0;
    }

    internal class DeltaResult : Convey.BaseObject {
        // Graph message IDs that were created or updated; fetch full
        // messages for these, delta entries don't carry reliable properties
        public Gee.Set<string> changed_ids = new Gee.HashSet<string>();
        // Graph message IDs that were deleted/moved out of the folder
        public Gee.Set<string> removed = new Gee.HashSet<string>();
        // The cursor for the next call: a deltaLink when complete, else a
        // nextLink to resume the current enumeration from
        public string delta_link = "";
        // Whether all pending changes were consumed (deltaLink reached)
        public bool complete = false;
        // The server invalidated the cursor (HTTP 410); the caller must
        // discard its saved cursor and re-baseline
        public bool resync_required = false;
    }


    public signal void response_received();

    private Convey.AccountInformation account;
    private Soup.Session session;
    internal string base_uri { get; set; default = DEFAULT_BASE_URI; }


    public Client(Convey.AccountInformation account,
                  string? base_uri = null) {
        this.account = account;
        this.session = new Soup.Session();
        this.session.timeout = REQUEST_TIMEOUT_SEC;
        this.session.idle_timeout = REQUEST_TIMEOUT_SEC;
        if (Endpoint.proxy_resolver != null) {
            this.session.proxy_resolver = Endpoint.proxy_resolver;
        }
        if (base_uri != null) {
            this.base_uri = base_uri;
        }
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

    public delegate void MessagePageHandler(Gee.List<Message> page);

    public async Gee.List<Message> list_messages(string folder_id,
                                                 int limit,
                                                 int prefetch_period_days,
                                                 int64 stop_at_unix = 0,
                                                 GLib.Cancellable? cancellable = null,
                                                 owned MessagePageHandler? on_page = null)
        throws GLib.Error {
        if (limit < 1) {
            limit = 1;
        }
        string path = "/me/mailFolders/%s/messages".printf(
            GLib.Uri.escape_string(folder_id, null, false)
        );

        // Fetch pages until we either exhaust the folder or reach the
        // configured prefetch boundary. This ensures the entire vector within
        // the selected download range is loaded, not just the first page.
        int64 cutoff_unix = 0;
        bool has_cutoff = prefetch_period_days >= 0;
        if (has_cutoff) {
            cutoff_unix = new GLib.DateTime.now_utc()
                .add_days(0 - prefetch_period_days)
                .to_unix();
        }

        string[] queries = {
            (
                "$top=%d"
              + "&$orderby=receivedDateTime%%20desc"
              + "&$select=id,conversationId,subject,internetMessageId,receivedDateTime,from,bodyPreview,isRead,flag,sender,from,toRecipients,ccRecipients,bccRecipients,hasAttachments,replyTo"
            ).printf(limit) + "&" + EXPAND_THREADING_HEADERS,
            (
                "$top=%d"
              + "&$orderby=receivedDateTime%%20desc"
              + "&$select=id,conversationId,subject,internetMessageId,receivedDateTime,from,bodyPreview,isRead,flag,sender,from,toRecipients,ccRecipients,bccRecipients,hasAttachments,replyTo"
            ).printf(limit),
            (
                "$top=%d"
              + "&$select=id,conversationId,subject,internetMessageId,receivedDateTime,from,bodyPreview,isRead,flag,sender,from,toRecipients,ccRecipients,bccRecipients,hasAttachments,replyTo"
            ).printf(limit),
            "$top=%d".printf(limit),
        };

        Gee.ArrayList<Message> messages = new Gee.ArrayList<Message>();
        string? next_url = null;
        bool done = false;
        bool ordered = true;
        int pages = 0;
        int max_pages = 1000;
        // Without $orderby the results are in no useful order, so the cutoff
        // below can only skip individual messages, never stop paging. Left
        // uncapped that enumerates the whole mailbox on a cold cache, which
        // looks like a hang. Fetch a bounded prefix instead.
        int unordered_max_pages = 20;

        while (!done && pages < (ordered ? max_pages : unordered_max_pages)) {
            pages++;
            Json.Object root;
            if (pages == 1) {
                root = null;
                for (int q = 0; q < queries.length; q++) {
                    try {
                        root = yield request_json("GET", path, queries[q], cancellable);
                        if (!queries[q].contains("$orderby")) {
                            // Fallback queries carry no $orderby, so results
                            // aren't guaranteed newest-first and the early
                            // stops below could truncate the listing.
                            stop_at_unix = 0;
                            ordered = false;
                        }
                        break;
                    } catch (Convey.Graph.HttpError.BAD_REQUEST err) {
                        // Not all tenants/API versions support every field
                        // in this query; try the next, simpler one.
                        debug("Graph: list query %d rejected for folder %s, " +
                            "trying a simpler one: %s",
                            q, folder_id, err.message);
                    }
                }
                if (root == null) {
                    throw new Convey.EngineError.SERVER_UNAVAILABLE(
                        "Graph request failed (%s)",
                        path
                    );
                }
            } else {
                root = yield request_json_url(next_url, cancellable);
            }

            Gee.ArrayList<Message> page = new Gee.ArrayList<Message>();

            if (root.has_member("value")) {
                Json.Array values = root.get_array_member("value");
                for (uint i = 0; i < values.get_length(); i++) {
                    Json.Node value = values.get_element(i);
                    if (value.get_node_type() != Json.NodeType.OBJECT) {
                        continue;
                    }
                    Message parsed = parse_message(values.get_object_element(i), false);
                    if (String.is_empty(parsed.id)) {
                        continue;
                    }

                    if (has_cutoff && parsed.received_at != null &&
                        parsed.received_at.to_unix() < cutoff_unix) {
                        if (!ordered) {
                            // Unordered results: skip the old one, don't
                            // assume everything after it is older too.
                            continue;
                        }
                        done = true;
                        break;
                    }

                    // Caller already has everything strictly older than
                    // stop_at_unix; no need to fetch further pages.
                    if (stop_at_unix > 0 && parsed.received_at != null &&
                        parsed.received_at.to_unix() < stop_at_unix) {
                        done = true;
                        break;
                    }

                    page.add(parsed);
                }
            }
            foreach (Message message in page) {
                yield detect_encryption(message, cancellable);
            }
            messages.add_all(page);
            if (on_page != null && !page.is_empty) {
                on_page(page);
            }

            if (pages % 5 == 0) {
                debug("Graph: listed %d pages (%d messages) for folder %s%s",
                    pages, messages.size, folder_id,
                    ordered ? "" : " (unordered)");
            }

            string? next_link = null;
            if (root.has_member("@odata.nextLink")) {
                next_link = get_string_member(root, "@odata.nextLink");
            }
            next_url = String.is_empty(next_link) ? null : next_link;
            if (String.is_empty(next_url)) {
                done = true;
            }
        }

        if (!done) {
            warning(
                "Graph list_messages for folder %s hit the %d page cap " +
                "(%s); more messages may remain unfetched",
                folder_id,
                ordered ? max_pages : unordered_max_pages,
                ordered ? "ordered" : "unordered, so paging could not stop " +
                    "at the prefetch window"
            );
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
        root = yield request_json(
            "GET",
            path,
            EXPAND_THREADING_HEADERS,
            cancellable,
            null,
            GLib.Priority.HIGH
        );
        Message message = parse_message(root, true);
        yield detect_encryption(message, cancellable);
        return message;
    }

    private async void detect_encryption(Message message,
                                         GLib.Cancellable? cancellable) {
        if (!message.has_attachments || !String.is_empty(message.body_preview)) {
            return;
        }
        try {
            Json.Object attachments = yield request_json(
                "GET",
                "/me/messages/%s/attachments".printf(
                    GLib.Uri.escape_string(message.id, null, false)
                ),
                "$select=contentType",
                cancellable
            );
            if (attachments.has_member("value")) {
                foreach (Json.Node node in
                         attachments.get_array_member("value").get_elements()) {
                    string? type = get_string_member(node.get_object(), "contentType");
                    if (type == "application/pgp-encrypted" ||
                        type == "multipart/signed") {
                        message.is_encrypted = true;
                        return;
                    }
                }
            }
        } catch (GLib.Error err) {
            debug("Graph: unable to check attachments of %s: %s",
                  message.id, err.message);
        }
    }

    public async Convey.Memory.Buffer fetch_message_rfc822(
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
            "message/rfc822",
            GLib.Priority.HIGH
        );
        return new Convey.Memory.ByteBuffer(
            body.get_data(),
            (size_t) body.get_size()
        );
    }

    /**
     * Reports which messages changed in a folder since the last delta call.
     *
     * Delta responses are used purely as a change signal — like
     * evolution-ews' IdOnly SyncFolderItems — because Graph does not
     * reliably return full message properties in delta entries (updates
     * carry only the changed fields). Callers must fetch full messages for
     * the changed ids themselves.
     *
     * On the first call pass null for delta_link; $deltaToken=latest asks
     * the server for a cursor at the current state without enumerating the
     * folder, so the caller must pair it with a full listing. On subsequent
     * calls pass the cursor from the previous result.
     *
     * The returned cursor is a deltaLink when complete is true, or a
     * nextLink to resume from when the page cap was hit; either way it is
     * what the next call's delta_link should be. resync_required means the
     * server invalidated the cursor and the caller must re-baseline.
     */
    public async DeltaResult delta_messages(
        string folder_id,
        string? delta_link,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        DeltaResult result = new DeltaResult();

        string url;
        if (!String.is_empty(delta_link)) {
            url = delta_link;
        } else {
            url = this.base_uri
                + "/me/mailFolders/%s/messages/delta".printf(
                    GLib.Uri.escape_string(folder_id, null, false))
                // Some tenants ignore "latest" and enumerate the folder
                // instead; $top keeps that fallback from crawling at the
                // default page size of 10.
                + "?$deltaToken=latest&$select=id&$top=100";
        }

        int page = 0;
        int max_pages = 50;
        while (page < max_pages) {
            page++;
            Json.Object root;
            try {
                root = yield request_json_url(url, cancellable);
            } catch (Convey.Graph.HttpError.GONE err) {
                // The cursor expired; caller must restart with a fresh
                // baseline sync.
                result.resync_required = true;
                return result;
            }

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

                    // Deleted / moved-out items carry @removed instead of
                    // normal message fields.
                    if (obj.has_member("@removed")) {
                        result.removed.add(id);
                        result.changed_ids.remove(id);
                    } else {
                        result.changed_ids.add(id);
                        result.removed.remove(id);
                    }
                }
            }

            // deltaLink means all pending changes are consumed; nextLink
            // means more pages. A response with neither is treated as
            // complete so a misbehaving server can't cause an infinite
            // resume loop.
            if (root.has_member("@odata.deltaLink")) {
                string? next = get_string_member(root, "@odata.deltaLink");
                if (!String.is_empty(next)) {
                    result.delta_link = next;
                    result.complete = true;
                    return result;
                }
            }
            string? next_link = null;
            if (root.has_member("@odata.nextLink")) {
                next_link = get_string_member(root, "@odata.nextLink");
            }
            if (String.is_empty(next_link)) {
                result.complete = true;
                return result;
            }
            url = next_link;
        }

        // Page cap hit: return the nextLink as a resumable cursor so the
        // caller can pick up where this batch ended.
        result.delta_link = url;
        result.complete = false;
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
        Convey.RFC822.Message rfc822,
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
            GLib.Priority.DEFAULT,
            "text/plain"
        );
        string? id = get_string_member(result, "id");
        if (String.is_empty(id)) {
            throw new Convey.EngineError.SERVER_UNAVAILABLE(
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
        Convey.ComposedEmail composed,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        string domain = this.account.primary_mailbox.domain;
        if (!composed.from.is_empty) {
            domain = composed.from[0].domain;
        }
        Convey.RFC822.Message rfc822 =
            yield new Convey.RFC822.Message.from_composed_email(
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
            GLib.Priority.DEFAULT,
            "text/plain"
        );
        string? id = get_string_member(result, "id");
        if (String.is_empty(id)) {
            throw new Convey.EngineError.SERVER_UNAVAILABLE(
                "Graph: create_message_in_outbox returned no message id"
            );
        }
        // Graph preserves the MIME body, but the saved draft can lose the
        // explicit recipient envelope unless it is patched separately.
        yield patch_message_recipients(id, composed, cancellable);
        Convey.Memory.Buffer? pgp_mime = rfc822.get_pgp_mime_buffer();
        if (pgp_mime != null) {
            yield replace_with_pgp_mime_attachment(id, pgp_mime, cancellable);
        }
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

    public async void send_composed_email(Convey.ComposedEmail composed,
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
                                               string? parent_id = null,
                                               GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        Json.Builder builder = new Json.Builder();
        builder.begin_object();
        builder.set_member_name("displayName");
        builder.add_string_value(display_name);
        builder.end_object();
        Json.Object root = yield request_json(
            "POST",
            String.is_empty(parent_id)
                ? "/me/mailFolders"
                : "/me/mailFolders/%s/childFolders".printf(
                    GLib.Uri.escape_string(parent_id, null, false)
                ),
            null,
            cancellable,
            to_json(builder)
        );
        MailFolder folder = new MailFolder();
        folder.id = get_string_member(root, "id") ?? "";
        folder.display_name = get_string_member(root, "displayName") ?? display_name;
        return folder;
    }

    public async void delete_mail_folder(string folder_id,
                                         GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        string path = "/me/mailFolders/%s".printf(
            GLib.Uri.escape_string(folder_id, null, false)
        );
        yield request_no_content("DELETE", path, null, cancellable);
    }

    public async MailFolder rename_mail_folder(string folder_id,
                                               string display_name,
                                               GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        Json.Builder builder = new Json.Builder();
        builder.begin_object();
        builder.set_member_name("displayName");
        builder.add_string_value(display_name);
        builder.end_object();
        string path = "/me/mailFolders/%s".printf(
            GLib.Uri.escape_string(folder_id, null, false)
        );
        Json.Object root = yield request_json(
            "PATCH",
            path,
            null,
            cancellable,
            to_json(builder)
        );
        MailFolder folder = new MailFolder();
        folder.id = get_string_member(root, "id") ?? folder_id;
        folder.display_name = get_string_member(root, "displayName") ?? display_name;
        return folder;
    }

    public async Gee.List<MailFolder> list_mail_folder_page(
        string path,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        // Try progressively simpler queries, as not all tenants/API versions
        // support $select with wellKnownName/isHidden.
        string[] queries = {
            "$top=100&$select=id,displayName,parentFolderId,childFolderCount,wellKnownName,isHidden",
            "$top=100&$select=id,displayName,parentFolderId,childFolderCount,wellKnownName",
            "$top=100&$select=id,displayName,parentFolderId,childFolderCount",
            "$top=100&$select=id,displayName,parentFolderId",
            "$top=100&$select=id,displayName",
            "$top=100",
        };

        Json.Object? root = null;
        foreach (string query in queries) {
            try {
                root = yield request_json(
                    "GET",
                    path,
                    query,
                    cancellable
                );
                break;
            } catch (Convey.Graph.HttpError.BAD_REQUEST err) {
                continue;
            }
        }

        if (root == null) {
            throw new Convey.EngineError.SERVER_UNAVAILABLE(
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
                    folder.parent_id = get_string_member(obj, "parentFolderId") ?? "";
                    folder.child_folder_count = get_int_member(obj, "childFolderCount", 0);
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

    public async Gee.List<MailFolder> list_mail_folders(
        string? parent_id = null,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error {
        return yield list_mail_folder_page(
            String.is_empty(parent_id)
                ? "/me/mailFolders"
                : "/me/mailFolders/%s/childFolders".printf(
                    GLib.Uri.escape_string(parent_id, null, false)
                ),
            cancellable
        );
    }

    private async Json.Object request_json_url(string url,
                                               GLib.Cancellable? cancellable,
                                               int io_priority = GLib.Priority.DEFAULT)
        throws GLib.Error {
        GLib.Bytes body = yield send_request(
            "GET", url, null, "application/json", "application/json",
            cancellable, io_priority
        );
        return parse_json_object(body, url);
    }

    private async Json.Object request_json(string method,
                                           string path,
                                           string? query,
                                           GLib.Cancellable? cancellable,
                                           string? request_body = null,
                                           int io_priority = GLib.Priority.DEFAULT,
                                           string content_type = "application/json")
        throws GLib.Error {
        string uri = build_uri(path, query);
        GLib.Bytes body = yield send_request(
            method, uri, request_body, content_type, "application/json",
            cancellable, io_priority
        );
        return parse_json_object(body, uri);
    }

    private async GLib.Bytes request_bytes(string method,
                                           string path,
                                           string? query,
                                           GLib.Cancellable? cancellable,
                                           string accept = "application/octet-stream",
                                           int io_priority = GLib.Priority.DEFAULT)
        throws GLib.Error {
        string uri = build_uri(path, query);
        return yield send_request(
            method, uri, null, "application/json", accept,
            cancellable, io_priority
        );
    }

    private async void request_no_content(string method,
                                          string path,
                                          string? query,
                                          GLib.Cancellable? cancellable,
                                          string? request_body = null,
                                          int io_priority = GLib.Priority.DEFAULT)
        throws GLib.Error {
        string uri = build_uri(path, query);
        yield send_request(
            method, uri, request_body, "application/json", "application/json",
            cancellable, io_priority
        );
    }

    private string build_uri(string path, string? query) {
        string uri = this.base_uri + path;
        if (!String.is_empty(query)) {
            uri += "?" + query;
        }
        return uri;
    }

    /**
     * Sends a single Graph request, transparently handling throttling
     * (429 + Retry-After) and a one-time credential refresh on 401.
     */
    private async GLib.Bytes send_request(string method,
                                          string uri,
                                          string? request_body,
                                          string content_type,
                                          string accept,
                                          GLib.Cancellable? cancellable,
                                          int io_priority)
        throws GLib.Error {
        bool refreshed_credentials = false;
        uint throttle_retries = 0;
        int timeout_retries = 0;

        while (true) {
            yield this.account.load_incoming_credentials(cancellable);

            Convey.Credentials? credentials = this.account.incoming.credentials;
            if (credentials == null || String.is_empty(credentials.token)) {
                throw new Convey.EngineError.SERVER_UNAVAILABLE(
                    "No Graph OAuth token available"
                );
            }

            var request = create_request_message(method, uri);
            request.set_force_http1(true);
            request.request_headers.append(
                "Authorization", "Bearer %s".printf(credentials.token)
            );
            request.request_headers.append("Accept", accept);
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
                    io_priority,
                    cancellable
                );
            } catch (GLib.IOError.TIMED_OUT err) {
                if (timeout_retries < REQUEST_RETRIES) {
                    timeout_retries++;
                    continue;
                }
                throw new Convey.EngineError.SERVER_UNAVAILABLE(
                    "Graph request timed out (%s)",
                    uri
                );
            }

            response_received();

            uint status = request.status_code;
            if (status >= 200 && status < 300) {
                return body;
            }

            if (status == 429 && throttle_retries < MAX_THROTTLE_RETRIES) {
                throttle_retries++;
                uint wait_sec = uint.min(
                    parse_retry_after_seconds(
                        request.response_headers.get_one("Retry-After")
                    ),
                    MAX_RETRY_AFTER_SEC
                );
                yield Convey.Scheduler.sleep_async(wait_sec);
                continue;
            }

            if (status == 401 && !refreshed_credentials) {
                refreshed_credentials = true;
                continue;
            }

            throw http_error_for_status(status, request.reason_phrase, uri);
        }
    }

    private static uint parse_retry_after_seconds(string? header) {
        int seconds = String.is_empty(header) ? 0 : int.parse(header);
        return seconds > 0 ? (uint) seconds : 1;
    }

    private static GLib.Error http_error_for_status(uint status,
                                                     string reason,
                                                     string uri) {
        string message = "Graph request failed (%u): %s (%s)".printf(
            status, reason, uri
        );
        switch (status) {
        case 400:
            return new Convey.Graph.HttpError.BAD_REQUEST(message);
        case 401:
            return new Convey.Graph.HttpError.UNAUTHORIZED(message);
        case 404:
            return new Convey.Graph.HttpError.NOT_FOUND(message);
        case 410:
            return new Convey.Graph.HttpError.GONE(message);
        case 429:
            return new Convey.Graph.HttpError.TOO_MANY_REQUESTS(message);
        default:
            return new Convey.Graph.HttpError.SERVER(message);
        }
    }

    private static Json.Object parse_json_object(GLib.Bytes body, string uri)
        throws GLib.Error {
        var parser = new Json.Parser();
        try {
            parser.load_from_data(
                (string) body.get_data(),
                (ssize_t) body.get_size()
            );
        } catch (GLib.Error err) {
            throw new Convey.EngineError.SERVER_UNAVAILABLE(
                "Graph response decode failed (%s): %s",
                uri,
                err.message
            );
        }
        Json.Node root = parser.get_root();
        if (root == null || root.get_node_type() != Json.NodeType.OBJECT) {
            throw new Convey.EngineError.SERVER_UNAVAILABLE(
                "Invalid Graph response payload"
            );
        }
        return root.get_object();
    }

    private static Soup.Message create_request_message(string method,
                                                       string uri_string)
        throws GLib.Error {
        try {
            GLib.Uri uri = GLib.Uri.parse(
                uri_string,
                GLib.UriFlags.PARSE_RELAXED | GLib.UriFlags.ENCODED
            );
            return new Soup.Message.from_uri(method, uri);
        } catch (GLib.UriError err) {
            throw new Convey.EngineError.SERVER_UNAVAILABLE(
                "Invalid Graph request URI (%s): %s",
                uri_string,
                err.message
            );
        }
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

        if (object.has_member("singleValueExtendedProperties")) {
            foreach (Json.Node node in
                     object.get_array_member("singleValueExtendedProperties").get_elements()) {
                Json.Object property = node.get_object();
                string id = get_string_member(property, "id") ?? "";
                string value = get_string_member(property, "value") ?? "";
                if (id == "String 0x1042") {
                    parsed.in_reply_to = value;
                } else if (id == "String 0x1039") {
                    parsed.references = value;
                }
            }
        }

        if (include_body &&
            object.has_member("body") &&
            object.get_member("body").get_node_type() == Json.NodeType.OBJECT) {
            Json.Object body = object.get_object_member("body");
            parsed.body = get_string_member(body, "content");
            parsed.body_content_type = get_string_member(body, "contentType") ?? "text";
        }

        return parsed;
    }

    private static Convey.RFC822.MailboxAddresses? parse_address_member(Json.Object object,
                                                                        string key) {
        Convey.RFC822.MailboxAddress? mailbox = null;
        if (object.has_member(key) &&
            object.get_member(key).get_node_type() == Json.NodeType.OBJECT) {
            Json.Object wrapper = object.get_object_member(key);
            mailbox = parse_email_address_wrapper(wrapper);
        }
        return mailbox == null ? null : new Convey.RFC822.MailboxAddresses.single(mailbox);
    }

    private static Convey.RFC822.MailboxAddresses? parse_addresses_member(Json.Object object,
                                                                          string key) {
        if (!object.has_member(key) ||
            object.get_member(key).get_node_type() != Json.NodeType.ARRAY) {
            return null;
        }
        Json.Array values = object.get_array_member(key);
        Gee.ArrayList<Convey.RFC822.MailboxAddress> addresses =
            new Gee.ArrayList<Convey.RFC822.MailboxAddress>();
        for (uint i = 0; i < values.get_length(); i++) {
            Json.Node value = values.get_element(i);
            if (value.get_node_type() != Json.NodeType.OBJECT) {
                continue;
            }
            Convey.RFC822.MailboxAddress? mailbox =
                parse_email_address_wrapper(values.get_object_element(i));
            if (mailbox != null) {
                addresses.add(mailbox);
            }
        }
        return addresses.is_empty ? null : new Convey.RFC822.MailboxAddresses(addresses);
    }

    private static Convey.RFC822.MailboxAddress? parse_email_address_wrapper(Json.Object wrapper) {
        if (!wrapper.has_member("emailAddress") ||
            wrapper.get_member("emailAddress").get_node_type() != Json.NodeType.OBJECT) {
            return null;
        }
        Json.Object email = wrapper.get_object_member("emailAddress");
        string? address = get_string_member(email, "address");
        if (String.is_empty(address)) {
            return null;
        }
        return new Convey.RFC822.MailboxAddress(get_string_member(email, "name"), address);
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

    internal static string? get_string_member(Json.Object object, string key) {
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

    internal static bool get_bool_member(Json.Object object,
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

    internal static int64 get_int_member(Json.Object object,
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

    internal static GLib.DateTime? parse_datetime(string? value) {
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

    private Convey.ComposedEmail message_to_composed_email(Convey.RFC822.Message message) {
        GLib.DateTime date = message.date != null
            ? message.date.value
            : new GLib.DateTime.now_local();
        Convey.RFC822.MailboxAddresses from = (
            message.from != null && !message.from.is_empty
            ? message.from
            : new Convey.RFC822.MailboxAddresses.single(
                this.account.primary_mailbox
            )
        );

        Convey.ComposedEmail composed = new Convey.ComposedEmail(date, from);
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
                                                Convey.ComposedEmail composed,
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

    private async void replace_with_pgp_mime_attachment(
        string message_id,
        Convey.Memory.Buffer pgp_mime,
        GLib.Cancellable? cancellable
    ) throws GLib.Error {
        string path = "/me/messages/%s".printf(
            GLib.Uri.escape_string(message_id, null, false)
        );
        string attachments_path = path + "/attachments";

        Json.Object existing = yield request_json(
            "GET", attachments_path, "$select=id", cancellable
        );
        if (existing.has_member("value")) {
            foreach (Json.Node node in existing.get_array_member("value").get_elements()) {
                string? attachment_id = get_string_member(
                    node.get_object(), "id"
                );
                if (!String.is_empty(attachment_id)) {
                    yield request_no_content(
                        "DELETE",
                        "%s/%s".printf(
                            attachments_path,
                            GLib.Uri.escape_string(attachment_id, null, false)
                        ),
                        null,
                        cancellable
                    );
                }
            }
        }

        Json.Builder attachment = new Json.Builder();
        attachment.begin_object();
        attachment.set_member_name("@odata.type");
        attachment.add_string_value("#microsoft.graph.fileAttachment");
        attachment.set_member_name("name");
        attachment.add_string_value("smime.p7m");
        attachment.set_member_name("contentType");
        attachment.add_string_value("multipart/signed");
        attachment.set_member_name("contentBytes");
        attachment.add_string_value(
            GLib.Base64.encode(pgp_mime.get_bytes().get_data())
        );
        attachment.end_object();
        yield request_json(
            "POST", attachments_path, null, cancellable, to_json(attachment)
        );

        Json.Builder message_class = new Json.Builder();
        message_class.begin_object();
        message_class.set_member_name("singleValueExtendedProperties");
        message_class.begin_array();
        message_class.begin_object();
        message_class.set_member_name("id");
        message_class.add_string_value("String 0x001A");
        message_class.set_member_name("value");
        message_class.add_string_value("IPM.Note.SMIME.MultipartSigned");
        message_class.end_object();
        message_class.end_array();
        message_class.end_object();
        yield request_json(
            "PATCH", path, null, cancellable, to_json(message_class)
        );
    }

    private static bool append_mailbox_addresses_to_builder(
        Json.Builder builder,
        string name,
        Convey.RFC822.MailboxAddresses? addresses
    ) {
        if (addresses == null || addresses.size == 0) {
            return false;
        }
        Gee.ArrayList<Convey.RFC822.MailboxAddress> valid_addresses =
            new Gee.ArrayList<Convey.RFC822.MailboxAddress>();
        foreach (Convey.RFC822.MailboxAddress address in addresses) {
            if (!String.is_empty(address.address)) {
                valid_addresses.add(address);
            }
        }
        if (valid_addresses.is_empty) {
            return false;
        }
        builder.set_member_name(name);
        builder.begin_array();
        foreach (Convey.RFC822.MailboxAddress address in valid_addresses) {
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
