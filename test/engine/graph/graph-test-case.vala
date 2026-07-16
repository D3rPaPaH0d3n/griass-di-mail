/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/** Base class for Graph engine unit tests. */
class Geary.GraphTestCase : TestCase {


    private const string TEST_TOKEN = "test-graph-token";


    public Soup.Server server { get; private set; }
    public string base_uri { get; private set; }
    public Geary.CredentialsMediator mediator { get; private set; }
    public AccountInformation account { get; private set; }
    public File? tmp_dir { get; private set; }


    public GraphTestCase(string name) {
        base(name);
    }

    public override void set_up() throws GLib.Error {
        this.server = new Soup.Server("server-header", "test");
        this.server.listen_all(0, Soup.ServerListenOptions.IPV4_ONLY);

        GLib.SList<GLib.Uri> uris = this.server.get_uris();
        assert_non_null(uris.nth(0).data, "Soup.Server should report a URI");
        this.base_uri = uris.nth(0).data.to_string();

        // The Soup URI ends with a trailing slash; strip it so we can
        // concatenate it with the Graph API paths the client uses
        // (e.g. "/me", "/me/mailFolders").
        if (this.base_uri.has_suffix("/")) {
            this.base_uri = this.base_uri.substring(0, this.base_uri.length - 1);
        }

        // 0.0.0.0 is a valid listen address but connecting to it is
        // unreliable across systems; use 127.0.0.1 for the client.
        this.base_uri = this.base_uri.replace("0.0.0.0", "127.0.0.1");

        this.mediator = new GraphStubCredentialsMediator();
        this.account = new AccountInformation(
            "graph-test",
            ServiceProvider.OUTLOOK,
            this.mediator,
            new RFC822.MailboxAddress(null, "user@example.com")
        );
        this.account.account_backend = AccountBackend.MICROSOFT_GRAPH;
        this.account.incoming.credentials = new Geary.Credentials(
            Geary.Credentials.Method.OAUTH2, "user@example.com", TEST_TOKEN
        );
        this.account.outgoing.credentials = new Geary.Credentials(
            Geary.Credentials.Method.OAUTH2, "user@example.com", TEST_TOKEN
        );

        this.tmp_dir = GLib.File.new_for_path(
            GLib.DirUtils.make_tmp("geary-graph-test-XXXXXX")
        );
        this.account.set_account_directories(this.tmp_dir, this.tmp_dir);
    }

    public override void tear_down() throws GLib.Error {
        if (this.server != null) {
            this.server.disconnect();
            this.server = null;
        }
        this.base_uri = null;
        this.mediator = null;
        this.account = null;
        if (this.tmp_dir != null) {
            delete_file(this.tmp_dir);
            this.tmp_dir = null;
        }
    }

    /** Registers a JSON responder for the given method and path. */
    public void respond_json(string method,
                             string path,
                             uint status_code,
                             string json_body) {
        this.register_responder(method, path, status_code, json_body, null);
    }

    /**
     * Registers a JSON responder for the given method and path,
     * returning a capture object that records the request details.
     */
    public SoupServerCapture respond_capture_json(string method,
                                                 string path,
                                                 uint status_code,
                                                 string json_body) {
        return this.register_responder(
            method, path, status_code, json_body, null
        );
    }

    private SoupServerCapture register_responder(string method,
                                                 string path,
                                                 uint status_code,
                                                 string json_body,
                                                 SoupServerCapture? reuse) {
        var capture = reuse ?? new SoupServerCapture(path);
        this.server.add_handler(path, (srv, msg, p, query) => {
            capture.record(msg);
            if (msg.get_method() != method) {
                critical(
                    "Unexpected method %s for path %s (wanted %s)",
                    msg.get_method(), path, method
                );
            }
            // Copy the body bytes into a freshly-allocated array so
            // the Soup response owns the data independent of the
            // lifetime of `json_body` in the closure.
            uint8[] body = new uint8[json_body.length];
            GLib.Memory.copy(body, json_body.data, json_body.length);
            msg.set_response("application/json", Soup.MemoryUse.COPY, body);
            msg.set_status(status_code, null);
        });
        return capture;
    }

    /** Records the last request seen for the given path. */
    public SoupServerCapture capture_request(string path) {
        var capture = new SoupServerCapture(path);
        this.server.add_handler(path, (srv, msg, p, query) => {
            capture.record(msg);
        });
        return capture;
    }

    /** Returns a Client configured to talk to the test Soup.Server. */
    public Geary.Graph.Client new_client() {
        return new Geary.Graph.Client(this.account, this.base_uri);
    }

}


/** Simple request capture for a Soup.Server handler. */
public class Geary.SoupServerCapture : GLib.Object {

    public string path { get; private set; }
    public string method { get; private set; default = ""; }
    public Gee.Map<string,string> headers {
        get; private set; default = new Gee.HashMap<string,string>();
    }
    public string body { get; private set; default = ""; }
    public int hit_count { get; private set; default = 0; }


    public SoupServerCapture(string path) {
        this.path = path;
    }

    internal void record(Soup.ServerMessage msg) {
        this.method = msg.get_method();
        this.hit_count++;

        Soup.MessageHeaders req_headers = msg.get_request_headers();
        req_headers.foreach((name, value) => {
            this.headers.set(name.down(), value);
        });
        Soup.MessageBody req_body = msg.get_request_body();
        if (req_body.length > 0) {
            this.body = (string) req_body.flatten().get_data();
        }
    }

}


/**
 * Permissive credentials mediator for Graph engine unit tests.
 *
 * Always reports the existing token as valid so the test does not
 * have to set up {@link expect_call} entries for every request the
 * client makes. Tests that need to simulate token failures can
 * subclass or replace this.
 */
public class Geary.GraphStubCredentialsMediator :
    GLib.Object,
    Geary.CredentialsMediator {


    public bool fail_load { get; set; default = false; }
    public int load_count { get; private set; default = 0; }


    public async bool load_token(Geary.AccountInformation account,
                                 Geary.ServiceInformation service,
                                 GLib.Cancellable? cancellable)
        throws GLib.Error {
        this.load_count++;
        if (this.fail_load) {
            throw new Geary.EngineError.SERVER_UNAVAILABLE(
                "Test-induced load failure"
            );
        }
        return true;
    }

    public async bool prompt_token(Geary.AccountInformation account,
                                   Geary.ServiceInformation service,
                                   GLib.Cancellable? cancellable)
        throws GLib.Error {
        return false;
    }

}
