/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Handles open/close for local folders.
 */
public abstract class GriabuntuMail.AbstractLocalFolder : GriabuntuMail.Folder {
    private ProgressMonitor _opening_monitor = new GriabuntuMail.ReentrantProgressMonitor(GriabuntuMail.ProgressType.ACTIVITY);
    public override GriabuntuMail.ProgressMonitor opening_monitor { get { return _opening_monitor; } }

    private int open_count = 0;
    private Nonblocking.Semaphore closed_semaphore = new Nonblocking.Semaphore();

    protected AbstractLocalFolder() {
        // Notify now to ensure that wait_for_close_async does not
        // block if never opened.
        this.closed_semaphore.blind_notify();
    }

    public override GriabuntuMail.Folder.OpenState get_open_state() {
        return open_count > 0 ? GriabuntuMail.Folder.OpenState.LOCAL : GriabuntuMail.Folder.OpenState.CLOSED;
    }

    protected void check_open() throws EngineError {
        if (open_count == 0)
            throw new EngineError.OPEN_REQUIRED("%s not open", to_string());
    }

    protected bool is_open() {
        return open_count > 0;
    }

    public override async bool open_async(GriabuntuMail.Folder.OpenFlags open_flags, Cancellable? cancellable = null)
        throws Error {
        if (open_count++ > 0)
            return false;

        closed_semaphore.reset();

        notify_opened(GriabuntuMail.Folder.OpenState.LOCAL, properties.email_total);

        return true;
    }

    public override async bool close_async(Cancellable? cancellable = null) throws Error {
        if (open_count == 0 || --open_count > 0)
            return false;

        closed_semaphore.blind_notify();

        notify_closed(GriabuntuMail.Folder.CloseReason.LOCAL_CLOSE);
        notify_closed(GriabuntuMail.Folder.CloseReason.FOLDER_CLOSED);

        return false;
    }

    public override async void wait_for_close_async(Cancellable? cancellable = null) throws Error {
        yield closed_semaphore.wait_async(cancellable);
    }

    public override async void synchronise_remote(GLib.Cancellable? cancellable)
        throws GLib.Error {
        // No-op
    }

}
