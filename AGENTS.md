<!-- Current icon correction, 2026-10-27: The owner selected the CLOSED COLOURED
ENVELOPE in design/owner-artwork-20261027/. Active exports in brand/ preserve
that supplied PNG. The previously installed .3 icon study was a mistaken
substitution and is superseded. Do not reuse its CC0 claim for owner originals.
See brand/README.md. Broader UI theming remains separate. -->

# Working on Griabuntu Mail

This is the owner's independent Convey/Geary downstream, not official Convey,
Geary or an Ubuntu/Canonical product. The product is **Griabuntu Mail**. The owner explicitly requested a project-wide
identity change on 2026-10-27. Current executable/project/gettext domain:
`griabuntu-mail`; application ID: `io.github.d3rpapah0d3n.GriabuntuMail`;
engine namespace: `GriabuntuMail`. Read `docs/IDENTITY.md` before identity work.
The repository is `D3rPaPaH0d3n/griabuntu-mail`.

Native Ubuntu 26.10 .deb packaging is the current primary build route. Keep
profiles, secret schemas and launchers separate from the historical Convey
installation. A source rename does not authorise silently copying personal state.
Original author/licence texts and dated release evidence retain historical names.

## Start here

Current development branch: **`work/griabuntu-ubuntu-deb`**, based on
`handoff/griabuntu-ai`; preserve the old `main` and complete history. Read:

1. [AI handoff and current decisions](docs/AI-HANDOFF.md).
2. [Current design direction](docs/desktop-design-direction.md).
3. [Fresh build/package evidence](docs/release/VERIFICATION.md).
4. [GPL-copy boundaries](docs/release/GPLV3-COPY.md),
   [component notices](THIRD-PARTY-NOTICES.md) and
   [release gates](RELEASE-CHECKLIST.md).

Re-check the actual branch, status, source and relevant tests before changing
anything. Inspect the next task yourself, identify stale assumptions, and agree
a bounded next change with the owner. Do not outsource a second-model review by
default or rebuild a large validation framework for a small edit.

## Decisions to preserve

- This elected application copy is **GPL-3.0-only**, using LGPL-2.1 section 3.
  Independent original LGPL copies/history and third-party terms remain intact.
  **Keep TNEF/winmail.dat support.** Do not re-open this approved choice or
  blanket-relicense MIT, CC, BSD or separately licensed library material.
- Future UI: native GTK4/libadwaita/Ubuntu-GNOME controls, with pastel petrol/teal
  and copper/peach, Material-inspired tonal surfaces, light/dark and accessibility.
  The current art is a concept, not an implemented redesign.
- The owner selected the supplied **closed coloured envelope** on 2026-10-27.
  Originals are in `design/owner-artwork-20261027/`; active technical exports
  are in `brand/`. The app SVG embeds the original PNG; it is not a new vector.
  Symbolic geometry follows the supplied mono alpha mask. Earlier local and
  folded-G studies are archived. Their CC0 grants do not apply automatically
  to these supplied originals. Keep larger theme work separate; read
  `brand/README.md` before asset changes.
- Tray count means **session-new/unseen**, not all historical unread mail; it
  starts empty after restart. Keep account/folder deduplication and stale-target
  protection. Reply opens a draft, Archive targets one message, Delete means
  existing Trash only. Never auto-send, permanently delete or silently act on
  the selected whole conversation.
- Contact photos use existing local desktop sources; no new external avatar,
  logo, sender-hash or mail-content services without permission.

## Safety and evidence

Use synthetic data and disposable HOME/XDG/private buses for tests. Do not open
or modify real mail, contacts, accounts, keyrings or profiles for validation.
Reuse existing SDK/Builder installations; never weaken isolation to green a test.
The historical flag baseline has **6 passes / 4 failures**; don't mask it.
The 2026-10-27 handler fix passes all **10** unchanged cases; the identity build
also adds a synthetic old/new FTS-tokeniser compatibility case. See `test/README.md`.
Earlier dated handoff/release records describe the pre-fix source and package.
The actual staged library must be loaded when claiming package-library tests;
see the verification record's ELF-loader/RPATH procedure.

Do not publish, change repository visibility/default branch, merge main, contact
Canonical, install/sign a package, migrate profiles/IDs or change production
settings without explicit owner instruction. No credentials, personal mail,
private machine access details or operational logs belong in commits.
Report scoped changes, actual checks, unresolved failures and remaining gates.

## Owner-authorised continuation (2026-10-27)

The owner authorised work on a dedicated development branch: native pastel
teal/peach UI, the supplied closed-envelope icon and banner, visible Griabuntu
Mail branding, Markus Kainer (D3rPaPaH0d3n) as maintainer and
projekt@kainer.co.at as public contact. Keep required upstream notices accessible.
The six supplied graphics were generated with ChatGPT using text-only prompts.
External pictures are authorised only behind explicit in-app consent, off by
default, with local-photo → Gravatar → company/website icon → initials priority.
Native Ubuntu 26.10 updates must retain existing Griabuntu Mail profiles.
Commits/pushes, creating a .deb and a synthetic installation test on TerraLinux
are authorised. Public repository visibility is authorised when finished and
publication prerequisites are met. No personal mail/account access or contacting
third parties is authorised. Keep actual validation and unresolved items honest.

The owner also explicitly authorised setting the finished development branch
as the GitHub default while preserving main and the full fork history.

The owner confirmed there is no written Canonical permission or qualified name
review. The public-name gate remains unresolved; do not claim clearance or
contact Canonical without separate instruction. Private development and pushes
continue under the existing authorisation.
