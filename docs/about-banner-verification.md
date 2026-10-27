# Native About banner · 2026-10-27

Package: `griabuntu-mail_51.0+griabuntu20261027.5_amd64.deb`.
SHA-256: `0732633a9c2b0261fec685eb047084758073f16c0869117a0e78ef162d94a854`.

The exact owner-supplied `brand-banner.png` is embedded in GResource. Its
extracted package resource bytes match the preserved original. The About view
uses a 480 × 160 logical-pixel Gtk.Picture with preserved aspect ratio, backed
by the full source texture through a bounded snapshot paintable for HiDPI.

Gtk.AboutDialog's stock logo Gtk.Image shrinks wide logos to icon size. Only
the image holding the supplied paintable is hidden, with its replacement
inserted in the same box. The code uses paintable identity rather than private
template child names. The native credits and licence content remain intact.
A weak dialog reference prevents duplicate live About windows; banner decode
failure falls back to the application icon.

The final `.5` package completed the existing native validation: 328 engine,
62 helper and 10 flag cases, two desktop-file validators and AppStream
validation. Source identity checks passed. The actual packaged executable
and private client-library bytes were asserted in the isolated GUI fixture.
Fresh-start/About and themed icon lookup passed on private Xvfb, with no
personal profiles or network access. About screenshots were visually inspected
in light and dark appearances and at 200% scaling. The banner is readable and
uncropped; the version, credits tab, licence text/link and repository link
remain visible. The early 128px logo-sized render was discarded.

This scoped change adds the About banner. It does not implement the pending
new-mail/empty tray-icon state switch or the broader application theme.
