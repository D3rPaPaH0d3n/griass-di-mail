/* Licensed under LGPL-2.1-or-later. See COPYING. */

/** No GTK init, application registration, account opening or live D-Bus. */
int main(string[] args) {
    GLib.Environment.set_variable("GSETTINGS_BACKEND", "memory", true);
    GLib.Environment.set_variable("GIO_USE_NETWORK_MONITOR", "base", true);
    GLib.Test.init(ref args);
    Convey.RFC822.init();
    GLib.TestSuite.get_root().add_suite(
        new Application.NotificationPluginContextTest().steal_suite()
    );
    return GLib.Test.run();
}
