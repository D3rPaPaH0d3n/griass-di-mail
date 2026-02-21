/*
 * Copyright 2017 Software Freedom Conservancy Inc.
 * Copyright 2018 Michael Gratton <mike@vee.net>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/** GNOME Online Accounts token adapter. */
public class GoaMediator : Geary.CredentialsMediator, Object {


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

    public Geary.ServiceProvider get_service_provider() {
        Geary.ServiceProvider provider = Geary.ServiceProvider.OTHER;
        switch (this.handle.get_account().provider_type) {
        case "google":
            provider = Geary.ServiceProvider.GMAIL;
            break;

        case PROVIDER_TYPE_WINDOWS_LIVE:
        case PROVIDER_TYPE_MS_GRAPH:
            provider = Geary.ServiceProvider.OUTLOOK;
            break;
        }
        return provider;
    }

    public Geary.AccountBackend get_account_backend() {
        Geary.AccountBackend backend = Geary.AccountBackend.IMAP_SMTP;
        if (this.handle.get_account().provider_type == PROVIDER_TYPE_MS_GRAPH) {
            backend = Geary.AccountBackend.MICROSOFT_GRAPH;
        }
        return backend;
    }

    public string get_service_label() {
        return this.handle.get_account().provider_name;
    }

    public async void update(Geary.AccountInformation geary_account,
                             GLib.Cancellable? cancellable)
        throws GLib.Error {
        // Call this to get the exception thrown if no auth method is
        // supported.
        get_auth_method();

        update_imap_config(geary_account.incoming);
        update_smtp_config(geary_account.outgoing);
    }

    public virtual async bool load_token(Geary.AccountInformation account,
                                         Geary.ServiceInformation service,
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
            case Geary.Protocol.IMAP:
                yield this.handle.get_password_based().call_get_password(
                    "imap-password", cancellable, out token
                );
                break;

            case Geary.Protocol.SMTP:
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

    private Geary.Credentials.Method get_auth_method() throws GLib.Error {
        if (this.handle.get_oauth2_based() != null) {
            return Geary.Credentials.Method.OAUTH2;
        }
        if (this.handle.get_password_based() != null) {
            return Geary.Credentials.Method.PASSWORD;
        }
        throw new Geary.EngineError.UNSUPPORTED(
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
            !Geary.String.is_empty(mail.imap_host) &&
            !Geary.String.is_empty(mail.smtp_host)
        );
    }

    private string get_service_user_name(Geary.Protocol protocol)
        throws GLib.Error {
        Goa.Mail? mail = this.handle.get_mail();
        if (mail != null) {
            string? user = null;
            switch (protocol) {
            case Geary.Protocol.IMAP:
                user = mail.imap_user_name;
                break;

            case Geary.Protocol.SMTP:
                user = mail.smtp_user_name;
                break;
            }
            if (!Geary.String.is_empty_or_whitespace(user)) {
                return (string) user;
            }
        }

        string mailbox = this.handle.get_account().presentation_identity;
        if (Geary.String.is_empty_or_whitespace(mailbox)) {
            throw new Geary.EngineError.UNSUPPORTED(
                "GOA account does not include a mailbox identity"
            );
        }
        return mailbox;
    }

    private void update_imap_config(Geary.ServiceInformation service)
        throws GLib.Error {
        Goa.Mail? mail = this.handle.get_mail();
        bool use_microsoft_fallback = (
            is_microsoft_account() &&
            (mail == null || !has_mail_endpoints(mail))
        );
        if (mail != null && !use_microsoft_fallback) {
            parse_host_name(service, mail.imap_host);

            if (mail.imap_use_ssl) {
                service.transport_security = Geary.TlsNegotiationMethod.TRANSPORT;
            } else if (mail.imap_use_tls) {
                service.transport_security = Geary.TlsNegotiationMethod.START_TLS;
            } else {
                service.transport_security = Geary.TlsNegotiationMethod.NONE;
            }
        } else if (use_microsoft_fallback) {
            parse_host_name(service, get_default_imap_host());
            service.transport_security = Geary.TlsNegotiationMethod.TRANSPORT;
        } else {
            return;
        }

        service.credentials = new Geary.Credentials(
            get_auth_method(), get_service_user_name(Geary.Protocol.IMAP)
        );

        if (service.port == 0) {
            service.port = service.get_default_port();
        }
    }

    private void update_smtp_config(Geary.ServiceInformation service)
        throws GLib.Error {
        Goa.Mail? mail = this.handle.get_mail();
        bool use_microsoft_fallback = (
            is_microsoft_account() &&
            (mail == null || !has_mail_endpoints(mail))
        );
        if (mail != null && !use_microsoft_fallback) {
            parse_host_name(service, mail.smtp_host);

            if (mail.smtp_use_ssl) {
                service.transport_security = Geary.TlsNegotiationMethod.TRANSPORT;
            } else if (mail.smtp_use_tls) {
                service.transport_security = Geary.TlsNegotiationMethod.START_TLS;
            } else {
                service.transport_security = Geary.TlsNegotiationMethod.NONE;
            }

            if (mail.smtp_use_auth) {
                service.credentials_requirement = Geary.Credentials.Requirement.CUSTOM;
            } else {
                service.credentials_requirement = Geary.Credentials.Requirement.NONE;
            }

            if (mail.smtp_use_auth) {
                service.credentials = new Geary.Credentials(
                    get_auth_method(), get_service_user_name(Geary.Protocol.SMTP)
                );
            }
        } else if (use_microsoft_fallback) {
            parse_host_name(service, get_default_smtp_host());
            service.transport_security = Geary.TlsNegotiationMethod.START_TLS;
            service.credentials_requirement = Geary.Credentials.Requirement.CUSTOM;
            service.credentials = new Geary.Credentials(
                get_auth_method(), get_service_user_name(Geary.Protocol.SMTP)
            );
        } else {
            return;
        }

        if (service.port == 0) {
            service.port = service.get_default_port();
        }
    }

    private void parse_host_name(Geary.ServiceInformation service,
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
