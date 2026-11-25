# Native corresponding source

For each binary, provide equivalent access to its exact complete source, build instructions and required library sources (GPLv3 §6(d)). Identify the matching source revision and checksums. Retain original component copyright texts and allow modified builds and replacement of shared libraries. Do not substitute a moving branch for matching source.

The [published .8 preview](https://github.com/D3rPaPaH0d3n/griass-di-mail/releases/tag/v51.0-griassdi20261028.8) includes application, Dark Reader and libytnef companion sources. The historical [dependency index](NATIVE-SOURCES-20261028.json) applies to that binary, not automatically to later builds. To inspect its entries offline:

```sh
python3 build-aux/fetch-native-sources.py docs/release/NATIVE-SOURCES-20261028.json --list
```

A new binary requires its own dependency closure, exact source mapping and verification.
