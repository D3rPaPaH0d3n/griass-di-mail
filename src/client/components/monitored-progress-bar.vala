/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * Adapts a progress bar to automatically display progress of a GriabuntuMail.ProgressMonitor.
 */
public class MonitoredProgressBar : Adw.Bin {
    private GriabuntuMail.ProgressMonitor? monitor = null;

    private Gtk.ProgressBar progress_bar;

    construct {
        this.progress_bar = new Gtk.ProgressBar();
        this.child = this.progress_bar;
    }

    public void set_progress_monitor(GriabuntuMail.ProgressMonitor monitor) {
        this.monitor = monitor;
        monitor.start.connect(on_start);
        monitor.finish.connect(on_finish);
        monitor.update.connect(on_update);

        this.progress_bar.fraction = monitor.progress;
    }

    private void on_start() {
        this.progress_bar.fraction = 0.0;
    }

    private void on_update(double total_progress, double change, GriabuntuMail.ProgressMonitor monitor) {
        this.progress_bar.fraction = total_progress;
    }

    private void on_finish() {
        this.progress_bar.fraction = 1.0;
    }
}

