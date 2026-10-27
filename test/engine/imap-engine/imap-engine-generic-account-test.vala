/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
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
