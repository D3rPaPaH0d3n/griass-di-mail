/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

internal class Convey.Graph.Service : Convey.ClientService {

    public Service(Convey.AccountInformation account,
                   Convey.ServiceInformation configuration,
                   Convey.Endpoint remote) {
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
        this.current_status = Convey.ClientService.Status.UNREACHABLE;
    }

}
