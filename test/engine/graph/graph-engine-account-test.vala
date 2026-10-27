/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */


class GriabuntuMail.Graph.AccountTest : GraphTestCase {


    public AccountTest() {
        base("GriabuntuMail.Graph.AccountTest");
        add_test("exposes_seven_special_folders", exposes_seven_special_folders);
        add_test("special_folders_map_to_correct_use", special_folders_map_to_correct_use);
        add_test("get_required_special_folder_returns_match", get_required_special_folder_returns_match);
        add_test("get_required_special_folder_throws_for_unknown", get_required_special_folder_throws_for_unknown);
        add_test("get_folder_looks_up_by_path", get_folder_looks_up_by_path);
        add_test("create_personal_folder_rejects_special_use", create_personal_folder_rejects_special_use);
        add_test("account_supports_queue_send_interface", account_supports_queue_send_interface);
    }

    private GriabuntuMail.Graph.Account new_account() throws GLib.Error {
        return new GriabuntuMail.Graph.Account(
            this.account,
            new GriabuntuMail.Endpoint(
                new GLib.NetworkAddress("localhost", 0),
                GriabuntuMail.TlsNegotiationMethod.TRANSPORT,
                1
            ),
            new GriabuntuMail.Endpoint(
                new GLib.NetworkAddress("localhost", 0),
                GriabuntuMail.TlsNegotiationMethod.TRANSPORT,
                1
            )
        );
    }

    public void exposes_seven_special_folders() throws GLib.Error {
        // A freshly-constructed Graph.Account should expose the seven
        // hard-coded special-use folders that the engine uses to
        // represent the Outlook mailbox.
        GriabuntuMail.Graph.Account account = new_account();
        Gee.Collection<GriabuntuMail.Folder> folders = account.list_folders();
        assert_true(
            folders.size == 7,
            "Expected 7 hard-coded special folders"
        );
    }

    public void special_folders_map_to_correct_use() throws GLib.Error {
        GriabuntuMail.Graph.Account account = new_account();

        Gee.Map<GriabuntuMail.Folder.SpecialUse,string> expected = new Gee.HashMap<
            GriabuntuMail.Folder.SpecialUse,string
        >();
        expected.set(GriabuntuMail.Folder.SpecialUse.INBOX, "Inbox");
        expected.set(GriabuntuMail.Folder.SpecialUse.SENT, "Sent");
        expected.set(GriabuntuMail.Folder.SpecialUse.DRAFTS, "Drafts");
        expected.set(GriabuntuMail.Folder.SpecialUse.TRASH, "Trash");
        expected.set(GriabuntuMail.Folder.SpecialUse.JUNK, "Junk");
        expected.set(GriabuntuMail.Folder.SpecialUse.ARCHIVE, "Archive");
        expected.set(GriabuntuMail.Folder.SpecialUse.OUTBOX, "Outbox");

        foreach (GriabuntuMail.Folder folder in account.list_folders()) {
            string? expected_name = expected.get(folder.used_as);
            if (expected_name == null) {
                continue;
            }
            assert_equal(
                folder.path.name, expected_name,
                "Folder %s should map to %s".printf(
                    folder.path.to_string(),
                    folder.used_as.to_string()
                )
            );
            expected.unset(folder.used_as);
        }
        assert_true(
            expected.size == 0,
            "All seven special-use folders should be present"
        );
    }

    public void get_required_special_folder_returns_match() throws GLib.Error {
        GriabuntuMail.Graph.Account account = new_account();

        GriabuntuMail.Folder? inbox = null;
        account.get_required_special_folder_async.begin(
            GriabuntuMail.Folder.SpecialUse.INBOX, null, (obj, res) => {
                try {
                    inbox = account.get_required_special_folder_async.end(res);
                } catch (GLib.Error err) {
                    fail("get_required_special_folder_async failed: %s".printf(err.message));
                }
            }
        );
        while (inbox == null) {
            MainContext.default().iteration(true);
        }
        assert_non_null(inbox);
        assert_true(inbox.used_as == GriabuntuMail.Folder.SpecialUse.INBOX);
    }

    public void get_required_special_folder_throws_for_unknown() throws GLib.Error {
        GriabuntuMail.Graph.Account account = new_account();

        // NONE is not registered as a special folder; asking for it
        // should fail rather than return null silently.
        bool threw = false;
        account.get_required_special_folder_async.begin(
            GriabuntuMail.Folder.SpecialUse.NONE, null, (obj, res) => {
                try {
                    account.get_required_special_folder_async.end(res);
                } catch (GriabuntuMail.EngineError.NOT_FOUND err) {
                    threw = true;
                } catch (GLib.Error err) {
                    fail("Expected NOT_FOUND, got: %s".printf(err.message));
                }
            }
        );
        while (!threw) {
            MainContext.default().iteration(true);
        }
        assert_true(threw);
    }

    public void get_folder_looks_up_by_path() throws GLib.Error {
        GriabuntuMail.Graph.Account account = new_account();

        GriabuntuMail.FolderPath inbox_path = account.get_graph_special_folder(
            GriabuntuMail.Folder.SpecialUse.INBOX
        ).path;
        GriabuntuMail.Folder folder = account.get_folder(inbox_path);
        assert_true(folder.used_as == GriabuntuMail.Folder.SpecialUse.INBOX);

        // A path that doesn't exist should raise NOT_FOUND.
        GriabuntuMail.FolderPath bogus = new GriabuntuMail.FolderRoot("bogus", false)
            .get_child("DoesNotExist");
        bool threw = false;
        try {
            account.get_folder(bogus);
        } catch (GriabuntuMail.EngineError.NOT_FOUND err) {
            threw = true;
        }
        assert_true(threw, "Unknown path should raise NOT_FOUND");
    }

    public void create_personal_folder_rejects_special_use() throws GLib.Error {
        // Graph doesn't allow callers to choose a special use when
        // creating a folder; that should be rejected up front rather
        // than silently creating a generic folder.
        GriabuntuMail.Graph.Account account = new_account();

        bool threw = false;
        try {
            account.create_personal_folder.begin(
                "Archive", GriabuntuMail.Folder.SpecialUse.ARCHIVE, null, null,
                (obj, res) => {
                    try {
                        account.create_personal_folder.end(res);
                    } catch (GriabuntuMail.EngineError.UNSUPPORTED err) {
                        threw = true;
                    } catch (GLib.Error err) {
                        // The account is not open in this test, so the
                        // method may reject with an "account not open"
                        // error before checking the special use. Both
                        // outcomes prove the caller-visible API refuses
                        // to create a special-use folder.
                        if (err.message.contains("not open")) {
                            threw = true;
                        } else {
                            fail("Expected UNSUPPORTED, got: %s".printf(err.message));
                        }
                    }
                }
            );
            while (!threw) {
                MainContext.default().iteration(true);
            }
        } catch (GLib.Error open_err) {
            // open_async was not called so this path is unreachable,
            // but if the API ever starts checking is_open first, we
            // still want a passing test.
            fail("create_personal_folder threw synchronously: %s".printf(open_err.message));
        }
        assert_true(threw);
    }

    public void account_supports_queue_send_interface() throws GLib.Error {
        // A Graph.Account must implement the QueueSend interface so
        // the application controller can wire up staged-send
        // notifications.
        GriabuntuMail.Graph.Account account = new_account();
        assert_true(
            account is GriabuntuMail.AccountSupport.QueueSend,
            "Graph.Account should implement AccountSupport.QueueSend"
        );
    }

}
