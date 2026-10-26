/*
 * Copyright 2017 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

class Convey.EngineTest : TestCase {


    private Engine? engine = null;
    private File? tmp = null;
    private File? res = null;
    private Convey.AccountInformation? account = null;


    public EngineTest() {
        base("Convey.EngineTest");
        add_test("add_account", add_account);
        add_test("remove_account", remove_account);
        add_test("re_add_account", re_add_account);
        add_test("add_graph_account_creates_graph_account", add_graph_account_creates_graph_account);
        add_test("add_imap_account_creates_imap_account", add_imap_account_creates_imap_account);
    }

    ~EngineTest() {
        // Need this in addition to the code in tear_down in case a
        // test fails
        if (this.tmp != null) {
            try {
                @delete(this.tmp);
            } catch (Error err) {
                print("\nError removing tmp files: %s\n", err.message);
            }
        }
    }

    public override void set_up() throws GLib.Error {
        // XXX this whole thing stinks. We need to be able to test the
        // engine without creating all of these dirs.

        this.tmp = GLib.File.new_for_path(
            GLib.DirUtils.make_tmp("convey-engine-test-XXXXXX")
        );

        this.res = this.tmp.get_child("res");
        this.res.make_directory();

        this.engine = new Engine(res);

        this.account = new AccountInformation(
            "test",
            ServiceProvider.OTHER,
            new Mock.CredentialsMediator(),
            new RFC822.MailboxAddress(null, "test1@example.com")
        );
        this.account.set_account_directories(this.tmp, this.tmp);
    }

    public override void tear_down() throws GLib.Error {
        this.account = null;
        this.res.delete();
        this.tmp.delete();
        this.tmp = null;
    }

    public void add_account() throws GLib.Error {
        assert_false(this.engine.has_account(this.account));

        this.engine.add_account(this.account);
        assert_true(this.engine.has_account(this.account), "Account not added");

        try {
            this.engine.add_account(this.account);
            assert_not_reached();
        } catch (GLib.Error err) {
            // expected
        }
    }

    public void remove_account() throws GLib.Error {
        this.engine.add_account(this.account);
        assert_true(this.engine.has_account(this.account));

        this.engine.remove_account(this.account);
        assert_false(this.engine.has_account(this.account), "Account not removed");

        try {
            this.engine.remove_account(this.account);
            assert_not_reached();
        } catch (GLib.Error err) {
            // expected
        }
    }

    public void re_add_account() throws GLib.Error {
        assert_false(this.engine.has_account(this.account));

        this.engine.add_account(this.account);
        this.engine.remove_account(this.account);
        this.engine.add_account(this.account);

        assert_true(this.engine.has_account(this.account));
    }

    public void add_graph_account_creates_graph_account() throws GLib.Error {
        // An account configured with the MICROSOFT_GRAPH backend must
        // be wired up to a Graph.Account by the engine, not an
        // ImapEngine.OutlookAccount.
        AccountInformation graph_account = new AccountInformation(
            "graph-test",
            ServiceProvider.OUTLOOK,
            new Mock.CredentialsMediator(),
            new RFC822.MailboxAddress(null, "test1@example.com")
        );
        graph_account.account_backend = AccountBackend.MICROSOFT_GRAPH;
        graph_account.set_account_directories(this.tmp, this.tmp);

        assert_false(this.engine.has_account(graph_account));

        this.engine.add_account(graph_account);
        assert_true(
            this.engine.has_account(graph_account),
            "Graph account not added to engine"
        );

        Account account = this.engine.get_account(graph_account);
        assert_true(
            account is Convey.Graph.Account,
            "Engine should produce a Graph.Account for MICROSOFT_GRAPH backend"
        );
        this.engine.remove_account(graph_account);
    }

    public void add_imap_account_creates_imap_account() throws GLib.Error {
        // The default IMAP_SMTP backend should still produce an
        // ImapEngine-backed account. This guards against regressions
        // where the Graph switch accidentally becomes the default.
        AccountInformation imap_account = new AccountInformation(
            "imap-test",
            ServiceProvider.OUTLOOK,
            new Mock.CredentialsMediator(),
            new RFC822.MailboxAddress(null, "test1@example.com")
        );
        imap_account.account_backend = AccountBackend.IMAP_SMTP;
        imap_account.set_account_directories(this.tmp, this.tmp);

        this.engine.add_account(imap_account);
        Account account = this.engine.get_account(imap_account);
        assert_true(
            account is Convey.ImapEngine.OutlookAccount,
            "Engine should produce an ImapEngine.OutlookAccount for IMAP_SMTP/OUTLOOK"
        );
        this.engine.remove_account(imap_account);
    }

   private void delete(File parent) throws Error {
        FileInfo info = parent.query_info(
            "standard::*",
            FileQueryInfoFlags.NOFOLLOW_SYMLINKS
        );

        if (info.get_file_type () == FileType.DIRECTORY) {
            FileEnumerator enumerator = parent.enumerate_children(
                "standard::*",
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS
            );

            info = null;
            while (((info = enumerator.next_file()) != null)) {
                @delete(parent.get_child(info.get_name()));
            }
        }

        parent.delete();
    }

}