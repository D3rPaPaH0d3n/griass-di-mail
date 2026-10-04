/*
 * Copyright © 2022 John Renner <john@jrenner.net>
 * Copyright © 2022 Cédric Bellegarde <cedric.bellegarde@adishatz.org>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/**
 * Represents in folder conversations list.
 *
 */
[GtkTemplate (ui = "/net/donnybeelo/Convey/conversation-list-view.ui")]
public class ConversationList.View : Adw.Bin, Convey.BaseInterface {

    /**
     * The fields that must be available on any ConversationMonitor
     * passed to ConversationList.View
     */
    public const Convey.Email.Field REQUIRED_FIELDS = (
        Convey.Email.Field.ENVELOPE |
        Convey.Email.Field.FLAGS |
        Convey.Email.Field.PROPERTIES
    );

    [CCode(notify = false)]
    public bool selection_mode_enabled {
        get {
            return this.list.get_selection_mode() == Gtk.SelectionMode.MULTIPLE;
        }
        set {
            Gtk.SelectionMode mode = value ? Gtk.SelectionMode.MULTIPLE : Gtk.SelectionMode.SINGLE;
            if (this.list.get_selection_mode() != mode) {
                this.list.set_selection_mode(mode);
                notify_property("selection-mode-enabled");
            }
        }
    }

    public Gee.Set<Convey.App.Conversation> selected {
        get; set; default = new Gee.HashSet<Convey.App.Conversation>();
    }

    private Application.Configuration config;

    private Gtk.GestureLongPress long_press_gesture;
    private Gdk.ModifierType last_modifier_type;

    [GtkChild] public unowned Gtk.ScrolledWindow scrolled_window;

    [GtkChild] private unowned Gtk.ListBox list;

    /*
     * Use to restore selected row when exiting selection/edition
     */
    private Gtk.ListBoxRow? to_restore_row = null;

    public View(Application.Configuration config) {
        this.config = config;

        var overlay = new Gtk.Overlay();
        Gtk.Widget scrolled = this.child;
        this.child = overlay;
        overlay.child = scrolled;
        overlay.add_overlay(this.old_list);

        this.notify["selection-mode-enabled"].connect(on_selection_mode_changed);

        this.list.selected_rows_changed.connect(on_selected_rows_changed);
        this.list.selected_rows_changed.connect(update_separators);
        this.list.row_activated.connect(on_row_activated);

        this.list.set_header_func(header_func);

        this.scrolled_window.vadjustment.value_changed.connect(maybe_load_more);
        this.scrolled_window.vadjustment.value_changed.connect(update_visible_conversations);

        this.long_press_gesture = new Gtk.GestureLongPress();
        this.long_press_gesture.propagation_phase = CAPTURE;
        this.long_press_gesture.pressed.connect((n_press, x, y) => {
            Row? row = (Row) this.list.get_row_at_y((int) y);
            if (row != null) {
                this.list.unselect_all();
                this.selection_mode_enabled = true;
            }
        });
        this.list.add_controller(this.long_press_gesture);

        var drag_source = new Gtk.DragSource();
        drag_source.actions = Gdk.DragAction.COPY | Gdk.DragAction.MOVE;
        drag_source.prepare.connect(on_drag_prepare);
        drag_source.drag_begin.connect(on_drag_begin);
        drag_source.drag_end.connect(on_drag_end);
        this.list.add_controller(drag_source);
    }

    static construct {
        set_css_name("conversation-list");
    }

    // -------
    //   UI
    // -------
    private void header_func(Gtk.ListBoxRow row, Gtk.ListBoxRow? before) {
        if (before != null) {
            if (row.get_header() == null) {
                var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
                sep.add_css_class("conversation-list-separator");
                sep.show();
                row.set_header(sep);
            }
        } else {
            // First row: drop any separator left over from when it wasn't
            // first (e.g. after the previous top row was deleted).
            row.set_header(null);
        }
    }

    /**
     * Updates the display of the received time on each list row.
     *
     * Because the received time is displayed as relative to the current time,
     * it must be periodically updated. ConversationList.View does not do this
     * automatically but instead it must be externally scheduled
     */
    public void refresh_times() {
        int i = 0;
        Row? row = this.list.get_row_at_index(0) as Row;
        while (row != null) {
            row.refresh_time();
            i++;
            row = this.list.get_row_at_index(i) as Row;
        }
    }

    // -------------------
    //  Model Management
    // -------------------

    /**
     * The currently bound model
     */
    private Model? model;

    private Adw.TimedAnimation? list_fade = null;

    private const uint SWITCH_FADE_OUT_MS = 150;

    // Still image of the previous folder's list, faded out over the new one
    private Gtk.Picture old_list = new Gtk.Picture() {
        can_target = false,
        visible = false
    };
    private Adw.TimedAnimation? old_list_fade = null;

    /**
     * Set the conversation monitors which the listview is displaying.
     *
     * Conversations from every monitor are merged into a single date
     * ordered list, as used by the combined inbox view.
     */
    public void set_monitors(Gee.Collection<Convey.App.ConversationMonitor>? monitors) {
        if (this.model != null && this.list.opacity > 0) {
            fade_out_old_list();
        }
        if (this.model != null) {
            this.model.conversations_loaded.disconnect(on_conversations_loaded);
            this.model.conversations_removed.disconnect(on_conversations_removed);
            this.model.conversation_updated.disconnect(on_conversation_updated);
            this.model.conversation_leaving.disconnect(on_conversation_leaving);
            this.model.ready.disconnect(on_model_ready);
        }
        if (this.list_fade != null) {
            this.list_fade.skip();
            this.list_fade = null;
        }

        if (monitors == null || monitors.is_empty) {
            this.model = null;
            this.list.opacity = 1;
            this.list.bind_model(null, row_factory);
        } else {
            this.model = new Model(monitors);
            this.list.opacity = 0;
            this.model.ready.connect(on_model_ready);
            this.list.bind_model(this.model, row_factory);
            // bind_model doesn't re-run the header func for neighbours when
            // items change, so a deleted top row leaves the new top row with a
            // stale separator above it. Re-invalidate on every change.
            this.model.items_changed.connect(() => {
                this.list.invalidate_headers();
                if (this.focus_pending)
                    grab_focus();
            });
            this.model.conversations_loaded.connect(on_conversations_loaded);
            this.model.conversations_removed.connect(on_conversations_removed);
            this.model.conversation_updated.connect(on_conversation_updated);
            this.model.conversation_leaving.connect(on_conversation_leaving);
        }
    }

    private void fade_out_old_list() {
        var image = new Gtk.WidgetPaintable(this.scrolled_window).get_current_image();
        this.old_list.paintable = image;
        this.old_list.visible = true;
        if (this.old_list_fade != null) {
            this.old_list_fade.pause();
        }
        var target = new Adw.PropertyAnimationTarget(this.old_list, "opacity");
        this.old_list_fade = new Adw.TimedAnimation(
            this.old_list, 1, 0, SWITCH_FADE_OUT_MS, target
        );
        this.old_list_fade.done.connect(() => {
            this.old_list.visible = false;
            this.old_list.paintable = null;
            this.old_list_fade = null;
            if (this.model != null && this.model.is_ready) {
                on_model_ready();
            }
        });
        this.old_list_fade.play();
    }

    // Focus belongs on the open conversation, or the first one if none is
    // open -- not on the scrolled window or whatever else comes first in
    // the focus chain. The list is usually still loading when the window
    // first asks, so remember the request and honour it once rows arrive.
    private bool focus_pending = false;

    public override bool grab_focus() {
        Gtk.ListBoxRow? row = this.list.get_selected_row();
        if (row == null)
            row = this.list.get_row_at_index(0);

        this.focus_pending = (row == null);
        if (row == null)
            return false;

        // Don't yank the focus out of an entry the user has started
        // typing in while the list was loading.
        var root = get_root() as Gtk.Root;
        if (root != null && root.get_focus() is Gtk.Editable) {
            this.focus_pending = false;
            return false;
        }
        return row.grab_focus();
    }

    /**
     * Attempt to load more conversations from the current monitor
     */
    public void load_more(int request) {
        if (model != null) {
            model.load_more(request);
        }
    }

    private Adw.Animation? scroll_animation = null;

    /** Scrolls the conversation list back to the top. */
    public void scroll_to_top() {
        this.scroll_animation = Util.Gtk.animate_adjustment(
            this,
            this.scrolled_window.vadjustment,
            this.scrolled_window.vadjustment.lower
        );
    }

    public void scroll(Gtk.ScrollType scroll_type) {
        Gtk.ListBoxRow row = this.list.get_selected_row();

        if (row == null) {
            return;
        }

        int index = row.get_index();
        if (scroll_type == Gtk.ScrollType.STEP_UP) {
            row = this.list.get_row_at_index(index - 1);
        } else {
            row = this.list.get_row_at_index(index + 1);
        }

        if (row != null) {
            this.list.select_row(row);
        }
    }

    private Gtk.Widget row_factory(Object convo_obj) {
        var convo = (Convey.App.Conversation) convo_obj;
        var row = new Row(config, convo, this.selection_mode_enabled);
        row.toggle_flag.connect(on_toggle_flags);
        row.toggle_selection.connect(on_toggle_selection);
        if (this.model != null && this.model.is_ready) {
            row.animate_in();
        } else {
            row.show_now();
        }
        return row;
    }

    private void on_model_ready() {
        if (this.old_list_fade != null) {
            return;
        }
        var target = new Adw.PropertyAnimationTarget(this.list, "opacity");
        this.list_fade = new Adw.TimedAnimation(
            this.list, this.list.opacity, 1, Row.ANIMATION_DURATION_MS, target
        );
        this.list_fade.play();
    }

    private void on_conversation_leaving(uint position) {
        var row = this.list.get_row_at_index((int) position) as Row;
        if (row == null) {
            return;
        }
        bool was_selected = row.is_selected();
        bool had_focus = row.has_focus;
        row.animate_out();
        if (row.get_header() == null) {
            this.list.get_row_at_index((int) position + 1)?.get_header()?.add_css_class("hidden-divider");
        }

        // A re-sorted conversation has a new row elsewhere in the list
        Row? moved = find_live_row(row.conversation);
        if (moved != null) {
            if (was_selected) {
                this.list.select_row(moved);
            }
            if (had_focus) {
                moved.grab_focus();
            }
        }
    }

    private Row? find_live_row(Convey.App.Conversation conversation) {
        int i = 0;
        Row? row = this.list.get_row_at_index(0) as Row;
        while (row != null) {
            if (!row.leaving && row.conversation == conversation) {
                return row;
            }
            i++;
            row = this.list.get_row_at_index(i) as Row;
        }
        return null;
    }


    // --------------------
    //  Right-click Popup
    // --------------------
    private void context_menu(Row row, Gdk.Rectangle? rect=null) {
        if (!row.is_selected()) {
            this.list.unselect_all();
            this.list.select_row(row);
        }

        var popup_menu = construct_popover(row, this.list.get_selected_rows().length());
        if (rect != null) {
            popup_menu.set_pointing_to(rect);
        }
        popup_menu.popup();
    }

    private Gtk.Popover construct_popover(Row row, uint selection_size) {
        GLib.Menu context_menu_model = new GLib.Menu();
        var main = get_root() as Application.MainWindow;

        if (main != null) {
            if (!main.is_shift_down) {
                context_menu_model.append(
                    /// Translators: Context menu item
                    ngettext(
                        "Move conversation to _Trash",
                        "Move conversations to _Trash",
                        selection_size
                    ),
                    Action.Window.prefix(
                        Application.MainWindow.ACTION_TRASH_CONVERSATION
                    )
                );
            } else {
                context_menu_model.append(
                    /// Translators: Context menu item
                    ngettext(
                        "_Delete conversation",
                        "_Delete conversations",
                        selection_size
                    ),
                    Action.Window.prefix(
                        Application.MainWindow.ACTION_DELETE_CONVERSATION
                    )
                );
            }
        }

        if (row.conversation.is_unread()) {
            context_menu_model.append(
                _("Mark as _Read"),
                Action.Window.prefix(
                    Application.MainWindow.ACTION_MARK_AS_READ
                )
            );
        }

        if (row.conversation.has_any_read_message()) {
            context_menu_model.append(
                _("Mark as _Unread"),
                Action.Window.prefix(
                    Application.MainWindow.ACTION_MARK_AS_UNREAD
                )
            );
        }

        if (row.conversation.is_flagged()) {
            context_menu_model.append(
                _("U_nstar"),
                Action.Window.prefix(
                    Application.MainWindow.ACTION_MARK_AS_UNSTARRED
                )
            );
        } else {
            context_menu_model.append(
                _("_Star"),
                Action.Window.prefix(
                    Application.MainWindow.ACTION_MARK_AS_STARRED
                )
            );
        }

        if ((row.conversation.base_folder.used_as != ARCHIVE) &&
            (row.conversation.base_folder.used_as != ALL_MAIL)) {
                context_menu_model.append(
                    ngettext(
                        "_Archive conversation",
                        "_Archive conversations",
                        selection_size
                    ),
                    Action.Window.prefix(
                        Application.MainWindow.ACTION_ARCHIVE_CONVERSATION
                    )
                );
        }

        Menu actions_section = new Menu();
        actions_section.append(
            _("_Reply"),
            Action.Window.prefix(
                Application.MainWindow.ACTION_REPLY_CONVERSATION
            )
        );
        actions_section.append(
            _("R_eply All"),
            Action.Window.prefix(
                Application.MainWindow.ACTION_REPLY_ALL_CONVERSATION
            )
        );
        actions_section.append(
            _("_Forward"),
            Action.Window.prefix(
                Application.MainWindow.ACTION_FORWARD_CONVERSATION
            )
        );
        context_menu_model.append_section(null, actions_section);

        var context_menu = new Gtk.PopoverMenu.from_model(context_menu_model);
        context_menu.set_parent(row);

        return context_menu;
    }

    // -------------------
    //  Selection
    // -------------------

    /**
     * Emitted when one or more conversations are selected
     */
    public signal void conversations_selected(Gee.Set<Convey.App.Conversation> selected);

    /**
     * Emitted when one conversation is activated
     */
    public signal void conversation_activated(Convey.App.Conversation activated,
                                              uint button);

    /**
     * Gets the conversations represented by the current selection in the ListBox
     */
    public Gee.Set<Convey.App.Conversation> get_selected_conversations() {
        var selected = new Gee.HashSet<Convey.App.Conversation>();

        foreach (var row in this.list.get_selected_rows()) {
            selected.add(((Row) row).conversation);
        }
        return selected;
    }

    /**
     * Selects the rows for a given collection of conversations
     *
     * If a conversation is not present in the ListBox, it is ignored.
     */
    public void select_conversations(Gee.Collection<Convey.App.Conversation> selection) {
        int i = 0;
        Row? row = this.list.get_row_at_index(0) as Row;
        while (row != null) {
            Convey.App.Conversation conversation = row.conversation;
            if (!row.leaving && selection.contains(conversation)) {
                this.list.select_row(row);
            }
            i++;
            row = this.list.get_row_at_index(i) as Row;
        }
    }

    /**
     * Activate currently selected row
     *
     * If more than one selected, activate the first one
     */
    public void activate_selected() {
        Gee.Set<Convey.App.Conversation> conversations = get_selected_conversations();
        if (!conversations.is_empty) {
            conversation_activated(conversations.to_array()[0], 1);
        }
    }

    /**
     * Selects all conversations
     */
    public void select_all() {
        this.selection_mode_enabled = true;
        this.list.select_all();
    }

    /**
     * Unselects all conversations
     */
    public void unselect_all() {
        this.to_restore_row = null;
        this.list.unselect_all();
    }

    private bool selection_changed(Gee.Set<Convey.App.Conversation> selection) {
        bool changed = this.selected.size != selection.size;
        if (changed) {
            return true;
        }
        foreach (Convey.App.Conversation conversation in selection) {
            if (!this.selected.contains(conversation)) {
                changed = true;
            }
        }
        return changed;
    }

    private void restore_row() {
        if (this.to_restore_row != null) {
            // Workaround GTK issue, activating/selecting row while model is
            // updated scrolls to top
            GLib.Timeout.add(100, () => {
                this.to_restore_row.activate();
                this.to_restore_row = null;
                return false;
            });
        }
    }

    // -----------------
    //  Button Actions
    // ----------------

    /**
     * Emitted when the user expresses intent to update the flags on a set of conversations
     */
    public signal void mark_conversations(Gee.Collection<Convey.App.Conversation> conversations,
                                          Convey.NamedFlag flag);


    private void on_toggle_flags(ConversationList.Row row, Convey.NamedFlag flag) {
        if (row.is_selected()) {
            mark_conversations(this.selected, flag);
        } else {
            mark_conversations(Convey.Collection.single(row.conversation), flag);
        }
    }

    private void on_toggle_selection(ConversationList.Row row, bool active) {
        if (active) {
            this.list.select_row(row);
        } else {
            this.list.unselect_row(row);
        }
    }

    // ----------------
    //  Visibility
    // ---------------

    /**
     * If the number of pixels between the bottom of the viewport and the bottom of
     * of the listbox is less than LOAD_MORE_THRESHOLD, request more from the
     * monitor.
     */
    private double LOAD_MORE_THRESHOLD = 100;
    private int LOAD_MORE_COUNT = 50;

    /**
     * Called on scroll to possibly load more conversations from the model
     */
    private void maybe_load_more(Gtk.Adjustment adjustment) {
        double upper = adjustment.get_upper();
        double threshold = upper - adjustment.page_size - LOAD_MORE_THRESHOLD;

        if (this.is_visible() && adjustment.get_value() >= threshold) {
            this.load_more(LOAD_MORE_COUNT);
        }
    }

    /**
     * Time in milliseconds to delay updating the set of visible conversations.
     * If another update is triggered during this delay, it will be discarded
     * and the delay begins again.
     */
    private int VISIBILITY_UPDATE_DELAY_MS = 1000;

    /**
     * The set of all conversations currently displayed in the viewport
     */
    public Gee.Set<Convey.App.Conversation> visible_conversations {get; private set; default = new Gee.HashSet<Convey.App.Conversation>(); }
    private Convey.Scheduler.Scheduled? scheduled_visible_update;

    /**
     * Called on scroll to update the set of visible conversations
     */
    private void update_visible_conversations() {
        if(scheduled_visible_update != null) {
            scheduled_visible_update.cancel();
        }

        scheduled_visible_update = Convey.Scheduler.after_msec(VISIBILITY_UPDATE_DELAY_MS, () => {
            var visible = new Gee.HashSet<Convey.App.Conversation>();
            Gtk.ListBoxRow? first = this.list.get_row_at_y((int) this.scrolled_window.vadjustment.value);

            if (first == null) {
                this.visible_conversations = visible;
                return Source.REMOVE;
            }

            uint start_index = ((uint) first.get_index());
            uint end_index = uint.min(
                // Assume that all messages are the same height
                start_index + (uint) (this.scrolled_window.vadjustment.page_size / first.get_height()),
                this.model.get_n_items()
            );

            for (uint i = start_index; i < end_index; i++) {
                visible_conversations.add(
                    this.model.get_item(i) as Convey.App.Conversation
                );
            }

            this.visible_conversations = visible;
            return Source.REMOVE;
        }, GLib.Priority.DEFAULT_IDLE);
    }

    // ------------
    // Model
    // ------------
    private bool should_inhibit_autoactivate = false;

    public bool can_autoselect { get; set; default = true; }

    /**
     * Informs the listbox to suppress autoactivate behavior on the next update
     */
    public void inhibit_next_autoselect() {
        should_inhibit_autoactivate = true;
    }

    /**
     * Find a selectable conversation near current selection
     */
    private Gtk.ListBoxRow? get_next_conversation(bool asc=true) {
        int index = asc ? 0 : int.MAX;
        GLib.List<unowned Gtk.ListBoxRow> selected_rows;

        selected_rows = this.list.get_selected_rows();
        if (selected_rows.length() == 0 ) {
            return null;
        }

        foreach (var row in selected_rows) {
            if ((asc && row.get_index() > index) ||
                (!asc && row.get_index() < index)) {
                index = row.get_index();
            }
        }
        if (asc) {
            index += 1;
        } else {
            index -= 1;
        }
        Gtk.ListBoxRow? row = this.list.get_row_at_index(index);
        return row != null || !asc ? row : get_next_conversation(false);
    }

    private void on_conversations_loaded() {
        // Select the first conversation if autoselect on, except for Junk and Trash folders
        bool destructive = false;
        if (this.model != null) {
            foreach (var folder in this.model.get_folders()) {
                if (folder.used_as == TRASH || folder.used_as == JUNK) {
                    destructive = true;
                    break;
                }
            }
        }
        if (!destructive) {
            if (this.config.autoselect &&
                this.can_autoselect &&
                !this.should_inhibit_autoactivate &&
                this.list.get_selected_rows().length() == 0) {

                Gtk.ListBoxRow first_row = this.list.get_row_at_index(0);
                if (first_row != null) {
                    this.list.select_row(first_row);
                    grab_focus();
                }
            }
        }

        this.should_inhibit_autoactivate = false;
    }

    /*
     * Select next conversation
     */
    private void on_conversations_removed(bool start) {
        if (start) {
            remember_focused_row();
        } else {
            refocus_removed_row();
        }

        // Before model update, just find a conversation
        if (this.config.autoselect && this.can_autoselect && start) {
            this.to_restore_row = get_next_conversation();
        // If in selection mode, leaving will do the job
        } else if (this.selection_mode_enabled) {
            this.selection_mode_enabled = false;
        // Set next conversation
        } else if (this.config.autoselect && this.can_autoselect) {
            if (this.list.get_selected_rows().length() == 0) {
                restore_row();
            } else {
                // Removal didn't affect the selection; drop the stale
                // restore row so it doesn't swallow later selections
                this.to_restore_row = null;
            }
        }
    }

    // Remembers the row index of the focused row, so focus can be restored
    // after deeting/moving a conversation
    private Gtk.ListBoxRow? focused_row = null;
    private int focused_index = -1;

    private void remember_focused_row() {
        var focus = (get_root() as Gtk.Root)?.get_focus();
        var row = focus?.get_ancestor(typeof(Gtk.ListBoxRow)) as Gtk.ListBoxRow;
        if (row != null && row.get_parent() == this.list) {
            this.focused_row = row;
            this.focused_index = row.get_index();
        }
    }

    // Moves focus from a removed row to the row that replaced it
    private void refocus_removed_row() {
        if (this.focused_row != null && this.focused_row.get_parent() == null) {
            var row = this.list.get_row_at_index(this.focused_index) ??
                this.list.get_row_at_index(this.focused_index - 1);
            if (row != null) {
                row.grab_focus();
            }
        }
        this.focused_row = null;
    }

    /*
     * Update conversation row
     */
    private void on_conversation_updated(Convey.App.Conversation convo) {
        int i = 0;
        Row? row = this.list.get_row_at_index(0) as Row;
        while (row != null) {
            if (convo == row.conversation) {
                row.update();
            }

            i++;
            row = this.list.get_row_at_index(i) as Row;
        }
    }

    // ----------
    // Gestures
    // ----------

    [GtkCallback]
    private void on_press_gesture_released(Gtk.GestureClick click_gesture, int n_press, double x, double y) {
        var row = (Row) this.list.get_row_at_y((int) y);

        if (row == null)
            return;

        var button = click_gesture.get_current_button();
        if (button == Gdk.BUTTON_PRIMARY) {
            Gdk.EventSequence sequence = click_gesture.get_current_sequence();
            Gdk.Event event = click_gesture.get_last_event(sequence);
            this.last_modifier_type = event.get_modifier_state();
            if (!this.selection_mode_enabled) {
                if ((this.last_modifier_type & Gdk.ModifierType.SHIFT_MASK) ==
                        Gdk.ModifierType.SHIFT_MASK ||
                    (this.last_modifier_type & Gdk.ModifierType.CONTROL_MASK) ==
                        Gdk.ModifierType.CONTROL_MASK) {
                    this.selection_mode_enabled = true;
                } else {
                    conversation_activated(((Row) row).conversation, 1);
                }
            }
        } else if (button == Gdk.BUTTON_MIDDLE) {
            conversation_activated(row.conversation, 2);
        } else if (button == Gdk.BUTTON_SECONDARY) {
            Graphene.Point p = { (float) x, (float) y };
            Graphene.Point p_row;
            this.list.compute_point(row, p, out p_row);
            Gdk.Rectangle rect = { (int) p_row.x, (int) p_row.y, 0, 0 };
            context_menu(row, rect);
        }
    }

    [GtkCallback]
    private bool on_key_pressed(uint keyval, uint keycode, Gdk.ModifierType modifier_type) {
        switch (keyval) {
        case Gdk.Key.Up:
        case Gdk.Key.Down:
            if ((modifier_type & Gdk.ModifierType.SHIFT_MASK) ==
                    Gdk.ModifierType.SHIFT_MASK) {
                this.selection_mode_enabled = true;
            } else if (!this.can_autoselect && !this.selection_mode_enabled) {
                this.list.move_cursor(
                    Gtk.MovementStep.DISPLAY_LINES,
                    keyval == Gdk.Key.Up ? -1 : 1,
                    false,
                    true
                );
                return true;
            }
            break;
        case Gdk.Key.Escape:
            if (this.selection_mode_enabled) {
                this.selection_mode_enabled = false;
                return true;
            }
            break;
        }
        return false;
    }


    /**
     * Widgets used as drag icons have to be explicitly destroyed after the drag
     * so we track the widget as a private member
     */
    private Row? drag_widget = null;

    private Gdk.ContentProvider? on_drag_prepare(Gtk.DragSource drag_source,
                                                 double x, double y) {
        this.drag_widget = this.list.get_row_at_y((int) y) as Row;
        if (this.drag_widget == null) {
            return null;
        }
        // The dragged conversations are the list's selection; the
        // content is just a marker the folder list recognises.
        var marker = GLib.Value(typeof(string));
        marker.set_string("application/x-convey-mail");
        return new Gdk.ContentProvider.for_value(marker);
    }

    /** Fired while conversations are being dragged out of the list. */
    public signal void mail_drag_active(bool active);

    private void on_drag_begin(Gtk.DragSource drag_source, Gdk.Drag drag) {
        Row? row = this.drag_widget;
        if (row != null) {
            // If the user has a selection but drags starting from an
            // unselected row, we need to set the selection to that row
            if (!row.is_selected()) {
                this.list.unselect_all();
                this.list.select_row(row);
            }

            drag_source.set_icon(new Gtk.WidgetPaintable(row), 16, 16);
        }

        mail_drag_active(true);
    }

    private void on_drag_end(Gtk.DragSource drag_source, Gdk.Drag drag, bool delete_data) {
        mail_drag_active(false);
        this.drag_widget = null;
    }

    private void on_selected_rows_changed() {
        // When the focused row is removed, GTK moves focus (and with it
        // the selection) to the row above. Ignore that transient
        // selection so it isn't opened and marked read; restore_row()
        // will activate the intended row shortly.
        if (this.to_restore_row != null && !this.selection_mode_enabled) {
            var row = this.list.get_selected_row();
            if (row != null && row != this.to_restore_row) {
                return;
            }
        }

        var selected = get_selected_conversations();

        if (!selection_changed(selected)) {
            return;
        }

        this.selected = selected;
        if (this.selected.size > 0 || this.to_restore_row == null) {
            conversations_selected(this.selected);
        }
    }

    private void update_separators() {
        bool previous_selected = false;
        int i = 0;
        Gtk.ListBoxRow? row = this.list.get_row_at_index(0);
        while (row != null) {
            var header = row.get_header();
            if (header != null) {
                if (((Row) row).leaving || row.is_selected() || previous_selected) {
                    header.add_css_class("hidden-divider");
                } else {
                    header.remove_css_class("hidden-divider");
                }
            }
            previous_selected = row.is_selected();
            i++;
            row = this.list.get_row_at_index(i);
        }
    }

    private void on_row_activated() {
        var row = this.list.get_selected_row();
        if (row != null) {
            conversation_activated(((Row) row).conversation, 1);
        }
    }

    private void on_selection_mode_changed() {
        int i = 0;
        Row? row = this.list.get_row_at_index(0) as Row;
        while (row != null) {
            row.set_selection_enabled(this.selection_mode_enabled);
            i++;
            row = this.list.get_row_at_index(i) as Row;
        }

        if (this.selection_mode_enabled) {
            this.to_restore_row = this.list.get_selected_row();
        } else {
            restore_row();
        }
    }
}
