/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */


class Application.ClientTest : TestCase {


    private Client? test_article = null;


    public ClientTest() {
        base("Application.ClientTest");
        add_test("paths_when_installed", paths_when_installed);
    }

    public override void set_up() {
        this.test_article = new Client();
    }

    public override void tear_down() {
        this.test_article = null;
    }

    public void paths_when_installed() throws GLib.Error {
        string[] args = new string[] {
            Config.INSTALL_PREFIX + "/bin/griabuntu-mail",
            // Specify this so the app doesn't actually attempt
            // to start up
            "-v"
        };
        unowned string[] unowned_args = args;
        int status;
        this.test_article.local_command_line(ref unowned_args, out status);

        assert_equal(
            this.test_article.get_resource_directory().get_path(),
            Config.INSTALL_PREFIX + "/share/griabuntu-mail"
        );
        assert_equal(
            this.test_article.get_desktop_directory().get_path(),
            Config.INSTALL_PREFIX + "/share/applications"
        );
    }

}
