/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md. */
/* New downstream file: 2026-10-26. GPL-3.0-only; see COPYING. */
/* Licensed under GPL-3.0-only. See COPYING. */

/** Real notification handler driven solely by synthetic folder signals. */
public class Application.NotificationPluginContextTest : TestCase {
    private Client client;
    private PluginManager.PluginGlobals globals;
    private NotificationPluginContext context;
    private Mock.Account account;
    private Mock.Folder folder;
    private Plugin.Folder plugin_folder;
    private GriabuntuMail.EmailIdentifier first;
    private GriabuntuMail.EmailIdentifier second;
    private Gee.Set<GriabuntuMail.EmailIdentifier> seen;
    private int retired;

    public NotificationPluginContextTest() {
        base("Application.NotificationPluginContextTest");
        add_test("unread_star_added_stays_new", unread_star_added_stays_new);
        add_test("unread_star_removed_stays_new", unread_star_removed_stays_new);
        add_test("unread_other_flag_stays_new", unread_other_flag_stays_new);
        add_test("read_retires_only_read", read_retires_only_read);
        add_test("deleted_unread_retires_only_deleted", deleted_unread_retires_only_deleted);
        add_test("removed_retires_only_removed", removed_retires_only_removed);
        add_test("mixed_flags_retire_only_read_or_deleted", mixed_flags_retire_only_read_or_deleted);
        add_test("flags_do_not_promote_old_unread", flags_do_not_promote_old_unread);
        add_test("visible_folder_policy_unchanged", visible_folder_policy_unchanged);
        add_test("visible_recent_clears_session_new", visible_recent_clears_session_new);
    }

    public override void set_up() {
        var info = new GriabuntuMail.AccountInformation(
            "synthetic", GriabuntuMail.ServiceProvider.OTHER,
            new Mock.CredentialsMediator(),
            new GriabuntuMail.RFC822.MailboxAddress(null, "fixture@example.test")
        );
        this.account = new Mock.Account(info);
        this.folder = new Mock.Folder(
            this.account, null,
            new GriabuntuMail.FolderRoot("#synthetic", false).get_child("Inbox"),
            INBOX, null
        );
        this.client = new Client();
        this.globals = new PluginManager.PluginGlobals();
        this.globals.folders.folder = new FolderStoreFactory.FolderImpl(this.folder);
        this.plugin_folder = this.globals.folders.folder;
        this.context = new NotificationPluginContext(
            this.client, this.globals, new PluginManager.PluginContext()
        );
        this.context.start_monitoring_folder(this.plugin_folder);
        this.first = new Mock.EmailIdentifer(1);
        this.second = new Mock.EmailIdentifer(2);
        this.seen = new Gee.HashSet<GriabuntuMail.EmailIdentifier>();
        this.retired = 0;
        this.context.email_seen.connect((source, ids) => {
            foreach (var id in ids) this.seen.add(((EmailStoreFactory.IdImpl) id).backing);
        });
        this.context.new_messages_retired.connect((source, total) => this.retired++);
    }

    public override void tear_down() throws GLib.Error {
        this.context.destroy();
        this.folder.assert_expectations();
        this.account.assert_expectations();
    }

    private void append_new(bool first_starred = false) throws GLib.Error {
        var one = new GriabuntuMail.Email(this.first);
        var flags = new GriabuntuMail.EmailFlags.with(GriabuntuMail.EmailFlags.UNREAD);
        if (first_starred) flags.add(GriabuntuMail.EmailFlags.FLAGGED);
        one.set_flags(flags);
        var two = new GriabuntuMail.Email(this.second);
        two.set_flags(new GriabuntuMail.EmailFlags.with(GriabuntuMail.EmailFlags.UNREAD));
        this.folder.expect_call("list_email_by_sparse_id_async")
            .returns_object(new Gee.ArrayList<GriabuntuMail.Email>.wrap({one, two}));
        this.folder.email_locally_appended(
            new Gee.ArrayList<GriabuntuMail.EmailIdentifier>.wrap({this.first, this.second})
        );
        // Complete the mock async listing; no server or application is running.
        while (this.main_loop.pending()) this.main_loop.iteration(false);
        assert_counts(2);
    }

    private void assert_counts(int expected) throws GLib.Error {
        assert_equal<int?>(this.client.tray.total, expected, "tray session-new count");
        assert_equal<int?>(this.context.get_new_message_count(this.plugin_folder), expected,
                           "folder session-new count");
        assert_equal<int?>(this.context.total_new_messages, expected,
                           "total session-new count");
    }

    private void assert_tray_contains(GriabuntuMail.EmailIdentifier id, bool expected)
        throws GLib.Error {
        var target = new EmailStoreFactory.IdImpl(id).to_variant().print(false);
        bool found = false;
        foreach (var entry in this.client.tray.latest()) {
            if (entry.target.print(false) == target) found = true;
        }
        assert_equal<bool?>(found, expected, "tray target membership");
    }

    private void change(GriabuntuMail.EmailIdentifier id, GriabuntuMail.EmailFlags flags) {
        var updates = new Gee.HashMap<GriabuntuMail.EmailIdentifier,GriabuntuMail.EmailFlags>();
        updates.set(id, flags);
        this.folder.email_flags_changed(updates);
    }

    private void assert_unread_update_keeps_new(GriabuntuMail.EmailFlags flags) throws GLib.Error {
        append_new();
        change(this.first, flags);
        assert_counts(2);
        assert_tray_contains(this.first, true);
        assert_tray_contains(this.second, true);
        assert_true(this.retired == 0);
        assert_true(this.seen.is_empty);
    }

    public void unread_star_added_stays_new() throws GLib.Error {
        assert_unread_update_keeps_new(new GriabuntuMail.EmailFlags.with(
            GriabuntuMail.EmailFlags.UNREAD, GriabuntuMail.EmailFlags.FLAGGED
        ));
    }

    public void unread_star_removed_stays_new() throws GLib.Error {
        // The synthetic arrival is already starred, so this isolates star-off.
        append_new(true);
        change(this.first, new GriabuntuMail.EmailFlags.with(GriabuntuMail.EmailFlags.UNREAD));
        assert_counts(2);
        assert_tray_contains(this.first, true);
        assert_true(this.retired == 0);
        assert_true(this.seen.is_empty);
    }

    public void unread_other_flag_stays_new() throws GLib.Error {
        assert_unread_update_keeps_new(new GriabuntuMail.EmailFlags.with(
            GriabuntuMail.EmailFlags.UNREAD, GriabuntuMail.EmailFlags.LOAD_REMOTE_IMAGES
        ));
    }

    public void read_retires_only_read() throws GLib.Error {
        append_new();
        change(this.first, new GriabuntuMail.EmailFlags());
        assert_counts(1);
        assert_tray_contains(this.first, false);
        assert_tray_contains(this.second, true);
        assert_true(this.retired == 1);
        assert_true(this.seen.size == 1 && this.seen.contains(this.first));
        change(this.first, new GriabuntuMail.EmailFlags());
        assert_counts(1);
        assert_true(this.retired == 1);
    }

    public void deleted_unread_retires_only_deleted() throws GLib.Error {
        append_new();
        change(this.first, new GriabuntuMail.EmailFlags.with(
            GriabuntuMail.EmailFlags.UNREAD, GriabuntuMail.EmailFlags.DELETED
        ));
        assert_counts(1);
        assert_tray_contains(this.first, false);
        assert_tray_contains(this.second, true);
        assert_true(this.retired == 1);
    }

    public void removed_retires_only_removed() throws GLib.Error {
        append_new();
        this.folder.email_removed(
            new Gee.ArrayList<GriabuntuMail.EmailIdentifier>.wrap({this.first})
        );
        assert_counts(1);
        assert_tray_contains(this.first, false);
        assert_tray_contains(this.second, true);
        assert_true(this.retired == 1);
        assert_true(this.seen.size == 1 && this.seen.contains(this.first));
    }

    public void mixed_flags_retire_only_read_or_deleted() throws GLib.Error {
        append_new();
        var updates = new Gee.HashMap<GriabuntuMail.EmailIdentifier,GriabuntuMail.EmailFlags>();
        updates.set(this.first, new GriabuntuMail.EmailFlags.with(
            GriabuntuMail.EmailFlags.UNREAD, GriabuntuMail.EmailFlags.FLAGGED
        ));
        updates.set(this.second, new GriabuntuMail.EmailFlags());
        var historical = new Mock.EmailIdentifer(99);
        updates.set(historical, new GriabuntuMail.EmailFlags.with(
            GriabuntuMail.EmailFlags.UNREAD, GriabuntuMail.EmailFlags.DELETED
        ));
        this.folder.email_flags_changed(updates);
        assert_counts(1);
        assert_tray_contains(this.first, true);
        assert_tray_contains(this.second, false);
        assert_true(this.retired == 1);
        assert_true(this.seen.contains(this.second));
        assert_false(this.seen.contains(this.first));
    }

    public void flags_do_not_promote_old_unread() throws GLib.Error {
        assert_counts(0);
        change(new Mock.EmailIdentifer(99), new GriabuntuMail.EmailFlags.with(
            GriabuntuMail.EmailFlags.UNREAD, GriabuntuMail.EmailFlags.FLAGGED
        ));
        assert_counts(0);
        append_new();
        change(this.first, new GriabuntuMail.EmailFlags());
        // Re-unreading / un-deleting is not a new arrival in this session.
        change(this.first, new GriabuntuMail.EmailFlags.with(GriabuntuMail.EmailFlags.UNREAD));
        assert_counts(1);
        assert_tray_contains(this.first, false);
        assert_tray_contains(this.second, true);
        assert_true(this.retired == 1);
    }

    public void visible_recent_clears_session_new() throws GLib.Error {
        append_new();
        var visible = new Gee.HashSet<GriabuntuMail.App.Conversation>();
        this.context.clear_new_messages(this.folder, visible);
        assert_counts(2);
        var conversation = new GriabuntuMail.App.Conversation(this.folder);
        var email = new GriabuntuMail.Email(this.first);
        email.set_flags(new GriabuntuMail.EmailFlags.with(GriabuntuMail.EmailFlags.UNREAD));
        conversation.add(email, GriabuntuMail.Collection.single(this.folder.path));
        visible.add(conversation);
        // Existing policy clears ALL session-new IDs once a recent one is seen,
        // even though both messages remain unread. Do not make this unread-total.
        this.context.clear_new_messages(this.folder, visible);
        assert_counts(0);
        assert_true(email.email_flags.is_unread());
        change(this.first, new GriabuntuMail.EmailFlags.with(
            GriabuntuMail.EmailFlags.UNREAD, GriabuntuMail.EmailFlags.FLAGGED
        ));
        assert_counts(0);
    }

    public void visible_folder_policy_unchanged() throws GLib.Error {
        append_new();
        assert_true(this.context.should_notify_new_messages(this.plugin_folder));
        var window = new MainWindow();
        this.client.last_active_main_window = window;
        window.selected_folder = this.folder;
        window.is_active = true;
        assert_false(this.context.should_notify_new_messages(this.plugin_folder));
        window.conversation_list_view.scrolled_window.vadjustment.value = 1.0;
        assert_true(this.context.should_notify_new_messages(this.plugin_folder));
        window.conversation_list_view.scrolled_window.vadjustment.value = 0.0;
        window.is_active = false;
        assert_true(this.context.should_notify_new_messages(this.plugin_folder));
        assert_counts(2);
    }
}
