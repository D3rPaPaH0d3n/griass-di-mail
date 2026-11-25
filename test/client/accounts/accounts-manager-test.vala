/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2018 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

class Accounts.ManagerTest : TestCase {


    private const string TEST_ID = "test";

    private Manager? test = null;
    private GriabuntuMail.CredentialsMediator? mediator = null;
    private GriabuntuMail.AccountInformation? account = null;
    private GriabuntuMail.RFC822.MailboxAddress primary_mailbox;
    private File? tmp = null;


    public ManagerTest() {
        base("AccountManagerTest");
        add_test("create_account", create_account);
        add_test("create_orphan_account", create_orphan_account);
        add_test(
            "create_orphan_account_with_legacy",
            create_orphan_account_with_legacy
        );
        add_test(
            "create_orphan_account_with_existing_dirs",
            create_orphan_account_with_existing_dirs
        );
        add_test("account_config_v1", account_config_v1);
        add_test("account_config_legacy", account_config_legacy);
        add_test("alias_remove_undo_after_provider_import", alias_remove_undo_after_provider_import);
        add_test("alias_append_redo_after_provider_import", alias_append_redo_after_provider_import);
        add_test("service_config_v1", service_config_v1);
        add_test("service_config_legacy", service_config_legacy);
    }

    public override void set_up() throws GLib.Error {
        // XXX this whole thing stinks. We need to be able to test the
        // engine without creating all of these dirs.

        this.tmp = GLib.File.new_for_path(
            GLib.DirUtils.make_tmp("accounts-manager-test-XXXXXX")
        );

        this.primary_mailbox = new GriabuntuMail.RFC822.MailboxAddress(
            null, "test1@example.com"
        );

        this.mediator = new Mock.CredentialsMediator();
        this.account = new GriabuntuMail.AccountInformation(
            TEST_ID,
            GriabuntuMail.ServiceProvider.OTHER,
            this.mediator,
            this.primary_mailbox
        );
        this.test = new Manager(this.mediator, this.tmp, this.tmp);
    }

    public override void tear_down() throws GLib.Error {
        this.account = null;
        this.mediator = null;
        this.test = null;
        this.primary_mailbox = null;
        // Filtered client runs may destroy this suite without ever setting it up.
        if (this.tmp != null) {
            @delete(this.tmp);
            this.tmp = null;
        }
    }

    public void create_account() throws GLib.Error {
        bool was_added = false;
        bool was_enabled = false;

        this.test.account_added.connect((added, status) => {
                was_added = (added == account);
                was_enabled = (status == Manager.Status.ENABLED);
            });

        this.test.create_account.begin(
            account, new GLib.Cancellable(),
             this.async_completion
        );
        this.test.create_account.end(async_result());

        assert_equal<int?>(this.test.size, 1, "Account manager size");
        assert_equal(this.test.get_account(TEST_ID), account, "Is not contained");
        assert_true(was_added, "Was not added");
        assert_true(was_enabled, "Was not enabled");
    }

    public void create_orphan_account() throws GLib.Error {
        this.test.new_orphan_account.begin(
            GriabuntuMail.ServiceProvider.OTHER, this.primary_mailbox, null,
            this.async_completion
        );
        GriabuntuMail.AccountInformation account1 =
            this.test.new_orphan_account.end(async_result());
        assert(account1.id == "account_01");

        this.test.create_account.begin(
            account1, new GLib.Cancellable(),
            this.async_completion
        );
        this.test.create_account.end(async_result());

        this.test.new_orphan_account.begin(
            GriabuntuMail.ServiceProvider.OTHER, this.primary_mailbox, null,
            this.async_completion
        );
        GriabuntuMail.AccountInformation account2 =
            this.test.new_orphan_account.end(async_result());
        assert(account2.id == "account_02");
    }

    public void create_orphan_account_with_legacy() throws GLib.Error {
        this.test.create_account.begin(
            account, new GLib.Cancellable(),
            this.async_completion
        );
        this.test.create_account.end(async_result());

        this.test.new_orphan_account.begin(
            GriabuntuMail.ServiceProvider.OTHER, this.primary_mailbox, null,
            this.async_completion
        );
        GriabuntuMail.AccountInformation account1 =
            this.test.new_orphan_account.end(async_result());
        assert(account1.id == "account_01");

        this.test.create_account.begin(
            account1, new GLib.Cancellable(),
            this.async_completion
        );
        this.test.create_account.end(async_result());

        this.test.new_orphan_account.begin(
            GriabuntuMail.ServiceProvider.OTHER, this.primary_mailbox, null,
            this.async_completion
        );
        GriabuntuMail.AccountInformation account2 =
            this.test.new_orphan_account.end(async_result());
        assert(account2.id == "account_02");
    }

    public void create_orphan_account_with_existing_dirs() throws GLib.Error {
        GLib.File existing = this.test.config_dir.get_child("account_01");
        existing.make_directory();
        existing = this.test.data_dir.get_child("account_02");
        existing.make_directory();

        this.test.new_orphan_account.begin(
            GriabuntuMail.ServiceProvider.OTHER, this.primary_mailbox, null,
            this.async_completion
        );
        GriabuntuMail.AccountInformation account =
            this.test.new_orphan_account.end(async_result());
        assert(account.id == "account_03");
    }

    public void account_config_v1() throws GLib.Error {
        this.account.label = "test-name";
        this.account.ordinal = 100;
        this.account.prefetch_period_days = 42;
        this.account.save_drafts = false;
        this.account.save_sent = false;
        this.account.signature = "blarg";
        this.account.use_signature = false;

        GriabuntuMail.ConfigFile file =
            new GriabuntuMail.ConfigFile(this.tmp.get_child("config.ini"));

        Accounts.AccountConfigV1 config = new Accounts.AccountConfigV1(false);
        config.save(this.account, file);

        GriabuntuMail.AccountInformation copy = config.load(
            file, TEST_ID, this.mediator, null, null
        );

        assert_true(this.account.equal_to(copy));
    }

    public void account_config_legacy() throws GLib.Error {
        this.account.label = "test-name";
        this.account.ordinal = 100;
        this.account.prefetch_period_days = 42;
        this.account.save_drafts = false;
        this.account.save_sent = false;
        this.account.signature = "blarg";
        this.account.use_signature = false;
        Accounts.AccountConfigLegacy config =
            new Accounts.AccountConfigLegacy();

        GriabuntuMail.ConfigFile file =
            new GriabuntuMail.ConfigFile(this.tmp.get_child("config.ini"));

        config.save(this.account, file);
        GriabuntuMail.AccountInformation copy = config.load(
            file, TEST_ID, this.mediator, null, null
        );

        assert_true(this.account.equal_to(copy));
    }

    private MailboxRow command_row(GriabuntuMail.RFC822.MailboxAddress mailbox) {
        // These command tests need real list rows, but no account pane, web view
        // or colour editor. Set the command's two model properties directly.
        return (MailboxRow) GLib.Object.new(
            typeof(MailboxRow), "account", this.account, "mailbox", mailbox
        );
    }

    private int row_count(Gtk.ListBox list) {
        int count = 0;
        for (var child = list.get_first_child(); child != null;
             child = child.get_next_sibling()) count++;
        return count;
    }

    public void alias_remove_undo_after_provider_import() throws GLib.Error {
        var alias = new GriabuntuMail.RFC822.MailboxAddress("Local alias", "alias@example.test");
        this.account.append_sender(alias);
        this.account.set_sender_color(alias, "#123456");
        var list = new Gtk.ListBox();
        list.append(command_row(this.primary_mailbox));
        var original_row = command_row(alias);
        list.append(original_row);
        var command = new RemoveMailboxCommand(original_row);
        command.execute.begin(null, this.async_completion);
        command.execute.end(async_result());

        var imported = new GriabuntuMail.RFC822.MailboxAddress("Provider", "ALIAS@EXAMPLE.TEST");
        this.account.append_sender(imported);
        list.append(command_row(imported));
        command.undo.begin(null, this.async_completion);
        command.undo.end(async_result());
        assert_equal<int?>(this.account.sender_mailboxes.size, 2);
        assert_equal<int?>(row_count(list), 2);
        assert_true(list.get_last_child() == original_row);
        assert_true(this.account.sender_mailboxes[1] == alias);
        assert_equal(this.account.get_sender_color(alias), "#123456");

        // The restored command must still remove that exact model and row.
        command.redo.begin(null, this.async_completion);
        command.redo.end(async_result());
        assert_equal<int?>(this.account.sender_mailboxes.size, 1);
        assert_equal<int?>(row_count(list), 1);
    }

    public void alias_append_redo_after_provider_import() throws GLib.Error {
        var alias = new GriabuntuMail.RFC822.MailboxAddress("Local alias", "alias@example.test");
        var list = new Gtk.ListBox();
        list.append(command_row(this.primary_mailbox));
        var original_row = command_row(alias);
        var command = new AppendMailboxCommand(list, original_row, "Local signature");
        command.execute.begin(null, this.async_completion);
        command.execute.end(async_result());
        command.undo.begin(null, this.async_completion);
        command.undo.end(async_result());

        var other = new GriabuntuMail.RFC822.MailboxAddress("Other", "other@example.test");
        var imported = new GriabuntuMail.RFC822.MailboxAddress("Provider", "ALIAS@EXAMPLE.TEST");
        this.account.append_sender(other);
        this.account.append_sender(imported);
        list.append(command_row(other));
        list.append(command_row(imported));
        command.redo.begin(null, this.async_completion);
        command.redo.end(async_result());
        assert_equal<int?>(this.account.sender_mailboxes.size, 3);
        assert_equal<int?>(row_count(list), 3);
        assert_true(this.account.sender_mailboxes[1] == alias);
        assert_true(this.account.sender_mailboxes[2] == other);
        assert_true(list.get_first_child().get_next_sibling() == original_row);
        assert_equal(this.account.get_sender_signature(alias), "Local signature");
    }

    public void service_config_v1() throws GLib.Error {
        // take a copy before updating the service info so we don't
        // also copy the test data
        GriabuntuMail.AccountInformation copy = new GriabuntuMail.AccountInformation.copy(
            this.account
        );

        this.account.outgoing.host = "blarg";
        this.account.outgoing.port = 1234;
        this.account.outgoing.transport_security = GriabuntuMail.TlsNegotiationMethod.NONE;
        this.account.outgoing.credentials = new GriabuntuMail.Credentials(
            GriabuntuMail.Credentials.Method.PASSWORD, "testerson"
        );
        this.account.outgoing.credentials_requirement =
            GriabuntuMail.Credentials.Requirement.NONE;
        Accounts.ServiceConfigV1 config = new Accounts.ServiceConfigV1();
        GriabuntuMail.ConfigFile file =
            new GriabuntuMail.ConfigFile(this.tmp.get_child("config.ini"));

        config.save(this.account, this.account.outgoing, file);
        config.load(file, copy, copy.outgoing);

        assert_true(this.account.outgoing.equal_to(copy.outgoing));
    }

    public void service_config_legacy() throws GLib.Error {
        // take a copy before updating the service info so we don't
        // also copy the test data
        GriabuntuMail.AccountInformation copy = new GriabuntuMail.AccountInformation.copy(
            this.account
        );

        this.account.outgoing.host = "blarg";
        this.account.outgoing.port = 1234;
        this.account.outgoing.transport_security = GriabuntuMail.TlsNegotiationMethod.NONE;
        this.account.outgoing.credentials = new GriabuntuMail.Credentials(
            GriabuntuMail.Credentials.Method.PASSWORD, "testerson"
        );
        this.account.outgoing.credentials_requirement =
            GriabuntuMail.Credentials.Requirement.NONE;
        Accounts.ServiceConfigLegacy config = new Accounts.ServiceConfigLegacy();
        GriabuntuMail.ConfigFile file =
            new GriabuntuMail.ConfigFile(this.tmp.get_child("config.ini"));

        config.save(this.account, this.account.outgoing, file);
        config.load(file, copy, copy.outgoing);

        assert_true(this.account.outgoing.equal_to(copy.outgoing));
    }

    private void delete(File parent) throws GLib.Error {
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
