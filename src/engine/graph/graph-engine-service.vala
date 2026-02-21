/*
 * Copyright 2026 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

internal class Geary.Graph.Service : Geary.ClientService {

    public Service(Geary.AccountInformation account,
                   Geary.ServiceInformation configuration,
                   Geary.Endpoint remote) {
        base(account, configuration, remote);
    }

    public override async void start(GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        notify_started();
        notify_connected();
    }

    public override async void stop(GLib.Cancellable? cancellable = null)
        throws GLib.Error {
        notify_stopped();
    }

    protected override void became_reachable() {
        notify_connected();
    }

    protected override void became_unreachable() {
        this.current_status = Geary.ClientService.Status.UNREACHABLE;
    }

}
