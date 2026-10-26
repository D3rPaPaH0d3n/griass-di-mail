/* Private downstream tests, 2026-10-26. LGPL-2.1-or-later; see COPYING. */

[DBus (name = "org.gtk.Notifications")]
public class Application.NotificationTestSink : GLib.Object {
    public GLib.HashTable<string, GLib.Variant>? received = null;
    public void add_notification(string app_id, string id,
                                 GLib.HashTable<string, GLib.Variant> notification)
        throws GLib.Error {
        this.received = notification;
    }
    public void remove_notification(string app_id, string id) throws GLib.Error {}
}

public class Application.NotificationActionsTest : TestCase {
    /** Desktop fixture: all callbacks only print; no Client or mail store exists. */
    public static int run_fixture() {
        var app = new GLib.Application("net.donnybeelo.Convey.NotificationFixture", FLAGS_NONE);
        GLib.Intl.setlocale(LocaleCategory.ALL, "");
        GLib.Intl.bindtextdomain(Config.GETTEXT_PACKAGE, "/app/share/locale");
        GLib.Intl.textdomain(Config.GETTEXT_PACKAGE);
        string[] names = {Action.Application.NOTIFICATION_REPLY,
                          Action.Application.NOTIFICATION_ARCHIVE,
                          Action.Application.NOTIFICATION_TRASH};
        foreach (string name in names) {
            var action = new GLib.SimpleAction(name, new GLib.VariantType(NotificationActions.TARGET_TYPE));
            action.activate.connect((source, target) => {
                GLib.stdout.printf("FIXTURE %s — no mail operation\n", source.name);
                GLib.stdout.flush();
            });
            app.add_action(action);
        }
        app.activate.connect(() => {
            app.hold();
            var notice = new GLib.Notification("Convey: synthetischer Aktionstest");
            notice.set_body("Keine echte Mail – alle drei Buttons sind gefahrlos.");
            NotificationActions.add_buttons(notice, make_target());
            app.send_notification("synthetic-actions", notice);
            GLib.Timeout.add_seconds(90, () => {
                app.withdraw_notification("synthetic-actions");
                app.release();
                return false;
            });
        });
        return app.run({"convey-notification-fixture"});
    }

    private class MovableFolder : Mock.Folder, Convey.FolderSupport.Move {
        public int moves = 0;
        public Convey.EmailIdentifier? moved = null;
        public Convey.FolderPath? destination = null;
        public bool fail_move = false;
        public MovableFolder(Convey.Account account, Convey.FolderPath path) {
            base(account, null, path, INBOX, null);
        }
        public async Convey.Revokable? move_email_async(
            Gee.Collection<Convey.EmailIdentifier> ids, Convey.FolderPath path,
            GLib.Cancellable? cancellable = null) throws GLib.Error {
            this.moves++;
            assert(ids.size == 1);
            this.moved = Convey.Collection.first(ids);
            this.destination = path;
            if (this.fail_move) throw new GLib.IOError.FAILED("Synthetic move error");
            return null;
        }
    }

    public NotificationActionsTest() {
        base("Application.NotificationActionsTest");
        add_test("round_trip_account_and_source", round_trip_account_and_source);
        add_test("malformed_targets_rejected", malformed_targets_rejected);
        add_test("cross_account_rejected", cross_account_rejected);
        add_test("invalid_engine_ids_rejected", invalid_engine_ids_rejected);
        add_test("three_buttons_on_wire", three_buttons_on_wire);
        add_test("invalid_target_has_no_buttons", invalid_target_has_no_buttons);
        add_test("exact_source_present", exact_source_present);
        add_test("stale_source_rejected", stale_source_rejected);
        add_test("different_mail_rejected", different_mail_rejected);
        add_test("unsafe_source_rejected", unsafe_source_rejected);
        add_test("source_open_failure", source_open_failure);
        add_test("source_lookup_failure_closes", source_lookup_failure_closes);
        add_test("cancelled_source_not_opened", cancelled_source_not_opened);
        add_test("trash_moves_only_single_mail", trash_moves_only_single_mail);
        add_test("archive_moves_only_single_mail", archive_moves_only_single_mail);
        add_test("cross_account_move_rejected", cross_account_move_rejected);
        add_test("unsafe_destination_rejected", unsafe_destination_rejected);
        add_test("move_failure_closes_source", move_failure_closes_source);
    }

    private static GLib.Variant make_target(string email_account = "one",
                                            string folder_account = "one",
                                            int64 row = 42, int64 uid = 7) {
        var raw = new GLib.Variant("(y(xx))", (uchar) 'i', row, uid);
        var path = new Convey.FolderRoot("#imap", false).get_child("INBOX");
        return NotificationActions.target(
            new GLib.Variant("(sv)", email_account, raw),
            new GLib.Variant("(sv)", folder_account, path.to_variant())
        );
    }

    private void rejects(GLib.Variant? target) throws GLib.Error {
        GLib.Variant? email, folder;
        assert_false(NotificationActions.parse(target, out email, out folder));
        assert_null(email);
        assert_null(folder);
    }

    public void round_trip_account_and_source() throws GLib.Error {
        var target = make_target();
        GLib.Variant? email, folder;
        assert_true(NotificationActions.parse(target, out email, out folder));
        assert_equal(target.get_type_string(), NotificationActions.TARGET_TYPE);
        assert_equal(email.get_child_value(0).get_string(), "one");
        assert_true(folder.equal(target.get_child_value(1)));
    }
    public void malformed_targets_rejected() throws GLib.Error {
        rejects(null);
        rejects(new GLib.Variant.string("bad"));
        rejects(new GLib.Variant("((sv)(sv))", "one", new GLib.Variant.string("bad"),
                                 "one", new GLib.Variant.string("bad")));
    }
    public void cross_account_rejected() throws GLib.Error {
        rejects(make_target("one", "two"));
        rejects(make_target("", ""));
    }
    public void invalid_engine_ids_rejected() throws GLib.Error {
        rejects(make_target("one", "one", 0));
        rejects(make_target("one", "one", 42, 0));
        rejects(make_target("one", "one", 42, -2));
        rejects(make_target("one", "one", 42, 4294967296));
    }

    private GLib.HashTable<string, GLib.Variant> send_to_sink(GLib.Notification notice)
        throws GLib.Error {
        var bus = GLib.Bus.get_sync(SESSION);
        var sink = new NotificationTestSink();
        uint object = bus.register_object("/org/gtk/Notifications", sink);
        bool name_acquired = false;
        uint name = GLib.Bus.own_name_on_connection(bus, "org.gtk.Notifications", NONE,
                                                   () => { name_acquired = true; });
        bool expired = false;
        uint timer = GLib.Timeout.add_seconds(5, () => { expired = true; return false; });
        while (!name_acquired && !expired) this.main_loop.iteration(true);
        var app = new GLib.Application("net.donnybeelo.Convey.NotificationTest", NON_UNIQUE);
        app.register();
        app.send_notification("synthetic", notice);
        while (sink.received == null && !expired) this.main_loop.iteration(true);
        if (!expired) GLib.Source.remove(timer);
        GLib.Bus.unown_name(name);
        bus.unregister_object(object);
        assert_non_null(sink.received, "synthetic notification delivered on private bus");
        return sink.received;
    }
    public void three_buttons_on_wire() throws GLib.Error {
        var target = make_target();
        var notice = new GLib.Notification("Synthetic mail");
        NotificationActions.add_buttons(notice, target);
        var data = send_to_sink(notice);
        var buttons = data.lookup("buttons");
        assert_non_null(buttons);
        assert_true(buttons.n_children() == 3);
        string[] actions = {"app.notification-reply", "app.notification-archive", "app.notification-trash"};
        for (int i = 0; i < 3; i++) {
            var button = buttons.get_child_value(i);
            assert_equal(button.lookup_value("action", GLib.VariantType.STRING).get_string(), actions[i]);
            assert_true(button.lookup_value("target", null).equal(target));
        }
    }
    public void invalid_target_has_no_buttons() throws GLib.Error {
        var notice = new GLib.Notification("Synthetic summary");
        NotificationActions.add_buttons(notice, new GLib.Variant.string("invalid"));
        assert_null(send_to_sink(notice).lookup("buttons"));
    }

    private Mock.Folder source(Convey.Folder.SpecialUse use = INBOX) {
        return new Mock.Folder(null, null,
            new Convey.FolderRoot("#test", false).get_child("INBOX"), use, null);
    }
    private void check(Mock.Folder folder, GLib.Cancellable? cancel = null) throws GLib.Error {
        NotificationActions.check_source.begin(folder, new Mock.EmailIdentifer(42), cancel,
                                                this.async_completion);
        NotificationActions.check_source.end(async_result());
    }
    private void expect_present(Mock.Folder folder, int row = 42) {
        folder.expect_call("open_async");
        folder.expect_call("contains_identifiers").returns_object(
            new Gee.ArrayList<Convey.EmailIdentifier>.wrap({new Mock.EmailIdentifer(row)})
        );
        folder.expect_call("close_async");
    }
    public void exact_source_present() throws GLib.Error {
        var folder = source();
        expect_present(folder);
        check(folder);
        folder.assert_expectations();
    }
    public void stale_source_rejected() throws GLib.Error {
        var folder = source();
        folder.expect_call("open_async");
        folder.expect_call("contains_identifiers");
        folder.expect_call("close_async");
        try { check(folder); assert_not_reached(); }
        catch (Convey.EngineError.NOT_FOUND error) {}
        folder.assert_expectations();
    }
    public void different_mail_rejected() throws GLib.Error {
        var folder = source();
        expect_present(folder, 99);
        try { check(folder); assert_not_reached(); }
        catch (Convey.EngineError.NOT_FOUND error) {}
        folder.assert_expectations();
    }
    public void unsafe_source_rejected() throws GLib.Error {
        var folder = source(TRASH);
        try { check(folder); assert_not_reached(); }
        catch (Convey.EngineError.BAD_PARAMETERS error) {}
        folder.assert_expectations();
    }
    public void source_open_failure() throws GLib.Error {
        var folder = source();
        folder.expect_call("open_async").throws(new GLib.IOError.FAILED("Synthetic failure"));
        try { check(folder); assert_not_reached(); }
        catch (GLib.IOError.FAILED error) {}
        folder.assert_expectations();
    }
    public void source_lookup_failure_closes() throws GLib.Error {
        var folder = source();
        folder.expect_call("open_async");
        folder.expect_call("contains_identifiers").throws(new GLib.IOError.FAILED("Synthetic failure"));
        folder.expect_call("close_async");
        try { check(folder); assert_not_reached(); }
        catch (GLib.IOError.FAILED error) {}
        folder.assert_expectations();
    }
    public void cancelled_source_not_opened() throws GLib.Error {
        var folder = source();
        var cancel = new GLib.Cancellable();
        cancel.cancel();
        try { check(folder, cancel); assert_not_reached(); }
        catch (GLib.IOError.CANCELLED error) {}
        folder.assert_expectations();
    }

    private Mock.Account account(string id) {
        return new Mock.Account(new Convey.AccountInformation(id, Convey.ServiceProvider.OTHER,
            new Mock.CredentialsMediator(), new Convey.RFC822.MailboxAddress(null, "fixture@example.test")));
    }
    private void move(Convey.Folder.SpecialUse use, bool fail = false) throws GLib.Error {
        var owner = account("one");
        var root = new Convey.FolderRoot("#test", false);
        var folder = new MovableFolder(owner, root.get_child("INBOX"));
        var dest = new Mock.Folder(owner, null, root.get_child("Destination"), use, null);
        var commands = new CommandStack();
        expect_present(folder);
        folder.expect_call("open_async");
        folder.expect_call("close_async");
        folder.fail_move = fail;
        NotificationActions.move_message.begin(folder, dest, new Mock.EmailIdentifer(42), commands,
                                                new GLib.Cancellable(), this.async_completion);
        try {
            NotificationActions.move_message.end(async_result());
            assert_false(fail);
        } catch (GLib.IOError.FAILED error) { assert_true(fail); }
        assert_true(folder.moves == 1);
        assert_true(folder.moved.equal_to(new Mock.EmailIdentifer(42)));
        assert_true(folder.destination.equal_to(dest.path));
        folder.assert_expectations();
        owner.assert_expectations();
    }
    public void trash_moves_only_single_mail() throws GLib.Error { move(TRASH); }
    public void archive_moves_only_single_mail() throws GLib.Error { move(ARCHIVE); move(ALL_MAIL); }
    public void move_failure_closes_source() throws GLib.Error { move(TRASH, true); }
    private void reject_move(bool cross_account) throws GLib.Error {
        var owner = account("one");
        var root = new Convey.FolderRoot("#test", false);
        var folder = new MovableFolder(owner, root.get_child("INBOX"));
        var dest = new Mock.Folder(cross_account ? account("two") : owner, null,
            root.get_child("Destination"), cross_account ? Convey.Folder.SpecialUse.TRASH : Convey.Folder.SpecialUse.SENT, null);
        NotificationActions.move_message.begin(folder, dest, new Mock.EmailIdentifer(42),
            new CommandStack(), new GLib.Cancellable(), this.async_completion);
        try { NotificationActions.move_message.end(async_result()); assert_not_reached(); }
        catch (Convey.EngineError.BAD_PARAMETERS error) {}
        assert_true(folder.moves == 0);
        folder.assert_expectations();
    }
    public void cross_account_move_rejected() throws GLib.Error { reject_move(true); }
    public void unsafe_destination_rejected() throws GLib.Error { reject_move(false); }
}
