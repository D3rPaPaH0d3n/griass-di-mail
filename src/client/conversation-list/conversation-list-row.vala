/* Downstream modification: 2026-10-26 — recipient badges, local contact photos and full identities. */
/*
 * Copyright © 2022 John Renner <john@jrenner.net>
 * Copyright © 2022 Cédric Bellegarde <cedric.bellegarde@adishatz.org>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */


/**
 * A conversation list row displaying an email summary
 */
[GtkTemplate (ui = "/net/donnybeelo/Convey/conversation-list-row.ui")]
internal class ConversationList.Row : Gtk.ListBoxRow {

    private Gee.List<Convey.RFC822.MailboxAddress>? user_accounts  {
        owned get {
            return conversation.base_folder.account.information.sender_mailboxes;
        }
    }

    [GtkChild] unowned Gtk.Box details;
    [GtkChild] unowned Gtk.Box participants_line;
    [GtkChild] unowned Gtk.Box preview_box;
    [GtkChild] unowned Gtk.Image encrypted_icon;
    [GtkChild] unowned Gtk.Label preview;
    [GtkChild] unowned Gtk.Label subject;
    [GtkChild] unowned Gtk.Label participants;
    [GtkChild] unowned Gtk.Label date;
    [GtkChild] unowned Gtk.Label count_badge;
    [GtkChild] unowned Gtk.Box recipient_aliases;
    [GtkChild] unowned Adw.Avatar sender_avatar;

    [GtkChild] unowned Gtk.Image flagged_icon;

    [GtkChild] unowned Gtk.CheckButton selected_button;
    [GtkChild] unowned Gtk.Revealer selected_revealer;

    private Gtk.Revealer revealer = new Gtk.Revealer() {
        transition_type = SLIDE_DOWN,
        transition_duration = ANIMATION_DURATION_MS
    };

    internal const uint ANIMATION_DURATION_MS = 250;
    private const uint DIVIDER_DELAY_MS = 20;

    internal string[] field_order {
        set {
            Gtk.Widget? previous = null;
            foreach (string field in value) {
                Gtk.Widget? widget = get_field_widget(field);
                if (widget != null) {
                    this.details.reorder_child_after(widget, previous);
                    previous = widget;
                }
            }
        }
    }

    internal bool leaving { get; private set; default = false; }
    internal bool entering { get; private set; default = false; }

    private Adw.TimedAnimation? fade_animation = null;

    internal Convey.App.Conversation conversation;
    private Application.Configuration config;
    private Application.DecryptedSubjects decrypted_subjects;
    private DateTime? recv_time;
    private Convey.AccountInformation account_information;
    private ulong flags_changed_id = 0;
    private ulong account_changed_id = 0;
    private ulong aliases_setting_changed_id = 0;
    private Application.ContactStore? contacts;
    private Convey.RFC822.MailboxAddress? avatar_mailbox = null;
    private Convey.Account? avatar_account = null;
    private Application.Contact? avatar_contact = null;
    private GLib.LoadableIcon? avatar_icon = null;
    private GLib.Cancellable? contact_cancellable = null;
    private GLib.Cancellable? image_cancellable = null;
    private uint avatar_generation = 0;
    private bool avatar_disposed = false;
    private ulong pictures_setting_changed_id = 0;
    private ulong contact_avatar_changed_id = 0;
    private ulong contact_changed_id = 0;
    private ulong contact_store_changed_id = 0;

    internal signal void toggle_flag(ConversationList.Row row,
                                     Convey.NamedFlag flag);
    internal signal void toggle_selection(ConversationList.Row row,
                                          bool active);

    internal Row(Application.Configuration config,
                 Application.DecryptedSubjects decrypted_subjects,
                 Convey.App.Conversation conversation,
                 bool selection_mode_enabled,
                 Application.ContactStore? contacts = null) {
        this.config = config;
        this.decrypted_subjects = decrypted_subjects;
        this.conversation = conversation;
        this.account_information = conversation.base_folder.account.information;
        this.contacts = contacts;
        if (contacts != null) {
            this.contact_store_changed_id = contacts.contacts_changed.connect(
                on_desktop_contacts_changed
            );
        }

        Gtk.Widget content = this.child;
        this.child = this.revealer;
        this.revealer.child = content;
        this.revealer.notify["child-revealed"].connect(() => {
            if (this.revealer.child_revealed && this.entering) {
                GLib.Timeout.add(DIVIDER_DELAY_MS, () => {
                    this.entering = false;
                    return GLib.Source.REMOVE;
                });
            }
        });

        this.flags_changed_id = conversation.email_flags_changed.connect(on_email_flags_changed);
        // Sender alias mutators do not notify sender-mailboxes. The account
        // editor emits changed for edits and undo instead.
        this.account_changed_id = this.account_information.changed.connect(
            update_recipient_aliases
        );
        this.aliases_setting_changed_id = config.settings.changed[
            Application.Configuration.DISPLAY_RECIPIENT_ALIASES_KEY
        ].connect(update_recipient_aliases);
        this.pictures_setting_changed_id = config.settings.changed[
            Application.Configuration.DISPLAY_CONTACT_PICTURES_KEY
        ].connect(update_sender_avatar);
        // Only mapped rows perform contact IO. Unmapping cancels outstanding
        // work even if an async continuation still holds a reference to us.
        this.map.connect(update_sender_avatar);
        this.unmap.connect(on_avatar_unmap);

        config.bind(Application.Configuration.DISPLAY_PREVIEW_KEY,
                    this.preview_box, "visible");
        config.bind(Application.Configuration.DISPLAY_PARTICIPANTS_KEY,
                    this.participants, "visible");
        this.participants.notify["visible"].connect(update_participants_line_visibility);
        this.recipient_aliases.notify["visible"].connect(update_participants_line_visibility);
        update_participants_line_visibility();
        config.bind(Application.Configuration.DISPLAY_SUBJECT_KEY,
                    this.subject, "visible");
        config.bind(Application.Configuration.CONVERSATION_LIST_ORDER_KEY,
                    this, "field-order", GET);

        if (selection_mode_enabled) {
            set_selection_enabled(true);
        }

        update();
    }

    protected override void dispose() {
        if (!this.avatar_disposed) {
            this.avatar_disposed = true;
            clear_sender_contact();
        }
        if (this.flags_changed_id != 0) {
            GLib.SignalHandler.disconnect(this.conversation, this.flags_changed_id);
            this.flags_changed_id = 0;
        }
        if (this.account_changed_id != 0) {
            GLib.SignalHandler.disconnect(this.account_information, this.account_changed_id);
            this.account_changed_id = 0;
        }
        if (this.aliases_setting_changed_id != 0) {
            GLib.SignalHandler.disconnect(this.config.settings, this.aliases_setting_changed_id);
            this.aliases_setting_changed_id = 0;
        }
        if (this.pictures_setting_changed_id != 0) {
            GLib.SignalHandler.disconnect(this.config.settings, this.pictures_setting_changed_id);
            this.pictures_setting_changed_id = 0;
        }
        if (this.contact_store_changed_id != 0) {
            GLib.SignalHandler.disconnect(this.contacts, this.contact_store_changed_id);
            this.contact_store_changed_id = 0;
        }
        base.dispose();
    }

    /** Shows the row immediately, without animating. */
    internal void show_now() {
        this.revealer.transition_type = NONE;
        this.revealer.reveal_child = true;
        this.revealer.transition_type = SLIDE_DOWN;
    }

    /** Glides the row open once it is on screen. */
    internal void animate_in() {
        this.entering = true;
        this.opacity = 0;
        if (get_mapped()) {
            reveal();
            return;
        }
        ulong id = 0;
        id = this.map.connect(() => {
            disconnect(id);
            if (!this.leaving) {
                reveal();
            }
        });
    }

    private void reveal() {
        fade(1);
        this.revealer.reveal_child = true;
    }

    /** Fades the row out while gliding it closed. */
    internal void animate_out() {
        this.leaving = true;
        get_header()?.add_css_class("hidden-divider");
        fade(0);
        this.revealer.reveal_child = false;
    }

    private void fade(double to) {
        if (this.fade_animation != null) {
            this.fade_animation.pause();
        }
        var target = new Adw.PropertyAnimationTarget(this, "opacity");
        this.fade_animation = new Adw.TimedAnimation(
            this, this.opacity, to, ANIMATION_DURATION_MS, target
        );
        this.fade_animation.play();
    }

    internal void update() {
        Convey.Email? last_email = conversation.get_latest_recv_email(
            Convey.App.Conversation.Location.IN_FOLDER_OUT_OF_FOLDER
        );

        if (last_email != null) {
            this.subject.set_text(
                this.decrypted_subjects.get_display_subject(last_email)
            );
            bool encrypted = last_email.preview != null && last_email.preview.is_encrypted;
            this.encrypted_icon.visible = encrypted;
            if (encrypted) {
                if (last_email.preview.is_inline_encrypted) {
                    this.encrypted_icon.icon_name = "dialog-password-symbolic";
                    this.encrypted_icon.tooltip_text = _("Encrypted with inline PGP");
                } else {
                    this.encrypted_icon.icon_name = "channel-secure-symbolic";
                    this.encrypted_icon.tooltip_text = null;
                }
                this.preview.set_text(_("Encrypted message"));
                this.preview.add_css_class("encrypted");
            } else {
                this.preview.set_text(
                    Convey.String.reduce_whitespace(last_email.get_preview_as_string())
                );
                this.preview.remove_css_class("encrypted");
            }
        }

        // Clear an unavailable date rather than retaining another summary's
        // timestamp. IMAP properties carry INTERNALDATE, not the Date header.
        this.recv_time = (last_email != null && last_email.properties != null)
            ? last_email.properties.date_received : null;
        refresh_time();

        this.participants.set_markup(get_participants());
        this.participants.tooltip_text = this.participants.get_text();

        var count = conversation.get_count();
        if (count > 1) {
            this.count_badge.set_text(conversation.get_count().to_string());
        } else {
            this.count_badge.hide();
        }

        update_flags(null);

    }

    internal void set_selection_enabled(bool enabled, bool animate = true) {
        if (!animate) {
            this.selected_revealer.transition_type = NONE;
        }
        if (enabled) {
            set_button_active(this.is_selected());
            this.state_flags_changed.connect(update_button);
            this.selected_button.toggled.connect(update_state_flags);
            this.selected_revealer.reveal_child = true;
        } else {
            this.state_flags_changed.disconnect(update_button);
            this.selected_button.toggled.disconnect(update_state_flags);
            set_button_active(false);
            this.selected_revealer.reveal_child = false;
        }
        this.selected_revealer.transition_type = SLIDE_RIGHT;
    }

    internal void refresh_time() {
        // Display the same received timestamp used for sorting, to the
        // second in the desktop timezone, never a rounded relative age.
        this.date.set_text(Util.Date.format_received(this.recv_time));
        this.date.tooltip_text = Util.Date.format_received_tooltip(this.recv_time);
    }

    private void set_button_active(bool active) {
        this.selected_button.set_active(active);
        if (active) {
            this.add_css_class("selected");
            this.set_state_flags(Gtk.StateFlags.SELECTED, false);
        } else {
            this.remove_css_class("selected");
            this.unset_state_flags(Gtk.StateFlags.SELECTED);
        }
    }
    private void update_button() {
        bool is_selected = (Gtk.StateFlags.SELECTED in this.get_state_flags());

        this.selected_button.toggled.disconnect(update_state_flags);
        set_button_active(is_selected);
        this.selected_button.toggled.connect(update_state_flags);

    }

    private void update_state_flags() {
        this.state_flags_changed.disconnect(update_button);
        toggle_selection(this, this.selected_button.get_active());
        this.state_flags_changed.connect(update_button);
    }

    private void on_email_flags_changed(Convey.Email email) {
        // Deletion can change the representative message. Refresh its text
        // and picture together; update_flags() is called by update(), so it
        // must not call update() itself.
        update();
    }

    private void update_flags(Convey.Email? email) {
        if (conversation.is_unread()) {
            add_css_class("unread");
        } else {
            remove_css_class("unread");
        }

        if (conversation.is_flagged()) {
            this.flagged_icon.show();
        } else {
            this.flagged_icon.hide();
        }

        // Keep the optional additions in the shared summary update path.
        update_recipient_aliases();
        update_sender_avatar();
    }

    private void on_desktop_contacts_changed(Gee.Set<string> addresses) {
        if (!this.avatar_disposed && get_mapped() &&
            this.config.display_contact_pictures &&
            this.avatar_mailbox != null &&
            addresses.contains(this.avatar_mailbox.address.normalize().casefold())) {
            // An initials-only engine contact may now have a desktop photo.
            // Cancel the superseded lookup/image before refreshing this row.
            clear_sender_contact();
            update_sender_avatar();
        }
    }

    private void on_avatar_unmap() {
        if (!this.avatar_disposed) {
            clear_sender_contact();
        }
    }

    private void clear_sender_contact() {
        this.avatar_generation++;
        this.contact_cancellable?.cancel();
        this.image_cancellable?.cancel();
        this.contact_cancellable = null;
        this.image_cancellable = null;
        if (this.avatar_contact != null) {
            if (this.contact_avatar_changed_id != 0) {
                GLib.SignalHandler.disconnect(this.avatar_contact, this.contact_avatar_changed_id);
                this.contact_avatar_changed_id = 0;
            }
            if (this.contact_changed_id != 0) {
                GLib.SignalHandler.disconnect(this.avatar_contact, this.contact_changed_id);
                this.contact_changed_id = 0;
            }
        }
        this.avatar_contact = null;
        this.avatar_icon = null;
        this.avatar_mailbox = null;
        this.avatar_account = null;
        this.sender_avatar.custom_image = null;
    }

    private void update_sender_avatar() {
        if (this.avatar_disposed) {
            return;
        }
        bool enabled = this.config.display_contact_pictures;
        this.sender_avatar.visible = enabled;
        var email = enabled ? this.conversation.get_latest_recv_email(
            Convey.App.Conversation.Location.IN_FOLDER_OUT_OF_FOLDER
        ) : null;
        bool outgoing = this.conversation.base_folder.used_as.is_outgoing();
        var mailbox = Util.Email.get_summary_contact_mailbox(email, outgoing);
        if (!enabled || mailbox == null) {
            clear_sender_contact();
            this.sender_avatar.text = "";
            this.sender_avatar.tooltip_text = null;
            this.sender_avatar.update_property(Gtk.AccessibleProperty.LABEL, "", -1);
            return;
        }

        // A single summary sender/recipient, not a face for the whole thread.
        string description = outgoing
            ? _("Recipient of the summary message: %s").printf(mailbox.to_full_display())
            : _("Sender of the summary message: %s").printf(mailbox.to_full_display());
        this.sender_avatar.tooltip_text = description;
        this.sender_avatar.update_property(Gtk.AccessibleProperty.LABEL, description, -1);
        var account = this.conversation.base_folder.account;
        if (this.avatar_mailbox != null &&
            this.avatar_account == account &&
            this.avatar_mailbox.equal_to(mailbox) &&
            this.avatar_mailbox.name == mailbox.name) {
            return;
        }

        clear_sender_contact();
        // Adw.Avatar's text property is plain text; never interpret a header
        // display name as markup. Missing pictures keep these initials.
        this.sender_avatar.text = !mailbox.is_spoofed() &&
            !Convey.String.is_empty_or_whitespace(mailbox.name)
            ? mailbox.name : mailbox.mailbox;
        if (!get_mapped()) {
            return;
        }
        this.avatar_mailbox = mailbox;
        this.avatar_account = account;
        if (this.contacts != null && this.contacts.account == account) {
            var cancellable = new GLib.Cancellable();
            this.contact_cancellable = cancellable;
            load_sender_contact.begin(mailbox, this.avatar_generation, cancellable);
        }
    }

    private bool is_current_sender(Convey.RFC822.MailboxAddress mailbox,
                                   uint generation,
                                   GLib.Cancellable cancellable) {
        return !this.avatar_disposed && get_mapped() &&
            this.config.display_contact_pictures &&
            !cancellable.is_cancelled() &&
            this.contact_cancellable == cancellable &&
            this.avatar_generation == generation &&
            this.avatar_account == this.conversation.base_folder.account &&
            this.avatar_mailbox != null && this.avatar_mailbox.equal_to(mailbox);
    }

    private async void load_sender_contact(Convey.RFC822.MailboxAddress mailbox,
                                           uint generation,
                                           GLib.Cancellable cancellable) {
        try {
            var contact = yield this.contacts.load(mailbox, cancellable);
            if (!is_current_sender(mailbox, generation, cancellable)) {
                return;
            }
            this.avatar_contact = contact;
            this.contact_avatar_changed_id = contact.notify["avatar"].connect(
                refresh_sender_image
            );
            this.contact_changed_id = contact.changed.connect(on_sender_contact_changed);
            on_sender_contact_changed();
        } catch (GLib.IOError.CANCELLED err) {
            // A new sender, toggle, unmap or disposal superseded this lookup.
        } catch (GLib.Error err) {
            if (is_current_sender(mailbox, generation, cancellable)) {
                debug("Couldn't load summary contact: %s", err.message);
            }
        }
    }

    private void on_sender_contact_changed() {
        if (this.avatar_contact != null) {
            if (!Convey.String.is_empty_or_whitespace(this.avatar_contact.display_name)) {
                this.sender_avatar.text = this.avatar_contact.display_name;
            }
            if (this.avatar_icon != this.avatar_contact.avatar) {
                refresh_sender_image();
            }
        }
    }

    private void refresh_sender_image() {
        this.image_cancellable?.cancel();
        this.image_cancellable = null;
        this.sender_avatar.custom_image = null;
        this.avatar_icon = this.avatar_contact != null ? this.avatar_contact.avatar : null;
        var mailbox = this.avatar_mailbox;
        var request = this.contact_cancellable;
        var icon = this.avatar_icon;
        if (mailbox != null && request != null && icon != null &&
            is_current_sender(mailbox, this.avatar_generation, request)) {
            var cancellable = new GLib.Cancellable();
            this.image_cancellable = cancellable;
            load_sender_image.begin(icon, mailbox, this.avatar_generation, request, cancellable);
        }
    }

    private async void load_sender_image(GLib.LoadableIcon icon,
                                         Convey.RFC822.MailboxAddress mailbox,
                                         uint generation,
                                         GLib.Cancellable request,
                                         GLib.Cancellable cancellable) {
        GLib.InputStream? stream = null;
        try {
            stream = yield icon.load_async(this.sender_avatar.size, cancellable);
            if (cancellable.is_cancelled()) {
                return;
            }
            var pixbuf = yield new Gdk.Pixbuf.from_stream_at_scale_async(
                stream, this.sender_avatar.size, this.sender_avatar.size, true, cancellable
            );
            if (is_current_sender(mailbox, generation, request) &&
                !cancellable.is_cancelled() && this.image_cancellable == cancellable &&
                this.avatar_icon == icon) {
                this.sender_avatar.custom_image = Gdk.Texture.for_pixbuf(pixbuf);
            }
        } catch (GLib.IOError.CANCELLED err) {
            // Keep initials, and never replace a newer sender's picture.
        } catch (GLib.Error err) {
            if (is_current_sender(mailbox, generation, request) &&
                this.image_cancellable == cancellable) {
                debug("Couldn't load summary contact picture: %s", err.message);
            }
        } finally {
            if (stream != null) {
                try {
                    yield stream.close_async(GLib.Priority.DEFAULT, null);
                } catch (GLib.Error err) {
                    debug("Couldn't close contact picture stream: %s", err.message);
                }
            }
        }
    }

    private void update_participants_line_visibility() {
        this.participants_line.visible =
            this.participants.visible || this.recipient_aliases.visible;
    }

    private void update_recipient_aliases() {
        this.recipient_aliases.visible = false;
        var child = this.recipient_aliases.get_first_child();
        while (child != null) {
            this.recipient_aliases.remove(child);
            child = this.recipient_aliases.get_first_child();
        }
        this.recipient_aliases.tooltip_text = null;
        this.recipient_aliases.update_property(Gtk.AccessibleProperty.LABEL, "", -1);
        if (!this.config.display_recipient_aliases ||
            this.conversation.base_folder.used_as.is_outgoing() ||
            this.conversation.base_folder.used_as == DRAFTS) {
            return;
        }

        // Both APIs below only inspect the existing model. In All Inboxes,
        // use this conversation's account, never the other visible accounts.
        var emails = this.conversation.get_emails(
            Convey.App.Conversation.Ordering.NONE
        );
        var excluded_ids = new Gee.HashSet<Convey.EmailIdentifier>();
        foreach (var folder in this.conversation.base_folder.account.list_folders()) {
            if (folder.used_as.is_outgoing() || folder.used_as == DRAFTS) {
                foreach (var email in emails) {
                    if (this.conversation.is_in_folder(email.id, folder.path)) {
                        excluded_ids.add(email.id);
                    }
                }
            }
        }
        var matches = Util.Email.get_recipient_aliases(
            emails, this.account_information.sender_mailboxes, excluded_ids
        );
        if (matches.is_empty) {
            return;
        }

        string[] addresses = {};
        uint shown = 0;
        foreach (var match in matches) {
            addresses += match.address;
            // Keep the sender line one line high even with many aliases.
            // Remaining exact addresses stay in the full tooltip/accessible
            // description; the neutral +N marker makes overflow explicit.
            if (shown >= 2) {
                continue;
            }
            // Leading badges share the header's fixed start; only their
            // ellipsized width, never their start, depends on the date width.
            // Short minima let two badges and +N yield space to the sender.
            // Exact address identifies the alias; colour is an additional cue.
            var badge = new Gtk.Label(match.address) {
                use_markup = false,
                single_line_mode = true,
                ellipsize = Pango.EllipsizeMode.END,
                width_chars = 2,
                max_width_chars = matches.size > 1 ? 14 : 20,
                xalign = 0,
                can_focus = false,
                tooltip_text = match.address
            };
            badge.add_css_class("recipient-alias-badge");
            badge.add_css_class("alias-colour-%u".printf(
                Util.Email.get_recipient_alias_color(
                    match, this.account_information.sender_mailboxes
                )
            ));
            badge.update_property(Gtk.AccessibleProperty.LABEL, match.address, -1);
            this.recipient_aliases.append(badge);
            shown++;
        }
        // Translators: %s lists all configured addresses matched in To/Cc.
        string description = _("Configured account addresses in To/Cc of loaded messages in this conversation, excluding drafts, deleted messages and apparent outgoing mail. Not a verified delivery address:\n%s").printf(
            string.joinv(", ", addresses)
        );
        this.recipient_aliases.tooltip_text = description;
        this.recipient_aliases.update_property(
            Gtk.AccessibleProperty.LABEL, description, -1
        );
        if (matches.size > shown) {
            var overflow = new Gtk.Label("+%u".printf(matches.size - shown)) {
                can_focus = false,
                tooltip_text = description
            };
            overflow.add_css_class("recipient-alias-badge");
            overflow.add_css_class("alias-overflow");
            overflow.update_property(Gtk.AccessibleProperty.LABEL, description, -1);
            this.recipient_aliases.append(overflow);
        }
        this.recipient_aliases.visible = true;
    }

    private Gtk.Widget? get_field_widget(string field) {
        switch (field) {
        case "participants":
            return this.participants_line;
        case "subject":
            return this.subject;
        case "preview":
            return this.preview_box;
        default:
            return null;
        }
    }

    private string get_participants() {
        var participants = new Gee.ArrayList<Participant>();
        var addresses = new Convey.RFC822.MailboxAddresses();
        Gee.List<Convey.Email> emails = conversation.get_emails(
                          Convey.App.Conversation.Ordering.RECV_DATE_ASCENDING);
        bool is_outgoing = conversation.base_folder.used_as.is_outgoing();
        foreach (Convey.Email message in emails) {
            Convey.RFC822.MailboxAddresses? addrs =
                is_outgoing
                ? message.to
                : message.from;
            if (addrs != null) {
                addresses = addresses.merge_list(addrs);
            } else if (!is_outgoing && message.sender != null) {
                addresses = addresses.merge_list(
                    new Convey.RFC822.MailboxAddresses.single(message.sender)
                );
            }
        }

        Gee.List<Convey.RFC822.MailboxAddress> list = Convey.traverse(
            addresses.get_all()
        ).filter((address) => {
            // In sent, we only want to show "Me"
            if (is_outgoing && addresses.size > 1) {
                foreach (var account in this.user_accounts) {
                    if (account.equal_to(address)) {
                        return false;
                    }
                }
            }
            return true;
        }).to_array_list();

        foreach (Convey.RFC822.MailboxAddress address in list) {
            Participant participant_display = new Participant(address);
            int existing_index = participants.index_of(participant_display);
            if (existing_index < 0) {
                participants.add(participant_display);
                continue;
            }
        }

        if (participants.size == 0) {
            return "";
        }

        if(participants.size == 1) {
            return participants[0].get_full_markup(this.user_accounts);
        }

        StringBuilder builder = new StringBuilder();
        bool first = true;
        foreach (Participant participant in participants) {
            if (!first) {
                builder.append(", ");
            }

            builder.append(participant.get_short_markup(this.user_accounts));
            first = false;
        }

        return builder.str;
    }
}
