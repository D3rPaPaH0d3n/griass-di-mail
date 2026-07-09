/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/**
 * A container for full-height paned composers in the main window.
 *
 * Adding a composer to this container places it in {@link
 * Widget.PresentationMode.INLINE} or {@link
 * Widget.PresentationMode.INLINE_COMPACT} mode.
 */
public class Composer.Embed : Gtk.EventBox, Container {

    private const int MIN_EDITOR_HEIGHT = 200;


    static construct {
        set_css_name("geary-composer-embed");
    }


    /** {@inheritDoc} */
    public Gtk.ApplicationWindow? top_window {
        get { return get_toplevel() as Gtk.ApplicationWindow; }
    }

    /** The email this composer was originally a reply to. */
    public Geary.Email referred { get; private set; }

    /** {@inheritDoc} */
    internal Widget composer { get; set; }


    // Scroll gesture tracking, see on_body_scroll.
    private int64 last_scroll_time = 0;
    private int64 last_outer_time = 0;
    private bool chain_to_outer = false;
    private uint32 last_body_event_time = 0;


    /** Emitted when the container is closed. */
    public signal void vanished();


    public Embed(Geary.Email referred,
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

        get_style_context().add_class("geary-composer-embed");
        this.halign = Gtk.Align.FILL;
        this.vexpand = true;
        this.vexpand_set = true;

        add(composer);
        realize.connect(on_realize);
        show();
    }

    /** {@inheritDoc} */
    public void close() {
        vanished();

        this.composer.free_header();
        remove(this.composer);
        destroy();
    }

    private void on_realize() {
        // Intercept scroll over the editor body *before* WebKit does (it
        // consumes scroll events and won't propagate them at its edges).
        // By default let WebKit scroll the body, so it stays contained;
        // but if a gesture *starts* with the body already at the edge
        // we're pushing against, drive the conversation behind instead
        // and keep doing so for the rest of that gesture.
        this.composer.editor.body.scroll_event.connect(on_body_scroll);

        // Backstop: if WebKit propagates a scroll event at the body's
        // edge, swallow it here so an inner gesture can't chain into the
        // conversation part-way through. Events from elsewhere in the
        // composer (header buttons, from/to fields) fall through to
        // scroll the conversation normally.
        add_events(Gdk.EventMask.SCROLL_MASK | Gdk.EventMask.SMOOTH_SCROLL_MASK);
        scroll_event.connect(on_embed_scroll);

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

    private bool on_embed_scroll(Gdk.EventScroll event) {
        // Same event object as one on_body_scroll just saw => it bubbled
        // up from the body at its edge, so contain it. Anything else
        // originated over the header, so let it scroll the conversation.
        return (event.time == this.last_body_event_time)
            ? Gdk.EVENT_STOP : Gdk.EVENT_PROPAGATE;
    }

    private bool on_body_scroll(Gdk.EventScroll event) {
        this.last_body_event_time = event.time;
        double dy = 0;
        switch (event.direction) {
        case Gdk.ScrollDirection.UP:     dy = -1; break;
        case Gdk.ScrollDirection.DOWN:   dy = 1; break;
        case Gdk.ScrollDirection.SMOOTH: dy = event.delta_y; break;
        default: break;
        }
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
                scroller.scroll_event(event);
            }
            // Consume it so WebKit doesn't also scroll the body.
            return Gdk.EVENT_STOP;
        }

        // Let WebKit scroll the body; it contains the gesture at its own
        // edges by simply not propagating further.
        return Gdk.EVENT_PROPAGATE;
    }

}
