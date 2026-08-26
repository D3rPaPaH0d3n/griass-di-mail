/*
 * Copyright © 2016 Software Freedom Conservancy Inc.
 * Copyright © 2016, 2019-2021 Michael Gratton <mike@vee.net>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

[GtkTemplate (ui = "/net/donnybeelo/Convey/application-main-window.ui")]
public class Application.MainWindow :
    Adw.ApplicationWindow, Convey.BaseInterface {


    // Named actions.
    public const string ACTION_ARCHIVE_CONVERSATION = "archive-conversation";
    public const string ACTION_CONVERSATION_DOWN = "down-conversation";
    public const string ACTION_CONVERSATION_UP = "up-conversation";
    public const string ACTION_DELETE_CONVERSATION = "delete-conversation";
    public const string ACTION_FIND_IN_CONVERSATION = "find-in-conversation";
    public const string ACTION_FORWARD_CONVERSATION = "forward-conversation";
    public const string ACTION_MARK_AS_READ = "mark-conversation-read";
    public const string ACTION_MARK_AS_STARRED = "mark-conversation-starred";
    public const string ACTION_MARK_AS_UNREAD = "mark-conversation-unread";
    public const string ACTION_MARK_AS_UNSTARRED = "mark-conversation-unstarred";
    public const string ACTION_REPLY_ALL_CONVERSATION = "reply-all-conversation";
    public const string ACTION_REPLY_CONVERSATION = "reply-conversation";
    public const string ACTION_SEARCH = "search";
    public const string ACTION_SELECT_INBOX = "select-inbox";
    public const string ACTION_FOLDER_NEW = "folder-new";
    public const string ACTION_FOLDER_RENAME = "folder-rename";
    public const string ACTION_FOLDER_DELETE = "folder-delete";
    public const string ACTION_SHOW_COPY_MENU = "show-copy-menu";
    public const string ACTION_TOGGLE_JUNK = "toggle-conversation-junk";
    public const string ACTION_TRASH_CONVERSATION = "trash-conversation";
    public const string ACTION_ZOOM = "zoom";
    public const string ACTION_NAVIGATION_BACK = "navigation-back";

    private const ActionEntry[] EDIT_ACTIONS = {
        { Action.Edit.UNDO, on_undo },
        { Action.Edit.REDO, on_redo },
    };

    private const ActionEntry[] WINDOW_ACTIONS = {
        { Action.Window.CLOSE, on_close },
        { Action.Window.SHOW_HELP_OVERLAY, on_show_help_overlay },
        { Action.Window.SHOW_MENU, on_show_window_menu },

        { ACTION_FIND_IN_CONVERSATION, on_find_in_conversation_action },
        { ACTION_SEARCH, on_search_activated },
        { ACTION_SELECT_INBOX, on_select_inbox, "i" },

        // Folder actions
        { ACTION_FOLDER_NEW, on_folder_new },
        { ACTION_FOLDER_RENAME, on_folder_rename },
        { ACTION_FOLDER_DELETE, on_folder_delete },

        // Message actions
        { ACTION_REPLY_CONVERSATION, on_reply_conversation },
        { ACTION_REPLY_ALL_CONVERSATION, on_reply_all_conversation },
        { ACTION_FORWARD_CONVERSATION, on_forward_conversation },
        { ACTION_ARCHIVE_CONVERSATION, on_archive_conversation },
        { ACTION_TRASH_CONVERSATION, on_trash_conversation },
        { ACTION_DELETE_CONVERSATION, on_delete_conversation },
        { ACTION_SHOW_COPY_MENU, on_show_copy_menu },
        { ACTION_CONVERSATION_UP, on_conversation_up },
        { ACTION_CONVERSATION_DOWN, on_conversation_down },
        // Message marking actions
        { ACTION_MARK_AS_READ, on_mark_as_read },
        { ACTION_MARK_AS_UNREAD, on_mark_as_unread },
        { ACTION_MARK_AS_STARRED, on_mark_as_starred },
        { ACTION_MARK_AS_UNSTARRED, on_mark_as_unstarred },
        { ACTION_TOGGLE_JUNK, on_mark_as_junk_toggle },
        // Message viewer
        { ACTION_ZOOM, on_zoom, "s" },
    };

    private const int UPDATE_UI_INTERVAL = 60;

    private const int MIN_CONVERSATION_COUNT = 50;

    public static void add_accelerators(Client owner) {
        for (int i = 1; i <= 9; i++) {
            owner.add_window_accelerators(
                ACTION_SELECT_INBOX+("(%d)".printf(i - 1)), { "<ALT>%d".printf(i) }
            );
        }

        // Zoom
        owner.add_window_accelerators(
            ACTION_ZOOM+("('in')"), { "<Ctrl>equal", "<Ctrl>plus" }
        );
        owner.add_window_accelerators(
            ACTION_ZOOM+("('out')"), { "<Ctrl>minus" }
        );
        owner.add_window_accelerators(
            ACTION_ZOOM+("('normal')"), { "<Ctrl>0" }
        );
    }


    private enum ConversationCount {
        NONE, SINGLE, MULTIPLE;

        public static ConversationCount for_size(int size) {
            return (
                size == 0
                ? NONE
                : size == 1
                ? SINGLE
                : MULTIPLE
            );
        }
    }


    /** Returns the window's associated client application instance. */
    public new Client application {
        get { return (Client) base.get_application(); }
        set { base.set_application(value); }
    }

    /** Currently selected account, null if none selected */
    public Convey.Account? selected_account { get; private set; default = null; }

    /** Currently selected folder, null if none selected */
    public Convey.Folder? selected_folder { get; private set; default = null; }

    /** Conversations for the current folder, null if none selected */
    public Convey.App.ConversationMonitor? conversations {
        get; private set; default = null;
    }

    /** Specifies if the conversation list is currently displayed. */
    public bool is_folder_list_shown {
        get {
            return (
                (!this.outer_view.collapsed || !this.outer_view.show_content)
                &&
                (!this.inner_view.collapsed || !this.inner_view.show_content)
            );
        }
    }

    /** Specifies if the conversation list is currently displayed. */
    public bool is_conversation_list_shown {
        get {
            return (
                (!this.outer_view.collapsed || !this.outer_view.show_content)
                &&
                (!this.inner_view.collapsed || this.inner_view.show_content)
            );
        }
    }

    /** Specifies if the conversation viewer is currently displayed. */
    public bool is_conversation_viewer_shown {
        get {
            return (
                !this.outer_view.collapsed || this.outer_view.show_content
            );
        }
    }

    /** The attachment manager for this window. */
    public AttachmentManager attachments { get; private set; }

    /** Determines if conversations in the selected folder can be trashed. */
    public bool selected_folder_supports_trash {
        get {
            return Controller.does_folder_support_trash(this.selected_folder);
        }
    }

    /** Determines if a composer is currently open in this window. */
    public bool has_composer {
        get {
            return (this.conversation_viewer.current_composer != null);
        }
    }

    /** Specifies if the Shift key is currently being held. */
    public bool is_shift_down { get; private set; default = false; }

    // Used to save/load the window state between sessions.
    public int window_width { get; set; }
    public int window_height { get; set; }

    // Widget descendants
    public FolderList.Tree folder_list { get; private set; default = new FolderList.Tree(); }
    public SearchBar search_bar { get; private set; }

    // Same menu, worded for folders and for labels; which model the
    // context menu uses depends on the account under the pointer.
    private GLib.Menu folder_menu;
    private GLib.Menu label_menu;
    public ConversationList.View conversation_list_view  { get; private set; }
    public ConversationViewer conversation_viewer { get; private set; }

    public Components.InfoBarStack conversation_list_info_bars {
        get; private set; default = new Components.InfoBarStack(PRIORITY_QUEUE);
    }

    private Controller controller;

    private Gee.Set<AccountContext> accounts = new Gee.HashSet<AccountContext>();

    private GLib.SimpleActionGroup edit_actions = new GLib.SimpleActionGroup();

    // Determines if the conversation viewer should auto-mark messages
    // on next load
    private bool previous_selection_was_interactive = false;

    // Caches the last non-search folder so it can be re-selected on
    // the search folder closing
    private Convey.Folder? previous_non_search_folder = null;

    private Convey.AggregateProgressMonitor progress_monitor = new Convey.AggregateProgressMonitor();

    private GLib.Cancellable action_update_cancellable = new GLib.Cancellable();
    private GLib.Cancellable folder_open = new GLib.Cancellable();

    private Convey.TimeoutManager update_ui_timeout;
    private int64 update_ui_last = 0;

    [GtkChild] private unowned Gtk.ToggleButton search_button;
    [GtkChild] private unowned Gtk.ToggleButton conversation_list_selection_button;
    [GtkChild] private unowned Gtk.MenuButton app_menu_button;
    [GtkChild] private unowned Gtk.Button refresh_button;
    [GtkChild] private unowned Gtk.Stack refresh_stack;
    [GtkChild] private unowned Gtk.Image refresh_image;
    [GtkChild] private unowned Gtk.Spinner headerbar_spinner;

    private int headerbar_busy_count = 0;

    [GtkChild] private unowned Adw.HeaderBar conversation_list_headerbar;

    // Outer and inner split are [[ folder_box | conversation_list ] | conversation_viewer ]
    [GtkChild] private unowned Adw.NavigationSplitView outer_view;
    [GtkChild] private unowned Adw.NavigationSplitView inner_view;

    [GtkChild] private unowned Gtk.ScrolledWindow folder_list_scrolled;

    [GtkChild] private unowned Adw.NavigationPage conversation_list_page;
    [GtkChild] private unowned Adw.WindowTitle conversation_list_title;
    [GtkChild] private unowned Gtk.Box conversation_list_box;
    [GtkChild] private unowned Gtk.Revealer conversation_list_actions_revealer;
    [GtkChild] private unowned Components.ConversationActions conversation_list_actions;
    [GtkChild] private unowned Components.ConversationActions conversation_viewer_actions;

    [GtkChild] private unowned Adw.NavigationPage conversation_viewer_page;

    [GtkChild] private unowned Adw.ToastOverlay overlay;

    [GtkChild] private unowned Components.InfoBarStack info_bars;

    private Components.ConversationActions[] folder_conversation_actions = {};

    private Components.InfoBar offline_infobar;
    private Components.InfoBar cert_problem_infobar;
    private Components.InfoBar auth_problem_infobar;
    private Components.ProblemReportInfoBar? service_problem_infobar = null;

    /** Fired when the user requests an account status be retried. */
    public signal void retry_service_problem(Convey.ClientService.Status problem);


    /** Keybinding signal for replying to sender for the current conversation. */
    [Signal (action=true)]
    public virtual signal void reply_conversation_sender() {
        activate_action(get_window_action(ACTION_REPLY_CONVERSATION));
    }

    /** Keybinding signal for replying to all for the current conversation. */
    [Signal (action=true)]
    public virtual signal void reply_conversation_all() {
        activate_action(get_window_action(ACTION_REPLY_ALL_CONVERSATION));
    }

    /** Keybinding signal for forwarding the current conversation. */
    [Signal (action=true)]
    public virtual signal void forward_conversation() {
        activate_action(get_window_action(ACTION_FORWARD_CONVERSATION));
    }

    /** Keybinding signal for marking the current selection read. */
    [Signal (action=true)]
    public virtual signal void mark_conversations_read(bool prefer_read) {
        activate_action(
            prefer_read
            ? get_window_action(ACTION_MARK_AS_READ)
            : get_window_action(ACTION_MARK_AS_UNREAD)
        );
    }

    /** Keybinding signal for marking the current selection starred. */
    [Signal (action=true)]
    public virtual signal void mark_conversations_starred(bool prefer_starred) {
        activate_action(
            prefer_starred
            ? get_window_action(ACTION_MARK_AS_STARRED)
            : get_window_action(ACTION_MARK_AS_UNSTARRED)
        );
    }

    /** Keybinding signal for showing the copy/label menu. */
    [Signal (action=true)]
    public virtual signal void show_copy_menu() {
        activate_action(get_window_action(ACTION_SHOW_COPY_MENU));
    }

    /** Keybinding signal for archiving the current selection. */
    [Signal (action=true)]
    public virtual signal void archive_conversations() {
        activate_action(get_window_action(ACTION_ARCHIVE_CONVERSATION));
    }

    /** Keybinding signal for junking the current selection. */
    [Signal (action=true)]
    public virtual signal void junk_conversations() {
        activate_action(get_window_action(ACTION_TOGGLE_JUNK));
    }

    /** Keybinding signal for trashing the current selection. */
    [Signal (action=true)]
    public virtual signal void trash_conversations() {
        // The Shift+BackSpace combo above doesn't seem to work
        // for delete, so double-check here.
        activate_action(
            !this.is_shift_down
            ? get_window_action(ACTION_TRASH_CONVERSATION)
            : get_window_action(ACTION_DELETE_CONVERSATION)
        );
    }

    /** Keybinding signal for deleting the current selection. */
    [Signal (action=true)]
    public virtual signal void delete_conversations() {
        activate_action(get_window_action(ACTION_DELETE_CONVERSATION));
    }

    /** Keybinding signal for activating conversation search. */
    [Signal (action=true)]
    public virtual signal void search() {
        activate_action(get_window_action(ACTION_SEARCH));
    }

    /** Keybinding signal for activating in-conversation find. */
    [Signal (action=true)]
    public virtual signal void find() {
        activate_action(get_window_action(ACTION_FIND_IN_CONVERSATION));
    }

    /** Keybinding signal for selecting all elements in current view. */
    [Signal (action=true)]
    public virtual signal void select_all() {
        this.conversation_list_view.select_all();
    }

    /** Keybinding signal for shifting the keyboard focus. */
    [Signal (action=true)]
    public virtual signal void navigate(Gtk.ScrollType type) {
        switch (type) {
        case Gtk.ScrollType.STEP_UP:
            activate_action(get_window_action(ACTION_CONVERSATION_UP));
            break;
        case Gtk.ScrollType.STEP_DOWN:
            activate_action(get_window_action(ACTION_CONVERSATION_DOWN));
            break;
        default:
            error_bell();
            break;
        }
    }


    internal MainWindow(Client application) {
        Object(
            application: application,
            show_menubar: false
        );
        base_ref();

        // Keep a ref on the current controller so that even if the
        // application has been shut down, any async tasks that are
        // running (and presumably being cancelled) can still complete
        // without a warning.
        this.controller = application.controller;

        // Create a new group for the window so attachment file
        // choosers (save attachments & composer attach files) do not
        // block other main windows or composers.
        var group = new Gtk.WindowGroup();
        group.add_window(this);

        load_config(application.config);
        restore_saved_window_state();

        if (Config.PROFILE != Client.PROFILE_RELEASE) {
            add_css_class("devel");
        }

        // Edit actions
        this.edit_actions.add_action_entries(EDIT_ACTIONS, this);
        insert_action_group(Action.Edit.GROUP_NAME, this.edit_actions);

        // Window actions
        add_action_entries(MainWindow.WINDOW_ACTIONS, this);

        setup_layout(application.config);

        update_command_actions();
        update_conversation_actions(NONE);

        this.attachments = new AttachmentManager(this);

        this.update_ui_timeout = new Convey.TimeoutManager.seconds(
            UPDATE_UI_INTERVAL, on_update_ui_timeout
        );
        this.update_ui_timeout.repetition = FOREVER;

        // Add future and existing accounts to the main window
        this.controller.account_available.connect(
            on_account_available
        );
        this.controller.account_unavailable.connect(
            on_account_unavailable
        );
        foreach (AccountContext context in
                 this.controller.get_account_contexts()) {
            add_account(context);
        }

        this.offline_infobar = new Components.InfoBar(
            // Translators: An info bar status label
            _("Working offline"),
            // Translators: An info bar description label
            _("You will not be able to send or receive email until re-connected.")
        );
        this.offline_infobar.show_close_button = true;
        this.offline_infobar.response.connect(on_offline_infobar_response);

        this.auth_problem_infobar = new Components.InfoBar(
            // Translators: An info bar status label
            _("Login problem"),
            // Translators: An info bar description label
            _("An account has reported an incorrect login or password.")
        );
        // Translators: An info bar button label
        var auth_retry = new Gtk.Button.with_label(_("Login"));
        auth_retry.show();
        // Translators: An info bar button tool-tip
        auth_retry.tooltip_text = _(
            "Retry login, you will be prompted for your password"
        );
        auth_retry.clicked.connect(on_auth_problem_retry);
        this.auth_problem_infobar.get_action_area().append(auth_retry);

        this.cert_problem_infobar = new Components.InfoBar(
            // Translators: An info bar status label
            _("Security problem"),
            // Translators: An info bar description label
            _("An account has reported an untrusted server.")
        );
        // Translators: An info bar button label
        var cert_retry = new Gtk.Button.with_label(_("Check"));
        cert_retry.show();
        // Translators: An info bar button tool-tip
        cert_retry.tooltip_text = _(
            "Check the security details for the connection"
        );
        cert_retry.clicked.connect(on_cert_problem_retry);
        this.cert_problem_infobar.get_action_area().append(cert_retry);

        this.map.connect(() => {
            this.folder_list.grab_focus();
        });

        foreach (var actions in this.folder_conversation_actions) {
            actions.mark_message_button_toggled.connect(on_show_mark_menu);
        }
    }

    ~MainWindow() {
        base_unref();
    }

    /** Updates the window's title and headerbar titles. */
    public void update_title() {
        AccountContext? account = get_selected_account_context();
        FolderContext? folder = (
            account != null && this.selected_folder != null
            ? account.get_folder(this.selected_folder)
            : null
        );
        string title = _("Convey");
        string? account_name = null;
        string? folder_name = null;
        if (account != null && folder != null) {
            account_name = account.account.information.display_name;
            folder_name = folder.display_name;
            /// Translators: Main window title, first string
            /// substitution being the currently selected folder name,
            /// the second being the selected account name.
            title = _("%s — %s").printf(folder_name, account_name);
        }
        this.title = title;
        this.conversation_list_page.title = account_name ?? "";
        this.conversation_list_title.title = account_name ?? "";
        // ponytail: only show the address when it isn't already the title
        string address = (
            account != null ? account.account.information.primary_mailbox.address : ""
        );
        this.conversation_list_title.subtitle = (
            account_name != null && account_name != address ? address : ""
        );
    }

    /** Updates the window's account status info bars. */
    public void update_account_status(Convey.Account.Status status,
                                      bool has_auth_error,
                                      bool has_cert_error,
                                      Convey.Account? problem_source) {
        // Only ever show one info bar at a time. Offline is primary
        // since nothing else can happen when offline. Service
        // problems are secondary since auth and cert problems can't
        // be resolved when the service isn't talking to the
        // server. Cert problems are tertiary since you can't auth if
        // you can't connect.
        if (!status.is_online()) {
            this.info_bars.add(this.offline_infobar);
        } else if (status.has_service_problem()) {
            Convey.ClientService? service = (
                problem_source.incoming.last_error != null
                ? problem_source.incoming
                : problem_source.outgoing
            );
            this.service_problem_infobar = new Components.ProblemReportInfoBar(
                new Convey.ServiceProblemReport(
                    problem_source.information,
                    service.configuration,
                    service.last_error.thrown
                )
            );
            this.service_problem_infobar.retry.connect(on_service_problem_retry);
            this.info_bars.add(this.service_problem_infobar);
        } else if (has_cert_error) {
            this.info_bars.add(this.cert_problem_infobar);
        } else if (has_auth_error) {
            this.info_bars.add(this.auth_problem_infobar);
        } else {
            this.info_bars.remove_all();
        }
    }

    /**
     * Selects and open the given folder.
     *
     * If is_interactive is true, the selection is treated as being
     * caused directly by human request (e.g. clicking on a folder in
     * the folder list), as opposed to some side effect.
     */
    public async void select_folder(Convey.Folder? to_select,
                                    bool is_interactive,
                                    bool inhibit_autoselect = false) {
        if (this.selected_folder == to_select) {
            // Clicking the already-selected folder scrolls the
            // conversation list back to the top.
            if (is_interactive && to_select != null) {
                this.conversation_list_view.scroll_to_top();
            }
        } else {
            // Cancel any existing folder loading
            this.folder_open.cancel();
            var cancellable = this.folder_open = new GLib.Cancellable();

            this.conversation_list_selection_button.active = false;

            // Dispose of all existing objects for the currently
            // selected model.

            if (this.selected_folder != null) {
                this.progress_monitor.remove(this.selected_folder.opening_monitor);
                this.selected_folder.properties.notify.disconnect(update_headerbar);
                this.selected_folder = null;
            }
            if (this.conversations != null) {
                this.progress_monitor.remove(this.conversations.progress_monitor);
                close_conversation_monitor(this.conversations);
                this.conversations = null;
                this.conversation_list_view.set_monitor(null);
            }

            this.conversation_list_info_bars.remove_all();

            // With everything disposed of, update existing window
            // state

            select_account(to_select != null ? to_select.account : null);
            this.selected_folder = to_select;
            foreach (var actions in this.folder_conversation_actions) {
                actions.source_folder = to_select;
            }

            // Ensure that the folder is selected in the UI if
            // this was called by something other than the
            // selection changed callback. That will check to
            // ensure that we're not setting it again.
            if (to_select != null) {
                // Prefer the inboxes branch if it is a thing, but
                // only for non-interactive calls
                if (is_interactive ||
                    (to_select.used_as != INBOX ||
                     !this.folder_list.select_inbox(to_select.account))) {
                    this.folder_list.select_folder(to_select);
                }
            } else {
                this.folder_list.deselect_folder();
            }

            update_title();
            update_conversation_actions(NONE);
            update_trash_action();

            this.conversation_viewer.show_loading();
            this.previous_selection_was_interactive = is_interactive;

            debug("Folder selected: %s",
                  (to_select != null) ? to_select.to_string() : "(null)");

            // Finally, hook up the new folder if any and start
            // loading conversations.

            if (to_select != null) {
                this.progress_monitor.add(to_select.opening_monitor);
                to_select.properties.notify.connect(update_headerbar);

                this.conversations = new Convey.App.ConversationMonitor(
                    to_select,
                    // Include fields for the conversation viewer as well so
                    // conversations can be displayed without having to go
                    // back to the db
                    ConversationList.View.REQUIRED_FIELDS |
                    ConversationListBox.REQUIRED_FIELDS |
                    ConversationEmail.REQUIRED_FOR_CONSTRUCT,
                    MIN_CONVERSATION_COUNT
                );
                this.progress_monitor.add(this.conversations.progress_monitor);

                if (inhibit_autoselect) {
                    this.conversation_list_view.inhibit_next_autoselect();
                }
                this.conversation_list_view.set_monitor(this.conversations);

                yield open_conversation_monitor(this.conversations, cancellable);
                yield this.controller.process_pending_composers();
            }
        }

        this.outer_view.show_content = false;
        this.inner_view.show_content = true;
        update_headerbar();
    }

    /** Selects the given account, folder and conversations. */
    public async void show_conversations(Convey.Folder location,
                                         Gee.Collection<Convey.App.Conversation> to_show,
                                         bool is_interactive) {
        bool inhibit_autoselect = (location != this.selected_folder);
        yield select_folder(location, is_interactive, inhibit_autoselect);
        // The folder may have changed again by the type the async
        // call returns, so only continue if still current
        if (this.selected_folder == location) {
            this.outer_view.show_content = true;

            // Since conversation ids don't persist between
            // conversation monitor instances, need to load
            // conversations based on their messages.
            var latest_email = new Gee.HashSet<Convey.EmailIdentifier>();
            foreach (var stale in to_show) {
                Convey.Email? first = stale.get_latest_recv_email(IN_FOLDER);
                if (first != null) {
                    latest_email.add(first.id);
                }
            }
            var loaded = yield load_conversations_for_email(
                location, latest_email
            );
            if (!loaded.is_empty) {
                yield select_conversations(
                    loaded,
                    Gee.Collection.empty<Convey.EmailIdentifier>(),
                    is_interactive
                );
            }
        }
    }

    /** Selects the given account, folder and email. */
    public async void show_email(Convey.Folder location,
                                 Gee.Collection<Convey.EmailIdentifier> to_show,
                                 bool is_interactive) {
        bool inhibit_autoselect = (location != this.selected_folder);
        yield select_folder(location, is_interactive, inhibit_autoselect);
        // The folder may have changed again by the type the async
        // call returns, so only continue if still current
        if (this.selected_folder == location) {
            var loaded = yield load_conversations_for_email(location, to_show);

            this.outer_view.show_content = true;
            if (loaded.size == 1) {
                // A single conversation was loaded, so ensure we
                // scroll to the email in the conversation.
                Convey.App.Conversation? target = Convey.Collection.first(loaded);
                ConversationListBox? current_list =
                    this.conversation_viewer.current_list;
                if (current_list != null &&
                    current_list.conversation == target) {
                    // The target conversation is already loaded, just
                    // scroll to the messages.
                    //
                    // This is actually racy, since the view may
                    // still be in the middle of loading the messages
                    // obtained from the conversation monitor when
                    // this call is made.
                    current_list.scroll_to_messages(to_show);
                } else {
                    // The target conversation is not loaded, select
                    // it and scroll to the messages.
                    yield select_conversations(loaded, to_show, is_interactive);
                }
            } else if (!loaded.is_empty) {
                // Multiple conversations found, just select those
                yield select_conversations(
                    loaded,
                    Gee.Collection.empty<Convey.EmailIdentifier>(),
                    is_interactive
                );
            }
        }
    }

    /** Shows the appopriate window menu, if any. */
    public void show_window_menu() {
        this.outer_view.show_content = false;
        this.inner_view.show_content = false;
        this.app_menu_button.active = true;
    }

    /** Displays and focuses the search bar for the window. */
    public void show_search_bar(string? text = null) {
        this.outer_view.show_content = false;
        this.inner_view.show_content = true;

        this.search_bar.search_mode_enabled = true;
        this.search_bar.grab_focus();
        if (text != null) {
            this.search_bar.entry.text = text;
        }
    }

    /** Displays an infobar in the window. */
    public void show_info_bar(Components.InfoBar info_bar) {
        if (!this.info_bars.has_current) {
            this.info_bars.add(info_bar);
        }
    }

    /**
     * Displays a composer in the window if possible, else in a new window.
     */
    internal void show_composer(Composer.Widget composer) {
        if (this.has_composer) {
            composer.detach(this.application);
        } else {
            // See if the currently displayed conversation contains
            // any of the composer's referred emails (preferring the
            // latest), and if so add it inline, otherwise add it full
            // paned.
            Convey.Email? latest_referred = null;
            if (this.conversation_viewer.current_list != null) {
                Convey.App.Conversation selected =
                    this.conversation_viewer.current_list.conversation;
                // When editing an existing draft, use the draft email
                // itself as the anchor so the composer appears at the
                // draft's position rather than the parent message's
                // position (restore_reply_to_state adds the parent's
                // ID to referred_ids, which would place the composer
                // one row too high).
                if (composer.saved_id != null) {
                    var draft_id = composer.saved_id;
                    latest_referred = selected.get_emails(
                        RECV_DATE_DESCENDING
                    ).first_match(
                        (email) => email.id.equal_to(draft_id)
                    );
                }
                if (latest_referred == null) {
                    Gee.Collection<Convey.EmailIdentifier>? referrants =
                        composer.get_referred_ids();
                    latest_referred = selected.get_emails(
                        RECV_DATE_DESCENDING
                    ).first_match(
                        (email) => email.id in referrants
                    );
                }
            }

            if (latest_referred != null) {
                this.conversation_viewer.do_compose_embedded(
                    composer, latest_referred
                );
            } else {
                this.conversation_viewer.do_compose(composer);
            }
            // Show the correct view
            this.outer_view.show_content = true;
        }
    }

    /**
     * Closes any open composers, after prompting the user if requested.
     *
     * Returns true if none were open or the user approved closing
     * them.
     */
    internal bool close_composer(bool should_prompt, bool is_shutdown = false) {
        Composer.Widget? composer = this.conversation_viewer.current_composer;
        if (composer == null) {
            return true;
        }
        if (!should_prompt) {
            // Without a prompt this saves or discards as appropriate
            // and always closes, so it can run in the background
            composer.conditional_close.begin(false, is_shutdown);
            return true;
        }
        // Prompting requires an async dialog; kick it off and report
        // not-closed so the caller doesn't proceed prematurely
        composer.conditional_close.begin(true, is_shutdown);
        return false;
    }

    internal void start_search(string query_text, bool is_interactive) {
        var context = get_selected_account_context();
        if (context != null) {
            // If the current folder is not the search folder, save it
            // so it can be re-selected later when search is closed
            if (this.previous_non_search_folder == null &&
                this.selected_folder != null &&
                this.selected_folder.used_as != SEARCH) {
                this.previous_non_search_folder = this.selected_folder;
            }

            try {
                var expr_factory = new Util.Email.SearchExpressionFactory(
                    this.application.config.get_search_strategy(),
                    context.account.information
                );
                var query = context.account.new_search_query(
                    expr_factory.parse_query(query_text),
                    query_text
                );
                this.folder_list.set_search(
                    this.application.engine, context.search
                );
                context.search.update_query(query);
            } catch (GLib.Error error) {
                handle_error(context.account.information, error);
            }
        }
    }

    internal void stop_search(bool is_interactive) {
        // If the search folder is current selected, deselect and
        // re-select any previously selected folder
        if (this.selected_folder == null ||
            this.selected_folder.used_as == SEARCH) {
            var to_select = this.previous_non_search_folder;
            if (to_select == null) {
                var account = get_selected_account_context();
                if (account != null) {
                    to_select = account.inbox;
                }

            }
            this.previous_non_search_folder = null;
            if (to_select != null) {
                this.select_folder.begin(
                    to_select, is_interactive
                );
            } else {
                select_first_inbox(is_interactive);
            }
        }
        this.folder_list.remove_search();

        foreach (var context in this.controller.get_account_contexts()) {
            context.search.clear_query();
        }
    }

    internal bool select_first_inbox(bool is_interactive) {
        bool success = false;
        Convey.Folder? inbox = get_first_inbox();
        if (inbox != null) {
            this.select_folder.begin(inbox, is_interactive);
            success = true;
        }
        return success;
    }

    private void add_account(AccountContext to_add) {
        if (!this.accounts.contains(to_add)) {
            this.folder_list.set_user_folders_root_name(
                to_add.account, _("Labels")
            );

            this.progress_monitor.add(to_add.account.background_progress);
            Convey.Smtp.ClientService? smtp = (
                to_add.account.outgoing as Convey.Smtp.ClientService
            );
            if (smtp != null) {
                this.progress_monitor.add(smtp.sending_monitor);
            }

            to_add.folders_available.connect(on_folders_available);
            to_add.folders_unavailable.connect(on_folders_unavailable);
            to_add.commands.executed.connect(on_command_execute);
            to_add.commands.undone.connect(on_command_undo);
            to_add.commands.redone.connect(on_command_redo);

            // Sort the folders so FolderListTree adds them all
            // correctly
            var added = new Gee.TreeSet<FolderContext>();
            added.add_all(to_add.get_folders());

            // Register the account before adding folders so anything
            // resolving the selected folder's context (e.g. the
            // window title) can find it
            this.accounts.add(to_add);
            add_folders(added);
        }
    }

    /**
     * Removes the given account from the main window.
     *
     * If `to_select` is not null, the given folder will be selected,
     * otherwise no folder will be.
     */
    private async void remove_account(AccountContext to_remove,
                                      Convey.Folder? to_select) {
        if (this.accounts.contains(to_remove)) {
            // Explicitly unset the selected folder if it belongs to the
            // account so we block until it's gone. This also clears the
            // previous search folder, so it won't try to re-load that
            // that when the account is gone.
            if (this.selected_folder != null &&
                this.selected_folder.account == to_remove.account) {
                bool is_account_search_active = (
                    this.selected_folder.used_as == SEARCH
                );

                yield select_folder(to_select, false);

                if (is_account_search_active) {
                    this.search_bar.entry.text = "";
                    this.search_bar.search_mode_enabled = false;
                }
            }

            to_remove.commands.executed.disconnect(on_command_execute);
            to_remove.commands.undone.disconnect(on_command_undo);
            to_remove.commands.redone.disconnect(on_command_redo);
            to_remove.folders_available.disconnect(on_folders_available);
            to_remove.folders_available.disconnect(on_folders_unavailable);

            this.progress_monitor.remove(to_remove.account.background_progress);
            Convey.Smtp.ClientService? smtp = (
                to_remove.account.outgoing as Convey.Smtp.ClientService
            );
            if (smtp != null) {
                this.progress_monitor.remove(smtp.sending_monitor);
            }

            // Finally, remove the account and its folders
            remove_folders(to_remove.get_folders(), false);
            this.folder_list.remove_account(to_remove.account);
            this.accounts.remove(to_remove);
        }
    }

    /** Adds a folder to the window. */
    private void add_folders(Gee.Collection<FolderContext> to_add) {
        // Build map between path and display name for
        // special directories
        var map = new Gee.HashMap<string,string>();
        foreach (var context in to_add) {
            var folder = context.folder;
            if (folder.used_as == Convey.Folder.SpecialUse.NONE)
                continue;
            map.set(
                folder.path.to_string().substring(1),
                context.display_name
            );
        }
        foreach (var context in to_add) {
            this.folder_list.add_folder(context);
            context.folder.use_changed.connect(on_use_changed);
        }

        // The selected folder may have been opened before its entry
        // (or account context) existed here, leaving the sidebar
        // unselected and the title empty; sync them now
        foreach (var context in to_add) {
            if (context.folder == this.selected_folder) {
                this.folder_list.select_folder(context.folder);
                update_title();
                break;
            }
        }
    }

    /** Removes a folder from the window. */
    private void remove_folders(Gee.Collection<FolderContext> to_remove,
                                bool update_selecton) {
        foreach (var context in to_remove) {
            Convey.Folder folder = context.folder;
            if (this.selected_folder == folder) {
                var account = get_selected_account_context();
                if (account != null) {
                    this.select_folder.begin(account.inbox, true);
                }
            }

            folder.use_changed.disconnect(on_use_changed);
            this.folder_list.remove_folder(context);
        }
    }

    private AccountContext? get_selected_account_context() {
        AccountContext? context = null;
        if (this.selected_account != null) {
            context = this.controller.get_context_for_account(
                this.selected_account.information
            );
        }
        return context;
    }

    private Convey.Folder? get_first_inbox() {
        Convey.Folder? inbox = null;
        try {
            Convey.Account? first = Convey.Collection.first<Convey.Account>(
                this.application.engine.get_accounts()
            );
            if (first != null) {
                inbox = first.get_special_folder(INBOX);
            }
        } catch (GLib.Error error) {
            debug("Error getting inbox for first account");
        }
        return inbox;
    }

    private void load_config(Configuration config) {
        // This code both loads AND saves the pane positions with live updating. This is more
        // resilient against crashes because the value in dconf changes *immediately*, and
        // stays saved in the event of a crash.
        config.bind(Configuration.WINDOW_WIDTH_KEY, this, "window-width");
        config.bind(Configuration.WINDOW_HEIGHT_KEY, this, "window-height");
        config.bind(Configuration.WINDOW_MAXIMIZE_KEY, this, "maximized");
    }

    private void restore_saved_window_state() {
        // The window isn't realized yet, so there's no monitor to
        // sanity-check the size against; the compositor will clamp
        // over-size windows anyway.
        if (this.window_width > 0 && this.window_height > 0) {
            set_default_size(this.window_width, this.window_height);
        }
        if (this.maximized) {
            maximize();
        }
    }

    public override bool close_request() {
        // Any composer prompt and the final teardown are async, so
        // always inhibit the close here and destroy the window
        // ourselves when ready
        this.do_close_request.begin();
        return true;
    }

    private async void do_close_request() {
        Composer.Widget? composer = this.conversation_viewer.current_composer;
        if (composer != null &&
            (yield composer.conditional_close(true, false)) == CANCELLED) {
            return;
        }

        this.window_width = this.default_width;
        this.window_height = this.default_height;

        if (this.application != null) {
            this.controller.account_available.disconnect(
                on_account_available
            );
            this.controller.account_unavailable.disconnect(
                on_account_unavailable
            );
        }
        this.update_ui_timeout.reset();

        this.sensitive = false;
        this.select_folder.begin(
            null,
            false,
            true,
            (obj, res) => {
                this.select_folder.end(res);
                destroy();
            }
        );
    }

    public void add_toast(Adw.Toast toast) {
        this.overlay.add_toast(toast);
    }

    private void setup_layout(Configuration config) {
        this.notify["has-toplevel-focus"].connect(on_has_toplevel_focus);

        // Search bar
        this.search_bar = new SearchBar(this.application.engine);
        this.search_bar.search_text_changed.connect(on_search);
        this.conversation_list_box.append(this.search_bar);


        // Folder list
        this.folder_list.folder_selected.connect(on_folder_selected);
        this.folder_list.move_conversation.connect(on_move_conversation);
        this.folder_list.copy_conversation.connect(on_copy_conversation);
        this.folder_list.folder_activated.connect(on_folder_activated);
        this.folder_list.folder_rename.connect(on_folder_rename_requested);
        this.folder_list.folder_delete.connect(on_folder_delete_requested);
        this.folder_list_scrolled.child = this.folder_list;
        setup_folder_context_menu();

        // Conversation list
        this.conversation_list_box.append(this.conversation_list_info_bars);

        this.conversation_list_view = new ConversationList.View(this.application.config);
        this.conversation_list_view.mark_conversations.connect(on_mark_conversations);
        this.conversation_list_view.conversations_selected.connect(on_conversations_selected);
        this.conversation_list_view.conversation_activated.connect(on_conversation_activated);
        this.conversation_list_view.visible_conversations.notify.connect(on_visible_conversations_changed);
        this.conversation_list_view.mail_drag_active.connect(
            this.folder_list.set_drag_active
        );
        this.conversation_list_view.vexpand = true;

        this.conversation_list_box.append(this.conversation_list_view);

        // Conversation viewer
        this.conversation_viewer = new ConversationViewer(
            this.application.config
        );
        this.conversation_viewer.conversation_added.connect(
            on_conversation_view_added
        );

        this.conversation_viewer.hexpand = true;
        this.conversation_viewer_page.child = this.conversation_viewer;

        // Left/Right walk the keyboard focus across the panes. The
        // conversation viewer gets no handler of its own: its message
        // bodies and composers want the arrow keys for themselves.
        setup_pane_navigation(
            this.folder_list, null, this.conversation_list_view
        );
        setup_pane_navigation(
            this.conversation_list_view,
            this.folder_list,
            this.conversation_viewer
        );

        this.conversation_list_selection_button.bind_property(
            "active",
            this.conversation_list_view, "selection-mode-enabled",
            SYNC_CREATE | BIDIRECTIONAL
        );
        this.search_button.bind_property(
            "active",
            this.search_bar, "search-mode-enabled",
            SYNC_CREATE | BIDIRECTIONAL
        );
        this.conversation_viewer.headerbar.bind_property(
            "find-open",
            this.conversation_viewer.conversation_find_bar, "search-mode-enabled",
            SYNC_CREATE | BIDIRECTIONAL
        );
        this.conversation_list_selection_button.notify["active"].connect(
            (obj, pspec) => {
                // Only show revealer with bottom actions in narrow mode
                if (this.conversation_list_view.selection_mode_enabled)
                    this.conversation_list_actions_revealer.reveal_child = (
                        this.inner_view.collapsed);
                else
                    this.conversation_list_actions_revealer.reveal_child = false;
            }
        );

        progress_monitor.start.connect(() => headerbar_push_busy());
        progress_monitor.finish.connect(() => headerbar_pop_busy());
        this.refresh_button.clicked.connect(on_refresh_folder);

        this.conversation_list_actions.set_mark_inverted();

        this.conversation_viewer.headerbar.left_actions.init(this.application.config);
        this.conversation_viewer.headerbar.right_actions.init(this.application.config);
        this.conversation_list_actions.init(this.application.config);
        this.conversation_viewer_actions.init(this.application.config);

        this.folder_conversation_actions = {
            this.conversation_viewer.headerbar.left_actions,
            this.conversation_viewer.headerbar.right_actions,
            this.conversation_list_actions,
            this.conversation_viewer_actions
        };

        foreach (var actions in this.folder_conversation_actions) {
            actions.copy_popover.copy_conversation.connect(on_copy_conversation);
            actions.move_popover.move_conversation.connect(on_move_conversation);
        }
    }

    [GtkCallback]
    private bool on_key_pressed(Gtk.EventControllerKey controller,
                                uint keyval,
                                uint keycode,
                                Gdk.ModifierType state) {
        check_shift_event(keyval, true);
        return false;
    }

    [GtkCallback]
    private void on_key_released(uint keyval, uint keycode, Gdk.ModifierType state) {
        check_shift_event(keyval, false);
    }

    //
    // Folder management
    //

    private void setup_folder_context_menu() {
        this.folder_menu = new_folder_menu_model(false);
        this.label_menu = new_folder_menu_model(true);

        var popover = new Gtk.PopoverMenu.from_model(this.folder_menu) {
            has_arrow = false,
            halign = START
        };
        popover.set_parent(this.folder_list);
        this.folder_list.default_context_menu = popover;

        // The Inboxes section spans accounts, so there is no single
        // folder to manage there — offer the accounts editor instead.
        var inboxes_menu = new GLib.Menu();
        // Translators: Folder list context menu item opening the
        // accounts editor
        inboxes_menu.append(_("_Manage Accounts…"), "app.accounts");
        var inboxes_popover = new Gtk.PopoverMenu.from_model(inboxes_menu) {
            has_arrow = false,
            halign = START
        };
        inboxes_popover.set_parent(this.folder_list);
        this.folder_list.set_inboxes_context_menu(inboxes_popover);

        this.folder_list.context_menu_requested.connect(
            on_folder_context_menu_requested
        );
    }

    private GLib.Menu new_folder_menu_model(bool labels) {
        var menu = new GLib.Menu();
        menu.append(
            // Translators: Folder list context menu item for creating
            // a new folder, and the label equivalent
            labels ? _("_New Label…") : _("_New Folder…"),
            "win." + ACTION_FOLDER_NEW
        );
        menu.append(
            // Translators: Folder list context menu item for renaming
            // a folder, and the label equivalent
            labels ? _("_Rename Label…") : _("_Rename Folder…"),
            "win." + ACTION_FOLDER_RENAME
        );
        menu.append(
            // Translators: Folder list context menu item for deleting
            // a folder, and the label equivalent
            labels ? _("_Delete Label") : _("_Delete Folder"),
            "win." + ACTION_FOLDER_DELETE
        );
        return menu;
    }

    /** The folder the folder list's context menu was invoked on, if any. */
    private Convey.Folder? get_context_folder() {
        var entry = (
            this.folder_list.context_entry as FolderList.AbstractFolderEntry
        );
        return (entry != null) ? entry.folder : null;
    }

    /** The account to create new folders in, if any. */
    private Convey.Account? get_context_account() {
        Convey.Folder? folder = get_context_folder();
        if (folder != null) {
            return folder.account;
        }
        var entry = this.folder_list.context_entry;
        return (entry != null)
            ? this.folder_list.get_account_for_entry(entry)
            : null;
    }

    private void on_folder_context_menu_requested(Sidebar.Entry? entry) {
        Convey.Account? account = get_context_account();
        if (account != null) {
            this.folder_list.default_context_menu.menu_model = (
                Util.I18n.uses_labels(account) ? this.label_menu : this.folder_menu
            );
        }

        Convey.Folder? folder = get_context_folder();
        bool is_user_folder = (folder != null && folder.used_as == NONE);

        ((GLib.SimpleAction) lookup_action(ACTION_FOLDER_NEW)).set_enabled(
            get_context_account() != null
        );
        ((GLib.SimpleAction) lookup_action(ACTION_FOLDER_RENAME)).set_enabled(
            is_user_folder
        );
        ((GLib.SimpleAction) lookup_action(ACTION_FOLDER_DELETE)).set_enabled(
            is_user_folder
        );
    }

    private void on_folder_new() {
        Convey.Account? account = get_context_account();
        if (account != null) {
            create_folder.begin(account);
        }
    }

    private void on_folder_rename() {
        var entry = this.folder_list.context_entry;
        if (entry != null) {
            // Falls back to the inline editor, which calls back in
            // via on_folder_rename_requested
            this.folder_list.rename_entry_in_place(entry);
        }
    }

    private void on_folder_delete() {
        Convey.Folder? folder = get_context_folder();
        if (folder != null) {
            delete_folder.begin(folder);
        }
    }

    private void on_folder_rename_requested(Convey.Folder folder,
                                            string new_name) {
        rename_folder.begin(folder, new_name);
    }

    private void on_folder_delete_requested(Convey.Folder folder) {
        delete_folder.begin(folder);
    }

    private async void create_folder(Convey.Account account) {
        bool labels = Util.I18n.uses_labels(account);
        var entry = new Gtk.Entry() { activates_default = true };
        var dialog = new Adw.AlertDialog(
            // Translators: Title of the new folder dialog, and the
            // label equivalent
            labels ? _("New Label") : _("New Folder"),
            null
        );
        dialog.extra_child = entry;
        dialog.focus_widget = entry;
        dialog.add_response("cancel", _("_Cancel"));
        dialog.add_response("create", _("_Create"));
        dialog.default_response = "create";
        dialog.close_response = "cancel";
        dialog.set_response_appearance("create", Adw.ResponseAppearance.SUGGESTED);

        string response = yield dialog.choose(this, null);
        string name = entry.text.strip();
        if (response != "create" || name == "") {
            return;
        }

        // Show the folder straight away, dimmed and spinning, so the
        // round trip to the server isn't silent
        var pending = this.folder_list.add_pending_folder(account, name);
        try {
            yield account.create_personal_folder(name, NONE, null);
            add_toast(new Adw.Toast(
                // Translators: Toast shown once a folder has been
                // created on the server, and the label equivalent.
                // Substitution is the folder name.
                (labels
                 ? _("Created label “%s”")
                 : _("Created folder “%s”")).printf(name)
            ));
        } catch (GLib.Error err) {
            handle_error(account.information, err);
        } finally {
            if (pending != null) {
                this.folder_list.remove_pending_folder(account, pending);
            }
        }
    }

    private async void rename_folder(Convey.Folder folder, string new_name) {
        bool labels = Util.I18n.uses_labels(folder.account);
        string old_name = folder.path.name;
        this.folder_list.set_folder_busy(folder, true);
        try {
            yield folder.account.rename_folder(folder, new_name, null);
            add_toast(new Adw.Toast(
                // Translators: Toast shown once a folder has been
                // renamed on the server, and the label equivalent.
                // Substitutions are the old and new names.
                (labels
                 ? _("Renamed label “%s” to “%s”")
                 : _("Renamed folder “%s” to “%s”")).printf(
                     old_name, new_name
                 )
            ));
        } catch (GLib.Error err) {
            handle_error(folder.account.information, err);
        } finally {
            this.folder_list.set_folder_busy(folder, false);
        }
    }

    private async void delete_folder(Convey.Folder folder) {
        bool labels = Util.I18n.uses_labels(folder.account);
        var dialog = new Adw.AlertDialog(
            // Translators: Title of the delete folder confirmation and
            // the label equivalent, substitution is the folder name
            (labels
             ? _("Delete label “%s”?")
             : _("Delete folder “%s”?")).printf(folder.path.name),
            (labels
             ? _("This removes the label and all email in it from Convey and your email server.")
             : _("This removes the folder and all email in it from Convey and your email server.")) +
            "  <b>" + _("This cannot be undone.") + "</b>"
        );
        dialog.body_use_markup = true;
        dialog.add_response("cancel", _("_Cancel"));
        dialog.add_response("delete", _("_Delete"));
        // Delete is the default, as in Files; Esc still cancels
        dialog.default_response = "delete";
        dialog.close_response = "cancel";
        dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE);

        if ((yield dialog.choose(this, null)) != "delete") {
            return;
        }

        string name = folder.path.name;
        this.folder_list.set_folder_busy(folder, true);
        try {
            yield folder.account.delete_folder(folder, null);
            add_toast(new Adw.Toast(
                // Translators: Toast shown once a folder has been
                // deleted from the server, and the label equivalent.
                // Substitution is the folder name.
                (labels
                 ? _("Deleted label “%s”")
                 : _("Deleted folder “%s”")).printf(name)
            ));
        } catch (GLib.Error err) {
            handle_error(folder.account.information, err);
        } finally {
            this.folder_list.set_folder_busy(folder, false);
        }
    }

    internal async bool prompt_empty_folder(Convey.Folder.SpecialUse type) {
        var folder_name = Util.I18n.to_folder_type_display_name(type);
        var dialog = new Adw.AlertDialog(
            _("Empty all email from your %s folder?").printf(folder_name),
            _("This removes the email from Convey and your email server.") +
            "  <b>" + _("This cannot be undone.") + "</b>");
        dialog.body_use_markup = true;
        dialog.add_response("cancel", _("_Cancel"));
        dialog.add_response("confirm", _("Empty %s").printf(folder_name));
        dialog.default_response = "cancel";
        dialog.close_response = "cancel";
        dialog.set_response_appearance("confirm", Adw.ResponseAppearance.DESTRUCTIVE);
        string response = yield dialog.choose(this, null);
        return (response == "confirm");
    }

    /** Un-does the last executed application command, if any. */
    private async void undo() {
        AccountContext? selected = get_selected_account_context();
        if (selected != null) {
            selected.commands.undo.begin(
                selected.cancellable,
                (obj, res) => {
                    try {
                        selected.commands.undo.end(res);
                    } catch (GLib.Error err) {
                        handle_error(selected.account.information, err);
                    }
                }
            );
        }
    }

    /** Re-does the last undone application command, if any. */
    private async void redo() {
        AccountContext? selected = get_selected_account_context();
        if (selected != null) {
            selected.commands.redo.begin(
                selected.cancellable,
                (obj, res) => {
                    try {
                        selected.commands.redo.end(res);
                    } catch (GLib.Error err) {
                        handle_error(selected.account.information, err);
                    }
                }
            );
        }
    }

    private void update_command_actions() {
        AccountContext? selected = get_selected_account_context();
        get_edit_action(Action.Edit.UNDO).set_enabled(
            selected != null && selected.commands.can_undo
        );
        get_edit_action(Action.Edit.REDO).set_enabled(
            selected != null && selected.commands.can_redo
        );
    }

    private async bool prompt_delete_conversations(int count) {
        var dialog = new Adw.AlertDialog(
            /// Translators: Primary text for a confirmation dialog
            ngettext(
                "Do you want to permanently delete this conversation?",
                "Do you want to permanently delete these conversations?",
                count
            ),
            null
        );
        dialog.add_response("cancel", _("_Cancel"));
        dialog.add_response("delete", _("_Delete"));
        dialog.default_response = "cancel";
        dialog.close_response = "cancel";
        dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE);
        string response = yield dialog.choose(this, null);
        return (response == "delete");
    }

    private async bool prompt_delete_messages(int count) {
        var dialog = new Adw.AlertDialog(
            /// Translators: Primary text for a confirmation dialog
            ngettext(
                "Do you want to permanently delete this message?",
                "Do you want to permanently delete these messages?",
                count
            ),
            null
        );
        dialog.add_response("cancel", _("_Cancel"));
        dialog.add_response("delete", _("_Delete"));
        dialog.default_response = "cancel";
        dialog.close_response = "cancel";
        dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE);
        string response = yield dialog.choose(this, null);
        return (response == "delete");
    }

    private async Gee.Collection<Convey.App.Conversation>
        load_conversations_for_email(
            Convey.Folder location,
            Gee.Collection<Convey.EmailIdentifier> to_load) {
        bool was_loaded = false;
        // Can't assume the conversation monitor is valid, so check
        // it first.
        if (this.conversations != null &&
            this.conversations.base_folder == location) {
            try {
                yield this.conversations.load_email(to_load, this.folder_open);
                was_loaded = true;
            } catch (GLib.Error err) {
                debug("Error loading conversations to show them: %s",
                      err.message);
            }
        }

        // Conversation monitor may have changed since resuming from
        // the last async statement, so check it's still valid again.
        var loaded = new Gee.HashSet<Convey.App.Conversation>();
        if (was_loaded &&
            this.conversations != null &&
            this.conversations.base_folder == location) {
            foreach (var id in to_load) {
                Convey.App.Conversation? conversation =
                    this.conversations.get_by_email_identifier(id);
                if (conversation != null) {
                    loaded.add(conversation);
                }
            }
        }
        return loaded;
    }

    private inline void handle_error(Convey.AccountInformation? account,
                                     GLib.Error error) {
        Convey.ProblemReport? report = (account != null)
            ? new Convey.AccountProblemReport(account, error)
            : new Convey.ProblemReport(error);
        this.controller.report_problem(report);
    }

    private void update_ui() {
        // Only update if we haven't done so within the last while
        int64 now = GLib.get_monotonic_time() / (1000 * 1000);
        if (this.update_ui_last + UPDATE_UI_INTERVAL < now) {
            this.update_ui_last = now;

            if (this.conversation_viewer.current_list != null) {
                this.conversation_viewer.current_list.update_display();
            }

            this.conversation_list_view.refresh_times();
        }
    }

    private void select_account(Convey.Account? account) {
        if (this.selected_account != account) {
            this.selected_account = account;
            this.search_bar.set_account(account);

            if (account != null) {
                this.conversation_list_actions.account = account;
                this.conversation_viewer_actions.account = account;
                this.conversation_viewer.headerbar.left_actions.account = account;
                this.conversation_viewer.headerbar.right_actions.account = account;
            }

            update_command_actions();
        }
    }

    private async void select_conversations(Gee.Collection<Convey.App.Conversation> to_select,
                                            Gee.Collection<Convey.EmailIdentifier> scroll_to,
                                            bool is_interactive) {
        bool start_mark_timer = (
            this.previous_selection_was_interactive && is_interactive
        );
        this.previous_selection_was_interactive = is_interactive;

        // Ensure that the conversations are selected in the UI if
        // this was called by something other than the selection
        // changed callback. That will check to ensure that we're not
        // setting it again.
        this.conversation_list_view.select_conversations(to_select);

        this.conversation_list_actions.selected_conversations = to_select.size;
        this.conversation_viewer.headerbar.right_actions.selected_conversations = to_select.size;
        this.conversation_viewer.headerbar.left_actions.selected_conversations = to_select.size;

        if (this.selected_folder != null && !this.has_composer) {
            switch(to_select.size) {
            case 0:
                update_conversation_actions(NONE);
                this.conversation_viewer.show_none_selected();
                break;

            case 1:
                update_conversation_actions(SINGLE);
                Convey.App.Conversation? convo = Convey.Collection.first(to_select);

                // It's possible for a conversation with zero email to
                // be selected, when it has just evaporated after its
                // last email was removed but the conversation monitor
                // hasn't signalled its removal yet. In this case,
                // just don't load it since it will soon disappear.
                AccountContext? context = get_selected_account_context();
                if (context != null && convo.get_count() > 0) {
                    try {
                        yield this.conversation_viewer.load_conversation(
                            convo,
                            scroll_to,
                            context.emails,
                            context.contacts,
                            start_mark_timer
                        );
                    } catch (Convey.EngineError.NOT_FOUND err) {
                        // The first interesting email from the
                        // conversation wasn't found.
                        // This happens:
                        // - in the drafts folder, there is a race between the
                        // composer being discarded and the draft
                        // itself disappearing
                        // - when message has been removed while being loaded
                        debug("Ignoring not found error: %s", err.message);
                    } catch (GLib.IOError.CANCELLED err) {
                        // All good
                    } catch (GLib.Error err) {
                        handle_error(convo.base_folder.account.information, err);
                    }
                }
                break;

            default:
                update_conversation_actions(MULTIPLE);
                this.conversation_viewer.show_multiple_selected();
                break;
            }
        }
    }

    private async void open_conversation_monitor(Convey.App.ConversationMonitor to_open,
                                                 GLib.Cancellable cancellable) {
        to_open.scan_completed.connect(on_scan_completed);
        to_open.scan_error.connect(on_scan_error);

        to_open.scan_completed.connect(on_conversation_count_changed);
        to_open.conversations_added.connect(on_conversation_count_changed);
        to_open.conversations_removed.connect(on_conversation_count_changed);

        to_open.start_monitoring.begin(
            NO_DELAY,
            cancellable,
            (obj, res) => {
                try {
                    to_open.start_monitoring.end(res);
                } catch (GLib.Error err) {
                    handle_error(to_open.base_folder.account.information, err);
                }
            }
        );
    }

    private void close_conversation_monitor(Convey.App.ConversationMonitor to_close) {
        to_close.scan_completed.disconnect(on_scan_completed);
        to_close.scan_error.disconnect(on_scan_error);

        to_close.scan_completed.disconnect(on_conversation_count_changed);
        to_close.conversations_added.disconnect(on_conversation_count_changed);
        to_close.conversations_removed.disconnect(on_conversation_count_changed);

        to_close.stop_monitoring.begin(
            null,
            (obj, res) => {
                try {
                    to_close.stop_monitoring.end(res);
                } catch (GLib.Error err) {
                    warning(
                        "Error closing conversation monitor %s: %s",
                        to_close.base_folder.to_string(),
                        err.message
                    );
                }
            }
        );
    }

    private async void create_composer(Convey.Account send_context,
                                       Composer.Widget.ContextType type,
                                       Convey.Email context,
                                       string? quote) {
        var composer = yield this.controller.compose_with_context(
            this.controller.get_context_for_account(send_context.information),
            type,
            context,
            quote ?? ""
        );
        this.controller.present_composer(composer);
    }

    private async void create_composer_from_viewer(Composer.Widget.ContextType type) {
        Convey.Account? account = this.selected_account;
        ConversationEmail? email_view = null;
        ConversationListBox? list_view = this.conversation_viewer.current_list;
        if (list_view != null) {
            email_view = list_view.get_reply_target();
        }
        if (account != null && email_view != null) {
            string? quote = yield email_view.get_selection_for_quoting();
            yield create_composer(account, type, email_view.email, quote);
        }
    }

    /** Shows the spinner in place of the refresh button while busy. */
    private void headerbar_push_busy() {
        this.headerbar_busy_count++;
        this.headerbar_spinner.start();
        this.refresh_stack.visible_child = this.headerbar_spinner;
    }

    /** Restores the refresh icon once all busy work has finished. */
    private void headerbar_pop_busy() {
        this.headerbar_busy_count = int.max(0, this.headerbar_busy_count - 1);
        if (this.headerbar_busy_count == 0) {
            this.headerbar_spinner.stop();
            this.refresh_stack.visible_child = this.refresh_image;
        }
    }

    private void on_refresh_folder() {
        Convey.Folder? folder = this.selected_folder;
        if (folder == null) {
            return;
        }
        headerbar_push_busy();
        folder.synchronise_remote.begin(null, (obj, res) => {
            try {
                folder.synchronise_remote.end(res);
            } catch (GLib.Error err) {
                debug("Error refreshing %s: %s",
                    folder.path.to_string(), err.message);
            }
            headerbar_pop_busy();
        });
    }

    private void on_conversations_selected(Gee.Set<Convey.App.Conversation> selected) {
        // The conversation viewer is shown next to the list unless the
        // inner split view is collapsed, in which case it is a separate
        // page reached by activating a row. Only defer loading to
        // activation when the viewer is actually a separate page --
        // keying off outer_view (the folder list) here would wrongly
        // defer at intermediate widths where the viewer is visible.
        bool viewer_is_separate_page = this.inner_view.collapsed;
        bool folded = this.outer_view.collapsed;

        // If the viewer is a separate page, selection is handled by activate
        if (selected.size > 1 || !viewer_is_separate_page) {
            select_conversations.begin(selected, Gee.Collection.empty(), true);
        } else if (viewer_is_separate_page) {
            switch(selected.size) {
            case 0:
                update_conversation_actions(NONE);
                break;
            case 1:
                update_conversation_actions(SINGLE);
                break;
            default:
                update_conversation_actions(MULTIPLE);
                break;
            }
        }

        if (this.conversation_list_view.selection_mode_enabled) {
            if (selected.size > 0) {
                this.conversation_list_actions_revealer.reveal_child = folded;
            } else {
                this.conversation_list_actions_revealer.reveal_child = false;
            }
        }
    }

    private void on_conversation_activated(Convey.App.Conversation activated, uint button) {
        if (button == Gdk.BUTTON_PRIMARY) {
            bool collapsed = this.inner_view.collapsed;
            this.outer_view.show_content = true;
            if (collapsed) {
                Gee.Collection<Convey.App.Conversation> selected =
                    new Gee.ArrayList<Convey.App.Conversation>();
                selected.add(activated);
                select_conversations.begin(selected, Gee.Collection.empty(), true);
            }
        } else if (this.selected_folder != null) {
            if (this.selected_folder.used_as != DRAFTS) {
                this.application.new_window.begin(
                    this.selected_folder,
                    this.conversation_list_view.selected
                    );
            } else {
                // TODO: Determine how to map between conversations
                // and drafts correctly.
                Convey.Email draft = activated.get_latest_recv_email(IN_FOLDER);
                this.create_composer.begin(
                    this.selected_folder.account,
                    EDIT,
                    draft,
                    null
                );
            }
        }
    }

    private void on_conversation_count_changed() {
        // Only update the UI if we don't currently have a composer,
        // so we don't clobber it
        if (!this.has_composer) {
            if (this.conversations.size == 0) {
                // Let the user know if there's no available conversations
                if (this.selected_folder.used_as == SEARCH) {
                    this.conversation_viewer.show_empty_search();
                } else {
                    this.conversation_viewer.show_empty_folder();
                }
                update_conversation_actions(NONE);
            } else {
                // When not doing autoselect, we never get
                // conversations_selected firing from the convo list,
                // so we need to stop the loading spinner here.
                if (!this.application.config.autoselect &&
                    this.conversation_list_view.selected.size == 0) {
                    this.conversation_viewer.show_none_selected();
                    update_conversation_actions(NONE);
                }
            }
        }
    }

    private void update_headerbar() {
        update_title();
        // Note the headerbar no longer shows the folder's unread
        // count: since the GTK4 port the subtitle holds the account
        // address, and the folder list already shows the count
    }

    private void update_conversation_actions(ConversationCount count) {
        bool sensitive = (count != NONE);
        bool multiple = (count == MULTIPLE);

        bool find_in_enabled = (
            sensitive && !multiple && this.is_conversation_viewer_shown
        );
        get_window_action(ACTION_FIND_IN_CONVERSATION).set_enabled(find_in_enabled);
        this.conversation_viewer.headerbar.set_find_sensitive(find_in_enabled);

        bool reply_sensitive = (
            sensitive &&
            !multiple &&
            this.selected_folder != null &&
            this.selected_folder.used_as != DRAFTS
        );
        get_window_action(ACTION_REPLY_CONVERSATION).set_enabled(reply_sensitive);
        get_window_action(ACTION_REPLY_ALL_CONVERSATION).set_enabled(reply_sensitive);
        get_window_action(ACTION_FORWARD_CONVERSATION).set_enabled(reply_sensitive);

        bool copy_enabled = (
            sensitive && (this.selected_folder is Convey.FolderSupport.Copy)
        );
        get_window_action(ACTION_SHOW_COPY_MENU).set_enabled(copy_enabled);
        foreach (var actions in this.folder_conversation_actions) {
            actions.set_copy_sensitive(copy_enabled);
        }

        bool mark_enabled = (
            sensitive && (this.selected_folder is Convey.FolderSupport.Mark)
        );
        foreach (var actions in this.folder_conversation_actions) {
            actions.set_mark_sensitive(mark_enabled);
        }

        get_window_action(ACTION_ARCHIVE_CONVERSATION).set_enabled(
            sensitive && (this.selected_folder is Convey.FolderSupport.Archive)
        );
        get_window_action(ACTION_TRASH_CONVERSATION).set_enabled(
            sensitive && this.selected_folder_supports_trash
        );
        get_window_action(ACTION_DELETE_CONVERSATION).set_enabled(
            sensitive && (this.selected_folder is Convey.FolderSupport.Remove)
        );

        this.update_context_dependent_actions.begin(sensitive);
    }

    private void update_trash_action() {
        var show_trash = (
            !this.is_shift_down &&
            this.selected_folder_supports_trash
        );
        this.conversation_list_actions.update_trash_button(show_trash);
        this.conversation_viewer.headerbar.left_actions.update_trash_button(show_trash);
        this.conversation_viewer.headerbar.right_actions.update_trash_button(show_trash);
    }

    private async void update_context_dependent_actions(bool sensitive) {
        // Cancel any existing update that is running
        this.action_update_cancellable.cancel();
        GLib.Cancellable cancellable = new Cancellable();
        this.action_update_cancellable = cancellable;

        Gee.MultiMap<Convey.EmailIdentifier, Type>? selected_operations = null;
        if (this.selected_folder != null) {
            AccountContext? context =
                this.controller.get_context_for_account(
                    this.selected_folder.account.information
                );
            if (context != null) {
                Gee.Collection<Convey.EmailIdentifier> ids =
                    new Gee.LinkedList<Convey.EmailIdentifier>();
                foreach (Convey.App.Conversation convo in
                         this.conversation_list_view.selected) {
                    ids.add_all(convo.get_email_ids());
                }
                try {
                    selected_operations = yield context.emails.get_supported_operations_async(
                        ids, cancellable
                    );
                } catch (GLib.Error e) {
                    debug("Error checking for what operations are supported in the selected conversations: %s",
                          e.message);
                }
            }
        }

        if (!cancellable.is_cancelled()) {
            Gee.HashSet<Type> supported_operations = new Gee.HashSet<Type>();
            if (selected_operations != null) {
                supported_operations.add_all(selected_operations.get_values());
            }

            get_window_action(ACTION_SHOW_COPY_MENU).set_enabled(
                sensitive &&
                (supported_operations.contains(typeof(Convey.FolderSupport.Copy)))
            );
        }
    }

    private void set_shift_key_down(bool down) {
        this.is_shift_down = down;
        update_trash_action();
    }

    private inline void check_shift_event(uint keyval, bool is_key_press) {
        // FIXME: it's possible the user will press two shift keys.  We want
        // the shift key to report as released when they release ALL of them.
        // There doesn't seem to be an easy way to do this in Gdk.
        if (keyval == Gdk.Key.Shift_L || keyval == Gdk.Key.Shift_R) {
            Gtk.Widget? focus = get_focus();
            if (focus == null ||
                (!(focus is Gtk.Entry) && !(focus is Composer.WebView))) {
                set_shift_key_down(is_key_press);
            }
        }
    }

    // Makes Left/Right in pane move the focus to the neighbouring pane.
    // Runs in the capture phase since the panes' list widgets consume the
    // horizontal arrow keys themselves.
    private void setup_pane_navigation(Gtk.Widget pane,
                                       Gtk.Widget? left,
                                       Gtk.Widget? right) {
        var keys = new Gtk.EventControllerKey() {
            propagation_phase = Gtk.PropagationPhase.CAPTURE
        };
        keys.key_pressed.connect((keyval, keycode, state) => {
            if ((state & (Gdk.ModifierType.CONTROL_MASK |
                          Gdk.ModifierType.ALT_MASK |
                          Gdk.ModifierType.SHIFT_MASK)) != 0) {
                return false;
            }
            // Don't steal cursor keys from an entry (e.g. renaming a
            // folder in place, or the search bar).
            if (get_focus() is Gtk.Editable) {
                return false;
            }

            Gtk.Widget? target = null;
            switch (keyval) {
            case Gdk.Key.Left:
            case Gdk.Key.KP_Left:
                target = left;
                break;
            case Gdk.Key.Right:
            case Gdk.Key.KP_Right:
                target = right;
                break;
            default:
                return false;
            }

            if (target == null) {
                return false;
            }
            // Panes are plain containers, so grab_focus() alone won't take
            // -- fall back to handing focus to something inside them.
            return (
                target.grab_focus() ||
                target.child_focus(Gtk.DirectionType.TAB_FORWARD)
            );
        });
        pane.add_controller(keys);
    }

    private new void focus_widget(Gtk.Widget? widget) {
        if (widget != null) {
            widget.focus(TAB_FORWARD);
        } else {
            error_bell();
        }
    }

    private SimpleAction get_window_action(string name) {
        return (SimpleAction) lookup_action(name);
    }

    private SimpleAction get_edit_action(string name) {
        return (SimpleAction) this.edit_actions.lookup_action(name);
    }

    private new void activate_action(GLib.Action? action) {
        if (action != null && action.get_enabled()) {
            action.activate(null);
        } else {
            error_bell();
        }
    }

    private void reply_conversation(Composer.Widget.ContextType context_type) {
        if (this.inner_view.collapsed) {
            this.conversation_list_view.activate_selected();
            this.inner_view.show_content = true;
            // This is a lot of async actions, delay composer creation
            GLib.Timeout.add(500, () => {
              this.create_composer_from_viewer.begin(context_type);
              return Source.REMOVE;
            });
        } else {
            this.create_composer_from_viewer.begin(context_type);
        }
    }

    private void on_scan_completed(Convey.App.ConversationMonitor monitor) {
        // Done scanning.  Check if we have enough messages to fill
        // the conversation list; if not, trigger a load_more();
        Gtk.Scrollbar? scrollbar = (
            this.conversation_list_view.scrolled_window.get_vscrollbar() as Gtk.Scrollbar
        );
        if (is_visible() &&
            (scrollbar == null || !scrollbar.get_visible()) &&
            monitor == this.conversations &&
            monitor.can_load_more) {
            debug("Not enough messages, loading more for folder %s",
                  this.selected_folder.to_string());
            this.conversation_list_view.load_more(MIN_CONVERSATION_COUNT);
        }
    }

    private void on_scan_error(Convey.App.ConversationMonitor monitor,
                               GLib.Error err) {
        Convey.AccountInformation account =
            monitor.base_folder.account.information;
        this.controller.report_problem(
            new Convey.ServiceProblemReport(account, account.incoming, err)
        );
    }

    [GtkCallback]
    private void on_map() {
        this.update_ui_timeout.start();
        update_ui();
    }

    [GtkCallback]
    private void on_unmap() {
        // Save window size here as well as in close_request, since
        // application quit tears windows down without a close request
        this.window_width = this.default_width;
        this.window_height = this.default_height;
        this.update_ui_timeout.reset();
    }

    [GtkCallback]
    private void on_focus_enter(Gtk.EventControllerFocus controller) {
        set_shift_key_down(false);
        application.controller.window_focus_in();
    }

    [GtkCallback]
    private void on_focus_leave(Gtk.EventControllerFocus controller) {
        set_shift_key_down(false);
        application.controller.window_focus_out();
    }

    [GtkCallback]
    private void on_inner_view_changed(GLib.Object object, ParamSpec pspec) {
        int selected = this.conversation_list_view.selected.size;
        update_conversation_actions(
            ConversationCount.for_size(selected)
        );
        if (this.inner_view.collapsed) {
            // Ensure something useful gets the keyboard focus, given
            // GNOME/libhandy#179
            if (this.is_conversation_list_shown) {
                this.conversation_list_view.grab_focus();
            } else if (this.is_folder_list_shown) {
                this.folder_list.grab_focus();
            }

            // Close any open composer that is no longer visible
            if (this.has_composer &&
                (this.is_folder_list_shown || this.is_conversation_list_shown)) {
                close_composer(false, false);
            }
        } else {
            if (selected > 0) {
                select_conversations.begin(
                    this.conversation_list_view.selected,
                    Gee.Collection.empty<Convey.EmailIdentifier>(),
                    false
                );
            }
        }
    }

    private void on_offline_infobar_response() {
        this.info_bars.remove(this.offline_infobar);
    }

    private void on_service_problem_retry() {
        this.info_bars.remove(this.service_problem_infobar);
        this.service_problem_infobar = null;
        retry_service_problem(Convey.ClientService.Status.CONNECTION_FAILED);
    }

    private void on_cert_problem_retry() {
        this.info_bars.remove(this.cert_problem_infobar);
        retry_service_problem(Convey.ClientService.Status.TLS_VALIDATION_FAILED);
    }

    private void on_auth_problem_retry() {
        this.info_bars.remove(this.auth_problem_infobar);
        retry_service_problem(Convey.ClientService.Status.AUTHENTICATION_FAILED);
    }

    private void on_update_ui_timeout() {
        update_ui();
    }

    private void on_account_available(AccountContext account) {
        add_account(account);
    }

    private void on_account_unavailable(AccountContext account,
                                        bool is_shutdown) {
        // If we're not shutting down, select the inbox of the first
        // account so that we show something other than empty
        // conversation list/viewer.
        Convey.Folder? to_select = null;
        if (!is_shutdown) {
            to_select = get_first_inbox();
        }
        this.remove_account.begin(account, to_select);
    }

    private void on_folders_available(Gee.Collection<FolderContext> available) {
        add_folders(available);
    }

    private void on_folders_unavailable(Gee.Collection<FolderContext> unavailable) {
        remove_folders(unavailable, true);
    }

    private void on_use_changed(Convey.Folder folder,
                                Convey.Folder.SpecialUse old_type,
                                Convey.Folder.SpecialUse new_type) {
        // Update the main window
        AccountContext? context = this.controller.get_context_for_account(
            folder.account.information
        );
        if (context != null) {
            FolderContext? folder_context = context.get_folder(folder);
            if (folder_context != null) {
                this.folder_list.remove_folder(folder_context);
                this.folder_list.add_folder(folder_context);

                // Since removing the folder will also remove its children
                // from the folder list, we need to check for any and re-add
                // them. See issue #11.
                try {
                    foreach (Convey.Folder child in
                             folder.account.list_matching_folders(folder.path)) {
                        FolderContext? child_context = context.get_folder(child);
                        if (child_context != null) {
                            this.folder_list.add_folder(child_context);
                        }
                    }
                } catch (Error err) {
                    // Oh well
                }
            }
        }
    }

    private void on_command_execute(Command command) {
        if (!(command is TrivialCommand)) {
            // Only show an execute notification for non-trivial
            // commands
            on_command_redo(command);
        } else {
            // Still have to update the undo/redo actions for trivial
            // commands
            update_command_actions();
        }
    }

    private void on_command_undo(Command command) {
        update_command_actions();
        EmailCommand? email = command as EmailCommand;
        if (email != null) {
            if (email.conversations.size > 1) {
                this.show_conversations.begin(
                    email.location, email.conversations, false
                );
            } else {
                this.show_email.begin(
                    email.location, email.email, false
                );
            }
        }
        if (command.undone_label != null) {
            var toast = new Adw.Toast(command.undone_label);
            toast.button_label = _("Redo");
            toast.action_name = Action.Edit.prefix(Action.Edit.REDO);
            add_toast(toast);
        }
    }

    private void on_command_redo(Command command) {
        update_command_actions();
        if (command.executed_label != null) {
            var toast = new Adw.Toast(command.executed_label);
            toast.button_label = _("Undo");
            toast.action_name = Action.Edit.prefix(Action.Edit.UNDO);
            if (command.executed_notification_brief)
                toast.timeout = application.config.brief_notification_duration;
            add_toast(toast);
        }
    }

    private void on_conversation_view_added(ConversationListBox list) {
        list.email_loaded.connect(on_email_loaded);
        list.mark_email.connect(on_email_mark);
        list.reply_to_all_email.connect(on_email_reply_to_all);
        list.reply_to_sender_email.connect(on_email_reply_to_sender);
        list.forward_email.connect(on_email_forward);
        list.trash_email.connect(on_email_trash);
        list.delete_email.connect(on_email_delete);
    }

    // Window-level action callbacks

    private void on_undo() {
        this.undo.begin();
    }

    private void on_redo() {
        this.redo.begin();
    }

    private void on_close() {
        close();
    }

    // this signal does not necessarily indicate that the application
    // previously didn't have focus and now it does
    private void on_has_toplevel_focus() {
        if (this.selected_folder != null) {
            this.controller.clear_new_messages(
                this.selected_folder,
                this.conversation_list_view.visible_conversations
            );
        }
    }

    private void on_folder_selected(Convey.Folder? folder) {
        this.select_folder.begin(folder, true);
    }

    private void on_select_inbox(SimpleAction action, Variant? parameter) {
        if (parameter != null) {
            int account_number = parameter.get_int32();
            try {
                Gee.Collection<Convey.Account> accounts =
                    this.application.engine.get_accounts();
                if (account_number < accounts.size) {
                    Convey.Account account = accounts.to_array()[account_number];
                    Convey.Folder inbox = account.get_special_folder(INBOX);
                    this.select_folder.begin(inbox, true);
                }
            } catch (GLib.Error error) {
                debug("Error getting accounts");
            }
        }
    }

    private void on_search(string text) {
        if (Convey.String.is_empty_or_whitespace(text)) {
            stop_search(true);
        } else {
            this.start_search(text, true);
        }
    }

    private void on_visible_conversations_changed() {
        if (this.selected_folder != null) {
            this.controller.clear_new_messages(this.selected_folder, this.conversation_list_view.visible_conversations);
        }
    }

    private void on_folder_activated(Convey.Folder? folder) {
        if (folder != null) {
            this.inner_view.show_content = true;
            // Focus on conversation list will autoselect
            if (this.application.config.autoselect) {
                focus_widget(this.conversation_viewer.get_visible_child());
            }
        }
    }

    private void on_find_in_conversation_action() {
        this.conversation_viewer.enable_find();
    }

    private void on_search_activated() {
        show_search_bar();
    }

    private void on_zoom(SimpleAction action, Variant? parameter) {
        ConversationListBox? view = this.conversation_viewer.current_list;
        if (view != null && parameter != null) {
            string zoom_action = parameter.get_string();
            if (zoom_action == "in")
                view.zoom_in();
            else if (zoom_action == "out")
                view.zoom_out();
            else
                view.zoom_reset();
        }
    }

    private void on_reply_conversation() {
        reply_conversation(REPLY_SENDER);
    }

    private void on_reply_all_conversation() {
        reply_conversation(REPLY_ALL);
    }

    private void on_forward_conversation() {
        reply_conversation(FORWARD);
    }

    private void on_show_window_menu() {
        show_window_menu();
    }

    private void on_show_help_overlay() {
        var overlay = get_help_overlay();
        overlay.section_name = "conversation";
        overlay.show();
    }

    private void on_show_copy_menu() {
        if (this.is_conversation_list_shown &&
            this.conversation_list_actions_revealer.child_revealed) {
            this.conversation_list_actions.show_copy_menu();
        } else if (this.is_conversation_viewer_shown) {
            this.conversation_viewer.headerbar.left_actions.show_copy_menu();
            this.conversation_viewer.headerbar.right_actions.show_copy_menu();
        } else {
            error_bell();
        }
    }

    private void on_conversation_up() {
        this.conversation_list_view.scroll(Gtk.ScrollType.STEP_UP);
    }

    private void on_conversation_down() {
        this.conversation_list_view.scroll(Gtk.ScrollType.STEP_DOWN);
    }

    private void on_show_mark_menu() {
        bool unread_selected = false;
        bool read_selected = false;
        bool starred_selected = false;
        bool unstarred_selected = false;
        foreach (Convey.App.Conversation conversation in
                 this.conversation_list_view.selected) {
            if (conversation.is_unread())
                unread_selected = true;

            // Only check the messages that "Mark as Unread" would mark, so we
            // don't add the menu option and have it not do anything.
            //
            // Sort by Date: field to correspond with ConversationViewer ordering
            Convey.Email? latest = conversation.get_latest_sent_email(
                Convey.App.Conversation.Location.IN_FOLDER_OUT_OF_FOLDER);
            if (latest != null && latest.email_flags != null
                && !latest.email_flags.contains(Convey.EmailFlags.UNREAD))
                read_selected = true;

            if (conversation.is_flagged()) {
                starred_selected = true;
            } else {
                unstarred_selected = true;
            }
        }
        get_window_action(ACTION_MARK_AS_READ).set_enabled(unread_selected);
        get_window_action(ACTION_MARK_AS_UNREAD).set_enabled(read_selected);
        get_window_action(ACTION_MARK_AS_STARRED).set_enabled(unstarred_selected);
        get_window_action(ACTION_MARK_AS_UNSTARRED).set_enabled(starred_selected);

        // If we're in Drafts/Outbox, we also shouldn't set a message as junk
        bool in_junk_folder = (selected_folder.used_as == JUNK);
        get_window_action(ACTION_TOGGLE_JUNK).set_enabled(
            !in_junk_folder &&
            selected_folder.used_as != DRAFTS &&
            selected_folder.used_as != OUTBOX
        );
    }

    private void on_mark_conversations(Gee.Collection<Convey.App.Conversation> conversations,
                                       Convey.NamedFlag flag) {
        Convey.Folder? location = this.selected_folder;
        if (location != null) {
            this.controller.mark_conversations.begin(
                location,
                conversations,
                flag,
                true,
                (obj, res) => {
                    try {
                        this.controller.mark_conversations.end(res);
                    } catch (GLib.Error err) {
                        handle_error(location.account.information, err);
                    }
                }
            );
        }
    }

    private void on_mark_as_read() {
        Convey.Folder? location = this.selected_folder;
        if (location != null) {
            this.controller.mark_conversations.begin(
                location,
                this.conversation_list_view.selected,
                Convey.EmailFlags.UNREAD,
                false,
                (obj, res) => {
                    try {
                        this.controller.mark_conversations.end(res);
                    } catch (GLib.Error err) {
                        handle_error(location.account.information, err);
                    }
                }
            );
        }
        this.conversation_list_view.selection_mode_enabled = false;
    }

    private void on_mark_as_unread() {
        Convey.Folder? location = this.selected_folder;
        if (location != null) {
            this.controller.mark_conversations.begin(
                location,
                this.conversation_list_view.selected,
                Convey.EmailFlags.UNREAD,
                true,
                (obj, res) => {
                    try {
                        this.controller.mark_conversations.end(res);
                    } catch (GLib.Error err) {
                        handle_error(location.account.information, err);
                    }
                }
            );
        }
        this.conversation_list_view.selection_mode_enabled = false;
    }

    private void on_mark_as_starred() {
        Convey.Folder? location = this.selected_folder;
        if (location != null) {
            this.controller.mark_conversations.begin(
                location,
                this.conversation_list_view.selected,
                Convey.EmailFlags.FLAGGED,
                true,
                (obj, res) => {
                    try {
                        this.controller.mark_conversations.end(res);
                    } catch (GLib.Error err) {
                        handle_error(location.account.information, err);
                    }
                }
            );
        }
        this.conversation_list_view.selection_mode_enabled = false;
    }

    private void on_mark_as_unstarred() {
        Convey.Folder? location = this.selected_folder;
        if (location != null) {
            this.controller.mark_conversations.begin(
                location,
                this.conversation_list_view.selected,
                Convey.EmailFlags.FLAGGED,
                false,
                (obj, res) => {
                    try {
                        this.controller.mark_conversations.end(res);
                    } catch (GLib.Error err) {
                        handle_error(location.account.information, err);
                    }
                }
            );
        }
        this.conversation_list_view.selection_mode_enabled = false;
    }

    private void on_mark_as_junk_toggle() {
        Convey.Folder? source = this.selected_folder;
        if (source != null) {
            Convey.Folder.SpecialUse destination =
                (source.used_as != JUNK)
                ? Convey.Folder.SpecialUse.JUNK
                : Convey.Folder.SpecialUse.INBOX;
            this.controller.move_conversations_special.begin(
                source,
                destination,
                this.conversation_list_view.selected,
                (obj, res) => {
                    try {
                        this.controller.move_conversations_special.end(res);
                    } catch (GLib.Error err) {
                        handle_error(source.account.information, err);
                    }
                }
            );
        }
        this.conversation_list_view.selection_mode_enabled = false;
    }

    private void on_move_conversation(Convey.Folder destination) {
        Convey.FolderSupport.Move source =
            this.selected_folder as Convey.FolderSupport.Move;
        if (source != null) {
            this.controller.move_conversations.begin(
                source,
                destination,
                this.conversation_list_view.selected,
                (obj, res) => {
                    try {
                        this.controller.move_conversations.end(res);
                    } catch (GLib.Error err) {
                        handle_error(source.account.information, err);
                    }
                }
            );

        }
        this.conversation_list_view.selection_mode_enabled = false;
    }

    private void on_copy_conversation(Convey.Folder destination) {
        Convey.FolderSupport.Copy source =
            this.selected_folder as Convey.FolderSupport.Copy;
        if (source != null) {
            this.controller.copy_conversations.begin(
                source,
                destination,
                this.conversation_list_view.selected,
                (obj, res) => {
                    try {
                        this.controller.copy_conversations.end(res);
                    } catch (GLib.Error err) {
                        handle_error(source.account.information, err);
                    }
                }
            );

        }
        this.conversation_list_view.selection_mode_enabled = false;
    }

    private void on_archive_conversation() {
        Convey.Folder source = this.selected_folder;
        if (source != null) {
            this.controller.move_conversations_special.begin(
                source,
                ARCHIVE,
                this.conversation_list_view.selected,
                (obj, res) => {
                    try {
                        this.controller.move_conversations_special.end(res);
                    } catch (GLib.Error err) {
                        handle_error(source.account.information, err);
                    }
                }
            );
        }
        this.conversation_list_view.selection_mode_enabled = false;
    }

    private void on_trash_conversation() {
        Convey.Folder source = this.selected_folder;
        if (source != null) {
            this.controller.move_conversations_special.begin(
                source,
                TRASH,
                this.conversation_list_view.selected,
                (obj, res) => {
                    try {
                        this.controller.move_conversations_special.end(res);
                    } catch (GLib.Error err) {
                        handle_error(source.account.information, err);
                    }
                }
            );
        }
        // No need to disable selection mode, handled by model change
    }

    private void on_delete_conversation() {
        do_delete_conversation.begin();
    }

    private async void do_delete_conversation() {
        var target = this.selected_folder as Convey.FolderSupport.Remove;
        if (target == null)
            return;

        Gee.Collection<Convey.App.Conversation> conversations =
            this.conversation_list_view.selected;
        if (!yield prompt_delete_conversations(conversations.size))
            return;

        try {
            yield this.controller.delete_conversations(
                target,
                conversations);
        } catch (GLib.Error err) {
            handle_error(target.account.information, err);
        }

        // No need to disable selection mode, handled by model change
    }

    private void on_email_loaded(ConversationListBox view,
                                 Convey.Email loaded) {
        this.controller.email_loaded(
            view.conversation.base_folder.account.information,
            loaded
        );
    }

    private void on_email_mark(ConversationListBox view,
                               Gee.Collection<Convey.EmailIdentifier> messages,
                               Convey.NamedFlag? to_add,
                               Convey.NamedFlag? to_remove) {
        Convey.Folder? location = this.selected_folder;
        if (location != null) {
            Convey.EmailFlags add_flags = null;
            if (to_add != null) {
                add_flags = new Convey.EmailFlags();
                add_flags.add(to_add);
            }
            Convey.EmailFlags remove_flags = null;
            if (to_remove != null) {
                remove_flags = new Convey.EmailFlags();
                remove_flags.add(to_remove);
            }
            this.controller.mark_messages.begin(
                location,
                Convey.Collection.single(view.conversation),
                messages,
                add_flags,
                remove_flags,
                (obj, res) => {
                    try {
                        this.controller.mark_messages.end(res);
                    } catch (GLib.Error err) {
                        handle_error(location.account.information, err);
                    }
                }
            );
        }
        this.conversation_list_view.selection_mode_enabled = false;
    }

    private void on_email_reply_to_sender(Convey.Email target, string? quote) {
        if (this.selected_account != null) {
            this.create_composer.begin(
                this.selected_account, REPLY_SENDER, target, quote
            );
        }
        this.conversation_list_view.selection_mode_enabled = false;
    }

    private void on_email_reply_to_all(Convey.Email target, string? quote) {
        if (this.selected_account != null) {
            this.create_composer.begin(
                this.selected_account, REPLY_ALL, target, quote
            );
        }
        this.conversation_list_view.selection_mode_enabled = false;
    }

    private void on_email_forward(Convey.Email target, string? quote) {
        if (this.selected_account != null) {
            this.create_composer.begin(
                this.selected_account, FORWARD, target, quote
            );
        }
        this.conversation_list_view.selection_mode_enabled = false;
    }

    private void on_email_trash(ConversationListBox view, Convey.Email target) {
        do_trash_email.begin(view, target);
    }

    private async void do_trash_email(ConversationListBox view, Convey.Email target) {
        Convey.Folder? source = this.selected_folder;
        if (source == null)
            return;

        try {
            yield this.controller.move_messages_special(
                source,
                TRASH,
                Convey.Collection.single(view.conversation),
                Convey.Collection.single(target.id));
        } catch (GLib.Error err) {
            handle_error(source.account.information, err);
        }
    }

    private void on_email_delete(ConversationListBox view, Convey.Email target) {
        do_delete_email.begin(view, target);
    }

    private async void do_delete_email(ConversationListBox view, Convey.Email target) {
        Convey.FolderSupport.Remove? source =
            this.selected_folder as Convey.FolderSupport.Remove;
        if (source == null || !yield prompt_delete_messages(1))
            return;

        try {
            yield this.controller.delete_messages(
                source,
                Convey.Collection.single(view.conversation),
                Convey.Collection.single(target.id));
        } catch (GLib.Error err) {
            handle_error(source.account.information, err);
        }
    }
}
