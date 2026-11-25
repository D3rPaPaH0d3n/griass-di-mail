/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md. */
/* New downstream file: 2026-10-26. GPL-3.0-only; see COPYING. */
/* Licensed under GPL-3.0-only. See COPYING. */

/** No GTK init, application registration, account opening or live D-Bus. */
int main(string[] args) {
    GLib.Environment.set_variable("GSETTINGS_BACKEND", "memory", true);
    GLib.Environment.set_variable("GIO_USE_NETWORK_MONITOR", "base", true);
    GLib.Test.init(ref args);
    GriabuntuMail.RFC822.init();
    GLib.TestSuite.get_root().add_suite(
        new Application.NotificationPluginContextTest().steal_suite()
    );
    return GLib.Test.run();
}
