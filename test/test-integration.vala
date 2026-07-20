/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */


// 5s is too short for some SMTP servers
private const int TIMEOUT = 10;


public struct Integration.Configuration {

    Convey.Protocol type;
    Convey.ServiceProvider provider;
    Convey.ServiceInformation service;
    Convey.Endpoint target;
    Convey.Credentials credentials;

}


int main(string[] args) {
    /*
     * Initialise all the things.
     */

    // Ensure things like e.g. GLib's formatting routines uses a
    // UTF-8-based locale rather ASCII
    GLib.Intl.setlocale(LocaleCategory.ALL, "C.UTF-8");

    Test.init(ref args);

    Convey.RFC822.init();
    Convey.HTML.init();
    Convey.Logging.init();
    Convey.Logging.log_to(stderr);
    GLib.Log.set_writer_func(Convey.Logging.default_log_writer);

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
        Convey.Protocol type = Convey.Protocol.for_value(args[i++]);
        Convey.ServiceProvider provider = Convey.ServiceProvider.for_value(
            args[i++]
        );
        Convey.ServiceInformation service = new Convey.ServiceInformation(
            type, provider
        );

        if (provider == OTHER) {
            service.host = args[i++];
            service.port = service.get_default_port();
        }

        Convey.Credentials credentials = new Convey.Credentials(
            PASSWORD, args[i++], args[i++]
        );

        provider.set_service_defaults(service);

        Convey.Endpoint target = new Convey.Endpoint(
            new NetworkAddress(service.host, service.port),
            service.transport_security,
            TIMEOUT
        );

        return { type, provider, service, target, credentials };
    } catch (GLib.Error err) {
        error(
            "Error loading config: %s",
            (new Convey.ErrorContext(err)).format_full_error()
        );
    }

}
