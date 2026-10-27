/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2018 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * A representation of the various built-in email service providers Griabuntu Mail supports.
 */

public enum GriabuntuMail.ServiceProvider {
    GMAIL,
    OUTLOOK,
    OTHER;

    public static ServiceProvider for_value(string value)
        throws EngineError {
        return ObjectUtils.from_enum_nick<ServiceProvider>(
            typeof(ServiceProvider), value.ascii_down()
        );
    }

    public string to_value() {
        return ObjectUtils.to_enum_nick<ServiceProvider>(
            typeof(ServiceProvider), this
        );
    }

    public void set_account_defaults(AccountInformation service) {
        switch (this) {
        case GMAIL:
            ImapEngine.GmailAccount.setup_account(service);
            break;
        case OUTLOOK:
            ImapEngine.OutlookAccount.setup_account(service);
            break;
        case OTHER:
            // no-op
            break;
        }
    }

    public void set_service_defaults(ServiceInformation service) {
        switch (this) {
        case GMAIL:
            ImapEngine.GmailAccount.setup_service(service);
            break;
        case OUTLOOK:
            ImapEngine.OutlookAccount.setup_service(service);
            break;
        case OTHER:
            // no-op
            break;
        }
    }

}
