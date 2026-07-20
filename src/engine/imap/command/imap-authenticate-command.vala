/*
 * Copyright 2018 Michael Gratton <mike@vee.net>
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * The IMAP AUTHENTICATE command.
 *
 * See [[http://tools.ietf.org/html/rfc3501#section-6.2.2]]
 */
public class Convey.Imap.AuthenticateCommand : Command {


    public const string NAME = "authenticate";

    private const string OAUTH2_METHOD = "XOAUTH2";
    private const string OAUTH2_RESP = "user=%s\001auth=Bearer %s\001\001";


    public string method { get; private set; }

    private LiteralParameter? response_literal = null;
    private string? oauth2_token = null;
    private bool sent_oauth2_token = false;
    private bool sent_oauth2_empty = false;
    private bool serialised = false;
    private Convey.Nonblocking.Spinlock error_lock;
    private GLib.Cancellable error_cancellable = new GLib.Cancellable();


    private AuthenticateCommand(string method,
                                string[] args,
                                GLib.Cancellable? should_send) {
        base(NAME, args, should_send);
        this.method = method;
        this.error_lock = new Convey.Nonblocking.Spinlock(this.error_cancellable);
    }

    public AuthenticateCommand.oauth2(string user,
                                      string token,
                                      bool send_initial_response,
                                      GLib.Cancellable? should_send) {
        string encoded_token = Base64.encode(
            OAUTH2_RESP.printf(user, token).data
        );
        string[] args = { OAUTH2_METHOD };
        if (send_initial_response) {
            args = { OAUTH2_METHOD, encoded_token };
        }
        this(OAUTH2_METHOD, args, should_send);
        this.oauth2_token = encoded_token;
        this.sent_oauth2_token = send_initial_response;
    }

    internal override async void send(Serializer ser,
                                      GLib.Cancellable cancellable)
        throws GLib.Error {
        yield base.send(ser, cancellable);
        this.serialised = true;

        // Need to manually flush here since the connection will be
        // waiting for all pending commands to complete before
        // flushing it itself
        yield ser.flush_stream(cancellable);
    }

    public override string to_string() {
        return "%s %s %s <token>".printf(
            tag.to_string(), this.name, this.method
        );
    }

    internal override async void send_wait(Serializer ser,
                                          GLib.Cancellable cancellable)
        throws GLib.Error {
        while (true) {
            // Wait to either get a response or a continuation request
            yield this.error_lock.wait_async(cancellable);
            if (this.response_literal == null) {
                break;
            }
            LiteralParameter literal = this.response_literal;
            this.response_literal = null;
            yield ser.push_literal_data(
                literal.value.get_uint8_array(), cancellable
            );
            ser.push_eol(cancellable);
            yield ser.flush_stream(cancellable);
        }

        yield wait_until_complete(cancellable);
    }

    internal override void completed(StatusResponse new_status)
        throws ImapError {
        this.error_lock.blind_notify();
        base.completed(new_status);
    }

    internal override void continuation_requested(ContinuationResponse response)
        throws ImapError {
        if (!this.serialised) {
            // Allow any args sent as literals to be processed
            // normally
            base.continuation_requested(response);
        } else {
            if (this.method != AuthenticateCommand.OAUTH2_METHOD ||
                this.response_literal != null) {
                stop_serialisation();
                throw new ImapError.INVALID(
                    "Unexpected AUTHENTICATE continuation request"
                );
            }

            if (!this.sent_oauth2_token) {
                string? oauth2_token = this.oauth2_token;
                if (Convey.String.is_empty(oauth2_token)) {
                    stop_serialisation();
                    throw new ImapError.INVALID(
                        "Missing OAUTH2 response for AUTHENTICATE"
                    );
                }
                this.sent_oauth2_token = true;
                this.response_literal = new LiteralParameter(
                    new Convey.Memory.StringBuffer((string) oauth2_token)
                );
            } else if (!this.sent_oauth2_empty) {
                // Continuation will be a Base64 encoded JSON blob and which
                // indicates a login failure. We don't really care about that
                // (do we?) though since once we acknowledge it with a
                // zero-length response the server will respond with an IMAP
                // error.
                this.sent_oauth2_empty = true;
                this.response_literal = new LiteralParameter(
                    Convey.Memory.EmptyBuffer.instance
                );
            } else {
                stop_serialisation();
                throw new ImapError.INVALID(
                    "Unexpected repeated AUTHENTICATE continuation request"
                );
            }
            // Notify serialisation to continue
            this.error_lock.blind_notify();
        }
    }

    protected override void stop_serialisation() {
        base.stop_serialisation();
        this.error_cancellable.cancel();
    }

}
