#!/usr/bin/env python3
"""Check identity wiring across native desktop, resources and the WebKit bridge.

New downstream file: 2026-10-27. GPL-3.0-only; see COPYING.
"""

from pathlib import Path
import re
import struct
import sys
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parent.parent
APP_ID = "io.github.d3rpapah0d3n.GriabuntuMail"
RESOURCE_PATH = "/" + APP_ID.replace(".", "/")
EXECUTABLE = "griabuntu-mail"


def read(path):
    return (ROOT / path).read_text()


def check(condition, message):
    if not condition:
        raise SystemExit("Identity check failed: " + message)


def main():
    client = read("src/client/application/application-client.vala")
    check('NAME = "Griaß di Mail"' in client, "canonical application name")
    check(f'SCHEMA_ID = "{APP_ID}"' in client, "application schema ID")
    check(f'RESOURCE_BASE_PATH = "{RESOURCE_PATH}"' in client, "application resource path")
    check(f"'{APP_ID}@0@'" in read("meson.build"), "Meson application ID")
    check('SETTINGS_FILENAME = "griabuntu-mail.ini"' in
          read("src/client/accounts/accounts-manager.vala"), "account settings basename")
    check('DB_FILENAME = "griabuntu-mail.db"' in
          read("src/engine/imap-db/imap-db-account.vala"), "mail database basename")
    schema = ET.fromstring(read(f"desktop/{APP_ID}.gschema.xml")).find("schema")
    check(schema.attrib["id"] == APP_ID, "GSettings identity")
    check(schema.attrib["path"] == RESOURCE_PATH + "/", "GSettings path")
    check(schema.attrib["gettext-domain"] == EXECUTABLE, "translation domain")
    resources = ET.fromstring(read(f"ui/{APP_ID}.gresource.xml"))
    check(resources.find("gresource").attrib["prefix"] == RESOURCE_PATH, "GResource prefix")
    desktop = read(f"desktop/{APP_ID}.desktop.in.in")
    check("Name=Griaß di Mail\n" in desktop, "launcher name")
    check(f"TryExec={EXECUTABLE}\n" in desktop, "launcher executable")
    check(f"Exec={EXECUTABLE} %U\n" in desktop, "launcher command")
    check(f"@bindir@/{EXECUTABLE} --gapplication-service" in
          read(f"desktop/{APP_ID}.service.in"), "D-Bus activation executable")

    extension = read("src/client/web-process/web-process-extension.vala")
    bridge = re.search(r'EXTENSION_CLASS_VAR = "([^"]+)"', extension).group(1)
    state = re.search(r'PAGE_STATE_OBJECT_NAME = "([^"]+)"', extension).group(1)
    javascript = read("ui/components-web-view.js")
    check(bridge + ".send(" in javascript, "JavaScript/native extension bridge")
    for page in ("composer", "conversation"):
        check(f"var {state} = new " in read(f"ui/{page}-web-view.js"),
              page + " page state object")
    check("dataset.griabuntuMailImportant" in javascript and
          "[data-griabuntu-mail-important]" in javascript,
          "HTML data attribute and dataset property must agree")
    check("conveyImportant" not in javascript, "obsolete dataset property")

    for entry in read("po/POTFILES.in").splitlines():
        if entry.strip() and not entry.startswith("#"):
            check((ROOT / entry).is_file(), "translation source path: " + entry)
    for directory in ("src", "test"):
        for path in (ROOT / directory).rglob("*.vala"):
            check(not re.search(r"\b(?:namespace Convey|Convey\.)", path.read_text()),
                  "obsolete engine namespace: " + str(path.relative_to(ROOT)))
    for locale in (ROOT / "po").glob("*.po"):
        for block in locale.read_text().split("\n\n"):
            if re.search(r'^msgid "Griaß di Mail"$', block, re.M):
                check('msgstr "Griaß di Mail"' in block,
                      "translated product name: " + locale.name)

    import base64
    originals = ROOT / "design/owner-artwork-20261027"
    for basename in ("griabuntu-mail-app-icon", "griabuntu-mail-app-icon-nightly",
                     "griabuntu-mail-tray", "griabuntu-mail-symbolic"):
        icon = ET.fromstring(read("brand/" + basename + ".svg"))
        namespace = "{http://www.w3.org/2000/svg}"
        check(not list(icon.iter(namespace + "script")), "no SVG scripts: " + basename)
        if basename == "griabuntu-mail-symbolic":
            check(not list(icon.iter(namespace + "image")), "symbolic filled geometry")
            check(not any(element.get("stroke") or element.get("fill") == "none"
                          for element in icon.iter()), "symbolic icon must use filled paths")
        else:
            embedded = icon.find(namespace + "image").get("{http://www.w3.org/1999/xlink}href")
            check(embedded.startswith("data:image/png;base64,"), "embedded original PNG")
            check(base64.b64decode(embedded.split(",", 1)[1]) ==
                  (originals / "envelope-closed-color.png").read_bytes(),
                  "exact owner-selected original: " + basename)
    for basename in ("griabuntu-mail-app-icon", "griabuntu-mail-app-icon-nightly"):
        for size in (16, 24, 32, 48, 64, 128, 256, 512):
            png = (ROOT / "brand" / f"{basename}-{size}.png").read_bytes()
            check(png[:8] == b"\x89PNG\r\n\x1a\n" and
                  struct.unpack(">II", png[16:24]) == (size, size),
                  f"native raster export: {basename} {size}px")
    check((ROOT / "brand/griabuntu-mail-app-icon.svg").read_bytes() ==
          (ROOT / f"help/C/figures/{APP_ID}.svg").read_bytes(), "help icon source")

    print("Griaß di Mail identity and icon sources: desktop, schema, resources, translations and JS bridge agree.")


if __name__ == "__main__":
    main()
