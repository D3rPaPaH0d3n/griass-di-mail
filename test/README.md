
Automated Test Infrastructure
=============================

Convey currently supports three types of automated tests:

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

Integration tests
-----------------

Integration tests run Convey's network code against actual servers, to
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
