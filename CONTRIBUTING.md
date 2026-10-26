<!-- Downstream modification: 2026-10-26 — direct contributions to the independent downstream. -->
# Contributing

This repository is an independent Convey downstream, not official Convey or
Geary. File downstream reports here once issue reporting is made available.
Do not send fork-specific bugs to upstream unless reproduced there. Historical
[Geary development documentation](https://gitlab.gnome.org/GNOME/geary/-/wikis/Development)
can be useful background, but is not this project's support channel or a way to
fund this downstream.

## Useful reports

Include the source commit/build profile, desktop/session, reproduction steps,
expected/actual behaviour and whether a synthetic example reproduces it.
Never upload a live mail database, account settings, contact cache, credentials,
private message content or unredacted logs. See [SECURITY.md](SECURITY.md) for
sensitive reports.

## Changes

- Keep fixes focused. Describe user-visible behaviour and add synthetic tests.
- Preserve inherited copyright/licence headers and add real dated downstream
  change notices in modified inherited files. Do not invent authorship.
- State source/licence/provenance for new dependencies and assets; no borrowed
  brand marks or external avatar service additions without explicit review.
- Use the existing source licences; no blanket relicensing or unreviewed CLA is
  introduced here. Proposed original code should be LGPL-2.1-or-later-compatible;
  identify any exceptions before submission.
- Run relevant tests from [BUILDING.md](BUILDING.md) and [test/README.md](test/README.md).
  Report the known four red notification-flag baseline cases separately; do not
  hide them by marking the whole suite green.

Repository access, acceptance policy and maintainer capacity remain provisional
until publication. No automatic merge, deployment or release process is enabled.
