/*
 * Copyright 2017 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class Mock.CredentialsMediator :
    GLib.Object,
    Convey.CredentialsMediator,
    ValaUnit.TestAssertions,
    ValaUnit.MockObject {


    protected Gee.Queue<ValaUnit.ExpectedCall> expected {
        get; set; default = new Gee.LinkedList<ValaUnit.ExpectedCall>();
    }

    public virtual async bool load_token(Convey.AccountInformation account,
                                         Convey.ServiceInformation service,
                                         GLib.Cancellable? cancellable)
        throws GLib.Error {
        return object_call<bool>("load_token", { service, cancellable }, false);
    }

    /**
     * Prompt the user to enter passwords for the given services.
     *
     * Set the out parameters for the services to the values entered
     * by the user (out parameters for services not being prompted for
     * are ignored).  Return false if the user tried to cancel the
     * interaction, or true if they tried to proceed.
     */
    public virtual async bool prompt_token(Convey.AccountInformation account,
                                           Convey.ServiceInformation service,
                                           GLib.Cancellable? cancellable)
        throws GLib.Error {
        return boolean_call(
            "prompt_token",
            { account, service, cancellable },
            false
        );
    }

}
