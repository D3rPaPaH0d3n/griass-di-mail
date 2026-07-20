/*
 * Copyright 2017 Software Freedom Conservancy Inc.
 * Copyright 2018 Michael Gratton <mike@vee.net>
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/** GNOME Online Accounts token adapter. */
public class GoaMediator : Convey.CredentialsMediator, Object {


    private const string PROVIDER_TYPE_WINDOWS_LIVE = "windows_live";
    private const string PROVIDER_TYPE_MS_GRAPH = "ms_graph";
    private const string MS365_IMAP_HOST = "outlook.office365.com";
    private const string MS365_SMTP_HOST = "smtp.office365.com";
    private const string OUTLOOK_IMAP_HOST = "imap-mail.outlook.com";
    private const string OUTLOOK_SMTP_HOST = "smtp-mail.outlook.com";

    private Goa.Object handle;


    public GoaMediator(Goa.Object handle) {
        this.handle = handle;
    }

    public Convey.ServiceProvider get_service_provider() {
        Convey.ServiceProvider provider = Convey.ServiceProvider.OTHER;
        switch (this.handle.get_account().provider_type) {
        case "google":
            provider = Convey.ServiceProvider.GMAIL;
            break;

        case PROVIDER_TYPE_WINDOWS_LIVE:
        case PROVIDER_TYPE_MS_GRAPH:
            provider = Convey.ServiceProvider.OUTLOOK;
            break;
        }
        return provider;
    }

    public Convey.AccountBackend get_account_backend() {
        Convey.AccountBackend backend = Convey.AccountBackend.IMAP_SMTP;
        if (this.handle.get_account().provider_type == PROVIDER_TYPE_MS_GRAPH) {
            backend = Convey.AccountBackend.MICROSOFT_GRAPH;
        }
        return backend;
    }

    public string get_service_label() {
        return this.handle.get_account().provider_name;
    }

    public async void update(Convey.AccountInformation convey_account,
                             GLib.Cancellable? cancellable)
        throws GLib.Error {
        // Call this to get the exception thrown if no auth method is
        // supported.
        get_auth_method();

        update_imap_config(convey_account.incoming);
        update_smtp_config(convey_account.outgoing);
    }

    public virtual async bool load_token(Convey.AccountInformation account,
                                         Convey.ServiceInformation service,
                                         Cancellable? cancellable)
        throws GLib.Error {
        // Per GOA docs
        // <https://developer.gnome.org/goa/stable/ch01s03.html>:
        // "First the application should invoke the
        // Account.EnsureCredentials() method […] if the service
        // returns an authorization error (say, the access token
        // expired), the application should call
        // Account.EnsureCredentials() again to e.g. renew the
        // credentials."
        Goa.Account? goa_account = this.handle.get_account();
        if (account != null) {
            try {
                yield goa_account.call_ensure_credentials(cancellable, null);
            } catch (Goa.Error.NOT_AUTHORIZED err) {
                debug("GOA updating auth failed, retrying: %s", err.message);
                yield goa_account.call_ensure_credentials(cancellable, null);
            }
        }

        bool loaded = false;
        string? token = null;

        switch (get_auth_method()) {
        case OAUTH2:
            yield this.handle.get_oauth2_based().call_get_access_token(
                cancellable, out token, null
            );
            break;

        case PASSWORD:
            switch (service.protocol) {
            case Convey.Protocol.IMAP:
                yield this.handle.get_password_based().call_get_password(
                    "imap-password", cancellable, out token
                );
                break;

            case Convey.Protocol.SMTP:
                yield this.handle.get_password_based().call_get_password(
                    "smtp-password", cancellable, out token
                );
                break;

            default:
                return false;
            }
            break;
        }

        if (token != null) {
            service.credentials = service.credentials.copy_with_token(token);
            loaded = true;
        }
        return loaded;
    }

    private Convey.Credentials.Method get_auth_method() throws GLib.Error {
        if (this.handle.get_oauth2_based() != null) {
            return Convey.Credentials.Method.OAUTH2;
        }
        if (this.handle.get_password_based() != null) {
            return Convey.Credentials.Method.PASSWORD;
        }
        throw new Convey.EngineError.UNSUPPORTED(
            "GOA account supports neither password or OAuth2 auth"
        );
    }

    private bool is_microsoft_account() {
        string provider_type = this.handle.get_account().provider_type;
        return (
            provider_type == PROVIDER_TYPE_MS_GRAPH ||
            provider_type == PROVIDER_TYPE_WINDOWS_LIVE
        );
    }

    private string get_default_imap_host() {
        return this.handle.get_account().provider_type == PROVIDER_TYPE_MS_GRAPH
            ? MS365_IMAP_HOST
            : OUTLOOK_IMAP_HOST;
    }

    private string get_default_smtp_host() {
        return this.handle.get_account().provider_type == PROVIDER_TYPE_MS_GRAPH
            ? MS365_SMTP_HOST
            : OUTLOOK_SMTP_HOST;
    }

    private bool has_mail_endpoints(Goa.Mail mail) {
        return (
            !Convey.String.is_empty(mail.imap_host) &&
            !Convey.String.is_empty(mail.smtp_host)
        );
    }

    private string get_service_user_name(Convey.Protocol protocol)
        throws GLib.Error {
        Goa.Mail? mail = this.handle.get_mail();
        if (mail != null) {
            string? user = null;
            switch (protocol) {
            case Convey.Protocol.IMAP:
                user = mail.imap_user_name;
                break;

            case Convey.Protocol.SMTP:
                user = mail.smtp_user_name;
                break;
            }
            if (!Convey.String.is_empty_or_whitespace(user)) {
                return (string) user;
            }
        }

        string mailbox = this.handle.get_account().presentation_identity;
        if (Convey.String.is_empty_or_whitespace(mailbox)) {
            throw new Convey.EngineError.UNSUPPORTED(
                "GOA account does not include a mailbox identity"
            );
        }
        return mailbox;
    }

    private void update_imap_config(Convey.ServiceInformation service)
        throws GLib.Error {
        Goa.Mail? mail = this.handle.get_mail();
        bool use_microsoft_fallback = (
            is_microsoft_account() &&
            (mail == null || !has_mail_endpoints(mail))
        );
        if (mail != null && !use_microsoft_fallback) {
            parse_host_name(service, mail.imap_host);

            if (mail.imap_use_ssl) {
                service.transport_security = Convey.TlsNegotiationMethod.TRANSPORT;
            } else if (mail.imap_use_tls) {
                service.transport_security = Convey.TlsNegotiationMethod.START_TLS;
            } else {
                service.transport_security = Convey.TlsNegotiationMethod.NONE;
            }
        } else if (use_microsoft_fallback) {
            parse_host_name(service, get_default_imap_host());
            service.transport_security = Convey.TlsNegotiationMethod.TRANSPORT;
        } else {
            return;
        }

        service.credentials = new Convey.Credentials(
            get_auth_method(), get_service_user_name(Convey.Protocol.IMAP)
        );

        if (service.port == 0) {
            service.port = service.get_default_port();
        }
    }

    private void update_smtp_config(Convey.ServiceInformation service)
        throws GLib.Error {
        Goa.Mail? mail = this.handle.get_mail();
        bool use_microsoft_fallback = (
            is_microsoft_account() &&
            (mail == null || !has_mail_endpoints(mail))
        );
        if (mail != null && !use_microsoft_fallback) {
            parse_host_name(service, mail.smtp_host);

            if (mail.smtp_use_ssl) {
                service.transport_security = Convey.TlsNegotiationMethod.TRANSPORT;
            } else if (mail.smtp_use_tls) {
                service.transport_security = Convey.TlsNegotiationMethod.START_TLS;
            } else {
                service.transport_security = Convey.TlsNegotiationMethod.NONE;
            }

            if (mail.smtp_use_auth) {
                service.credentials_requirement = Convey.Credentials.Requirement.CUSTOM;
            } else {
                service.credentials_requirement = Convey.Credentials.Requirement.NONE;
            }

            if (mail.smtp_use_auth) {
                service.credentials = new Convey.Credentials(
                    get_auth_method(), get_service_user_name(Convey.Protocol.SMTP)
                );
            }
        } else if (use_microsoft_fallback) {
            parse_host_name(service, get_default_smtp_host());
            service.transport_security = Convey.TlsNegotiationMethod.START_TLS;
            service.credentials_requirement = Convey.Credentials.Requirement.CUSTOM;
            service.credentials = new Convey.Credentials(
                get_auth_method(), get_service_user_name(Convey.Protocol.SMTP)
            );
        } else {
            return;
        }

        if (service.port == 0) {
            service.port = service.get_default_port();
        }
    }

    private void parse_host_name(Convey.ServiceInformation service,
                                 string host_name) {
        // Fall back to trying to use the host name as-is.
        // At least the user can see it in the settings if
        // they look.
        service.host = host_name;
        service.port = 0;

        try {
            GLib.NetworkAddress address = GLib.NetworkAddress.parse(
                host_name, service.port
            );

            service.host = address.hostname;
            service.port = (uint16) address.port;
        } catch (GLib.Error err) {
            warning(
                "GOA account \"%s\" %s hostname \"%s\": %",
                this.handle.get_account().id,
                service.protocol.to_value(),
                host_name,
                err.message
            );
        }
    }

}
