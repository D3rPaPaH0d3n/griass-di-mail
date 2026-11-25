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
 * An object representing a folder for use by plugins.
 *
 * Instances of these may be obtained from {@link FolderStore}.
 */
public interface Plugin.Folder : GriabuntuMail.BaseObject {


    /**
     * Returns a unique identifier for this account and folder.
     *
     * The value returned is persistent across application restarts.
     */
    public abstract string persistent_id { get; }

    /** Returns the human-readable name of this folder. */
    public abstract string display_name { get; }

    /** Returns the type of this folder. */
    public abstract GriabuntuMail.Folder.SpecialUse used_as { get; }

    /** Returns the account the folder belongs to, if any. */
    public abstract Account? account { get; }

    /**
     * Returns a variant identifying this account and folder.
     *
     * This value can be used to obtain folders from {@link
     * FolderStore}, and is suitable to be used as the `show-folder`
     * application action parameter.
     *
     * @see FolderStore.get_folder_for_variant
     * @see FolderStore.folder_variant_type
     */
    public abstract GLib.Variant to_variant();

}
