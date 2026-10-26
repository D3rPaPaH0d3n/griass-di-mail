/*
 * Copyright © 2020 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */


int main(string[] args) {
    GLib.Test.init(ref args);
    Convey.RFC822.init();
    Convey.HTML.init();
    Convey.Logging.init();
    if (GLib.Test.verbose()) {
        GLib.Log.set_writer_func(Convey.Logging.default_log_writer);
        Convey.Logging.log_to(GLib.stdout);
    }

    GLib.TestSuite root = GLib.TestSuite.get_root();
    root.add_suite(new MailMerge.TestReader().steal_suite());
    root.add_suite(new MailMerge.TestProcessor().steal_suite());

    GLib.MainLoop loop = new GLib.MainLoop();
    int ret = -1;
    GLib.Idle.add(() => {
            ret = Test.run();
            loop.quit();
            return false;
        });

    loop.run();
    return ret;
}
