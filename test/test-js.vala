/*
 * Copyright 2016-2017 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */


int main(string[] args) {
    /*
     * Set env vars right up front to avoid weird bugs
     */

    // Use the memory GSettings DB so we a) always start with default
    // values, and b) don't persist any changes made during a test
    Environment.set_variable("GSETTINGS_BACKEND", "memory", true);

    // Let GSettings know where to find the dev schema
    Environment.set_variable("GSETTINGS_SCHEMA_DIR", Config.GSETTINGS_DIR, true);

    // Constructing any widget makes GTK build an AT-SPI context, which
    // warns when there is no accessibility bus -- and warnings are fatal
    // under the test harness. There is no a11y bus in the Flatpak build
    // sandbox, so disable the backend outright. Set here rather than in
    // the meson test env because it must be in place before Gtk.init().
    Environment.set_variable("GTK_A11Y", "none", true);

    /*
     * Initialise all the things.
     */

    GLib.Intl.setlocale(LocaleCategory.ALL, "C.UTF-8");

    Gtk.init();
    Test.init(ref args);

    Convey.RFC822.init();
    Convey.HTML.init();
    Convey.Logging.init();
    if (GLib.Test.verbose()) {
        GLib.Log.set_writer_func(Convey.Logging.default_log_writer);
        Convey.Logging.log_to(GLib.stdout);
    }

    /*
     * Hook up all tests into appropriate suites
     */

    TestSuite js = new TestSuite("js");

    js.add_suite(new Components.PageStateTest().steal_suite());
    js.add_suite(new Composer.PageStateTest().steal_suite());
    js.add_suite(new ConversationPageStateTest().steal_suite());

    /*
     * Run the tests
     */
    unowned TestSuite root = TestSuite.get_root();
    root.add_suite((owned) js);

    MainLoop loop = new MainLoop();

    int ret = -1;
    Idle.add(() => {
        ret = Test.run();
        loop.quit();
        return Source.REMOVE;
    });

    loop.run();
    return ret;
}
