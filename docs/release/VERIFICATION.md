# Private GPLv3 copy verification · 2026-10-26

This record is populated in the reporting-only follow-up after freezing and
building the elected source commit. It does not certify older prototype builds,
a public release, complete corresponding-source delivery or desktop acceptance.

Baseline `465e0c6c15233009a7e84ab60a783a3a1fb4a4e0` fails Meson configuration:
`Sandbox violation: Tried to grab file COPYING from a nested subproject`.
A distinct baseline-buildable copy corrects **only** that notice packaging:
remove the cross-subproject `install_data`, copy the identical ValaUnit COPYING
to `docs/licenses/vala-unit-LGPL-2.1.txt` (installed by the existing directory
rule). That copy builds successfully and freshly passes **327 engine + 62
focused cases**. The separate flag suite still fails **4/10**, controls 6/10
pass. No production handler is changed. The unmodified baseline is not falsely
reported buildable.

Actual GPL-copy build/tests, same-stage export and source/artifact identities
are added after execution. See `GPLV3-COPY.md` and `CORRESPONDING-SOURCE.md` for
scope, isolation, component boundaries and unclosed public-release gates.
