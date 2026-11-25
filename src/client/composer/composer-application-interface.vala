/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
 * Copyright © 2020 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */


/**
 * Provides access to application objects and services to the composer.
 *
 * This interface defines the composer's requirements for integrating
 * with the application and enables the composer to be unit tested
 * without having to load the complete application.
 */
internal interface Composer.ApplicationInterface :
    GLib.Object, Application.AccountInterface {


    public abstract void report_problem(GriabuntuMail.ProblemReport report);

    internal abstract async void send_composed_email(Composer.Widget composer);

    internal abstract async void save_composed_email(Composer.Widget composer);

    internal abstract async void discard_composed_email(Composer.Widget composer);

    internal abstract GLib.File get_web_cache_dir();
}
