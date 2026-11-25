/* New downstream file: 2026-10-28. GPL-3.0-only; see COPYING. */

/** Native colour chooser with an explicit return to automatic/no colour. */
public class Components.IdentityColorButton : Gtk.Box {
    public string color { get; set; default = ""; }
    public bool automatic_default { get; set; default = true; }
    private string description;
    private Gtk.Label default_label;
    private Gtk.ColorDialogButton chooser;
    private Gtk.Button reset;
    private bool updating = false;

    public IdentityColorButton(string initial, string description) {
        Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 6,
               valign: Gtk.Align.CENTER);
        this.description = description;
        this.default_label = new Gtk.Label(null);
        this.default_label.add_css_class("dim-label");
        this.chooser = new Gtk.ColorDialogButton(new Gtk.ColorDialog() {
            title = description, with_alpha = false
        });
        this.chooser.tooltip_text = description;
        this.chooser.update_property(Gtk.AccessibleProperty.LABEL, description, -1);
        this.reset = new Gtk.Button.from_icon_name("edit-undo-symbolic");
        this.reset.add_css_class("flat");
        append(this.default_label);
        append(this.chooser);
        append(this.reset);
        this.reset.clicked.connect(() => { this.color = ""; });
        this.chooser.notify["rgba"].connect(() => {
            if (!this.updating) {
                unowned Gdk.RGBA? rgba = this.chooser.get_rgba();
                this.color = "#%02x%02x%02x".printf(
                    (uint) Math.round(rgba.red * 255),
                    (uint) Math.round(rgba.green * 255),
                    (uint) Math.round(rgba.blue * 255)
                );
            }
        });
        this.notify["color"].connect(update);
        this.notify["automatic-default"].connect(update);
        this.color = initial;
        update();
    }

    private void update() {
        this.updating = true;
        bool has_color = this.color != "";
        string default_text = this.automatic_default ? _("Automatic") : _("No color");
        string reset_text = this.automatic_default ? _("Use automatic color") : _("Remove color");
        this.default_label.label = default_text;
        this.default_label.visible = !has_color;
        string state = has_color ? this.color : default_text;
        this.chooser.tooltip_text = "%s: %s".printf(this.description, state);
        this.chooser.update_property(Gtk.AccessibleProperty.DESCRIPTION, state, -1);
        this.reset.tooltip_text = reset_text;
        this.reset.update_property(Gtk.AccessibleProperty.LABEL, reset_text, -1);
        Gdk.RGBA rgba = {};
        rgba.parse(has_color ? this.color : "#808080");
        this.chooser.rgba = rgba;
        this.reset.sensitive = has_color;
        this.updating = false;
    }

    public static void style_badge(Gtk.Widget badge, string color) {
        string value = GriabuntuMail.AccountInformation.normalize_color(color);
        if (value == "") {
            return;
        }
        // Keep readable theme text; the chosen colour marks the edge and tint.
        // System selection/high-contrast rules keep their stronger specificity.
        var css = new Gtk.CssProvider();
        css.load_from_string(
            "label.recipient-alias-badge { background-color: alpha(%s, 0.16); ".printf(value) +
            "color: @view_fg_color; border-bottom: 2px solid %s; }".printf(value) +
            "row:selected label.recipient-alias-badge { color: @theme_selected_fg_color; " +
            "background-color: alpha(@theme_selected_fg_color, 0.16); } " +
            ".griabuntu-high-contrast label.recipient-alias-badge { " +
            "background-color: transparent; color: inherit; border: 1px solid currentColor; }"
        );
        badge.get_style_context().add_provider(css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }
}

/** A small optional marker, without recolouring text or selection surfaces. */
public class Components.IdentityColorSwatch : Gtk.DrawingArea {
    public string color { get; set; default = ""; }

    public IdentityColorSwatch() {
        Object(content_width: 12, content_height: 12, valign: Gtk.Align.CENTER,
               visible: false, can_target: false);
        this.notify["color"].connect(() => {
            this.visible = GriabuntuMail.AccountInformation.normalize_color(this.color) != "";
            queue_draw();
        });
        set_draw_func((area, cr, width, height) => {
            Gdk.RGBA rgba = {};
            if (rgba.parse(this.color)) {
                cr.arc(width / 2.0, height / 2.0, 4.5, 0, 2 * Math.PI);
                Gdk.cairo_set_source_rgba(cr, rgba);
                cr.fill_preserve();
                cr.set_source_rgba(0.5, 0.5, 0.5, 0.6);
                cr.set_line_width(1);
                cr.stroke();
            }
        });
    }
}
