/* New downstream file: 2026-10-28. GPL-3.0-only; see COPYING. */
public class Application.LauncherEntryTest : TestCase {
    public LauncherEntryTest() {
        base("Application.LauncherEntryTest");
        add_test("initial_reset_and_shell_reconnect", initial_reset_and_shell_reconnect);
    }

    private delegate bool Condition();
    private void wait_until(Condition condition) throws GLib.Error {
        var loop = new GLib.MainLoop();
        int remaining = 300;
        GLib.Timeout.add(10, () => {
            if (condition() || --remaining == 0) { loop.quit(); return false; }
            return true;
        });
        loop.run();
        assert_true(condition(), "Launcher update arrived on the private bus");
    }

    public void initial_reset_and_shell_reconnect() throws GLib.Error {
        string address;
        var bus = start_private_bus(out address);
        GLib.DBusConnection? connection = null;
        uint subscribed = 0;
        uint owner = 0;
        UnityLauncherEntry? entry = null;
        try {
            connection = new GLib.DBusConnection.for_address_sync(address,
                GLib.DBusConnectionFlags.AUTHENTICATION_CLIENT |
                GLib.DBusConnectionFlags.MESSAGE_BUS_CONNECTION);
            GLib.Variant? latest = null;
            int updates = 0;
            subscribed = connection.signal_subscribe(null,
                "com.canonical.Unity.LauncherEntry", "Update", "/test/launcher", null,
                NONE, (connection, sender, path, iface, name, args) => {
                    latest = args.get_child_value(1);
                    updates++;
                });
            entry = new UnityLauncherEntry(connection, "/test/launcher", "synthetic.desktop");
            wait_until(() => updates >= 1);
            assert_equal<int64?>(latest.lookup_value("count", null).get_int64(), 0);
            assert_false(latest.lookup_value("count-visible", null).get_boolean());
            entry.set_count(5);
            wait_until(() => updates >= 2);
            assert_equal<int64?>(latest.lookup_value("count", null).get_int64(), 5);
            assert_true(latest.lookup_value("count-visible", null).get_boolean());
            // A restarted dock owns Unity, not the signal interface name.
            int previous = updates;
            owner = GLib.Bus.own_name_on_connection(connection, "com.canonical.Unity", NONE);
            wait_until(() => updates > previous);
            assert_equal<int64?>(latest.lookup_value("count", null).get_int64(), 5);
            assert_true(latest.lookup_value("count-visible", null).get_boolean());
            previous = updates;
            entry.clear_count();
            wait_until(() => updates > previous);
            assert_equal<int64?>(latest.lookup_value("count", null).get_int64(), 0);
            assert_false(latest.lookup_value("count-visible", null).get_boolean());
        } finally {
            if (entry != null) entry.close();
            entry = null;
            if (owner != 0) GLib.Bus.unown_name(owner);
            if (connection != null) {
                if (subscribed != 0) connection.signal_unsubscribe(subscribed);
                try { connection.close_sync(); } catch (GLib.Error error) { warning("Private bus cleanup failed"); }
            }
            stop_private_bus(bus);
        }
    }
}
