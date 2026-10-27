#!/usr/bin/python3
"""Run existing native headless tests with disposable state and no host buses.

New downstream packaging: 2026-10-27. GPL-3.0-only; see COPYING.
"""

import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    source = Path.cwd().resolve()
    build = (source / sys.argv[1]).resolve()
    if source not in build.parents:
        raise SystemExit("Build directory must be inside the source snapshot")

    subprocess.run([sys.executable, str(source / "build-aux/check-identity.py")], check=True)

    with tempfile.TemporaryDirectory(prefix="griabuntu-native-tests-") as scratch:
        scratch = Path(scratch)
        home = scratch / "home"
        home.mkdir(mode=0o700)
        for directory in ("config", "cache", "data", "runtime"):
            (home / directory).mkdir(mode=0o700)
        etc = scratch / "etc"
        etc.mkdir()
        (etc / "passwd").write_text(
            f"fixture:x:{os.getuid()}:{os.getgid()}:Synthetic fixture:/home/fixture:/bin/sh\n"
        )
        (etc / "group").write_text(f"fixture:x:{os.getgid()}:\n")
        (etc / "machine-id").write_text("0123456789abcdef0123456789abcdef\n")

        command = [
            "bwrap", "--die-with-parent", "--unshare-all", "--new-session",
            "--ro-bind", "/usr", "/usr",
            "--symlink", "usr/bin", "/bin",
            "--symlink", "usr/sbin", "/sbin",
            "--symlink", "usr/lib", "/lib",
            "--symlink", "usr/lib64", "/lib64",
            "--ro-bind", str(etc), "/etc",
            "--proc", "/proc", "--dev", "/dev", "--tmpfs", "/tmp",
            "--dir", "/run", "--dir", "/var",
            "--bind", str(source), str(source),
            "--bind", str(home), "/home/fixture",
            "--chdir", str(source), "--clearenv",
        ]
        for path in ("/etc/ld.so.cache", "/etc/fonts", "/etc/localtime"):
            if Path(path).exists():
                target = etc / Path(path).name
                if Path(path).is_dir():
                    target.mkdir()
                else:
                    target.touch()
                command += ["--ro-bind", path, path]
        environment = {
            "PATH": "/usr/bin:/bin",
            "HOME": "/home/fixture",
            "USER": "fixture",
            "LOGNAME": "fixture",
            "LANG": "C.UTF-8",
            "XDG_CONFIG_HOME": "/home/fixture/config",
            "XDG_CACHE_HOME": "/home/fixture/cache",
            "XDG_DATA_HOME": "/home/fixture/data",
            "XDG_RUNTIME_DIR": "/home/fixture/runtime",
            "GSETTINGS_BACKEND": "memory",
            "GIO_USE_PROXY_RESOLVER": "dummy",
            "GNOTIFICATION_BACKEND": "gtk",
        }
        for key, value in environment.items():
            command += ["--setenv", key, value]
        command += [
            "dbus-run-session", "--", "meson", "test", "-C", str(build),
            "--no-rebuild", "--print-errorlogs",
            "engine-tests", "recipient-alias-tests", "notification-flag-tests",
            "desktop-file-validate", "io.github.d3rpapah0d3n.GriabuntuMail.metainfo.xml-validate",
        ]
        subprocess.run(command, check=True)


if __name__ == "__main__":
    main()
