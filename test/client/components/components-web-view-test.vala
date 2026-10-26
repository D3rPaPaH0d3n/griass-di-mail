/*
 * Copyright 2016 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class Components.WebViewTest : TestCase {

    public WebViewTest() {
        base("Components.WebViewTest");
        add_test("init_web_context", init_web_context);
        add_test("load_resources", load_resources);
    }

    public void init_web_context() throws Error {
        Application.Configuration config = new Application.Configuration(
            Application.Client.SCHEMA_ID
        );
        config.enable_debug = true;
        WebView.init_web_context(
            config,
            File.new_for_path(Config.BUILD_ROOT_DIR).get_child("src")
        );
        //XXX GTK4 - we used to disable sandboxing here, because of
        // https://bugs.webkit.org/show_bug.cgi?id=213174
    }

    public void load_resources() throws GLib.Error {
        try {
            WebView.load_resources(GLib.File.new_for_path("/tmp"));
        } catch (GLib.Error err) {
            assert_not_reached();
        }
    }

}
