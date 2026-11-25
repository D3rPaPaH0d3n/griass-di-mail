/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */


// 5s is too short for some SMTP servers
private const int TIMEOUT = 10;


public struct Integration.Configuration {

    GriabuntuMail.Protocol type;
    GriabuntuMail.ServiceProvider provider;
    GriabuntuMail.ServiceInformation service;
    GriabuntuMail.Endpoint target;
    GriabuntuMail.Credentials credentials;

}


int main(string[] args) {
    /*
     * Initialise all the things.
     */

    // Ensure things like e.g. GLib's formatting routines uses a
    // UTF-8-based locale rather ASCII
    GLib.Intl.setlocale(LocaleCategory.ALL, "C.UTF-8");

    Test.init(ref args);

    GriabuntuMail.RFC822.init();
    GriabuntuMail.HTML.init();
    GriabuntuMail.Logging.init();
    GriabuntuMail.Logging.log_to(stderr);
    GLib.Log.set_writer_func(GriabuntuMail.Logging.default_log_writer);

    Integration.Configuration config = load_config(args);

    /*
     * Hook up all tests into appropriate suites
     */

    TestSuite integration = new TestSuite("integration");

    switch (config.type) {
    case IMAP:
        integration.add_suite(new Integration.Imap.ClientSession(config).steal_suite());
        break;

    case SMTP:
        integration.add_suite(new Integration.Smtp.ClientSession(config).steal_suite());
        break;
    }

    /*
     * Run the tests
     */
    unowned TestSuite root = TestSuite.get_root();
    root.add_suite((owned) integration);

    MainLoop loop = new MainLoop();

    int ret = -1;
    Idle.add(() => {
            ret = Test.run();
            loop.quit();
            return false;
        });

    loop.run();
    return ret;
}

private Integration.Configuration load_config(string[] args) {
    int i = 1;
    try {
        GriabuntuMail.Protocol type = GriabuntuMail.Protocol.for_value(args[i++]);
        GriabuntuMail.ServiceProvider provider = GriabuntuMail.ServiceProvider.for_value(
            args[i++]
        );
        GriabuntuMail.ServiceInformation service = new GriabuntuMail.ServiceInformation(
            type, provider
        );

        if (provider == OTHER) {
            service.host = args[i++];
            service.port = service.get_default_port();
        }

        GriabuntuMail.Credentials credentials = new GriabuntuMail.Credentials(
            PASSWORD, args[i++], args[i++]
        );

        provider.set_service_defaults(service);

        GriabuntuMail.Endpoint target = new GriabuntuMail.Endpoint(
            new NetworkAddress(service.host, service.port),
            service.transport_security,
            TIMEOUT
        );

        return { type, provider, service, target, credentials };
    } catch (GLib.Error err) {
        error(
            "Error loading config: %s",
            (new GriabuntuMail.ErrorContext(err)).format_full_error()
        );
    }

}
