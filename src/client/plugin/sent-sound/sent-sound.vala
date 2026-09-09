/*
 * Copyright © 2020 Michael Gratton <mike@vee.net>.
 * Copyright © 2026 Daaniel Elia <d.elia@outlook.com>.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

[ModuleInit]
public void peas_register_types(TypeModule module) {
    Peas.ObjectModule obj = module as Peas.ObjectModule;
    obj.register_extension_type(
        typeof(Plugin.PluginBase),
        typeof(Plugin.SentSound)
    );
}

/** Plays the desktop sent-mail sound when an email is sent. */
public class Plugin.SentSound : PluginBase, EmailExtension {


    public EmailContext email {
        get; set construct;
    }


    private static bool gst_initialised = false;
    private Gst.Play.Play? player = null;
    private Gst.Play.SignalAdapter? player_signals = null;
    private EmailStore? store = null;


    public override async void activate(bool is_startup) throws GLib.Error {
        if (!SentSound.gst_initialised) {
            unowned string[]? argv = null;
            Gst.init(ref argv);
            SentSound.gst_initialised = true;
        }

        this.player = new Gst.Play.Play(null);
        this.player_signals = new Gst.Play.SignalAdapter(this.player);
        this.player_signals.error.connect(on_error);

        this.store = yield this.email.get_email_store();
        this.store.email_sent.connect(on_sent);
        this.store.email_sent_simple.connect(on_sent);

        if (!is_startup) {
            play_sound();
        }
    }

    public override async void deactivate(bool is_shutdown) throws GLib.Error {
        this.store.email_sent.disconnect(on_sent);
        this.store.email_sent_simple.disconnect(on_sent);
        this.store = null;

        this.player_signals.error.disconnect(on_error);
        this.player_signals = null;

        this.player.stop();
        this.player = null;
    }

    private void play_sound() {
        this.player.uri = GLib.File.new_for_path(
            GLib.Path.build_filename(
                Config.PLUGINS_DIR, "sent-sound", "message.oga"
            )
        ).get_uri();
        this.player.play();
    }

    private void on_error(GLib.Error err, Gst.Structure? details) {
        warning("Failed to play sent mail sound: %s", err.message);
        this.plugin_application.report_problem(
            new Convey.ProblemReport(err)
        );
    }

    private void on_sent() {
        play_sound();
    }

}
