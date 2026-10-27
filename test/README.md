<!-- Downstream modification: 2026-10-26 — document synthetic notification-flag regression suite and red baseline. -->
<!-- Downstream modification: 2026-10-27 — record verified notification-flag fix. -->

Automated Test Infrastructure
=============================

Griabuntu Mail currently supports three types of automated tests:

 * Engine unit tests
 * Client (GTK and JavaScript) unit tests
 * Server integration tests

Unit tests
----------

Unit tests test individual functions, in general avoid doing any I/O
so they are fast, and can be run automatically.

The engine and client unit tests are hooked up to the Meson build, so
you can use Meson's test infrastructure to build and run them. These
are run automatically as part of the Gitlab CI process and if you use
the development Makefile, you can execute them locally by simply
calling:

    make test

The engine tests can be run headless (i.e. without an X11 or Wayland
session), but the client tests require a functioning display since
they execute GTK code.

Synthetic notification flag regression
--------------------------------------

Build and run this separate, headless suite in the existing SDK environment:

```
meson compile -C build test-notification-flags
meson test -C build --no-rebuild --print-errorlogs notification-flag-tests
```

It compiles the actual `application-notification-plugin-context.vala` and tray
model, with the engine's flags, mock folder signals and production plugin
interfaces. Only application/plugin-loader/contact boundaries are replaced by
`mock/notification-context.vala`; the handler is not copied into the test.
The target is declared at the repository root because Vala needs a common
source root for the `src/` and `test/` inputs.

No GTK application, accounts, contacts backend or real mail store is opened.
Use a temporary HOME/XDG environment, memory GSettings, no network and no host
session/system bus. Do not run the installed mail application for this test.

Baseline `5834da28091fb951ba3f53dd610d2f30fa352135`: the ten cases compile;
four deliberately fail (star on, star off, unrelated unread flag, mixed batch).
For example, starring one of two synthetic unread arrivals incorrectly drops
the tray count from 2 to 1. The six controls pass: read, deleted-unread, removed,
no promotion of old/re-unread mail, notification visibility policy, and clearing
session-new IDs when a recent conversation is visible even while still unread.
This records the bug before the production fix is approved. The suite is
intentionally red on that baseline, not marked as an expected failure.

On **2026-10-27**, the unchanged handoff source `4f55c3c6` reproduced the same
**6 passes / 4 failures**. With the production handler changed to retire only
read or deleted IDs (`!is_unread() || is_deleted()`), **all 10 cases pass**.
The tests and their expectations were unchanged. Star-on, star-off and other
unread flag changes retain session-new entries; read/deleted/removed messages,
mixed batches, old/re-unread messages and visibility policy retain their tested
behaviour. The separate `email_seen` signal still selects only read messages.

Both runs compiled the real handler and engine using GNOME SDK 51, with
`profile=release`, TNEF enabled and libunwind disabled. Dependency development
files/libraries were copied from the existing Griabuntu Mail Flatpak into a disposable
build stage; the installed application was not launched or modified. Tests used
temporary HOME/XDG directories, memory GSettings, no network, host buses or
display. This is focused regression evidence, not a full app rebuild, new
package verification or visible desktop/mail acceptance.

Identity refactor (2026-10-27)
------------------------------

The first complete renamed build passes **328 engine + 62 focused + 10 flag
cases**, plus both desktop-file validators and AppStream validation. The extra
engine case exercises an old `convey_tokeniser` table and a new
`griabuntu_mail_tokeniser` table against synthetic in-memory message text.
Legacy names are lookup aliases, not a profile migration.

`python3 build-aux/check-identity.py` checks identity wiring across Vala,
GSettings, GResources, desktop/D-Bus launch commands, translation sources and
product names, and the JavaScript/WebKit bridge. The native package test runner
calls it before the isolated headless suites. See `docs/IDENTITY.md` for the
current naming map and deliberately preserved provenance/compatibility names.
The original baseline evidence above retains its original source commit.

Integration tests
-----------------

Integration tests run Griabuntu Mail's network code against actual servers, to
ensure that the code also works in the real world.

The integration tests are built by default, but not currently hooked
up to Meson and are not automatically run by Gitlab CI, since they
require multiple working servers, network connection to the servers,
and login credentials.

You can run them manually however against any server you have a test
account on, using the following form:

    build/test/test-integration PROTOCOL PROVIDER [HOSTNAME] LOGIN PASSWORD

For example, to test against GMail's IMAP service:

    build/test/test-integration imap gmail test@gmail.com p455w04d

If `PROVIDER` is `other`, then `HOSTNAME` is required.

The easiest way to test against a number of different servers at the
moment is to create a test account for each, then write a shell script
or similar to execute the tests against each in turn.

## Consent-controlled contact pictures (2026-10-27)

The focused headless runner includes seven policy tests for default-off consent,
separate company permission, SHA-256 normalisation, unsafe domains, free-mail
providers, fresh settings and rejecting vector payloads.

For the real client-library/GTK/HTTPS fixtures, with the build dependencies
installed, run from the source root:

```sh
python3 debian/run-tests.py obj-x86_64-linux-gnu --pictures
```

The runner creates disposable HOME/XDG, a private bus/display and a loopback-only
network namespace, with synthetic DNS and an ephemeral TLS trust/key fixture.
A local HTTPS server behind a local HTTP CONNECT proxy exercises the real Soup
transport, user proxy handling, Gravatar 404/company fallback, raster decoding,
revocation, redirects, oversized/vector payloads and stale delayed responses.
No external service or real mailbox is contacted. No TLS verification is disabled.
The integration script refuses to run without the explicit fixture marker,
memory settings and a loopback-only network namespace. Test keys are temporary
and are never included in the repository or application package.
