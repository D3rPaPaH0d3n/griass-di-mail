/* Downstream modification: 2026-10-28 — assert the owner-selected display name. */
/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md. */
/* New downstream file: 2026-10-26. GPL-3.0-only; see COPYING. */
/* Licensed under GPL-3.0-only. See COPYING. */
public class Application.StatusIconTest : TestCase {
    /** Synthetic D-Bus endpoint: no GTK, application, accounts or mail IO. */
    public static int run_fixture() {
        var loop = new GLib.MainLoop();
        StatusIcon? tray = null;
        string name = "io.github.d3rpapah0d3n.GriabuntuMail.TrayFixture";
        uint owner = GLib.Bus.own_name(SESSION, name, NONE, (connection) => {
            try {
                tray = new StatusIcon(connection, name);
                tray.item.open_requested.connect((token) => {
                    GLib.stdout.printf("OPEN\n"); GLib.stdout.flush();
                });
                tray.item.compose_requested.connect(() => {
                    GLib.stdout.printf("COMPOSE\n"); GLib.stdout.flush();
                });
                tray.item.quit_requested.connect(() => {
                    GLib.stdout.printf("QUIT\n"); GLib.stdout.flush();
                    loop.quit();
                });
                var first = mail_target("account-a", "one");
                var second = mail_target("account-b", "two");
                tray.item.email_requested.connect((target) => {
                    GLib.stdout.printf("MAIL\n"); GLib.stdout.flush();
                    tray.new_mail.set_folder("fixture", {second});
                });
                uint64 generation = tray.new_mail.set_folder("fixture", {first, second});
                tray.new_mail.set_details("fixture", generation, first,
                    "First <first@example.test>", "Synthetic message one", 1);
                tray.new_mail.set_details("fixture", generation, second,
                    "Second <second@example.test>", "Synthetic message two", 2);
            } catch (GLib.Error error) {
                GLib.stderr.printf("%s\n", error.message);
                loop.quit();
            }
        });
        loop.run();
        if (tray != null) tray.close();
        GLib.Bus.unown_name(owner);
        return 0;
    }

    // Isolated bus fixture for test/panel-badge.py; no GTK or mail IO.
    private class Counts : Mock.FolderPoperties {
        internal void update(int unread, int total) {
            this.email_total = total;
            this.email_unread = unread;
        }
    }

    private static FolderContext inbox(string id, int unread, int total) {
        var account = new Mock.Account(new GriabuntuMail.AccountInformation(id,
            GriabuntuMail.ServiceProvider.OTHER, new Mock.CredentialsMediator(),
            new GriabuntuMail.RFC822.MailboxAddress(null, "fixture@example.test")));
        var p = new Counts();
        p.update(unread, total);
        return new FolderContext(new Mock.Folder(account, p,
            new GriabuntuMail.FolderRoot("#test", false).get_child("Inbox"), INBOX, null));
    }

    public static int run_badge_fixture() throws GLib.Error {
        GriabuntuMail.RFC822.init();
        var loop = new GLib.MainLoop();
        var entry = new FolderList.AllInboxesEntry();
        var sidebar = new FolderList.AllInboxesBranch(entry);
        var a = inbox("a", 23, 100);
        var b = inbox("b", 6, 12);
        var c = inbox("c", 2, 90);
        entry.add_inbox(a); entry.add_inbox(b); entry.add_inbox(c);
        var conn = GLib.Bus.get_sync(SESSION);
        var name = "org.example.GriassdiBadgeFixture";
        var tray = new StatusIcon(conn, name, null, entry);
        int step = 0;
        tray.item.open_requested.connect(() => {
            switch (++step) {
            case 1: ((Counts) a.folder.properties).update(22, 100); break;
            case 2: ((Counts) a.folder.properties).update(23, 100); break;
            case 3: b.displayed_count = TOTAL; break;
            case 4: b.displayed_count = NONE; break;
            case 5: entry.remove_inbox(c.folder.account); break;
            case 6: ((Counts) c.folder.properties).update(80, 90); break;
            case 7: entry.add_inbox(b); break; // unchanged, not counted twice
            case 8: tray.new_mail.set_folder("recent", {mail_target("a", "one")}); break;
            case 9: entry.remove_inbox(a.folder.account, a); break;
            case 10: entry.add_inbox(c); break;
            case 11: c.displayed_count = TOTAL; break;
            case 12: ((Counts) c.folder.properties).update(80, 1002); break;
            }
            int count = sidebar.get_inboxes_entry().get_count();
            GLib.assert(tray.item.x_ayatana_label == (count > 0 ? count.to_string() : ""));
        });
        uint owner = GLib.Bus.own_name_on_connection(conn, name, NONE);
        loop.run();
        tray.close(); GLib.Bus.unown_name(owner);
        return 0;
    }

    public StatusIconTest() {
        base("Application.StatusIconTest");
        add_test("hydrate_sparse_tray_and_refresh_labels", hydrate_sparse_tray_and_refresh_labels);
        add_test("stable_menu_layout", stable_menu_layout);
        add_test("property_filter_and_invalid_ids", property_filter_and_invalid_ids);
        add_test("only_valid_clicks_activate", only_valid_clicks_activate);
        add_test("group_events_and_static_layout", group_events_and_static_layout);
        add_test("activation_token_consumed_once", activation_token_consumed_once);
        add_test("status_and_icon_identity", status_and_icon_identity);
        add_test("new_mail_deduplicated_and_account_scoped", new_mail_deduplicated_and_account_scoped);
        add_test("retired_folders_remove_only_their_mail", retired_folders_remove_only_their_mail);
        add_test("late_metadata_and_stale_menu_ids", late_metadata_and_stale_menu_ids);
        add_test("latest_five_and_stable_ids", latest_five_and_stable_ids);
        add_test("partial_metadata_does_not_displace_dated_mail", partial_metadata_does_not_displace_dated_mail);
        add_test("mail_click_target_and_literal_label", mail_click_target_and_literal_label);
        add_test("menu_refresh_only_on_change", menu_refresh_only_on_change);
        add_test("new_mail_counter_label", new_mail_counter_label);
        add_test("shared_model_initial_state_and_updates", shared_model_initial_state_and_updates);
        add_test("dock_icon_changes_and_cleans_own_launcher", dock_icon_changes_and_cleans_own_launcher);
        add_test("dock_preserves_existing_user_launcher", dock_preserves_existing_user_launcher);
        add_test("dock_preserves_edits_during_session", dock_preserves_edits_during_session);
    }

    private class MetadataFolder : Mock.Folder {
        internal int calls = 0;
        internal bool metadata_only = true;
        internal MetadataFolder() {
            base(null, null, new GriabuntuMail.FolderRoot("#test", false).get_child("Inbox"), INBOX, null);
        }
        public override async Gee.List<GriabuntuMail.Email>? list_email_by_sparse_id_async(
            Gee.Collection<GriabuntuMail.EmailIdentifier> ids, GriabuntuMail.Email.Field fields,
            GriabuntuMail.Folder.ListFlags flags, GLib.Cancellable? cancellable = null) throws GLib.Error {
            metadata_only = metadata_only && fields == (GriabuntuMail.Email.Field.SUBJECT |
                GriabuntuMail.Email.Field.ORIGINATORS | GriabuntuMail.Email.Field.PROPERTIES) &&
                flags == (calls == 0 ? GriabuntuMail.Folder.ListFlags.LOCAL_ONLY : GriabuntuMail.Folder.ListFlags.NONE);
            calls++;
            return yield base.list_email_by_sparse_id_async(ids, fields, flags, cancellable);
        }
    }

    public void hydrate_sparse_tray_and_refresh_labels() throws GLib.Error {
        string address;
        var bus = start_private_bus(out address);
        var connection = new GLib.DBusConnection.for_address_sync(address,
            GLib.DBusConnectionFlags.AUTHENTICATION_CLIENT |
            GLib.DBusConnectionFlags.MESSAGE_BUS_CONNECTION, null, null);
        var tray = new StatusIcon(connection, "org.example.SyntheticMail");
        try {
            var folder = new MetadataFolder();
            var targets = new Gee.HashMap<GriabuntuMail.EmailIdentifier,GLib.Variant>();
            for (int i = 1; i <= 6; i++) targets.set(new Mock.EmailIdentifer(i), mail_target("a", i.to_string()));
            var hit = new GriabuntuMail.Email(new Mock.EmailIdentifer(6));
            hit.set_message_subject(new GriabuntuMail.RFC822.Subject("Cached"));
            hit.set_email_properties(new Mock.EmailProperties(new GLib.DateTime.from_unix_utc(5)));
            var miss = new GriabuntuMail.Email(new Mock.EmailIdentifer(5));
            miss.set_originators(new GriabuntuMail.RFC822.MailboxAddresses.single(
                new GriabuntuMail.RFC822.MailboxAddress(null, "fixture@example.test")), null, null);
            miss.set_message_subject(new GriabuntuMail.RFC822.Subject("Hydrated"));
            miss.set_email_properties(new Mock.EmailProperties(new GLib.DateTime.from_unix_utc(7)));
            var cache = folder.expect_call("list_email_by_sparse_id_async")
                .returns_object(new Gee.ArrayList<GriabuntuMail.Email>.wrap({hit}));
            var hydrate = folder.expect_call("list_email_by_sparse_id_async")
                .returns_object(new Gee.ArrayList<GriabuntuMail.Email>.wrap({miss}));
            int changes = 0;
            tray.menu.items_properties_updated.connect((updates, removed) => changes++);
            tray.update_new_mail.begin("inbox", folder, targets, this.async_completion);
            tray.update_new_mail.end(async_result());
            folder.assert_expectations();
            assert_true(folder.metadata_only);
            assert_equal<int?>(folder.calls, 2);
            var requested = hydrate.called_arg<Gee.Collection<GriabuntuMail.EmailIdentifier>>(0);
            assert_equal<int?>(cache.called_arg<Gee.Collection<GriabuntuMail.EmailIdentifier>>(0).size, 5);
            assert_equal<int?>(requested.size, 4);
            assert_false(requested.contains(hit.id));
            assert_true(requested.contains(miss.id));
            assert_equal<int?>(tray.new_mail.total, 6);
            var latest = tray.new_mail.latest();
            assert_equal(tray.menu.get_property(latest[0].menu_id, "label").get_string(),
                         "fixture@example.test — Hydrated");
            assert_equal(tray.menu.get_property(latest[1].menu_id, "label").get_string(), "Cached");
            assert_true(changes > 0);
        } finally {
            tray.close();
            try { connection.close_sync(); } catch (GLib.Error e) { warning("Private bus cleanup failed"); }
            stop_private_bus(bus);
        }
    }

    public void stable_menu_layout() throws GLib.Error {
        var menu = new TrayMenu();
        uint revision;
        TrayMenuLayout layout;
        menu.get_layout(0, -1, {}, out revision, out layout);
        assert_true(revision == 1);
        assert_true(layout.id == 0);
        assert_true(layout.children.length == 6);
        assert_equal(layout.children[0].get_type_string(), "(ia{sv}av)");
        assert_true(layout.children[0].get_child_value(0).get_int32() == 1);
        menu.get_layout(0, 0, {}, out revision, out layout);
        assert_true(layout.children.length == 0);
    }

    public void property_filter_and_invalid_ids() throws GLib.Error {
        var menu = new TrayMenu();
        var props = menu.get_group_properties({1, 99, 2}, {"label"});
        assert_true(props.length == 2);
        assert_true(props[0].properties.size() == 1);
        assert_non_null(props[0].properties.lookup("label"));
        assert_null(props[0].properties.lookup("enabled"));
        try {
            menu.get_property(99, "label");
            assert_not_reached();
        } catch (GLib.DBusError.INVALID_ARGS error) {}
    }

    public void only_valid_clicks_activate() throws GLib.Error {
        var menu = new TrayMenu();
        int count = 0;
        menu.selected.connect((id) => count++);
        menu.event(1, "hovered", new GLib.Variant.int32(0), 0);
        menu.event(3, "clicked", new GLib.Variant.int32(0), 0);
        menu.event(99, "clicked", new GLib.Variant.int32(0), 0);
        assert_true(count == 0);
        foreach (int id in new int[] {1, 2, 4})
            menu.event(id, "clicked", new GLib.Variant.int32(0), 0);
        assert_true(count == 3);
    }

    public void group_events_and_static_layout() throws GLib.Error {
        var menu = new TrayMenu();
        TrayMenuEvent valid = {1, "clicked", new GLib.Variant.int32(0), 0};
        TrayMenuEvent invalid = {99, "clicked", new GLib.Variant.int32(0), 0};
        var errors = menu.event_group({valid, invalid});
        assert_true(errors.length == 1);
        assert_true(errors[0] == 99);
        int[] updates;
        menu.about_to_show_group({0, 1, 99}, out updates, out errors);
        assert_true(updates.length == 0);
        assert_true(errors.length == 1);
        assert_false(menu.about_to_show(0));
    }

    public void activation_token_consumed_once() throws GLib.Error {
        var item = new TrayItem();
        string token = "";
        int composed = 0;
        item.open_requested.connect((value) => token = value);
        item.compose_requested.connect(() => composed++);
        item.provide_xdg_activation_token("synthetic-token");
        item.activate(0, 0);
        assert_equal(token, "synthetic-token");
        item.activate(0, 0);
        assert_equal(token, "");
        item.secondary_activate(0, 0);
        assert_true(composed == 1);
    }

    public void status_and_icon_identity() throws GLib.Error {
        var item = new TrayItem();
        assert_equal(item.status, "Active");
        assert_equal(item.icon_name, Config.APP_ID + "-tray");
        assert_equal((string) item.menu, "/StatusNotifierItem/Menu");
        assert_equal(item.tool_tip.title, "Griaß di Mail");
    }

    private static GLib.Variant mail_target(string account, string id) {
        return new GLib.Variant("(sv)", account, new GLib.Variant.string(id));
    }

    public void new_mail_deduplicated_and_account_scoped() throws GLib.Error {
        var model = new TrayMailModel();
        var a = mail_target("a", "same-id");
        var b = mail_target("b", "same-id");
        model.set_folder("a:inbox", {a, a});
        model.set_folder("a:label", {a});
        assert_true(model.total == 1);
        model.set_folder("b:inbox", {b});
        assert_true(model.total == 2);
    }

    public void retired_folders_remove_only_their_mail() throws GLib.Error {
        var model = new TrayMailModel();
        var a = mail_target("a", "one");
        model.set_folder("inbox", {a});
        model.set_folder("label", {a});
        model.set_folder("inbox", {});
        assert_true(model.total == 1);
        model.set_folder("label", {});
        assert_true(model.total == 0);
    }

    public void late_metadata_and_stale_menu_ids() throws GLib.Error {
        var model = new TrayMailModel();
        var target = mail_target("a", "one");
        uint64 old = model.set_folder("inbox", {target});
        int old_id = model.latest()[0].menu_id;
        model.set_folder("inbox", {});
        assert_false(model.set_details("inbox", old, target, "Late", "Late", 1));
        uint64 fresh = model.set_folder("inbox", {target});
        assert_false(model.set_details("inbox", old, target, "Late", "Late", 1));
        assert_true(model.set_details("inbox", fresh, target, "Fresh", "Subject", 1));
        assert_true(model.latest()[0].menu_id > old_id);
    }

    public void latest_five_and_stable_ids() throws GLib.Error {
        var model = new TrayMailModel();
        GLib.Variant[] targets = {};
        for (int i = 0; i < 7; i++) targets += mail_target("a", i.to_string());
        uint64 generation = model.set_folder("inbox", targets);
        for (int i = 0; i < 7; i++)
            model.set_details("inbox", generation, targets[i], "Sender", i.to_string(), i + 1);
        assert_true(model.total == 7);
        assert_true(model.latest().size == 5);
        assert_equal(model.latest()[0].target.print(false), targets[6].print(false));
        int id = model.latest()[0].menu_id;
        model.set_folder("inbox", targets);
        assert_true(model.latest()[0].menu_id == id);
    }

    public void partial_metadata_does_not_displace_dated_mail() throws GLib.Error {
        var model = new TrayMailModel();
        GLib.Variant[] targets = {};
        for (int i = 0; i < 7; i++) targets += mail_target("a", i.to_string());
        uint64 generation = model.set_folder("inbox", targets);
        // The tray loader fetches details for at most five messages per folder.
        for (int i = 2; i < 7; i++)
            model.set_details("inbox", generation, targets[i], "Sender", i.to_string(), i + 1);
        var latest = model.latest();
        assert_true(model.total == 7);
        assert_true(latest.size == 5);
        for (int i = 0; i < 5; i++)
            assert_equal(latest[i].target.print(false), targets[6 - i].print(false));
    }

    public void mail_click_target_and_literal_label() throws GLib.Error {
        var model = new TrayMailModel();
        var menu = new TrayMenu();
        var target = mail_target("account-b", "mail-one");
        uint64 generation = model.set_folder("inbox", {target});
        model.set_details("inbox", generation, target, "Sender_Name", "Line\nbreak", 1);
        var entry = model.latest()[0];
        menu.set_new_mail(model.total, model.latest());
        string selected = "";
        menu.mail_selected.connect((value) => selected = value.print(false));
        menu.event(entry.menu_id, "clicked", new GLib.Variant.int32(0), 0);
        assert_equal(selected, target.print(false));
        assert_true("Sender__Name" in menu.get_property(entry.menu_id, "label").get_string());
        assert_false("\n" in menu.get_property(entry.menu_id, "label").get_string());
        selected = "";
        model.set_folder("inbox", {});
        menu.set_new_mail(0, model.latest());
        menu.event(entry.menu_id, "clicked", new GLib.Variant.int32(0), 0);
        assert_equal(selected, "");
    }

    public void menu_refresh_only_on_change() throws GLib.Error {
        var model = new TrayMailModel();
        var menu = new TrayMenu();
        int signals = 0;
        menu.layout_updated.connect((revision, parent) => signals++);
        model.set_folder("inbox", {mail_target("a", "one")});
        menu.set_new_mail(model.total, model.latest());
        menu.set_new_mail(model.total, model.latest());
        assert_true(signals == 1);
    }

    public void new_mail_counter_label() throws GLib.Error {
        var item = new TrayItem();
        int icon_changes = 0;
        item.new_icon.connect(() => icon_changes++);
        item.set_new_mail_count(3);
        item.set_inbox_count(3);
        assert_equal(item.x_ayatana_label, "3");
        assert_equal(item.icon_name, Config.APP_ID + "-open");
        assert_equal(item.attention_icon_name, item.icon_name);
        item.set_inbox_count(1002);
        assert_equal(item.x_ayatana_label, "1002");
        item.set_inbox_count(-1);
        item.set_new_mail_count(0);
        assert_equal(item.x_ayatana_label, "");
        assert_equal(item.title, "Griaß di Mail");
        assert_equal(item.icon_name, Config.APP_ID + "-tray");
        assert_equal<int?>(icon_changes, 2);
    }

    public void shared_model_initial_state_and_updates() throws GLib.Error {
        string address;
        var bus = start_private_bus(out address);
        GLib.DBusConnection? connection = null;
        StatusIcon? tray = null;
        try {
            connection = new GLib.DBusConnection.for_address_sync(
                address,
                GLib.DBusConnectionFlags.AUTHENTICATION_CLIENT |
                GLib.DBusConnectionFlags.MESSAGE_BUS_CONNECTION, null, null
            );
            var model = new TrayMailModel();
            var target = mail_target("one", "same");
            model.set_folder("inbox", {target});
            model.set_folder("label", {target});
            tray = new StatusIcon(connection, "org.example.SyntheticMail", model);
            assert_true(tray.new_mail == model);
            assert_equal(tray.item.x_ayatana_label, "");
            assert_equal(tray.item.icon_name, Config.APP_ID + "-open");
            model.set_folder("other-account", {mail_target("two", "same")});
            assert_equal(tray.item.x_ayatana_label, "");
            model.set_folder("inbox", {});
            assert_equal(tray.item.x_ayatana_label, "");
            model.set_folder("label", {});
            model.set_folder("other-account", {});
            assert_equal(tray.item.x_ayatana_label, "");
            assert_equal(tray.item.icon_name, Config.APP_ID + "-tray");
            tray.close();
            model.set_folder("later", {target});
            assert_equal<int?>(model.total, 1);
            assert_equal(tray.item.x_ayatana_label, "");
        } finally {
            if (tray != null) tray.close();
            if (connection != null) {
                try { connection.close_sync(); } catch (GLib.Error error) { warning("Private bus cleanup failed"); }
            }
            stop_private_bus(bus);
        }
    }

    private GLib.File dock_fixture(out string source, out string launcher) throws GLib.Error {
        var root = GLib.File.new_for_path(GLib.DirUtils.make_tmp("griass-dock-test-XXXXXX"));
        source = root.get_child("installed.desktop").get_path();
        GLib.FileUtils.set_contents(source,
            "[Desktop Entry]\nType=Application\nName=Synthetic Mail\nExec=true\nIcon=" + Config.APP_ID + "\n"
        );
        string apps = root.get_child("applications").get_path();
        GLib.DirUtils.create_with_parents(apps, 0700);
        launcher = GLib.Path.build_filename(apps, Config.APP_ID + ".desktop");
        return root;
    }

    private string dock_icon_digest(GLib.File root, string launcher) throws GLib.Error {
        var desktop = new GLib.KeyFile();
        desktop.load_from_file(launcher, NONE);
        string icon = GLib.Path.build_filename(root.get_path(), "icons", "hicolor", "64x64", "apps",
            desktop.get_string("Desktop Entry", "Icon") + ".png");
        var pixbuf = new Gdk.Pixbuf.from_file(icon);
        assert_equal<int?>(pixbuf.width, 64);
        assert_equal<int?>(pixbuf.height, 64);
        uint8[] bytes;
        GLib.FileUtils.get_data(icon, out bytes);
        return GLib.Checksum.compute_for_data(GLib.ChecksumType.SHA256, bytes);
    }

    public void dock_icon_changes_and_cleans_own_launcher() throws GLib.Error {
        string source, launcher;
        var root = dock_fixture(out source, out launcher);
        try {
            var dock = new DockIcon(root.get_path(), source);
            assert_true(GLib.FileUtils.test(launcher, EXISTS));
            string closed = dock_icon_digest(root, launcher);
            dock.set_new_mail(true);
            assert_true(closed != dock_icon_digest(root, launcher));
            dock.set_new_mail(false);
            assert_equal(dock_icon_digest(root, launcher), closed);
            dock.close();
            assert_false(GLib.FileUtils.test(launcher, EXISTS));
            assert_true(GLib.FileUtils.test(source, EXISTS));
        } finally {
            try { delete_file(root); } catch (GLib.Error error) { warning("Fixture cleanup failed"); }
        }
    }

    public void dock_preserves_existing_user_launcher() throws GLib.Error {
        string source, launcher;
        var root = dock_fixture(out source, out launcher);
        string custom = "[Desktop Entry]\nType=Application\nName=My Launcher\nExec=custom-command\nIcon=custom-icon\n";
        try {
            GLib.FileUtils.set_contents(launcher, custom);
            var dock = new DockIcon(root.get_path(), source);
            dock.set_new_mail(true);
            dock.close();
            string current;
            GLib.FileUtils.get_contents(launcher, out current);
            assert_equal(current, custom);
        } finally {
            try { delete_file(root); } catch (GLib.Error error) { warning("Fixture cleanup failed"); }
        }
    }

    public void dock_preserves_edits_during_session() throws GLib.Error {
        string source, launcher;
        var root = dock_fixture(out source, out launcher);
        try {
            var dock = new DockIcon(root.get_path(), source);
            dock.set_new_mail(true);
            var changed = new GLib.KeyFile();
            changed.load_from_file(launcher, NONE);
            changed.set_string("Desktop Entry", "Name", "User changed this launcher");
            string edited = changed.to_data();
            GLib.FileUtils.set_contents(launcher, edited);
            // Ordinary state changes and shutdown must both preserve user edits.
            dock.set_new_mail(false);
            dock.close();
            string current;
            GLib.FileUtils.get_contents(launcher, out current);
            assert_equal(current, edited);
        } finally {
            try { delete_file(root); } catch (GLib.Error error) { warning("Fixture cleanup failed"); }
        }
    }
}
