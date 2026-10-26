/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

class Integration.Imap.ClientSession : TestCase {


    private Configuration config;
    private Convey.Imap.ClientSession? session;


    public ClientSession(Configuration config) {
        base("Integration.Imap.ClientSession");
        this.config = config;
        add_test("session_connect", session_connect);

        add_test("login_password_invalid", login_password_invalid);
        if (config.provider == GMAIL ||
            config.provider == OUTLOOK) {
            add_test("login_oauth2_invalid", login_oauth2_invalid);
        }

        add_test("initiate_session", initiate_session);
    }

    public override void set_up() {
        this.session = new Convey.Imap.ClientSession(
            this.config.target,
            new Convey.Imap.Quirks()
        );
    }

    public override void tear_down() throws GLib.Error {
        if (this.session.protocol_state != NOT_CONNECTED) {
            this.session.disconnect_async.begin(null, this.async_completion);
            this.session.disconnect_async.end(async_result());
        }
        this.session = null;
    }

    public void session_connect() throws GLib.Error {
        this.session.connect_async.begin(2, null, this.async_completion);
        this.session.connect_async.end(async_result());

        this.session.disconnect_async.begin(null, this.async_completion);
        this.session.disconnect_async.end(async_result());
    }

    public void login_password_invalid() throws GLib.Error {
        do_connect();

        Convey.Credentials password_creds = new Convey.Credentials(
            PASSWORD, "automated-integration-test", "password"
        );
        this.session.login_async.begin(
            password_creds, null, this.async_completion
        );
        try {
            this.session.login_async.end(async_result());
            assert_not_reached();
        } catch (Convey.ImapError.UNAUTHENTICATED err) {
            // All good
        } catch (Convey.ImapError.SERVER_ERROR err) {
            // Some servers (Y!) return AUTHORIZATIONFAILED response
            // code if the login (not password) is bad
            if (!("AUTHORIZATIONFAILED" in err.message)) {
                throw err;
            }
        }
    }

    public void login_oauth2_invalid() throws GLib.Error {
        do_connect();

        Convey.Credentials oauth2_creds = new Convey.Credentials(
            OAUTH2, "automated-integration-test", "password"
        );
        this.session.login_async.begin(
            oauth2_creds, null, this.async_completion
        );
        try {
            this.session.login_async.end(async_result());
            assert_not_reached();
        } catch (Convey.ImapError.UNAUTHENTICATED err) {
            // All good
        }
    }

    public void initiate_session() throws GLib.Error {
        do_connect();

        this.session.initiate_session_async.begin(
            this.config.credentials, null, this.async_completion
        );
        this.session.initiate_session_async.end(async_result());
    }

    private void do_connect() throws GLib.Error {
        this.session.connect_async.begin(5, null, this.async_completion);
        this.session.connect_async.end(async_result());
    }

}
