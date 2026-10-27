# Native tonal shell · 2026-10-27

Implements the owner's request to begin applying the agreed Griabuntu Mail
desktop design. This is a source implementation of the main window, folder
navigation, conversation list and reader surroundings. Composer controls,
preferences, account dialogs and HTML mail rendering retain their existing UI.

## Visible changes

- Pastel petrol/teal folder and list surfaces, a subtly warm reader surround.
- Rounded conversation cards; unread messages have a leading edge and bold
  sender/subject, selection follows the system accent, keyboard focus is explicit.
- Full received time below the preview, leaving the trailing gutter for the star
  and conversation count. Existing received-time text/tooltips are retained.
- Slightly larger local avatars, a quieter count badge and aligned text fields.
- Native suggested-action emphasis for Compose and a Griabuntu Mail folder heading.

Field styles now follow named subject/preview/participant classes rather than
child positions, so changing the user's field order does not change typography.
The received-time widget stays after those reorderable fields. Existing alias,
contact-picture and field-visibility preferences are retained.

## Appearance and compatibility

All new surface rules are scoped to `.convey-main-window`. New colours mix with
libadwaita surfaces and use its foreground pairs. The system accent, semantic
warning/destructive colours, native icons, button states and popovers are retained.
High contrast removes pastel surfaces, adds card edges and restores full-strength
row text and outlined badges. Unread edges mirror in RTL.

The application still targets GTK 4.16 / libadwaita 1.7. CSS appearance media
queries require GTK 4.20, so named `Adw.StyleManager` notification handlers update
dark/high-contrast classes on each window instead. Appearance is applied on
construction and when the system preference changes. No new resource, schema,
application ID, settings key or runtime dependency is introduced.

References: [GTK CSS media-query compatibility](https://docs.gtk.org/gtk4/css-properties.html),
[libadwaita 1.7 colour variables](https://github.com/GNOME/libadwaita/blob/1.7.0/doc/css-variables.md),
[StyleManager](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/1.7/class.StyleManager.html).

## Verification boundary

This editing environment has no GTK4/libadwaita SDK, Vala compiler or complete
authenticated Git checkout. Files were read at source commit
`4f55c3c68c86468de0b0b8793bec0129d54a41f5` through the GitHub connector; only
the scoped changes are proposed on a separate branch.

Completed: XML parsing; preservation checks for template IDs, signals, actions,
bindings and adaptive breakpoints; CSS syntax/declaration parsing with tinycss2;
diff whitespace checks. These checks are not GTK Builder validation, Vala
compilation, screenshots or native desktop acceptance. Historical build results
in `release/VERIFICATION.md` do not apply to this UI change. The known four
notification-flag failures are unchanged and have not been rerun here.

Before merging, use the existing supported SDK/buildhost with disposable
HOME/XDG, a private bus and synthetic data:

1. Build the exact branch and check for Vala, GtkBuilder and CSS warnings.
2. Check light, dark, high-contrast light/dark, including switching while open.
3. Check 360/540/920/1280 logical-pixel widths, 200% text, display scaling and RTL.
   Existing 500/540/920/1020sp breakpoints and resize logic are unchanged.
4. Inspect unread/read/selected/focused/starred rows, long identities and dates,
   alias overflow, no contact photos, hidden fields and reordered fields.
5. Exercise folder/conversation selection, keyboard navigation, selection mode,
   search, sidebar drawers, native menus and Compose (never send test mail).
6. Capture real synthetic-data screenshots for owner acceptance. No installation,
   profile migration, main merge or release is part of this change.

The rest of the design brief and release gates remain in force. New logo assets
are a separate task; this change does not install or revise them.
