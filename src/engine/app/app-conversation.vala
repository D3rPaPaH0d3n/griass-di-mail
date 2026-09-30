/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class Convey.App.Conversation : BaseObject {
    /**
     * Specify the ordering of {@link Email} returned by various accessors.
     *
     * Note that sorting in {@link Conversation} is done by the RFC822 Date: header (i.e.
     * {@link Email.date}) and not the date received (i.e. {@link EmailProperties.date_received}).
     */
    public enum Ordering {
        NONE,
        SENT_DATE_ASCENDING,
        SENT_DATE_DESCENDING,
        RECV_DATE_ASCENDING,
        RECV_DATE_DESCENDING
    }

    /**
     * Specify the location of the {@link Email} in relation to the base folder being monitored
     * by the {@link Conversation}'s {@link ConversationMonitor}.
     *
     * IN_FOLDER represents Email that is found in the Folder the ConversationMonitor is
     * monitoring.  OUT_OF_FOLDER means the Email is located elsewhere in the {@link Account}.
     *
     * Some methods honor IN_FOLDER_OUT_OF_FOLDER and OUT_OF_FOLDER_IN_FOLDER.  These represent
     * preferences for finding an Email.  The first (IN_FOLDER / OUT_OF_FOLDER) is searched.  If
     * an Email is not found in that location, the other criteria is used.
     */
    public enum Location {
        IN_FOLDER,
        OUT_OF_FOLDER,
        IN_FOLDER_OUT_OF_FOLDER,
        OUT_OF_FOLDER_IN_FOLDER,
        ANYWHERE
    }

    private static int next_convnum = 0;

    /** Folder from which the conversation originated. */
    public Folder base_folder { get; private set; }

    /** Cache of paths associated with each email */
    internal Gee.HashMultiMap<Convey.EmailIdentifier,Convey.FolderPath> path_map {
        get;
        private set;
        default = new Gee.HashMultiMap< Convey.EmailIdentifier,Convey.FolderPath>();
    }

    private Gee.HashMultiSet<RFC822.MessageID> message_ids = new Gee.HashMultiSet<RFC822.MessageID>();

    private int convnum;

    private Gee.HashMap<EmailIdentifier, Email> emails = new Gee.HashMap<EmailIdentifier, Email>();

    // Copying a message to another folder produces a second, separate
    // message on the server, which the conversation would otherwise
    // show twice. Only the first copy of each Message-ID is held in
    // `emails`; the rest are folded away here and presented as one.
    private Gee.HashMap<RFC822.MessageID,EmailIdentifier> primary_ids =
        new Gee.HashMap<RFC822.MessageID,EmailIdentifier>();
    private Gee.HashMap<EmailIdentifier,Email> folded =
        new Gee.HashMap<EmailIdentifier,Email>();
    private Gee.HashMap<EmailIdentifier,EmailIdentifier> copy_of =
        new Gee.HashMap<EmailIdentifier,EmailIdentifier>();

    // this isn't ideal but the cost of adding an email to multiple sorted sets once versus
    // the number of times they're accessed makes it worth it
    private Gee.SortedSet<Email> sent_date_ascending = new Gee.TreeSet<Email>(
        Convey.Email.compare_sent_date_ascending);
    private Gee.SortedSet<Email> sent_date_descending = new Gee.TreeSet<Email>(
        Convey.Email.compare_sent_date_descending);
    private Gee.SortedSet<Email> recv_date_ascending = new Gee.TreeSet<Email>(
        Convey.Email.compare_recv_date_ascending);
    private Gee.SortedSet<Email> recv_date_descending = new Gee.TreeSet<Email>(
        Convey.Email.compare_recv_date_descending);

    /**
     * Fired when email has been added to this conversation.
     */
    public signal void appended(Convey.Email email);

    /**
     * Fired when email has been trimmed from this conversation.
     */
    public signal void trimmed(Convey.Email email);

    /**
     * Fired when the flags of an email in this conversation have changed.
     */
    public signal void email_flags_changed(Convey.Email email);


    /**
     * Constructs a conversation relative to the given base folder.
     */
    internal Conversation(Convey.Folder base_folder) {
        this.convnum = Conversation.next_convnum++;
        this.base_folder = base_folder;
    }

    /**
     * Returns the number of emails in the conversation.
     */
    public int get_count() {
        return emails.size;
    }

    /**
     * Returns the number of emails in the conversation in a particular folder.
     */
    public uint get_count_in_folder(FolderPath path) {
        uint count = 0;
        foreach (Convey.EmailIdentifier id in this.emails.keys) {
            if (is_in_folder(id, path)) {
                count++;
            }
        }
        return count;
    }

    /**
     * Returns true if *any* message in the conversation is unread.
     */
    public bool is_unread() {
        return has_flag(Convey.EmailFlags.UNREAD);
    }

    /**
     * Returns true if any message in the conversation is not unread.
     */
    public bool has_any_read_message() {
        return is_missing_flag(Convey.EmailFlags.UNREAD);
    }

    /**
     * Returns true if *any* message in the conversation is flagged.
     */
    public bool is_flagged() {
        return has_flag(Convey.EmailFlags.FLAGGED);
    }

    /**
     * Determines if the conversation contains un-deleted email messages.
     */
    public bool has_any_non_deleted_email() {
        return traverse(this.emails.values).any(e => !e.email_flags.is_deleted());
    }

    /**
     * Returns the earliest (first sent) email in the Conversation.
     *
     * Note that here, sent denotes the value of the Date header, not
     * being contained in the Sent folder.
     */
    public Email?
        get_earliest_sent_email(Location location,
                                Gee.Collection<FolderPath>? blacklist = null) {
        return get_single_email(Ordering.SENT_DATE_ASCENDING, location, blacklist);
    }

    /**
     * Returns the latest (most recently sent) email in the Conversation.
     *
     * Note that here, sent denotes the value of the Date header, not
     * being contained in the Sent folder.
     */
    public Email?
        get_latest_sent_email(Location location,
                              Gee.Collection<FolderPath>? blacklist = null) {
        return get_single_email(Ordering.SENT_DATE_DESCENDING, location);
    }

    /**
     * Returns the earliest (first received) email in the Conversation.
     */
    public Email?
        get_earliest_recv_email(Location location,
                                Gee.Collection<FolderPath>? blacklist = null) {
        return get_single_email(Ordering.RECV_DATE_ASCENDING, location);
    }

    /**
     * Returns the latest (most recently received) email in the Conversation.
     */
    public Email?
        get_latest_recv_email(Location location,
                              Gee.Collection<FolderPath>? blacklist = null) {
        return get_single_email(Ordering.RECV_DATE_DESCENDING, location);
    }

    public Gee.Collection<Email>
        get_emails_flagged_for_deletion(Location location,
                                        Gee.Collection<FolderPath>? blacklist = null) {
        Gee.Collection<Email> emails = get_emails(Ordering.NONE, location, blacklist, false);
        Iterable<Email> filtered = traverse<Email>(emails);
        return filtered.filter(
            (e) => e.email_flags.is_deleted()
        ).to_array_list();
    }

    /**
     * Returns the conversation's email, possibly sorted and filtered.
     *
     * {@link Location.IN_FOLDER} and {@link Location.OUT_OF_FOLDER} are the
     * only preferences honored; the others ({@link Location.IN_FOLDER_OUT_OF_FOLDER},
     * {@link Location.IN_FOLDER_OUT_OF_FOLDER}, and {@link Location.ANYWHERE}
     * are all treated as ANYWHERE.
     */
    public Gee.List<Email>
        get_emails(Ordering ordering,
                   Location location = Location.ANYWHERE,
                   Gee.Collection<FolderPath>? blacklist = null,
                   bool filter_deleted = true) {
        Gee.Collection<Email> email;
        switch (ordering) {
            case Ordering.SENT_DATE_ASCENDING:
                email = sent_date_ascending;
            break;

            case Ordering.SENT_DATE_DESCENDING:
                email = sent_date_descending;
            break;

            case Ordering.RECV_DATE_ASCENDING:
                email = recv_date_ascending;
            break;

            case Ordering.RECV_DATE_DESCENDING:
                email = recv_date_descending;
            break;

            case Ordering.NONE:
                email = emails.values;
            break;

            default:
                assert_not_reached();
        }

        Iterable<Email> filtered = traverse<Email>(email);
        switch (location) {
        case Location.IN_FOLDER:
            filtered = filtered.filter((e) => is_in_base_folder(e.id));
            break;

        case Location.OUT_OF_FOLDER:
            filtered = filtered.filter((e) => !is_in_base_folder(e.id));
            break;

        default:
            // Nothing to do
            break;
        }

        // Filter emails waiting to be expunged (\DELETED)
        if (filter_deleted) {
            filtered = filtered.filter(
                (e) => (e.email_flags != null) ? !e.email_flags.is_deleted() : true
            );
        }

        if (blacklist != null && !blacklist.is_empty) {
            if (blacklist.size == 1) {
                FolderPath blacklist_path =
                    traverse<FolderPath>(blacklist).first();
                filtered = filtered.filter(
                    (e) => !this.path_map.get(e.id).contains(blacklist_path)
                );
            } else {
                filtered = filtered.filter(
                    (e) => this.path_map.get(e.id).any_match(
                        (p) => !blacklist.contains(p)
                    )
                );
            }
        }

        return filtered.to_array_list();
    }

    /**
     * Determines if the given id is in the conversation's base folder.
     */
    public bool is_in_base_folder(Convey.EmailIdentifier id) {
        return is_in_folder(id, this.base_folder.path);
    }

    /**
     * Determines if the message with the given id is in the given folder.
     *
     * Any folded-away copy of the message counts, since they are all
     * presented as the same message.
     */
    public bool is_in_folder(Convey.EmailIdentifier id, FolderPath path) {
        foreach (var candidate in with_copies(id)) {
            Gee.Collection<Convey.FolderPath>? paths = this.path_map.get(candidate);
            if (paths != null && paths.contains(path)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Returns the number of folders the message with the given id is in.
     */
    public uint get_folder_count(Convey.EmailIdentifier id) {
        var paths = new Gee.HashSet<Convey.FolderPath>();
        foreach (var candidate in with_copies(id)) {
            Gee.Collection<Convey.FolderPath>? in_folder = this.path_map.get(candidate);
            if (in_folder != null) {
                paths.add_all(in_folder);
            }
        }
        return paths.size;
    }

    /**
     * Returns every identifier for the given message in the given folder.
     *
     * Copying a message leaves several distinct copies of it on the
     * server, so acting on "the message in this folder" means acting on
     * all of them — and on none of the copies living elsewhere.
     */
    public Gee.Collection<Convey.EmailIdentifier>
        get_ids_in_folder(Convey.EmailIdentifier id, FolderPath path) {
        var ids = new Gee.ArrayList<Convey.EmailIdentifier>();
        foreach (var candidate in with_copies(id)) {
            Gee.Collection<Convey.FolderPath>? paths = this.path_map.get(candidate);
            if (paths != null && paths.contains(path)) {
                ids.add(candidate);
            }
        }
        return ids;
    }

    // The given id plus any copies of the same message folded into it.
    public Gee.Collection<Convey.EmailIdentifier>
        with_copies(Convey.EmailIdentifier id) {
        var ids = new Gee.ArrayList<Convey.EmailIdentifier>();
        ids.add(id);
        foreach (var entry in this.copy_of.entries) {
            if (entry.value.equal_to(id)) {
                ids.add(entry.key);
            }
        }
        return ids;
    }

    /**
     * Determines if the message or any copy folded into it is unread.
     */
    public bool has_unread_copy(Convey.EmailIdentifier id) {
        foreach (var copy in with_copies(id)) {
            Convey.Email? email = get_copy_by_id(copy);
            if (email != null && email.is_unread().is_certain()) {
                return true;
            }
        }
        return false;
    }

    /**
     * Returns the email with exactly the given id, including folded copies.
     */
    public Convey.Email? get_copy_by_id(EmailIdentifier id) {
        return this.emails.get(id) ?? this.folded.get(id);
    }

    /**
     * Returns the copies folded into other emails in the conversation.
     */
    internal Gee.Collection<Email> get_folded() {
        return this.folded.values;
    }

    /**
     * Determines if an email with the give id exists in the conversation.
     */
    public bool contains_email_by_id(EmailIdentifier id) {
        return emails.has_key(id) || this.folded.has_key(id);
    }

    /**
     * Returns the email associated with the EmailIdentifier, if it exists.
     */
    public Convey.Email? get_email_by_id(EmailIdentifier id) {
        Convey.Email? email = emails.get(id);
        // A copy resolves to the message it was folded into
        if (email == null) {
            EmailIdentifier? primary = this.copy_of.get(id);
            if (primary != null) {
                email = emails.get(primary);
            }
        }
        return email;
    }

    /**
     * Returns all EmailIdentifiers in the conversation, unsorted.
     */
    public Gee.Collection<Convey.EmailIdentifier> get_email_ids() {
        return emails.keys;
    }

    /**
     * Return all Message IDs associated with the conversation.
     */
    public Gee.Collection<RFC822.MessageID> get_message_ids() {
        // Turn into a HashSet first, so we don't return duplicates.
        Gee.HashSet<RFC822.MessageID> ids = new Gee.HashSet<RFC822.MessageID>();
        ids.add_all(message_ids);
        return ids;
    }

    /**
     * Returns a string representation for debugging.
     */
    public string to_string() {
        return "[#%d] (%d emails)".printf(convnum, emails.size);
    }

    /**
     * Add the email to the conversation if not already present.
     *
     * The value of `known_paths` should contain all the known {@link
     * FolderPath} instances this email is contained within.
     *
     * Returns if the email was added, else false if already present
     * and only `known_paths` were merged.
     */
    internal bool add(Email email, Gee.Collection<Convey.FolderPath> known_paths) {
        // Add the known paths to the path map regardless of whether
        // the email is already in the conversation or not, so that it
        // remains complete
        foreach (Convey.FolderPath path in known_paths)
            this.path_map.set(email.id, path);

        if (this.emails.has_key(email.id) || this.folded.has_key(email.id))
            return false;

        // Fold copies of a message already here into the one on show
        RFC822.MessageID? message_id = email.message_id;
        if (message_id != null) {
            EmailIdentifier? primary = this.primary_ids.get(message_id);
            if (primary != null) {
                // Accepted into the conversation, but shown as part of
                // the copy already here rather than as its own message
                this.folded.set(email.id, email);
                this.copy_of.set(email.id, primary);
                return true;
            }
            this.primary_ids.set(message_id, email.id);
        }

        bool added = false;
        if (!emails.has_key(email.id)) {
            this.emails.set(email.id, email);
            this.sent_date_ascending.add(email);
            this.sent_date_descending.add(email);
            this.recv_date_ascending.add(email);
            this.recv_date_descending.add(email);

            Gee.Set<RFC822.MessageID>? ancestors = email.get_ancestors();
            if (ancestors != null)
                message_ids.add_all(ancestors);

            appended(email);
            added = true;
        }
        return added;
    }

    /**
     * Unconditionally removes an email from the conversation.
     *
     * Returns all Message-IDs that should be removed as result of
     * removing this message, or `null` if none were removed.
     */
    internal Gee.Set<RFC822.MessageID>? remove(Email email) {
        Gee.Set<RFC822.MessageID>? removed_ids = null;

        // A folded copy going away leaves the message itself on show
        if (this.folded.unset(email.id)) {
            this.copy_of.unset(email.id);
            this.path_map.remove_all(email.id);
            return null;
        }

        // If the copy on show is the one going away, another stands in
        // for it rather than the message vanishing from the thread
        if (this.emails.has_key(email.id) && promote_copy(email)) {
            return null;
        }

        if (emails.unset(email.id)) {
            this.sent_date_ascending.remove(email);
            this.sent_date_descending.remove(email);
            this.recv_date_ascending.remove(email);
            this.recv_date_descending.remove(email);
            this.path_map.remove_all(email.id);

            Gee.Set<RFC822.MessageID>? ancestors = email.get_ancestors();
            if (ancestors != null) {
                removed_ids = new Gee.HashSet<RFC822.MessageID>();
                foreach (RFC822.MessageID ancestor_id in ancestors) {
                    // if remove() changes set (i.e. it was present) but no longer present, that
                    // means the ancestor_id was the last one and is formally removed
                    if (message_ids.remove(ancestor_id) &&
                        !message_ids.contains(ancestor_id)) {
                        removed_ids.add(ancestor_id);
                    }
                }

                if (removed_ids.size == 0) {
                    removed_ids = null;
                }
            }


            trimmed(email);
        }

        return removed_ids;
    }

    /**
     * Removes the target path from the known set for the given id.
     */
    internal void remove_path(Convey.EmailIdentifier id, FolderPath path) {
        this.path_map.remove(id, path);
    }

    // Puts one of the folded copies of the given email on show in its
    // place. Returns false if there were none.
    private bool promote_copy(Email email) {
        Email? replacement = null;
        var others = new Gee.ArrayList<Convey.EmailIdentifier>();
        foreach (var entry in this.copy_of.entries) {
            if (!entry.value.equal_to(email.id)) {
                continue;
            }
            if (replacement == null) {
                replacement = this.folded.get(entry.key);
            } else {
                others.add(entry.key);
            }
        }
        if (replacement == null) {
            return false;
        }

        this.folded.unset(replacement.id);
        this.copy_of.unset(replacement.id);
        foreach (var other in others) {
            this.copy_of.set(other, replacement.id);
        }

        this.emails.unset(email.id);
        this.emails.set(replacement.id, replacement);
        this.sent_date_ascending.remove(email);
        this.sent_date_ascending.add(replacement);
        this.sent_date_descending.remove(email);
        this.sent_date_descending.add(replacement);
        this.recv_date_ascending.remove(email);
        this.recv_date_ascending.add(replacement);
        this.recv_date_descending.remove(email);
        this.recv_date_descending.add(replacement);
        this.path_map.remove_all(email.id);

        RFC822.MessageID? message_id = email.message_id;
        if (message_id != null) {
            this.primary_ids.set(message_id, replacement.id);
        }
        return true;
    }

    private Convey.Email?
        get_single_email(Ordering ordering, Location location,
                         Gee.Collection<Convey.FolderPath>? blacklist = null) {
        // note that the location-ordering preferences are treated as
        // ANYWHERE by get_emails()
        Gee.Collection<Convey.Email> all = get_emails(
            ordering, location, blacklist
        );
        if (all.size == 0) {
            return null;
        }

        // Because IN_FOLDER_OUT_OF_FOLDER and OUT_OF_FOLDER_IN_FOLDER
        // are treated as ANYWHERE, have to do our own filtering
        switch (location) {
            case Location.IN_FOLDER:
            case Location.OUT_OF_FOLDER:
            case Location.ANYWHERE:
                return traverse<Email>(all).first();

            case Location.IN_FOLDER_OUT_OF_FOLDER:
                Convey.Email? found = traverse<Email>(all)
                    .first_matching((email) => is_in_base_folder(email.id));

                return found ?? traverse<Email>(all).first();

            case Location.OUT_OF_FOLDER_IN_FOLDER:
                Convey.Email? found = traverse<Email>(all)
                    .first_matching((email) => !is_in_base_folder(email.id));

                return found ?? traverse<Email>(all).first();

            default:
                assert_not_reached();
        }
    }

    private bool check_flag(Convey.NamedFlag flag, bool contains) {
        var emails_with_folds = new Gee.ArrayList<Convey.Email>();
        emails_with_folds.add_all(get_emails(Ordering.NONE));
        emails_with_folds.add_all(this.folded.values);

        foreach (Convey.Email email in emails_with_folds) {
            if (email.email_flags != null && email.email_flags.contains(flag) == contains)
                return true;
        }

        return false;
    }

    private bool has_flag(Convey.NamedFlag flag) {
        return check_flag(flag, true);
    }

    private bool is_missing_flag(Convey.NamedFlag flag) {
        return check_flag(flag, false);
    }

}
