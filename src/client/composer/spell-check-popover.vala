/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

public class SpellCheckPopover {

    /**
     * This signal is emitted then the selection of rows changes.
     *
     * @param active_langs The new set of active dictionaries after the
     *                     selection has changed.
     */
    public signal void selection_changed(string[] active_langs);

    private Gtk.Popover? popover = null;
    private GLib.GenericSet<string> selected_rows;
    private Gtk.ListBox langs_list;
    private Gtk.SearchEntry search_box;
    private Gtk.ScrolledWindow view;
    private Gtk.Box content;
    private Application.Configuration config;

    private enum SpellCheckStatus {
        INACTIVE,
        ACTIVE
    }

    private class SpellCheckLangRow : Gtk.ListBoxRow {

        public string lang_code { get; private set; }

        private string lang_name;
        private string country_name;
        public bool is_lang_visible { get; private set; }
        private bool needs_download;
        private Gtk.Image active_image;
        private Gtk.Button visibility_button;
        private Gtk.DrawingArea progress_circle;
        private double download_progress = 0.0;
        private SpellCheckStatus lang_active = SpellCheckStatus.INACTIVE;

        /**
         * Emitted when the language has been enabled or disabled.
         */
        public signal void enabled_changed(bool is_enabled);

        /**
         * @brief Signal when the visibility has changed.
         */
        public signal void visibility_changed(bool is_visible);


        public SpellCheckLangRow(string lang_code,
                                 bool is_active,
                                 bool is_visible,
                                 bool needs_download) {
            this.lang_code = lang_code;
            this.needs_download = needs_download;
            this.lang_active = is_active
                ? SpellCheckStatus.ACTIVE
                : SpellCheckStatus.INACTIVE;
            this.is_lang_visible = is_active || is_visible;

            Gtk.Box box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            box.margin_start = 12;
            box.margin_end = 6;
            box.margin_top = 6;
            box.margin_bottom = 6;

            lang_name = Util.I18n.language_name_from_locale(lang_code);
            country_name = Util.I18n.country_name_from_locale(lang_code);

            string label_text = lang_name;
            Gtk.Label label = new Gtk.Label(label_text);
            label.tooltip_text = label_text;
            label.halign = Gtk.Align.START;
            label.ellipsize = END;
            label.xalign = 0;

            if (country_name != null) {
                Gtk.Box label_box = new Gtk.Box(VERTICAL, 3);
                Gtk.Label country_label = new Gtk.Label(country_name);
                country_label.tooltip_text = country_name;
                country_label.halign = Gtk.Align.START;
                country_label.ellipsize = END;
                country_label.xalign = 0;
                country_label.add_css_class("dim-label");

                label_box.append(label);
                label_box.append(country_label);
                label_box.hexpand = true;
                box.append(label_box);
            } else {
                label.hexpand = true;
                box.append(label);
            }

            active_image = new Gtk.Image.from_icon_name("object-select-symbolic");
            this.visibility_button = new Gtk.Button();
            this.visibility_button.add_css_class("flat");
            box.append(active_image);
            box.append(this.visibility_button);

            this.progress_circle = new Gtk.DrawingArea();
            this.progress_circle.content_width = 16;
            this.progress_circle.content_height = 16;
            this.progress_circle.margin_start = 9;
            this.progress_circle.margin_end = 9;
            this.progress_circle.valign = CENTER;
            this.progress_circle.visible = false;
            this.progress_circle.set_draw_func(draw_progress);
            box.append(this.progress_circle);
            this.visibility_button.halign = Gtk.Align.END; // Make the button stay at the right end of the screen
            this.visibility_button.valign = CENTER;

            this.visibility_button.clicked.connect(on_visibility_clicked);

            update_images();
            this.child = box;
        }

        public bool is_lang_active() {
            return lang_active == SpellCheckStatus.ACTIVE;
        }

        private void update_images() {
            switch (lang_active) {
            case SpellCheckStatus.ACTIVE:
                this.active_image.set_from_icon_name("object-select-symbolic");
                break;
            case SpellCheckStatus.INACTIVE:
                this.active_image.clear();
                break;
            }

            if (needs_download) {
                this.visibility_button.icon_name = "folder-download-symbolic";
                this.visibility_button.set_tooltip_text(_("Download this language"));
            }
            else if (is_lang_visible) {
                this.visibility_button.icon_name = "list-remove-symbolic";
                this.visibility_button.set_tooltip_text(_("Remove this language from the preferred list"));
            }
            else {
                this.visibility_button.icon_name = "list-add-symbolic";
                this.visibility_button.set_tooltip_text(_("Add this language to the preferred list"));
            }
        }

        public string sort_key() {
            return (lang_name ?? lang_code) + " " + (country_name ?? "");
        }

        public bool match_filter(string filter) {
            string filter_down = filter.down();
            return ((lang_name != null ? filter_down in lang_name.down() : false) ||
                    (country_name != null ? filter_down in country_name.down() : false));
        }

        private void set_lang_active(SpellCheckStatus active) {
            this.lang_active = active;

            switch (active) {
                case SpellCheckStatus.ACTIVE:
                    // If the lang is not visible make it visible now
                    if (!this.is_lang_visible) {
                        set_lang_visible(true);
                    }
                    break;
                case SpellCheckStatus.INACTIVE:
                    break;
            }

            update_images();
            this.enabled_changed(active == SpellCheckStatus.ACTIVE);
        }

        private void set_lang_visible(bool is_visible) {
            this.is_lang_visible = is_visible;

            update_images();
            if (!this.is_lang_visible &&
                this.lang_active == SpellCheckStatus.ACTIVE) {
                set_lang_active(SpellCheckStatus.INACTIVE);
            }

            visibility_changed(is_visible);
        }

        public void handle_activation(SpellCheckPopover spell_check_popover) {
            // Make sure that we do not enable the language when the user is just
            // trying to remove it from the list.
            if (!visible)
                return;

            if (needs_download) {
                on_visibility_clicked();
                return;
            }

            switch (lang_active) {
                case SpellCheckStatus.ACTIVE:
                    set_lang_active(SpellCheckStatus.INACTIVE);
                    break;
                case SpellCheckStatus.INACTIVE:
                    set_lang_active(SpellCheckStatus.ACTIVE);
                    break;
            }
        }

        private void set_download_progress(double fraction) {
            this.download_progress = fraction;
            this.progress_circle.queue_draw();
        }

        private async void download() {
            set_download_progress(0.0);
            this.visibility_button.visible = false;
            this.progress_circle.visible = true;
            try {
                yield Util.I18n.download_dictionary(lang_code, set_download_progress, null);
                this.needs_download = false;
                set_lang_active(SpellCheckStatus.ACTIVE);
            } catch (GLib.Error err) {
                warning("Failed to download dictionary %s: %s", lang_code, err.message);
                this.visibility_button.set_tooltip_text(
                    _("Download failed: %s").printf(err.message)
                );
            }
            this.progress_circle.visible = false;
            this.visibility_button.visible = true;
        }

        private void draw_progress(Gtk.DrawingArea area,
                                   Cairo.Context cr,
                                   int width,
                                   int height) {
            Gdk.RGBA color = area.get_color();
            double radius = double.min(width, height) / 2.0 - 1.5;
            double start = -Math.PI / 2.0;
            cr.set_line_width(2.0);
            cr.set_source_rgba(color.red, color.green, color.blue, color.alpha * 0.2);
            cr.arc(width / 2.0, height / 2.0, radius, 0, 2.0 * Math.PI);
            cr.stroke();
            cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
            cr.arc(width / 2.0, height / 2.0, radius, start, start + 2.0 * Math.PI * download_progress);
            cr.stroke();
        }

        private void on_visibility_clicked() {
            if (needs_download) {
                if (!this.progress_circle.visible) {
                    download.begin();
                }
                return;
            }
            set_lang_visible(!this.is_lang_visible);
        }

    }

    public SpellCheckPopover(Gtk.MenuButton button, Application.Configuration config) {
        this.popover = new Gtk.Popover();
        button.popover = this.popover;
        this.config = config;
        this.selected_rows = new GLib.GenericSet<string>(GLib.str_hash, GLib.str_equal);
        setup_popover();
    }

    private void header_function(Gtk.ListBoxRow row, Gtk.ListBoxRow? before) {
        if (before != null) {
            if (row.get_header() == null) {
                row.set_header(new Gtk.Separator(HORIZONTAL));
            }
        }
    }

    private bool filter_function (Gtk.ListBoxRow row) {
        string text = search_box.get_text();
        SpellCheckLangRow r = row as SpellCheckLangRow;
        return r.match_filter(text);
    }

    private int sort_function(Gtk.ListBoxRow row_a, Gtk.ListBoxRow row_b) {
        SpellCheckLangRow a = row_a as SpellCheckLangRow;
        SpellCheckLangRow b = row_b as SpellCheckLangRow;
        if (a.is_lang_active() != b.is_lang_active()) {
            return a.is_lang_active() ? -1 : 1;
        }
        if (a.is_lang_visible != b.is_lang_visible) {
            return a.is_lang_visible ? -1 : 1;
        }
        return a.sort_key().collate(b.sort_key());
    }

    private void setup_popover() {
        // We populate the popover with the list of languages that the user wants to see
        string[] installed = Util.I18n.get_available_dictionaries();
        string[] languages = installed;
        foreach (string lang in Util.I18n.get_downloadable_dictionaries()) {
            if (!(lang in installed)) {
                languages += lang;
            }
        }
        string[] enabled_langs = this.config.get_spell_check_languages();
        string[] visible_langs = this.config.get_spell_check_visible_languages();

        content = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        search_box = new Gtk.SearchEntry();
        search_box.set_placeholder_text(_("Search for more languages"));
        search_box.changed.connect(on_search_box_changed);
        content.append(search_box);

        view = new Gtk.ScrolledWindow();
        view.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        view.vexpand = true;

        langs_list = new Gtk.ListBox();
        langs_list.set_selection_mode(Gtk.SelectionMode.NONE);
        foreach (string lang in languages) {
            SpellCheckLangRow row = new SpellCheckLangRow(
                lang,
                lang in enabled_langs,
                lang in visible_langs,
                !(lang in installed)
            );
            langs_list.append(row);

            if (row.is_lang_active())
                selected_rows.add(lang);

            row.enabled_changed.connect(this.on_row_enabled_changed);
            row.visibility_changed.connect(this.on_row_visibility_changed);
        }
        langs_list.row_activated.connect(on_row_activated);
        view.child = langs_list;

        content.append(view);

        langs_list.set_filter_func(this.filter_function);
        langs_list.set_header_func(this.header_function);
        langs_list.set_sort_func(this.sort_function);

        this.popover.child = content;

        // Make sure that the search box does not get the focus first. We want it to have it only
        // if the user wants to perform an extended search.
        content.set_focus_child(view);
        content.set_margin_start(6);
        content.set_margin_end(6);
        content.set_margin_top(6);
        content.set_margin_bottom(6);

        this.popover.show.connect(this.on_shown);
        this.popover.set_size_request(360, 350);
    }

    private void on_row_activated(Gtk.ListBoxRow row) {
        SpellCheckLangRow r = row as SpellCheckLangRow;
        r.handle_activation(this);
        // Make sure that we update the visible languages based on the
        // possibly updated is_lang_visible_properties.
        langs_list.invalidate_filter();
    }

    private void on_search_box_changed() {
        langs_list.invalidate_filter();
    }

    private void on_shown() {
        search_box.set_text("");
        content.set_focus_child(view);
        langs_list.invalidate_filter();
    }

    private void on_row_enabled_changed(SpellCheckLangRow row,
                                        bool is_active) {
        langs_list.invalidate_sort();
        string lang = row.lang_code;
        if (is_active) {
            selected_rows.add(lang);
        } else {
            selected_rows.remove(lang);
        }

        // Signal that the selection has changed
        string[] active_langs = {};
        selected_rows.foreach((lang) => active_langs += lang);
        this.selection_changed(active_langs);
    }

    private void on_row_visibility_changed(SpellCheckLangRow row,
                                           bool is_visible) {
        langs_list.invalidate_filter();
        langs_list.invalidate_sort();

        string[] visible_langs = this.config.get_spell_check_visible_languages();
        string lang = row.lang_code;
        if (is_visible) {
            if (!(lang in visible_langs)) {
                visible_langs += lang;
            }
        } else {
            string[] new_langs = {};
            foreach (string lang_code in visible_langs) {
                if (lang != lang_code) {
                    new_langs += lang_code;
                }
            }
            visible_langs = new_langs;
        }
        this.config.set_spell_check_visible_languages(visible_langs);
    }

}
