/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Downstream modification: 2026-11-25, synthetic partial discovery regression.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class GriabuntuMail.ImapEngine.GenericAccountTest : TestCase {


    internal class TestAccount : GenericAccount {

        public TestAccount(AccountInformation config,
                           ImapDB.Account local,
                           Endpoint incoming_remote,
                           Endpoint outgoing_remote) {
            base(config, local, incoming_remote, outgoing_remote);
        }

        protected override MinimalFolder new_folder(ImapDB.Folder local_folder) {
            return new MinimalFolder(
                this,
                local_folder,
                NONE
            );
        }

    }


    private GLib.File? tmp_dir = null;
    private GriabuntuMail.AccountInformation? config = null;
    private ImapDB.Account? local_account = null;


    public GenericAccountTest() {
        base("GriabuntuMail.ImapEngine.GenericAccountTest");
        add_test("partial_folder_refresh", partial_folder_refresh);
        add_test("to_email_identifier", to_email_identifier);
    }

    public override void set_up() throws GLib.Error {
        this.tmp_dir = GLib.File.new_for_path(
            GLib.DirUtils.make_tmp(
                "griabuntu-mail-imap-engine-generic-account-test-XXXXXX"
            )
        );

        this.config = new GriabuntuMail.AccountInformation(
            "test",
            ServiceProvider.OTHER,
            new Mock.CredentialsMediator(),
            new GriabuntuMail.RFC822.MailboxAddress(null, "test@example.com")
        );

        this.local_account = new ImapDB.Account(
            config,
            this.tmp_dir,
            GLib.File.new_for_path(Config.SOURCE_ROOT_DIR).get_child("sql")
        );
        this.local_account.open_async.begin(null, this.async_completion);
        this.local_account.open_async.end(async_result());
    }

    public override void tear_down() throws GLib.Error {
        this.local_account.close_async.begin(null, this.async_completion);
        this.local_account.close_async.end(async_result());
        this.local_account = null;
        this.config = null;

        delete_file(this.tmp_dir);
        this.tmp_dir = null;
    }

    private void add_exchange(TestServer server, ref int sequence, string command,
                              string[] data, string completion = "OK done") {
        string tag = "a%03d".printf(++sequence);
        server.add_script_line(RECEIVE_LINE, tag + " " + command);
        foreach (var line in data) {
            server.add_script_line(SEND_LINE, line);
        }
        server.add_script_line(SEND_LINE, tag + " " + completion);
    }

    private int query_int(string sql) throws GLib.Error {
        return this.local_account.db.query(sql).int_at(0);
    }

    public void partial_folder_refresh() throws GLib.Error {
        var server = new TestServer();
        try {
            int seq = 0;
            server.add_script_line(SEND_LINE, "* OK [CAPABILITY IMAP4rev1 LOGIN] ready");
            add_exchange(server, ref seq, "login test password", {},
                         "OK [CAPABILITY IMAP4rev1 NAMESPACE] ready");
            add_exchange(server, ref seq, "LIST \"\" INBOX", {"* LIST () \".\" INBOX"});
            add_exchange(server, ref seq, "NAMESPACE", {"* NAMESPACE ((\"\" \".\")) NIL NIL"});

            string items = " (MESSAGES RECENT UIDNEXT UIDVALIDITY UNSEEN)";
            for (int pass = 1; pass <= 5; pass++) {
                add_exchange(server, ref seq, "LIST \"\" \"%\"", {
                    "* LIST (\\HasNoChildren) \".\" Alpha",
                    "* LIST (\\Noselect \\HasChildren) \".\" Group"
                });
                string alpha = "* STATUS Alpha (MESSAGES 9 RECENT 0 UIDNEXT 10 UIDVALIDITY 1 UNSEEN %d)".printf(pass);
                add_exchange(server, ref seq, "STATUS Alpha" + items, {alpha});
                if (pass == 5) {
                    add_exchange(server, ref seq, "LIST \"\" \"Group.%\"", {});
                } else {
                    string beta = "* LIST (\\HasNoChildren) \".\" Group.Beta";
                    add_exchange(server, ref seq, "LIST \"\" \"Group.%\"", {beta, beta});
                    string command = "STATUS Group.Beta" + items;
                    if (pass == 2) {
                        add_exchange(server, ref seq, command, {}, "NO unavailable");
                    } else if (pass == 3) {
                        // Extra data for Alpha cannot stand in for Beta.
                        add_exchange(server, ref seq, command, {alpha, alpha});
                    } else {
                        add_exchange(server, ref seq, command, {
                            "* STATUS Group.Beta (MESSAGES 9 RECENT 0 UIDNEXT 10 UIDVALIDITY 1 UNSEEN %d)".printf(pass)
                        });
                    }
                }
            }
            server.add_script_line(WAIT_FOR_DISCONNECT, "");

            var endpoint = new Endpoint(server.get_client_address(), NONE, 5);
            var client = new Imap.ClientSession(endpoint, new Imap.Quirks());
            client.connect_async.begin(5, null, this.async_completion);
            client.connect_async.end(async_result());
            client.initiate_session_async.begin(new Credentials(PASSWORD, "test", "password"),
                                                null, this.async_completion);
            client.initiate_session_async.end(async_result());
            var remote = new Imap.AccountSession(this.local_account.imap_folder_root, client);
            var account = new TestAccount(this.config, this.local_account, endpoint, endpoint);
            var refresh = new UpdateRemoteFolders(account, true, {});
            int deleted = 0;
            account.folders_deleted.connect((folders) => { deleted += folders.size; });
            for (int pass = 1; pass <= 5; pass++) {
                refresh.refresh_async.begin(remote, new GLib.Cancellable(), this.async_completion);
                refresh.refresh_async.end(async_result());
                if (pass == 1) {
                    this.local_account.db.exec("INSERT INTO MessageTable (id, fields) VALUES (1, 0)");
                    this.local_account.db.exec("""
                        INSERT INTO MessageLocationTable (message_id, folder_id, ordering)
                        SELECT 1, id, 1 FROM FolderTable WHERE name='Beta'
                    """);
                }
                assert_equal<int?>(query_int("SELECT unread_count FROM FolderTable WHERE name='Alpha'"), pass);
                assert_equal<int?>(query_int("SELECT COUNT(*) FROM MessageLocationTable WHERE message_id=1"),
                                   pass == 5 ? 0 : 1);
                assert_equal<int?>(deleted, pass == 5 ? 1 : 0);
                if (pass == 5) {
                    assert_equal<int?>(query_int("SELECT COUNT(*) FROM FolderTable WHERE name='Beta'"), 0);
                } else {
                    assert_equal<int?>(query_int("SELECT unread_count FROM FolderTable WHERE name='Beta'"),
                                       pass == 4 ? 4 : 1);
                }
            }
            remote.close();
            client.disconnect_async.begin(null, this.async_completion);
            client.disconnect_async.end(async_result());
            assert_true(server.wait_for_script(this.main_loop).succeeded);
        } finally {
            server.stop();
        }
    }

    public void to_email_identifier() throws GLib.Error {
        TestAccount test_article = new TestAccount(
            this.config,
            this.local_account,
            new Endpoint(new GLib.NetworkAddress("localhost", 143), NONE, 0),
            new Endpoint(new GLib.NetworkAddress("localhost", 25), NONE, 0)
        );

        assert_non_null(
            test_article.to_email_identifier(
                new GLib.Variant(
                    "(yr)", 'i', new GLib.Variant("(xx)", 1, 2)
                )
            )
        );
        assert_non_null(
            test_article.to_email_identifier(
                new GLib.Variant(
                    "(yr)", 'o', new GLib.Variant("(xx)", 1, 2)
                )
            )
        );
    }

}
