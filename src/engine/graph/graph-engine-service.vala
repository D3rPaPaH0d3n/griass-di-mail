/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
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

    internal void notify_response_received() {
        if (this.is_running &&
            this.current_status != CONNECTED &&
            this.current_status.automatically_reconnect()) {
            notify_connected();
        }
    }

    protected override void became_reachable() {
        notify_connected();
    }

    protected override void became_unreachable() {
        this.current_status = Convey.ClientService.Status.UNREACHABLE;
    }

}
