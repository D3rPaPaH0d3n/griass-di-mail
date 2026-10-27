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
 * A store for authentication tokens.
 */
public interface GriabuntuMail.CredentialsMediator : GLib.Object {

    /**
     * Updates the token for a service's credential from the store.
     *
     * Returns true if the token was present and loaded, else false.
     */
    public abstract async bool load_token(AccountInformation account,
                                          ServiceInformation service,
                                          GLib.Cancellable? cancellable)
        throws GLib.Error;

}
