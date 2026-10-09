/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */


class Convey.Graph.ClientTest : GraphTestCase {


    public ClientTest() {
        base("Convey.Graph.ClientTest");
        add_test("ping_sends_get_me", ping_sends_get_me);
        add_test("list_mail_folders_parses_response", list_mail_folders_parses_response);
        add_test("list_messages_parses_response", list_messages_parses_response);
        add_test("list_messages_follows_next_link", list_messages_follows_next_link);
        add_test("fetch_message_parses_full_body", fetch_message_parses_full_body);
        add_test("delta_messages_parses_changed_and_removed", delta_messages_parses_changed_and_removed);
        add_test("delta_messages_baseline_returns_cursor", delta_messages_baseline_returns_cursor);
        add_test("delta_messages_gone_requires_resync", delta_messages_gone_requires_resync);
        add_test("create_message_in_outbox_returns_id", create_message_in_outbox_returns_id);
        add_test("get_pgp_mime_buffer_is_null_for_plain_mail", get_pgp_mime_buffer_is_null_for_plain_mail);
        add_test("send_message_posts_to_send_endpoint", send_message_posts_to_send_endpoint);
        add_test("request_failure_throws_http_error", request_failure_throws_http_error);
        add_test("throttled_request_retries_after_wait", throttled_request_retries_after_wait);
        add_test("unauthorized_request_refreshes_credentials_and_retries", unauthorized_request_refreshes_credentials_and_retries);
    }

    public void ping_sends_get_me() throws GLib.Error {
        SoupServerCapture capture = respond_capture_json(
            "GET", "/me", 200,
            """{"id": "user-123"}"""
        );

        Convey.Graph.Client client = new_client();

        client.ping.begin(null, this.async_completion);
        client.ping.end(async_result());

        assert_true(capture.hit_count == 1, "Expected one /me request");
        assert_equal(capture.method, "GET");
        assert_equal(
            capture.headers.get("authorization") ?? "",
            "Bearer test-graph-token",
            "Authorization header should carry the OAuth bearer token"
        );
    }

    public void list_mail_folders_parses_response() throws GLib.Error {
        respond_json(
            "GET", "/me/mailFolders", 200,
            """{
                "value": [
                    {
                        "id": "AAMkAGI1",
                        "displayName": "Inbox",
                        "wellKnownName": "inbox"
                    },
                    {
                        "id": "AAMkAGI2",
                        "displayName": "Custom",
                        "wellKnownName": ""
                    }
                ]
            }"""
        );

        Convey.Graph.Client client = new_client();
        Gee.List<Convey.Graph.Client.MailFolder>? folders = null;
        client.list_mail_folders.begin(null, null, (obj, res) => {
            try {
                folders = client.list_mail_folders.end(res);
            } catch (GLib.Error err) {
                fail("list_mail_folders failed: %s".printf(err.message));
            }
        });
        // spin the main context until done
        while (folders == null) {
            MainContext.default().iteration(true);
        }

        assert_non_null(folders);
        assert_true(folders.size == 2, "expected 2");

        Convey.Graph.Client.MailFolder inbox = folders[0];
        assert_equal(inbox.id, "AAMkAGI1");
        assert_equal(inbox.display_name, "Inbox");
        assert_equal(inbox.well_known_name, "inbox");
        assert_false(inbox.is_hidden);

        Convey.Graph.Client.MailFolder custom = folders[1];
        assert_equal(custom.id, "AAMkAGI2");
        assert_equal(custom.display_name, "Custom");
        assert_true(
            String.is_empty(custom.well_known_name),
            "Empty wellKnownName should be reported as empty"
        );
    }

    public void list_messages_parses_response() throws GLib.Error {
        // Use a date within the prefetch window so the cutoff filter
        // does not drop the test message.
        string recent = new GLib.DateTime.now_utc()
            .add_days(-1)
            .format("%Y-%m-%dT%H:%M:%SZ");
        respond_json(
            "GET", "/me/mailFolders/inbox/messages", 200,
            """{
                "value": [
                    {
                        "id": "msg-1",
                        "conversationId": "conv-1",
                        "subject": "Hello",
                        "receivedDateTime": "%s",
                        "from": {
                            "emailAddress": {
                                "name": "Sender",
                                "address": "sender@example.com"
                            }
                        },
                        "bodyPreview": "preview text",
                        "isRead": false,
                        "flag": {"flagStatus": "flagged"},
                        "hasAttachments": true
                    }
                ]
            }""".printf(recent)
        );

        Convey.Graph.Client client = new_client();
        Gee.List<Convey.Graph.Client.Message>? messages = null;
        client.list_messages.begin(
            "inbox", 10, 14, 0, null, null, (obj, res) => {
                try {
                    messages = client.list_messages.end(res);
                } catch (GLib.Error err) {
                    fail("list_messages failed: %s".printf(err.message));
                }
            }
        );
        while (messages == null) {
            MainContext.default().iteration(true);
        }

        assert_non_null(messages);
        assert_true(messages.size == 1, "expected 1");

        Convey.Graph.Client.Message msg = messages[0];
        assert_equal(msg.id, "msg-1");
        assert_equal(msg.conversation_id, "conv-1");
        assert_equal(msg.subject, "Hello");
        assert_false(msg.is_read, "isRead=false should map to is_read=false");
        assert_true(msg.is_flagged, "flagStatus=flagged should map to is_flagged=true");
        assert_true(msg.has_attachments);
        assert_equal(msg.body_preview, "preview text");
        assert_non_null(msg.received_at, "received_at should be parsed");
    }

    public void list_messages_follows_next_link() throws GLib.Error {
        // First page includes a nextLink; second page has no further pages.
        string recent_a = new GLib.DateTime.now_utc()
            .add_days(-1)
            .format("%Y-%m-%dT%H:%M:%SZ");
        string recent_b = new GLib.DateTime.now_utc()
            .add_days(-2)
            .format("%Y-%m-%dT%H:%M:%SZ");
        // Use a request counter to alternate between the two pages.
        int page_num = 0;
        this.server.add_handler("/me/mailFolders/inbox/messages", (srv, msg, p, query) => {
            string body;
            if (page_num == 0) {
                // First page: one item + nextLink
                body = """{
                    "value": [
                        {
                            "id": "msg-a",
                            "conversationId": "conv-a",
                            "receivedDateTime": "%s"
                        }
                    ],
                    "@odata.nextLink": "%s/me/mailFolders/inbox/messages?$skip=1"
                }""".printf(recent_a, this.base_uri);
            } else {
                // Second page (via nextLink): one item, no further pages
                body = """{
                    "value": [
                        {
                            "id": "msg-b",
                            "conversationId": "conv-b",
                            "receivedDateTime": "%s"
                        }
                    ]
                }""".printf(recent_b);
            }
            page_num++;
            uint8[] bytes = new uint8[body.length];
            GLib.Memory.copy(bytes, body.data, body.length);
            msg.set_response("application/json", Soup.MemoryUse.COPY, bytes);
            msg.set_status(200, null);
        });

        Convey.Graph.Client client = new_client();
        Gee.List<Convey.Graph.Client.Message>? messages = null;
        client.list_messages.begin(
            "inbox", 10, 14, 0, null, null, (obj, res) => {
                try {
                    messages = client.list_messages.end(res);
                } catch (GLib.Error err) {
                    fail("list_messages failed: %s".printf(err.message));
                }
            }
        );
        while (messages == null) {
            MainContext.default().iteration(true);
        }

        assert_non_null(messages);
        // The parser must follow the nextLink to fetch the second
        // page, yielding two messages across pages.
        assert_true(
            messages.size == 2,
            "Expected 2 messages across pages, got %d".printf(messages.size)
        );
        assert_equal(messages[0].id, "msg-a");
        assert_equal(messages[1].id, "msg-b");
    }

    public void fetch_message_parses_full_body() throws GLib.Error {
        respond_json(
            "GET", "/me/messages/msg-1", 200,
            """{
                "id": "msg-1",
                "conversationId": "conv-1",
                "subject": "Hello",
                "receivedDateTime": "2024-01-02T10:00:00Z",
                "from": {
                    "emailAddress": {
                        "address": "sender@example.com"
                    }
                },
                "bodyPreview": "preview",
                "hasAttachments": false,
                "isRead": true,
                "flag": {"flagStatus": "notFlagged"},
                "body": {
                    "contentType": "html",
                    "content": "<p>hello</p>"
                },
                "singleValueExtendedProperties": [
                    {"id": "String 0x1042", "value": "<parent@example.com>"},
                    {"id": "String 0x1039", "value": "<root@example.com> <parent@example.com>"}
                ]
            }"""
        );

        Convey.Graph.Client client = new_client();
        Convey.Graph.Client.Message? msg = null;
        client.fetch_message.begin(
            "msg-1", null, (obj, res) => {
                try {
                    msg = client.fetch_message.end(res);
                } catch (GLib.Error err) {
                    fail("fetch_message failed: %s".printf(err.message));
                }
            }
        );
        while (msg == null) {
            MainContext.default().iteration(true);
        }

        assert_equal(msg.id, "msg-1");
        assert_true(msg.is_read, "isRead=true should map to is_read=true");
        assert_false(msg.is_flagged);
        assert_equal(msg.body_content_type, "html");
        assert_equal(msg.body, "<p>hello</p>");
        assert_equal(msg.in_reply_to, "<parent@example.com>");
        assert_equal(msg.references, "<root@example.com> <parent@example.com>");
    }

    public void delta_messages_parses_changed_and_removed() throws GLib.Error {
        // First page: one changed id plus a nextLink; second page: one
        // removed id plus the final deltaLink.
        respond_json(
            "GET", "/delta-cursor", 200,
            """{
                "value": [
                    {"id": "msg-1", "isRead": false}
                ],
                "@odata.nextLink": "%s/delta-page-2"
            }""".printf(this.base_uri)
        );
        respond_json(
            "GET", "/delta-page-2", 200,
            """{
                "value": [
                    {
                        "id": "msg-gone",
                        "@removed": {"reason": "deleted"}
                    }
                ],
                "@odata.deltaLink": "%s/delta-final"
            }""".printf(this.base_uri)
        );

        Convey.Graph.Client client = new_client();
        Convey.Graph.Client.DeltaResult? result = null;
        client.delta_messages.begin(
            "inbox", this.base_uri + "/delta-cursor", null, (obj, res) => {
                try {
                    result = client.delta_messages.end(res);
                } catch (GLib.Error err) {
                    fail("delta_messages failed: %s".printf(err.message));
                }
            }
        );
        while (result == null) {
            MainContext.default().iteration(true);
        }

        assert_true(result.complete, "delta should be complete");
        assert_false(result.resync_required);
        assert_equal(result.delta_link, this.base_uri + "/delta-final");
        assert_true(result.changed_ids.size == 1, "expected 1 changed");
        assert_true(result.changed_ids.contains("msg-1"), "msg-1 changed");
        assert_true(result.removed.size == 1, "expected 1 removed");
        assert_true(result.removed.contains("msg-gone"), "msg-gone removed");
    }

    public void delta_messages_baseline_returns_cursor() throws GLib.Error {
        // $deltaToken=latest: no items, just a fresh cursor.
        respond_json(
            "GET", "/me/mailFolders/inbox/messages/delta", 200,
            """{
                "value": [],
                "@odata.deltaLink": "%s/delta-fresh"
            }""".printf(this.base_uri)
        );

        Convey.Graph.Client client = new_client();
        Convey.Graph.Client.DeltaResult? result = null;
        client.delta_messages.begin(
            "inbox", null, null, (obj, res) => {
                try {
                    result = client.delta_messages.end(res);
                } catch (GLib.Error err) {
                    fail("delta_messages failed: %s".printf(err.message));
                }
            }
        );
        while (result == null) {
            MainContext.default().iteration(true);
        }

        assert_true(result.complete);
        assert_equal(result.delta_link, this.base_uri + "/delta-fresh");
        assert_true(result.changed_ids.size == 0 && result.removed.size == 0);
    }

    public void delta_messages_gone_requires_resync() throws GLib.Error {
        respond_json(
            "GET", "/expired-cursor", 410,
            """{"error": {"code": "resyncRequired"}}"""
        );

        Convey.Graph.Client client = new_client();
        Convey.Graph.Client.DeltaResult? result = null;
        client.delta_messages.begin(
            "inbox", this.base_uri + "/expired-cursor", null, (obj, res) => {
                try {
                    result = client.delta_messages.end(res);
                } catch (GLib.Error err) {
                    fail("delta_messages failed: %s".printf(err.message));
                }
            }
        );
        while (result == null) {
            MainContext.default().iteration(true);
        }

        assert_true(result.resync_required, "410 should require resync");
        assert_false(result.complete);
        assert_true(result.changed_ids.size == 0 && result.removed.size == 0);
    }

    public void create_message_in_outbox_returns_id() throws GLib.Error {
        var create = new SoupServerCapture("/me/messages");
        var patch = new SoupServerCapture("/me/messages/draft-42");
        this.server.add_handler("/me/messages", (srv, msg, p, query) => {
            create.record(msg);
            string body = """{"id": "draft-42"}""";
            uint8[] bytes = (uint8[]) body.data;
            msg.set_response("application/json", Soup.MemoryUse.COPY, bytes);
            msg.set_status(200, null);
        });
        this.server.add_handler("/me/messages/draft-42/move", (srv, msg, p, query) => {
            string body = """{"id": "draft-42"}""";
            uint8[] bytes = (uint8[]) body.data;
            msg.set_response("application/json", Soup.MemoryUse.COPY, bytes);
            msg.set_status(200, null);
        });
        this.server.add_handler("/me/messages/draft-42", (srv, msg, p, query) => {
            patch.record(msg);
            uint8[] bytes = (uint8[]) """{}""".data;
            msg.set_response("application/json", Soup.MemoryUse.COPY, bytes);
            msg.set_status(200, null);
        });

        Convey.Graph.Client client = new_client();
        Convey.ComposedEmail composed = new Convey.ComposedEmail(
            new GLib.DateTime.now_utc(),
            new RFC822.MailboxAddresses.single(
                new RFC822.MailboxAddress(null, "user@example.com")
            )
        );
        composed.set_to(new RFC822.MailboxAddresses.single(
            new RFC822.MailboxAddress(null, "dest@example.com")
        ));
        composed.set_subject("Test");
        composed.body_text = "Test body";

        string? id = null;
        client.create_message_in_outbox.begin(
            composed, null, (obj, res) => {
                try {
                    id = client.create_message_in_outbox.end(res);
                } catch (GLib.Error err) {
                    fail("create_message_in_outbox failed: %s".printf(err.message));
                }
            }
        );
        while (id == null) {
            MainContext.default().iteration(true);
        }

        assert_equal(id, "draft-42");
        assert_equal(create.headers.get("content-type") ?? "", "text/plain");
        uint8[] mime = GLib.Base64.decode(create.body);
        mime += 0;
        assert_true(
            ((string) mime).contains("Subject: Test"),
            "Plain mail should be uploaded as base64 MIME"
        );
        assert_equal(patch.method, "PATCH");
    }

    public void get_pgp_mime_buffer_is_null_for_plain_mail()
        throws GLib.Error {
        RFC822.Message rfc822 = new RFC822.Message.from_buffer(
            new Memory.StringBuffer(
                "From: user@example.com\nSubject: Hi\n\nHello\n"
            )
        );
        assert_null(rfc822.get_pgp_mime_buffer());
    }

    public void send_message_posts_to_send_endpoint() throws GLib.Error {
        SoupServerCapture capture = respond_capture_json(
            "POST", "/me/messages/msg-1/send", 202,
            ""
        );

        Convey.Graph.Client client = new_client();
        client.send_message.begin("msg-1", null, this.async_completion);
        client.send_message.end(async_result());

        assert_true(capture.hit_count == 1);
        assert_equal(capture.method, "POST");
    }

    public void request_failure_throws_http_error() throws GLib.Error {
        respond_json(
            "GET", "/me", 503,
            """{"error": {"code": "serviceUnavailable"}}"""
        );

        Convey.Graph.Client client = new_client();
        bool failed = false;
        client.ping.begin(null, (obj, res) => {
            try {
                client.ping.end(res);
            } catch (Convey.Graph.HttpError.SERVER err) {
                failed = true;
            } catch (GLib.Error err) {
                fail("Expected HttpError.SERVER, got: %s".printf(err.message));
            }
        });
        while (!failed) {
            MainContext.default().iteration(true);
        }
        assert_true(failed);
    }

    public void throttled_request_retries_after_wait() throws GLib.Error {
        int hit_count = 0;
        this.server.add_handler("/me", (srv, msg, p, query) => {
            hit_count++;
            if (hit_count == 1) {
                msg.get_response_headers().append("Retry-After", "0");
                msg.set_status(429, null);
                return;
            }
            string body = """{"id": "user-123"}""";
            uint8[] bytes = (uint8[]) body.data;
            msg.set_response("application/json", Soup.MemoryUse.COPY, bytes);
            msg.set_status(200, null);
        });

        Convey.Graph.Client client = new_client();
        client.ping.begin(null, this.async_completion);
        client.ping.end(async_result());

        assert_true(
            hit_count == 2,
            "Expected the client to retry after a 429, got %d requests".printf(hit_count)
        );
    }

    public void unauthorized_request_refreshes_credentials_and_retries() throws GLib.Error {
        var mediator = (Convey.GraphStubCredentialsMediator) this.mediator;
        int load_count_before = mediator.load_count;

        int hit_count = 0;
        this.server.add_handler("/me", (srv, msg, p, query) => {
            hit_count++;
            if (hit_count == 1) {
                msg.set_status(401, null);
                return;
            }
            string body = """{"id": "user-123"}""";
            uint8[] bytes = (uint8[]) body.data;
            msg.set_response("application/json", Soup.MemoryUse.COPY, bytes);
            msg.set_status(200, null);
        });

        Convey.Graph.Client client = new_client();
        client.ping.begin(null, this.async_completion);
        client.ping.end(async_result());

        assert_true(
            hit_count == 2,
            "Expected the client to retry once after a 401, got %d requests".printf(hit_count)
        );
        assert_true(
            mediator.load_count > load_count_before + 1,
            "Expected credentials to be reloaded again after the 401"
        );
    }

}
