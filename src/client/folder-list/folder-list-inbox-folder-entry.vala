/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

// A FolderEntry for inboxes in the Inboxes branch.
public class FolderList.InboxFolderEntry : FolderList.FolderEntry {


    private string display_name = "";


    public InboxFolderEntry(Application.FolderContext context) {
        base(context);
        this.display_name = context.folder.account.information.display_name;
        context.folder.account.information.changed.connect(on_information_changed);
    }

    ~InboxFolderEntry() {
        folder.account.information.changed.disconnect(on_information_changed);
    }

    public override string get_sidebar_name() {
        return this.display_name;
    }

    public Convey.AccountInformation get_account_information() {
        return folder.account.information;
    }

    private void on_information_changed(Convey.AccountInformation config) {
        if (this.display_name != config.display_name) {
            this.display_name = config.display_name;
            entry_changed();
        }
    }
}
