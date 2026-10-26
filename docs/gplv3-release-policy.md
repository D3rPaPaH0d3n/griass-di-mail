# Approved release preparation policy — 2026-10-26

The owner approved the recommended **GPLv3 combined-application release route
with all existing functions**, including TNEF/Outlook winmail.dat support.
The response “Ja passt!” at 19:56 UTC referred to that specific choice.

## Scope

Prepare a separate private GPLv3 release-source copy using the option granted
by LGPL-2.1 section 3 and the compatible libytnef terms. Version 3 is the
approved version; the preparation uses GPL-3.0-only for that elected application
copy, rather than silently promising future GPL versions.

Preserve the original independently available LGPL source copies/grants,
upstream history, copyright, change dates and component-specific terms.
The release-copy conversion is not a blanket relicensing of MIT JavaScript,
CC artwork, third-party libraries or the original LGPL preparation branch.
Do not remove TNEF to avoid the combined-release obligations.

The isolated release-preparation task covers operative notices, GPL text,
accurate application/build/AppStream/About metadata, installed notices,
corresponding-source instructions and synthetic baseline/patch verification.
Actual results and exact source/artifact identifiers must be recorded before
claiming a tested release copy.

## Internal preparation outcome

Private branch `openclaw/griabuntu-gplv3-release-prep` contains the elected
release copy. The actual freshly built source is
`a4774cb9e390a3d55efa6636c9f2f3b12fcc3f88`; later reporting-only commit
`7c3f99880d85634eb0c0998fdad450a8bfb782a4` records verification.

The GPL copy passed 327 engine and 62 focused cases, including synthetic TNEF
extraction, also with the actual staged client loaded. The separate known flag
suite still has four failures, unchanged from its baseline. The same tested
stage was internally exported unsigned and its installed notices/metadata
inspected. No application was installed or publicly released.

See that branch's `docs/release/VERIFICATION.md` and `GPLV3-COPY.md` under
`docs/release/`. Full corresponding-source delivery, shipped component/asset
closure and public-package cleanup are not certified by this internal result.

## Separate gates still apply

- No authorisation to make the repository public, publish binaries or merge main.
- No Canonical contact or public-name clearance has been authorised.
- No installed application/icon change, profile migration or technical-ID change.
- Asset attribution, final package/source mapping and engineering acceptance
  remain real checks; previous prototype tests do not certify a new release.
- The logo's more-recognisable-envelope direction remains under discussion.

Audit basis: private `openclaw/griabuntu-license-clarification`,
`465e0c6c15233009a7e84ab60a783a3a1fb4a4e0`, `docs/LICENSING-DECISION.md`.
This document records the approval and tested internal preparation, not a
public-release approval or complete legal certification of a binary.
