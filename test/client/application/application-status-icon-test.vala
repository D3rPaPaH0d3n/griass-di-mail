/* New downstream file: 2026-10-26. LGPL-2.1-or-later; see COPYING. */
/* Licensed under LGPL-2.1-or-later. See COPYING. */
public class Application.StatusIconTest : TestCase {
    /** Synthetic D-Bus endpoint: no GTK, application, accounts or mail IO. */
    public static int run_fixture() {
        var loop = new GLib.MainLoop();
        StatusIcon? tray = null;
        string name = "net.donnybeelo.Convey.TrayFixture";
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

    public StatusIconTest() {
        base("Application.StatusIconTest");
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
        add_test("mail_click_target_and_literal_label", mail_click_target_and_literal_label);
        add_test("menu_refresh_only_on_change", menu_refresh_only_on_change);
        add_test("new_mail_counter_label", new_mail_counter_label);
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
        assert_equal(item.tool_tip.title, "Convey");
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
        item.set_new_mail_count(3);
        assert_equal(item.x_ayatana_label, "3");
        item.set_new_mail_count(1002);
        assert_equal(item.x_ayatana_label, "999+");
        item.set_new_mail_count(-1);
        assert_equal(item.x_ayatana_label, "");
        assert_equal(item.title, "Convey");
    }
}
