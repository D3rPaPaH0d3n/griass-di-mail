# Griabuntu Mail — private identity

**Source update, 2026-10-27:** the owner has now requested and authorised the
project-wide naming implementation. The current own application ID, executable,
namespace and packaging are in [IDENTITY.md](IDENTITY.md). The migration plan
below records the earlier proposal; source changes and a private repository
rename do not imply that personal profiles have been migrated or that the
separate public-name/Canonical gate has been resolved.

**Owner decision: 2026-10-26, 19:25 UTC.** Use **Griabuntu Mail**, with that exact
spelling/case, for this private presentation candidate. This supersedes the
Briefwerk study and the intervening Griabu proposal. It does not establish legal
name availability or authorise publication. Repository name/visibility,
application IDs, installed icons and profile locations are unchanged.

## Preliminary collision search · 2026-10-26

- Exact web searches for `"Griabuntu"` and `"Griabuntu Mail"` returned no results.
- A broader search `Griabuntu mail linux software` returned general Linux email
  articles/listings, not an identifiable exact-name project in the returned set.
- GitHub repository-name search `griabuntu in:name` returned **0 repositories**.

These bounded search results are **not** trademark, domain, company-register or
app-store clearance, nor a guarantee that nobody uses the name. No domain
availability or trademark-registration assertion is made.

## Canonical / Ubuntu naming gate

Canonical's [current intellectual-property policy](https://canonical.com/legal/intellectual-property-policy)
was read on **2026-10-26**. Section 4 says written permission is required for
UBUNTU/BUNTU-ending marks sufficiently similar to its trademarks or other
confusingly similar marks; it also says its trademarks cannot be used in software
titles. Truthful compatibility references must not imply endorsement or
confusingly capitalise on Ubuntu's goodwill.

**Griabuntu Mail may raise a confusing-similarity/permission question.** This task
neither declares the name automatically prohibited nor claims it is cleared.
A “not affiliated” disclaimer is not clearance. Before public branding, obtain
an appropriate name-clearance decision and any necessary written Canonical
permission; consult relevant trademark registers/markets and qualified advice
as appropriate. The [permission-request draft](CANONICAL-NAME-PERMISSION-DRAFT.md)
is **unsent**; no contact, application or approval has taken place.

The name is honoured privately while this gate remains open. Open-source code
licences do not grant third-party trademark rights. No Ubuntu/Canonical logo or
borrowed trade dress is included in the new art.

## Original visual direction

**Latest feedback supersedes acceptance of this candidate:** the owner wants
a clearer envelope/mail cue. Closed/open envelope and the final replacement
mark remain undecided; see the [current design feedback](desktop-design-direction.md).
The following describes the existing study, not the final approved logo.

A newly drawn **G** forms a folded-page outline with a mail-slot crossbar and a
peach/copper corner. It replaces the old B-mark, not just its caption. Pastel
teal surfaces, deep petrol foregrounds and restrained rounding give the private
identity a soft Material-inspired feel. Light/dark/mono vectors, transparent
PNGs, app-icon candidates and the synthetic hero are in [brand/](../brand/).
See [provenance](../brand/README.md).

The [desktop design direction](desktop-design-direction.md) is a **future intent**:
native GTK4/libadwaita controls coherent with Ubuntu/GNOME, not an implemented
redesign, a web-widget replacement, or proof of integration. No app styling,
installed icon, runtime theme or profile was changed here.

## Safe technical identity/migration plan — not executed

1. Resolve name clearance/permission and choose a reverse-DNS application ID in
   an owner-controlled namespace. Do not invent an owned domain or silently
   distribute a new independent app as `net.donnybeelo.Convey`.
2. Inventory Meson `convey_id`, executable/resources, desktop/AppStream and
   `.doap` metadata, icons, gettext domain, D-Bus names/services, GSettings schema
   IDs/paths, portals and Flatpak manifests/permissions. Review repository rename
   and redirects separately. Retain upstream attribution in the app/about/docs.
3. Define explicit opt-in migration for config/cache/data, GOA/keyring references
   and sandbox profile paths. Back up with consent. Never copy credentials
   implicitly, start two writers against one mail store or delete old profiles.
   Retain a documented rollback path.
4. Test clean install, upstream coexistence, migration/upgrade and rollback with
   synthetic data on supported desktops. Check notifications, tray, launchers,
   schemas, file handlers, scaling, light/dark/high contrast and uninstall.
5. Only after separate approval update technical identity and native UI in
   focused changes; rebuild and accept-test. Decide source visibility, repository
   rename and binary/source publication separately. No switches occur here.
