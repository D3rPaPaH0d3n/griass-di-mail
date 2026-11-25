/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

class Integration.Smtp.ClientSession : TestCase {


    private Configuration config;
    private GriabuntuMail.Smtp.ClientSession? session;


    public ClientSession(Configuration config) {
        base("Integration.Smtp.ClientSession");
        this.config = config;

        // Break out connecting
        //add_test("session_connect", session_connect);

        add_test("login_password_invalid", login_password_invalid);
        if (config.provider == GMAIL ||
            config.provider == OUTLOOK) {
            add_test("login_oauth2_invalid", login_oauth2_invalid);
        }

        add_test("initiate_session", initiate_session);
        add_test("send_basic_email", send_basic_email);
    }

    public override void set_up() {
        this.session = new GriabuntuMail.Smtp.ClientSession(
            this.config.target
        );
    }

    public override void tear_down() throws GLib.Error {
        try {
            this.session.logout_async.begin(false, null, this.async_completion);
            this.session.logout_async.end(async_result());
        } catch (GLib.Error err) {
            // Oh well
        }
        this.session = null;
    }

    public void login_password_invalid() throws GLib.Error {
        GriabuntuMail.Credentials password_creds = new GriabuntuMail.Credentials(
            PASSWORD,
            "automated-integration-test",
            "deliberately-invalid-password"
        );
        this.session.login_async.begin(
            password_creds, null, this.async_completion
        );
        try {
            this.session.login_async.end(async_result());
            assert_not_reached();
        } catch (GriabuntuMail.SmtpError.AUTHENTICATION_FAILED err) {
            // All good
        }
    }

    public void login_oauth2_invalid() throws GLib.Error {
        GriabuntuMail.Credentials oauth2_creds = new GriabuntuMail.Credentials(
            OAUTH2,
            "automated-integration-test",
            "deliberately-invalid-token"
        );
        this.session.login_async.begin(
            oauth2_creds, null, this.async_completion
        );
        try {
            this.session.login_async.end(async_result());
            assert_not_reached();
        } catch (GriabuntuMail.SmtpError.AUTHENTICATION_FAILED err) {
            // All good
        }
    }

    public void initiate_session() throws GLib.Error {
        do_connect();
    }

    public void send_basic_email() throws GLib.Error {
        do_connect();

        GriabuntuMail.RFC822.MailboxAddress return_path =
            new GriabuntuMail.RFC822.MailboxAddress(
                null, this.config.credentials.user
            );

        this.new_message.begin(
            return_path,
            new GriabuntuMail.RFC822.MailboxAddress(
                "Griabuntu Mail integration test",
                this.config.credentials.user
            ),
            this.async_completion
        );
        GriabuntuMail.RFC822.Message message = new_message.end(async_result());

        this.session.send_email_async.begin(
            return_path,
            message,
            null,
            this.async_completion
        );
        this.session.send_email_async.end(async_result());
    }

    private void do_connect() throws GLib.Error {
        this.session.login_async.begin(
            this.config.credentials, null, this.async_completion
        );
        this.session.login_async.end(async_result());
    }

    private async GriabuntuMail.RFC822.Message new_message(GriabuntuMail.RFC822.MailboxAddress from,
                                                   GriabuntuMail.RFC822.MailboxAddress to)
        throws GriabuntuMail.RFC822.Error {
        GriabuntuMail.ComposedEmail composed = new GriabuntuMail.ComposedEmail(
            new GLib.DateTime.now_local(),
            new GriabuntuMail.RFC822.MailboxAddresses.single(from)
        ).set_to(
            new GriabuntuMail.RFC822.MailboxAddresses.single(to)
        ).set_subject(
            "Griabuntu Mail integration test subject"
        );
        composed.body_text = "Griabuntu Mail integration test message";

        return yield new GriabuntuMail.RFC822.Message.from_composed_email(
            composed,
            GMime.utils_generate_message_id(from.domain),
            GMime.EncodingConstraint.7BIT,
            null
        );
    }

}
