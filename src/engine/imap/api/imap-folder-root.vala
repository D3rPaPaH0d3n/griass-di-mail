/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2019 Michael Gratton <mike@vee.net>.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * The root of all IMAP mailbox paths.
 *
 * Because IMAP has peculiar requirements about its mailbox paths (in
 * particular, Inbox is guaranteed at the root and is named
 * case-insensitive, and that delimiters are particular to each path),
 * this class ensure certain requirements are held throughout the
 * library.
 */
public class Convey.Imap.FolderRoot : Convey.FolderRoot {


   /**
     * The canonical path for the IMAP inbox.
     *
     * This specific path object will always be returned when a child
     * with some case-insensitive version of the IMAP inbox mailbox is
     * obtained via {@link get_child} from this root folder. However
     * since multiple folder roots may be constructed, in general
     * {@link FolderPath.equal_to} or {@link FolderPath.compare_to}
     * should still be used for testing equality with this path.
     */
    public FolderPath inbox { get; private set; }


    public FolderRoot(string label) {
        base(label, false);
        this.inbox = base.get_child(
            MailboxSpecifier.CANONICAL_INBOX_NAME,
            Trillian.FALSE
        );
    }

    /**
     * Creates a path that is a child of this folder.
     *
     * If the given basename is that of the IMAP inbox, then {@link
     * inbox} will be returned.
     */
    public override
        FolderPath get_child(string basename,
                             Trillian is_case_sensitive = Trillian.UNKNOWN) {
        return (MailboxSpecifier.is_inbox_name(basename))
            ? this.inbox
            : base.get_child(basename, is_case_sensitive);
    }

}
