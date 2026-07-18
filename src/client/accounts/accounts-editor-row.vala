/*
 * Copyright 2018 Michael Gratton <mike@vee.net>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */


internal class Accounts.EditorRow<PaneType> : Gtk.ListBoxRow {


    protected Gtk.Box layout {
        get;
        private set;
        default = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 5); }

    private Gtk.Image drag_handle;
    private bool drag_picked_up = false;


    public signal void move_to(int new_position);
    public signal void dropped(EditorRow target);


    public EditorRow() {
        add_css_class("geary-settings");
        add_css_class("geary-labelled-row");

        var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 5);
        this.child = box;


        var breakpoint_bin = new Adw.BreakpointBin();
        box.append(breakpoint_bin);
        breakpoint_bin.child = this.layout;

        var breakpoint = new Adw.Breakpoint(Adw.BreakpointCondition.parse("max-width: 500px"));
        breakpoint.add_setters(this.layout, "orientation", Gtk.Orientation.VERTICAL);
        breakpoint_bin.add_breakpoint(breakpoint);

        this.drag_handle = new Gtk.Image.from_icon_name("list-drag-handle-symbolic");
        this.drag_handle.valign = Gtk.Align.CENTER;
        this.drag_handle.visible = false;
        // Translators: Tooltip for dragging list items
        this.drag_handle.set_tooltip_text(_("Drag to move this item"));
        box.append(this.drag_handle);

        var key_controller = new Gtk.EventControllerKey();
        key_controller.key_pressed.connect(on_key_pressed);
        add_controller(key_controller);
    }

    public virtual void activated(PaneType pane) {
        // No-op by default
    }

    private bool on_key_pressed(Gtk.EventControllerKey key_controller, uint keyval, uint keycode, Gdk.ModifierType state) {
        bool ret = Gdk.EVENT_PROPAGATE;

        if (state == Gdk.ModifierType.CONTROL_MASK) {
            int index = get_index();
            if (keyval == Gdk.Key.Up) {
                index -= 1;
                if (index >= 0) {
                    move_to(index);
                    ret = Gdk.EVENT_STOP;
                }
            } else if (keyval == Gdk.Key.Down) {
                index += 1;
                Gtk.ListBox? parent = get_parent() as Gtk.ListBox;
                if (parent != null &&
                    //XXX GTK4 - I *think* we don't need this anymore
                    // index < parent.get_children().length() &&
                    !(parent.get_row_at_index(index) is AddRow)) {
                    move_to(index);
                    ret = Gdk.EVENT_STOP;
                }
            }
        }

        return ret;
    }

    /** Adds a drag handle to the row and enables drag signals. */
    protected void enable_drag() {
        //XXX GTK4 - is this activated on click?
        Gtk.DragSource drag_source = new Gtk.DragSource();
        drag_source.drag_begin.connect(on_drag_source_begin);
        drag_source.drag_end.connect(on_drag_source_end);
        drag_source.prepare.connect(on_drag_source_prepare);
        this.drag_handle.add_controller(drag_source);

        Gtk.DropTarget drop_target = new Gtk.DropTarget(typeof(int), Gdk.DragAction.MOVE);
        drop_target.enter.connect(on_drop_target_enter);
        drop_target.leave.connect(on_drop_target_leave);
        drop_target.drop.connect(on_drop_target_drop);
        this.drag_handle.add_controller(drop_target);

        //XXX GTK4 - Disable highlight by default, so we can avoid highlighting the row that was picked up
        this.drag_handle.add_css_class("geary-drag-handle");
        this.drag_handle.visible = true;

        add_css_class("geary-draggable");
    }


    private void on_drag_source_begin(Gtk.DragSource drag_source, Gdk.Drag drag) {
        // Draw a nice drag icon
        //XXX GTK4 lol, let's just make this a proper drag icon at some point
        // Cairo.ImageSurface surface = new Cairo.ImageSurface(
        //     Cairo.Format.ARGB32, alloc.width, alloc.height
        // );
        // Cairo.Context paint = new Cairo.Context(surface);


        // add_css_class("geary-drag-icon");
        // draw(paint);
        // remove_css_class("geary-drag-icon");

        // drag_source.set_icon(surface, 0, 0);

        // Set a visual hint that the row is being dragged
        add_css_class("geary-drag-source");
        this.drag_picked_up = true;
    }

    private void on_drag_source_end(Gtk.DragSource drag_source,
                                    Gdk.Drag drag,
                                    bool delete_data) {
        remove_css_class("geary-drag-source");
        this.drag_picked_up = false;
    }

    private Gdk.DragAction on_drop_target_enter(Gtk.DropTarget drop_target,
                                                double x,
                                                double y) {
        // Don't highlight the same row that was picked up
        if (!this.drag_picked_up) {
            Gtk.ListBox? parent = get_parent() as Gtk.ListBox;
            if (parent != null) {
                parent.drag_highlight_row(this);
            }
        }

        return Gdk.DragAction.MOVE;
    }

    private void on_drop_target_leave(Gtk.DropTarget drop_target) {
        if (!this.drag_picked_up) {
            Gtk.ListBox? parent = get_parent() as Gtk.ListBox;
            if (parent != null) {
                parent.drag_unhighlight_row();
            }
        }
    }

    private Gdk.ContentProvider on_drag_source_prepare(Gtk.DragSource drag_source,
                                                       double x,
                                                       double y) {
        GLib.Value val = GLib.Value(typeof(int));
        val.set_int(get_index());
        return new Gdk.ContentProvider.for_value(val);
    }

    private bool on_drop_target_drop(Gtk.DropTarget drop_target,
                                     GLib.Value val,
                                     double x,
                                     double y) {
        if (!val.holds(typeof(int))) {
            warning("Can't deal with non-uint row value");
            return false;
        }

        int drag_index = val.get_int();
        Gtk.ListBox? parent = this.get_parent() as Gtk.ListBox;
        if (parent != null) {
            EditorRow? drag_row = parent.get_row_at_index(drag_index) as EditorRow;
            if (drag_row != null && drag_row != this) {
                drag_row.dropped(this);
                return true;
            }
        }

        return false;
    }

}


internal class Accounts.LabelledEditorRow<PaneType,V> : EditorRow<PaneType> {


    public Gtk.Label label { get; private set; default = new Gtk.Label(""); }
    public V value { get; private set; }


    public LabelledEditorRow(string label, V value) {
        this.label.halign = Gtk.Align.START;
        this.label.valign = Gtk.Align.CENTER;
        this.label.hexpand = true;
        this.label.label = label;
        this.label.wrap_mode = Pango.WrapMode.WORD_CHAR;
        this.label.wrap = true;
        this.layout.append(this.label);

        bool expand_label = true;
        this.value = value;
        Gtk.Widget? widget = value as Gtk.Widget;
        if (widget != null) {
            Gtk.Entry? entry = value as Gtk.Entry;
            if (entry != null) {
                expand_label = false;
                entry.hexpand = true;
            }
            Gtk.Label? vlabel = value as Gtk.Label;
            if (vlabel != null) {
                vlabel.wrap_mode = Pango.WrapMode.WORD_CHAR;
                vlabel.wrap = true;
            }

            widget.halign = Gtk.Align.START;
            widget.valign = Gtk.Align.CENTER;
            this.layout.append(widget);
        }

        this.label.hexpand = expand_label;
    }

    public void set_dim_label(bool is_dim) {
        if (is_dim) {
            this.label.add_css_class("dim-label");
        } else {
            this.label.remove_css_class("dim-label");
        }
    }

}


internal class Accounts.AddRow<PaneType> : EditorRow<PaneType> {


    public AddRow() {
        add_css_class("geary-add-row");
        var add_icon = new Gtk.Image.from_icon_name("list-add-symbolic");
        add_icon.set_hexpand(true);

        this.layout.append(add_icon);
    }

}


internal abstract class Accounts.AccountRow<PaneType,V> :
    LabelledEditorRow<PaneType,V> {


    internal Geary.AccountInformation account { get; private set; }


    protected AccountRow(Geary.AccountInformation account, string label, V value) {
        base(label, value);
        this.account = account;
        this.account.changed.connect(on_account_changed);

        set_dim_label(true);
    }

    ~AccountRow() {
        this.account.changed.disconnect(on_account_changed);
    }

    public abstract void update();

    private void on_account_changed() {
        update();
    }

}


private abstract class Accounts.ServiceRow<PaneType,V> : AccountRow<PaneType,V> {


    internal Geary.ServiceInformation service { get; private set; }

    protected virtual bool is_value_editable {
        get {
            return (
                this.account.service_provider == Geary.ServiceProvider.OTHER &&
                !this.is_goa_account
            );
        }
    }

    // XXX convenience method until we get a better way of doing this.
    protected bool is_goa_account {
        get { return (this.account.mediator is GoaMediator); }
    }


    protected ServiceRow(Geary.AccountInformation account,
                         Geary.ServiceInformation service,
                         string label,
                         V value) {
        base(account, label, value);
        this.service = service;
        this.service.notify.connect_after(on_notify);

        bool is_editable = this.is_value_editable;
        set_activatable(is_editable);

        Gtk.Widget? widget = value as Gtk.Widget;
        if (widget != null && !is_editable) {
            if (widget is Gtk.Label) {
                widget.add_css_class("dim-label");
            } else {
                widget.set_sensitive(false);
            }
        }
    }

    ~ServiceRow() {
        this.service.notify.disconnect(on_notify);
    }

    private void on_notify() {
        update();
    }

}


/** Interface for rows that use a validator for editable values. */
internal interface Accounts.ValidatingRow<PaneType> : EditorRow<PaneType> {


    /** The row's validator */
    public abstract Components.Validator validator { get; protected set; }

    /** Determines if the row's value has actually changed. */
    public abstract bool has_changed { get; }

    /** Fired when validated and the value has actually changed. */
    public signal void changed();

    /** Fired when validated and the value has actually changed. */
    public signal void committed();

    /**
     * Hooks up signals to the validator.
     *
     * Implementing classes should call this in their constructor
     * after having constructed a validator
     */
    protected void setup_validator() {
        this.validator.changed.connect(on_validator_changed);
        this.validator.activated.connect(on_validator_check_commit);
        this.validator.focus_lost.connect(on_validator_check_commit);
    }

    /**
     * Called when the row's value should be stored.
     *
     * This is only called when the row's value has changed, is
     * valid, and the user has activated or changed to a different
     * row.
     */
    protected virtual void commit() {
        // noop
    }

    private void on_validator_changed() {
        if (this.has_changed) {
            changed();
        }
    }

    private void on_validator_check_commit() {
        if (this.has_changed) {
            commit();
            committed();
        }
    }

}


// Item backing a Gtk.DropDown row: an integer value plus its label and
// optional icon.
internal class Accounts.ComboItem : GLib.Object {

    public int id { get; construct; }
    public string label { get; construct; }
    public string? icon_name { get; construct; }

    public ComboItem(int id, string label, string? icon_name = null) {
        Object(id: id, label: label, icon_name: icon_name);
    }

}


// Gtk.DropDown is sealed, so these wrap one in an Adw.Bin and expose a
// typed value plus a changed() signal, matching the row API.

internal class Accounts.TlsComboBox : Adw.Bin {

    private const string INSECURE_ICON = "channel-insecure-symbolic";
    private const string SECURE_ICON = "channel-secure-symbolic";


    public string label { get; private set; default = ""; }

    /** Fired when the selected method changes. */
    public signal void changed();


    private Gtk.DropDown drop;


    public Geary.TlsNegotiationMethod method {
        get {
            var item = this.drop.selected_item as ComboItem;
            return (item != null)
                ? (Geary.TlsNegotiationMethod) item.id
                : Geary.TlsNegotiationMethod.TRANSPORT;
        }
        set { select_id(this.drop, value); }
    }


    public TlsComboBox() {
        // Translators: This label describes what form of transport
        // security (TLS, StartTLS, etc) used by an account's IMAP or SMTP
        // service.
        this.label = _("Connection security");

        var store = new GLib.ListStore(typeof(ComboItem));
        store.append(
            new ComboItem(Geary.TlsNegotiationMethod.NONE, _("None"), INSECURE_ICON)
        );
        store.append(
            new ComboItem(Geary.TlsNegotiationMethod.START_TLS, _("StartTLS"), SECURE_ICON)
        );
        store.append(
            new ComboItem(Geary.TlsNegotiationMethod.TRANSPORT, _("TLS"), SECURE_ICON)
        );

        this.drop = new Gtk.DropDown(store, null);
        this.drop.factory = new_icon_label_factory();
        this.drop.notify["selected"].connect(() => { changed(); });
        this.child = this.drop;
    }

}

internal class Accounts.OutgoingAuthComboBox : Adw.Bin {


    public string label { get; private set; }

    /** Fired when the selected source changes. */
    public signal void changed();


    private Gtk.DropDown drop;


    public Geary.Credentials.Requirement source {
        get {
            var item = this.drop.selected_item as ComboItem;
            return (item != null)
                ? (Geary.Credentials.Requirement) item.id
                : Geary.Credentials.Requirement.USE_INCOMING;
        }
        set { select_id(this.drop, value); }
    }


    public OutgoingAuthComboBox() {
        // Translators: Label for source of SMTP authentication
        // credentials (none, use IMAP, custom) when adding a new
        // account
        this.label = _("Login");

        var store = new GLib.ListStore(typeof(ComboItem));
        store.append(new ComboItem(
            Geary.Credentials.Requirement.NONE,
            // Translators: ComboBox value for source of SMTP
            // authentication credentials (none) when adding a new
            // account
            _("No login needed")
        ));
        store.append(new ComboItem(
            Geary.Credentials.Requirement.USE_INCOMING,
            // Translators: ComboBox value for source of SMTP
            // authentication credentials (use IMAP) when adding a new
            // account
            _("Use same login as receiving")
        ));
        store.append(new ComboItem(
            Geary.Credentials.Requirement.CUSTOM,
            // Translators: ComboBox value for source of SMTP
            // authentication credentials (custom) when adding a new
            // account
            _("Use a different login")
        ));

        this.drop = new Gtk.DropDown(store, null);
        this.drop.factory = new_icon_label_factory();
        this.drop.notify["selected"].connect(() => { changed(); });
        this.child = this.drop;
    }

}


// Select the item in a ComboItem-backed drop-down whose id matches.
private void select_id(Gtk.DropDown drop, int id) {
    var model = (GLib.ListStore) drop.model;
    for (uint i = 0; i < model.get_n_items(); i++) {
        if (((Accounts.ComboItem) model.get_item(i)).id == id) {
            drop.selected = i;
            break;
        }
    }
}


// Shared factory: an optional icon followed by an ellipsized label,
// bound from a ComboItem.
private Gtk.SignalListItemFactory new_icon_label_factory() {
    var factory = new Gtk.SignalListItemFactory();
    factory.setup.connect((obj) => {
        var item = (Gtk.ListItem) obj;
        var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        var icon = new Gtk.Image();
        var text = new Gtk.Label(null);
        text.xalign = 0.0f;
        text.ellipsize = Pango.EllipsizeMode.END;
        box.append(icon);
        box.append(text);
        item.child = box;
    });
    factory.bind.connect((obj) => {
        var item = (Gtk.ListItem) obj;
        var data = (Accounts.ComboItem) item.item;
        var box = (Gtk.Box) item.child;
        var icon = (Gtk.Image) box.get_first_child();
        var text = (Gtk.Label) icon.get_next_sibling();
        icon.icon_name = data.icon_name;
        icon.visible = (data.icon_name != null);
        text.label = data.label;
    });
    return factory;
}


/**
 * Displaying and manages validation of popover-based forms.
 */
internal class Accounts.EditorPopover : Gtk.Popover {


    internal Gtk.Grid layout {
        get; private set; default = new Gtk.Grid();
    }

    protected Gtk.Widget popup_focus = null;


    public EditorPopover() {
        add_css_class("geary-editor");

        this.layout.orientation = Gtk.Orientation.VERTICAL;
        this.layout.set_row_spacing(6);
        this.layout.set_column_spacing(12);
        this.child = this.layout;

        this.closed.connect_after(on_closed);
    }

    ~EditorPopover() {
        this.closed.disconnect(on_closed);
    }

    public void add_labelled_row(string label, Gtk.Widget value) {
        Gtk.Label label_widget = new Gtk.Label(label);
        label_widget.add_css_class("dim-label");
        label_widget.halign = Gtk.Align.END;

        this.layout.attach_next_to(label_widget, null, Gtk.PositionType.BOTTOM);
        this.layout.attach_next_to(value, label_widget, Gtk.PositionType.RIGHT);
    }

    private void on_closed() {
        destroy();
    }

}
