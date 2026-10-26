# Prepared third-party licence texts

Retrieved 2026-10-26 from upstream files, verbatim (not relicensed).
Dependency files use the exact references below; CC0 uses the SPDX text mirror.
Their presence does not settle component exceptions or binary obligations.

| Local file(s) | Upstream source |
| --- | --- |
| DarkReader-MIT.txt | https://github.com/darkreader/darkreader/blob/51f97ccd34ed0a70832421c2768a19bc46fcec4d/LICENSE |
| Snowball-COPYING.txt | https://github.com/snowballstem/snowball/blob/cd195b51e948a902a4312f023f4a14392516a543/COPYING |
| ytnef-GPL-2.0.txt | https://github.com/Yeraze/ytnef/blob/d9b2f01d125c9b178f7a00ec397cc2a9f258e8e1/COPYING |
| gnome-online-accounts-COPYING.txt | https://github.com/GNOME/gnome-online-accounts/blob/c1fd9e58b8e4559e690ab96a191304a6660fba97/COPYING |
| evolution-data-server-COPYING.txt | https://github.com/GNOME/evolution-data-server/blob/242c81196daf074cdc4c224e48b7b4319985b589/COPYING |
| folks-COPYING.txt | https://github.com/GNOME/folks/blob/1157825538e3d565a4e9c519ac5fedd97ea10d00/COPYING |
| libpeas-COPYING.txt, libpeas-license_change.txt | https://github.com/GNOME/libpeas/tree/744430715e619069b3fcb6c994f2c09257700d05 (COPYING, license_change) |
| GMime-COPYING.txt | https://github.com/jstedfast/gmime/blob/3.2.15/COPYING |
| libical-LICENSE.txt, libical-COPYING.txt, libical-LGPL21.txt, libical-MPL2.txt | https://github.com/libical/libical/tree/v3.0.20 (LICENSE, COPYING, LICENSE.LGPL21.txt, LICENSE.MPL2.txt) |
| CC0-1.0.txt | https://github.com/spdx/license-list-data/blob/main/text/CC0-1.0.txt; canonical https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt (new original brand/hero artwork only) |

The GNOME GitHub mirrors were used for exact-commit reads when GitLab raw-file
fetches returned HTTP 406. Follow-up audit verified cached Git-source COPYING
hashes, the libical/GMime archives against the exact manifest SHA-256 values,
and all five archive licence members byte-for-byte. Dark Reader's official npm
API artifact and MIT text also match the vendored/prepared files exactly.
The libpeas licence-change record is preserved verbatim. See
[the inventory](../../THIRD-PARTY-NOTICES.md) and
[distribution decision](../LICENSING-DECISION.md); final package compliance and
corresponding-source mapping are separate from this input/text verification.
