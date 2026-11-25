/*
 * Copyright 2016 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class Application.ConfigurationTest : TestCase {

    private Configuration test_config = null;

    public ConfigurationTest() {
        base("ConfigurationTest");
        add_test("desktop_environment", desktop_environment);
    }

    public override void set_up() {
        Environment.unset_variable("XDG_CURRENT_DESKTOP");
        this.test_config = new Configuration(Client.SCHEMA_ID);
    }

    public void desktop_environment() throws Error {
        assert(this.test_config.desktop_environment ==
               Configuration.DesktopEnvironment.UNKNOWN);

        Environment.set_variable("XDG_CURRENT_DESKTOP", "BLARG", true);
        assert(this.test_config.desktop_environment ==
               Configuration.DesktopEnvironment.UNKNOWN);

        Environment.set_variable("XDG_CURRENT_DESKTOP", "Unity", true);
        assert(this.test_config.desktop_environment ==
               Configuration.DesktopEnvironment.UNITY);
    }

}
