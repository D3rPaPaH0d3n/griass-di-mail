/*
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/** Run only synthetic summary helpers, without GTK or application setup. */
int main(string[] args) {
    if (args.length > 1 && args[1] == "--tray-fixture")
        return Application.StatusIconTest.run_fixture();
    if (args.length > 1 && args[1] == "--notification-fixture")
        return Application.NotificationActionsTest.run_fixture();
    GLib.Environment.set_variable("GSETTINGS_BACKEND", "memory", true);
    GLib.Environment.set_variable("GNOTIFICATION_BACKEND", "gtk", true);
    GLib.Environment.set_variable("TZ", "Europe/Vienna", true);
    GLib.Intl.setlocale(LocaleCategory.ALL, "C.UTF-8");
    GLib.Test.init(ref args);
    Convey.RFC822.init();

    unowned GLib.TestSuite root = GLib.TestSuite.get_root();
    root.add_suite(new Util.Email.RecipientAliasesTest().steal_suite());
    root.add_suite(new Util.Email.SummaryContactTest().steal_suite());
    root.add_suite(new ConversationList.ParticipantDisplayTest().steal_suite());
    root.add_suite(new Util.Date.ReceivedTimeTest().steal_suite());
    root.add_suite(new Application.StatusIconTest().steal_suite());
    root.add_suite(new Application.NotificationActionsTest().steal_suite());
    return GLib.Test.run();
}
