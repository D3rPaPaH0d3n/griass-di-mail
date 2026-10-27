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
 * An object representing an account for use by plugins.
 *
 * Instances of these may be obtained from their respective {@link
 * Folder} objects.
 */
public interface Plugin.Account : GriabuntuMail.BaseObject {


    /** Returns the human-readable name of this account. */
    public abstract string display_name { get; }


}
