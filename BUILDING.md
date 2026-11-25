# Native build

On Ubuntu 26.10 amd64, install the dependencies listed in `debian/control` and build the native package from a clean checkout:

```sh
sudo apt-get build-dep .
dpkg-buildpackage -b -us -uc
```

The build produces packages in the parent directory; it does not install or launch the client. For a development build with the same features:

```sh
meson setup build -Dprofile=release -Dtnef=enabled -Dlibunwind=enabled -Dvaladoc=disabled --wrap-mode=nodownload
meson compile -C build
python3 build-aux/check-identity.py
python3 debian/run-tests.py build
python3 debian/run-tests.py build --pictures
```

Use a disposable build environment with unprivileged namespaces and a virtual display for GTK tests, never a personal mailbox. The panel fixture exercises the published D-Bus properties and signals: inside an isolated session, run `dbus-run-session -- python3 test/panel-badge.py build/test/test-recipient-aliases`. See [packaging](debian/README), [tests](test/README.md) and [corresponding source](docs/release/CORRESPONDING-SOURCE.md).

Copyright © 2016 Software Freedom Conservancy Inc.
Copyright © 2018–2020 Michael Gratton <mike@vee.net>
