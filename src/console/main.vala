/* Downstream modification: 2026-10-27 — Griabuntu Mail identity and namespace. */
/*
n * Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

errordomain CommandException {
    USAGE,
    STATE
}

const int IMAP_TIMEOUT_SEC = 60 * 15;

[GtkTemplate (ui = "/io/github/d3rpapah0d3n/GriabuntuMailConsole/imap-console.ui")]
class ImapConsole : Adw.ApplicationWindow {
    private const int KEEPALIVE_SEC = 60 * 10;

    [GtkChild] private unowned Gtk.TextView console;
    [GtkChild] private unowned Gtk.Entry cmdline;
    [GtkChild] private unowned Gtk.Label statusbar;

    private GriabuntuMail.Imap.ClientConnection? cx = null;
    private Gee.HashMap<GriabuntuMail.Imap.Tag, GriabuntuMail.Imap.StatusResponse> status_responses = new Gee.HashMap<
        GriabuntuMail.Imap.Tag, GriabuntuMail.Imap.StatusResponse>();
    private GriabuntuMail.Nonblocking.Event recvd_response_event = new GriabuntuMail.Nonblocking.Event();

    public ImapConsole(Adw.Application app) {
        Object(application: app);

        this.cmdline.activate.connect(on_activate);
        cmdline.grab_focus();
    }

    [GtkCallback]
    private void on_activate(Gtk.Entry cmdline) {
        exec(cmdline.buffer.text);
        cmdline.buffer.delete_text(0, -1);
    }

    private void clear_status() {
        this.statusbar.set_text("");
    }

    private void status(string text) {
        string msg = text;
        if (!msg.has_suffix(".") && !msg.has_prefix("usage"))
            msg += ".";

        this.statusbar.set_text(msg);
    }

    private void exception(Error err) {
        status(err.message);
    }

    private static string[] cmdnames = {
        "noop",
        "nop",
        "capabililties",
        "caps",
        "connect",
        "unsecure",
        "disconnect",
        "login",
        "logout",
        "id",
        "bye",
        "namespace",
        "list",
        "xlist",
        "examine",
        "create",
        "delete",
        "fetch",
        "uid-fetch",
        "fetch-fields",
        "append",
        "search",
        "uid-search",
        "help",
        "exit",
        "quit",
        "gmail",
        "yahoo",
        "keepalive",
        "status",
        "preview",
        "close"
    };

    private void exec(string input) {
        string[] lines = input.strip().split(";");
        foreach (string line in lines) {
            string[] tokens = line.strip().split(" ");
            if (tokens.length == 0)
                continue;

            string cmd = tokens[0].strip().down();
            string[] args = new string[0];
            for (int ctr = 1; ctr < tokens.length; ctr++) {
                string arg = tokens[ctr].strip();
                if (arg == "\"\"") {
                    args += "";
                } else if (!GriabuntuMail.String.is_empty(arg)) {
                    args += arg;
                }
            }

            clear_status();

            // TODO: Need to break out the command delegates into their own objects with the
            // human command-names and usage and exec()'s and such; this isn't a long-term approach
            try {
                switch (cmd) {
                    case "noop":
                    case "nop":
                        noop(cmd, args);
                    break;

                    case "capabilities":
                    case "caps":
                        capabilities(cmd, args);
                    break;

                    case "connect":
                    case "unsecure":
                        connect_cmd(cmd, args);
                    break;

                    case "disconnect":
                        disconnect_cmd(cmd, args);
                    break;

                    case "starttls":
                        starttls(cmd, args);
                    break;

                    case "login":
                        login(cmd, args);
                    break;

                    case "logout":
                    case "bye":
                    case "kthxbye":
                        logout(cmd, args);
                    break;

                    case "id":
                        id(cmd, args);
                    break;

                    case "namespace":
                        namespace(cmd, args);
                    break;

                    case "list":
                    case "xlist":
                        list(cmd, args);
                    break;

                    case "examine":
                        examine(cmd, args);
                    break;

                    case "create":
                        create(cmd, args);
                    break;

                    case "delete":
                        @delete(cmd, args);
                    break;

                    case "fetch":
                    case "uid-fetch":
                        fetch(cmd, args);
                    break;

                    case "close":
                        close_cmd(cmd, args);
                    break;

                    case "fetch-fields":
                        fetch_fields(cmd, args);
                    break;

                    case "append":
                        append(cmd, args);
                    break;

                    case "search":
                    case "uid-search":
                        search(cmd, args);
                    break;

                    case "help":
                        foreach (string cmdname in cmdnames)
                            print_console_line(cmdname);
                    break;

                    case "exit":
                    case "quit":
                        quit(cmd, args);
                    break;

                    case "gmail":
                        string[] fake_args = new string[1];
                        fake_args[0] = "imap.gmail.com:993";
                        connect_cmd("connect", fake_args);
                    break;

                    case "yahoo":
                        string[] fake_args = new string[1];
                        fake_args[0] = "imap.mail.yahoo.com:993";
                        connect_cmd("connect", fake_args);
                    break;

                    case "keepalive":
                        keepalive(cmd, args);
                    break;

                    case "status":
                        folder_status(cmd, args);
                    break;

                    case "preview":
                        preview(cmd, args);
                    break;

                    default:
                        status("Unknown command \"%s\"".printf(cmd));
                    break;
                }
            } catch (Error ce) {
                status(ce.message);
            }
        }
    }

    private void check_args(string cmd, string[] args, int count, string? usage) throws CommandException {
        if (args.length != count)
            throw new CommandException.USAGE("usage: %s %s", cmd, usage != null ? usage : "");
    }

    private void check_connected(string cmd, string[] args, int count, string? usage) throws CommandException {
        if (cx == null)
            throw new CommandException.STATE("'connect' required");

        check_args(cmd, args, count, usage);
    }

    private void check_min_args(string cmd, string[] args, int min_count, string? usage) throws CommandException {
        if (args.length < min_count)
            throw new CommandException.USAGE("usage: %s %s", cmd, usage != null ? usage : "");
    }

    private void check_min_connected(string cmd, string[] args, int min_count, string? usage) throws CommandException {
        if (cx == null)
            throw new CommandException.STATE("'connect' required");

        check_min_args(cmd, args, min_count, usage);
    }

    private void capabilities(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 0, null);

        this.cx.send_command(new GriabuntuMail.Imap.CapabilityCommand(null));
    }

    private void noop(string cmd, string[] args) throws GLib.Error {
        check_connected(cmd, args, 0, null);

        this.cx.send_command(new GriabuntuMail.Imap.NoopCommand(null));
    }

    private void connect_cmd(string cmd, string[] args) throws Error {
        if (cx != null)
            throw new CommandException.STATE("'logout' required");

        check_args(cmd, args, 1, "hostname[:port]");

        GriabuntuMail.TlsNegotiationMethod method = GriabuntuMail.TlsNegotiationMethod.TRANSPORT;
        if (cmd == "unsecure") {
            method = GriabuntuMail.TlsNegotiationMethod.START_TLS;
        }

        cx = new GriabuntuMail.Imap.ClientConnection(
            new GriabuntuMail.Endpoint(
                new GLib.NetworkAddress(args[0], GriabuntuMail.Imap.IMAP_TLS_PORT),
                method,
                IMAP_TIMEOUT_SEC
            ),
            new GriabuntuMail.Imap.Quirks()
        );

        cx.sent_command.connect(on_sent_command);
        cx.received_status_response.connect(on_received_status_response);
        cx.received_server_data.connect(on_received_server_data);
        cx.received_bad_response.connect(on_received_bad_response);

        status("Connecting to %s...".printf(args[0]));
        cx.connect_async.begin(null, on_connected);
    }

    private void on_connected(Object? source, AsyncResult result) {
        try {
            cx.connect_async.end(result);
            status("Connected");
        } catch (Error err) {
            cx = null;

            exception(err);
        }
    }

    private void disconnect_cmd(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 0, null);

        status("Disconnecting...");
        cx.disconnect_async.begin(null, on_disconnected);
    }

    private void on_disconnected(Object? source, AsyncResult result) {
        try {
            cx.disconnect_async.end(result);
            status("Disconnected");

            cx.sent_command.disconnect(on_sent_command);
            cx.received_status_response.disconnect(on_received_status_response);
            cx.received_server_data.connect(on_received_server_data);
            cx.received_bad_response.disconnect(on_received_bad_response);

            cx = null;
        } catch (Error err) {
            exception(err);
        }
    }

    private void starttls(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 0, "");

        status("Starting TLS...");
        do_starttls_async.begin(on_do_starttls_async_completed);
    }

    private async void do_starttls_async() throws Error {
        GriabuntuMail.Imap.StarttlsCommand cmd = new GriabuntuMail.Imap.StarttlsCommand(null);
        this.cx.send_command(cmd);

        GriabuntuMail.Imap.StatusResponse response = yield wait_for_response_async(cmd.tag);
        if (response.status == GriabuntuMail.Imap.Status.OK) {
            yield cx.starttls_async(null);
            status("STARTTLS completed");
        } else {
            status("STARTTLS denied: %s".printf(response.to_string()));
        }
    }

    private void on_do_starttls_async_completed(Object? source, AsyncResult result) {
        try {
            do_starttls_async.end(result);
        } catch (Error err) {
            exception(err);
        }
    }

    private void login(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 2, "user pass");

        status("Logging in...");
        this.cx.send_command(
            new GriabuntuMail.Imap.LoginCommand(args[0], args[1], null)
        );
    }

    private void logout(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 0, null);

        status("Logging out...");
        this.cx.send_command(
            new GriabuntuMail.Imap.LogoutCommand(null)
        );
    }

    private void id(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 0, null);

        status("Retrieving ID...");

        Gee.HashMap<string, string> fields = new Gee.HashMap<string, string>();
        fields.set("name", "griabuntu-mail-console");
        fields.set("version", Config.VERSION);

        this.cx.send_command(
            new GriabuntuMail.Imap.IdCommand(fields, null)
        );
    }

    private void namespace(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 0, null);

        status("Retrieving NAMESPACE...");
        this.cx.send_command(new GriabuntuMail.Imap.NamespaceCommand(null));
    }

    private void list(string cmd, string[] args) throws Error {
        check_min_connected(cmd, args, 2, "<reference> <mailbox> [special-use]");

        status("Listing...");
        GriabuntuMail.Imap.ListReturnParameter? return_param = null;
        if (args.length >= 3 && args[2] == "special-use") {
            return_param = new GriabuntuMail.Imap.ListReturnParameter();
            return_param.add_special_use();
        }
        this.cx.send_command(
            new GriabuntuMail.Imap.ListCommand.wildcarded(
                args[0],
                new GriabuntuMail.Imap.MailboxSpecifier(args[1]),
                (cmd.down() == "xlist"),
                return_param,
                null
            )
        );
    }

    private void examine(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 1, "<mailbox>");

        status("Opening %s read-only".printf(args[0]));
        this.cx.send_command(
            new GriabuntuMail.Imap.ExamineCommand(
                new GriabuntuMail.Imap.MailboxSpecifier(args[0]),
                null
            )
        );
    }

    private void create(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 1, "<mailbox>");

        status("Creating %s".printf(args[0]));
        this.cx.send_command(
            new GriabuntuMail.Imap.CreateCommand(
                new GriabuntuMail.Imap.MailboxSpecifier(args[0]),
                null
            )
        );
    }

    private void @delete(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 1, "<mailbox>");

        status("Deleting %s".printf(args[0]));
        this.cx.send_command(
            new GriabuntuMail.Imap.DeleteCommand(
                new GriabuntuMail.Imap.MailboxSpecifier(args[0]),
                null
            )
        );
    }

    private void fetch(string cmd, string[] args) throws Error {
        check_min_connected(cmd, args, 2, "<message-span> <data-item...>");

        status("Fetching %s".printf(args[0]));

        GriabuntuMail.Imap.MessageSet msg_set = (cmd.down() == "fetch")
            ? new GriabuntuMail.Imap.MessageSet.custom(args[0])
            : new GriabuntuMail.Imap.MessageSet.uid_custom(args[0]);

        Gee.ArrayList<GriabuntuMail.Imap.FetchDataSpecifier> data_items = new Gee.ArrayList<GriabuntuMail.Imap.FetchDataSpecifier>();
        for (int ctr = 1; ctr < args.length; ctr++) {
            GriabuntuMail.Imap.StringParameter stringp = GriabuntuMail.Imap.StringParameter.get_best_for(args[ctr]);
            GriabuntuMail.Imap.FetchDataSpecifier data_type = GriabuntuMail.Imap.FetchDataSpecifier.from_parameter(stringp);
            data_items.add(data_type);
        }

        this.cx.send_command(
            new GriabuntuMail.Imap.FetchCommand(msg_set, data_items, null, null)
        );
    }

    private void fetch_fields(string cmd, string[] args) throws Error {
        check_min_connected(cmd, args, 2, "<message-span> <field-name...>");

        status("Fetching fields %s".printf(args[0]));

        GriabuntuMail.Imap.FetchBodyDataSpecifier fields = new GriabuntuMail.Imap.FetchBodyDataSpecifier(
            GriabuntuMail.Imap.FetchBodyDataSpecifier.SectionPart.HEADER_FIELDS, null, -1, -1, args[1:args.length]);

        Gee.List<GriabuntuMail.Imap.FetchBodyDataSpecifier> list = new Gee.ArrayList<GriabuntuMail.Imap.FetchBodyDataSpecifier>();
        list.add(fields);

        this.cx.send_command(
            new GriabuntuMail.Imap.FetchCommand(
                new GriabuntuMail.Imap.MessageSet.custom(args[0]), null, list, null
            )
        );
    }

    private void append(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 2, "<mailbox> <filename>");

        status("Appending %s to %s".printf(args[1], args[0]));

        this.cx.send_command(
            new GriabuntuMail.Imap.AppendCommand(
                new GriabuntuMail.Imap.MailboxSpecifier(args[0]),
                null,
                null,
                new GriabuntuMail.Memory.FileBuffer(File.new_for_path(args[1]), true),
                null
            )
        );
    }

    private void search(string cmd, string[] args) throws Error {
        check_min_connected(cmd, args, 1, "<arg> ...");

        status("Searching");

        GriabuntuMail.Imap.SearchCriteria criteria = new GriabuntuMail.Imap.SearchCriteria();
        foreach (string arg in args)
            criteria.and(new GriabuntuMail.Imap.SearchCriterion.simple(arg));

        GriabuntuMail.Imap.SearchCommand search;
        if (cmd == "uid-search")
            search = new GriabuntuMail.Imap.SearchCommand.uid(criteria, null);
        else
            search = new GriabuntuMail.Imap.SearchCommand(criteria, null);

        this.cx.send_command(search);
    }

    private void close_cmd(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 0, null);

        status("Closing");

        this.cx.send_command(
            new GriabuntuMail.Imap.CloseCommand(null)
        );
    }

    private void folder_status(string cmd, string[] args) throws Error {
        check_min_connected(cmd, args, 2, "<folder> <data-item...>");

        status("Status %s".printf(args[0]));

        GriabuntuMail.Imap.StatusDataType[] data_items = new GriabuntuMail.Imap.StatusDataType[0];
        for (int ctr = 1; ctr < args.length; ctr++) {
            GriabuntuMail.Imap.StringParameter stringp = GriabuntuMail.Imap.StringParameter.get_best_for(args[ctr]);
            data_items += GriabuntuMail.Imap.StatusDataType.from_parameter(stringp);
        }

        this.cx.send_command(
            new GriabuntuMail.Imap.StatusCommand(
                new GriabuntuMail.Imap.MailboxSpecifier(args[0]),
                data_items,
                null
            )
        );
    }

    private void preview(string cmd, string[] args) throws Error {
        check_min_connected(cmd, args, 1, "<message-span>");

        status("Preview %s".printf(args[0]));

        GriabuntuMail.Imap.FetchBodyDataSpecifier preview_data_type = new GriabuntuMail.Imap.FetchBodyDataSpecifier.peek(
            GriabuntuMail.Imap.FetchBodyDataSpecifier.SectionPart.NONE, { 1 }, 0, GriabuntuMail.Email.MAX_PREVIEW_BYTES,
            null);

        Gee.ArrayList<GriabuntuMail.Imap.FetchBodyDataSpecifier> list = new Gee.ArrayList<GriabuntuMail.Imap.FetchBodyDataSpecifier>();
        list.add(preview_data_type);

        this.cx.send_command(
            new GriabuntuMail.Imap.FetchCommand(
                new GriabuntuMail.Imap.MessageSet.custom(args[0]), null, list, null
            )
        );
    }

    private void quit(string cmd, string[] args) throws Error {
        GLib.Application app = GLib.Application.get_default();
        app.quit();
    }

    private bool keepalive_on = false;

    private void keepalive(string cmd, string[] args) throws Error {
        if (keepalive_on) {
            status("Keepalive already active.");

            return;
        }

        check_connected(cmd, args, 0, null);

        keepalive_on = true;
        Timeout.add_seconds(KEEPALIVE_SEC, on_keepalive);

        status("Keepalive on.");
    }

    private bool on_keepalive() {
        try {
            noop("noop", new string[0]);
        } catch (Error err) {
            status("Keepalive failed, halted: %s".printf(err.message));

            keepalive_on = false;
        }

        return keepalive_on;
    }

    private void print_console_line(string text) {
        append_to_console("[C] ");
        append_to_console(text);
        append_to_console("\n");
    }

    private void on_sent_command(GriabuntuMail.Imap.Command cmd) {
        append_to_console("[L] ");
        append_to_console(cmd.to_string());
        append_to_console("\n");
    }

    private void on_received_status_response(GriabuntuMail.Imap.StatusResponse status_response) {
        append_to_console("[R] ");
        append_to_console(status_response.to_string());
        append_to_console("\n");

        // TODO: This means that responses will grow without bounds without some process of
        // timing-out old unharvested responses
        status_responses.set(status_response.tag, status_response);
        recvd_response_event.blind_notify();
    }

    private async GriabuntuMail.Imap.StatusResponse wait_for_response_async(GriabuntuMail.Imap.Tag tag) throws Error {
        for (;;) {
            GriabuntuMail.Imap.StatusResponse? response = status_responses.get(tag);
            if (response != null)
                return response;

            yield recvd_response_event.wait_async();
        }
    }

    private void on_received_server_data(GriabuntuMail.Imap.ServerData server_data) {
        append_to_console("[D] ");
        append_to_console(server_data.to_string());
        append_to_console("\n");
    }

    private void on_received_bad_response(GriabuntuMail.Imap.RootParameters root, GriabuntuMail.ImapError err) {
        append_to_console("[E] ");
        append_to_console(err.message);
        append_to_console(": ");
        append_to_console(root.to_string());
        append_to_console("\n");
    }

    private void append_to_console(string text) {
        Gtk.TextIter iter;
        console.buffer.get_iter_at_offset(out iter, -1);
        console.buffer.insert(ref iter, text, -1);
    }
}

int main(string[] args) {
    GriabuntuMail.Logging.init();
    GriabuntuMail.Logging.log_to(stdout);

    Adw.Application app = new Adw.Application(null, GLib.ApplicationFlags.DEFAULT_FLAGS);

    app.activate.connect((gapp) => {
        ImapConsole console = new ImapConsole(app);
        console.present();
    });

    return app.run(args);
}
