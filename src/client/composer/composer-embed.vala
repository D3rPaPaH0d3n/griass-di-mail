/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * A container for full-height paned composers in the main window.
 *
 * Adding a composer to this container places it in {@link
 * Widget.PresentationMode.INLINE} or {@link
 * Widget.PresentationMode.INLINE_COMPACT} mode.
 */
public class Composer.Embed : Adw.Bin, Container {

    private const int MIN_EDITOR_HEIGHT = 200;


    static construct {
        set_css_name("convey-composer-embed");
    }


    /** {@inheritDoc} */
    public Gtk.ApplicationWindow? top_window {
        get { return get_root() as Gtk.ApplicationWindow; }
    }

    /** The email this composer was originally a reply to. */
    public Convey.Email referred { get; private set; }

    /** {@inheritDoc} */
    internal Widget composer { get; set; }


    // Scroll gesture tracking, see on_body_scroll.
    private int64 last_scroll_time = 0;
    private int64 last_outer_time = 0;
    private bool chain_to_outer = false;
    private uint32 last_body_event_time = 0;

    private Gtk.EventControllerScroll? body_scroll = null;


    /** Emitted when the container is closed. */
    public signal void vanished();


    public Embed(Convey.Email referred,
                 Widget composer) {
        this.referred = referred;
        this.composer = composer;
        this.composer.embed_header();

        Widget.PresentationMode mode = INLINE_COMPACT;
        if (composer.context_type == FORWARD ||
            composer.has_multiple_from_addresses) {
            mode = INLINE;
        }
        composer.set_mode(mode);

        add_css_class("convey-composer-embed");
        this.halign = Gtk.Align.FILL;
        this.vexpand = true;
        this.vexpand_set = true;

        this.child = composer;
        realize.connect(on_realize);
    }

    /** {@inheritDoc} */
    public void close() {
        if (this.body_scroll != null) {
            this.composer.editor.body.remove_controller(this.body_scroll);
            this.body_scroll = null;
        }
        vanished();

        this.child = null;
    }

    private void on_realize() {
        if (this.body_scroll != null) {
            return;
        }

        // Intercept scroll over the editor body *before* WebKit does (it
        // consumes scroll events and won't propagate them at its edges).
        // By default let WebKit scroll the body, so it stays contained;
        // but if a gesture *starts* with the body already at the edge
        // we're pushing against, drive the conversation behind instead
        // and keep doing so for the rest of that gesture.
        var body_scroll = new Gtk.EventControllerScroll(VERTICAL);
        body_scroll.propagation_phase = CAPTURE;
        body_scroll.scroll.connect(on_body_scroll);
        this.composer.editor.body.add_controller(body_scroll);
        this.body_scroll = body_scroll;

        // Backstop: if WebKit propagates a scroll event at the body's
        // edge, swallow it here so an inner gesture can't chain into the
        // conversation part-way through. Events from elsewhere in the
        // composer (header buttons, from/to fields) fall through to
        // scroll the conversation normally.
        var embed_scroll = new Gtk.EventControllerScroll(VERTICAL);
        embed_scroll.scroll.connect(on_embed_scroll);
        add_controller(embed_scroll);

        // Note when the conversation itself is scrolling, so a gesture
        // begun on the conversation isn't hijacked by the body when the
        // pointer drifts over it mid-scroll.
        var scroller = (
            get_ancestor(typeof(Gtk.ScrolledWindow)) as Gtk.ScrolledWindow
        );
        if (scroller != null) {
            scroller.get_vadjustment().value_changed.connect(() => {
                this.last_outer_time = GLib.get_monotonic_time();
            });
        }
    }

    private bool on_embed_scroll(Gtk.EventControllerScroll ctrl,
                                 double dx, double dy) {
        // Same event as one on_body_scroll just saw => it bubbled up
        // from the body at its edge, so contain it. Anything else
        // originated over the header, so let it scroll the conversation.
        return (ctrl.get_current_event_time() == this.last_body_event_time);
    }

    private bool on_body_scroll(Gtk.EventControllerScroll ctrl,
                                double dx, double dy) {
        this.last_body_event_time = ctrl.get_current_event_time();
        if (dy == 0) {
            return Gdk.EVENT_PROPAGATE;
        }

        var body = this.composer.editor.body;
        int64 now = GLib.get_monotonic_time();
        if (now - this.last_scroll_time > 150000) { // 150ms idle => new gesture
            if (now - this.last_outer_time < 150000) {
                // The conversation is already mid-scroll and the pointer
                // just crossed into the body: keep scrolling it.
                this.chain_to_outer = true;
            } else {
                this.chain_to_outer = (dy < 0 && body.body_at_top) ||
                                      (dy > 0 && body.body_at_bottom);
            }
        }
        this.last_scroll_time = now;

        if (this.chain_to_outer) {
            var scroller = (
                get_ancestor(typeof(Gtk.ScrolledWindow)) as Gtk.ScrolledWindow
            );
            if (scroller != null) {
                Gtk.Adjustment adj = scroller.get_vadjustment();
                // Match GtkScrolledWindow's smooth-scroll step.
                double unit = Math.pow(adj.page_size, 2.0 / 3.0);
                double delta = (ctrl.get_unit() == Gdk.ScrollUnit.SURFACE)
                    ? dy : dy * unit;
                adj.value = adj.value + delta;
            }
            // Consume it so WebKit doesn't also scroll the body.
            return Gdk.EVENT_STOP;
        }

        // Let WebKit scroll the body; it contains the gesture at its own
        // edges by simply not propagating further.
        return Gdk.EVENT_PROPAGATE;
    }

}
