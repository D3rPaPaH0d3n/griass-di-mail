# Briefwerk — identity preparation

**Owner name decision: 2026-10-26.** The public-facing project name is
**Briefwerk**. The repository name, installed identity and data locations are
unchanged in this preparation. Name approval is not a trademark-clearance claim
or permission to publish/deploy.

## Preliminary collision check · 2026-10-26

Current web searches for `"Briefwerk" mail app software` and
`"Briefwerk" software GitHub Marke` found:

- [briefwerk.com](https://www.briefwerk.com/) already uses **Briefwerk** for
  direct-marketing, mailing production and lettershop services. This is a
  material adjacent-field naming collision, even though no Linux email client
  under that exact name appeared in the short search.
- An [Etsy shop named briefwerk](https://www.etsy.com/shop/briefwerk) and a
  [Briefwerkstatt website project](https://github.com/0xbriefwerkstatt/briefwerkstatt-www)
  also surfaced. These are not proof of software trademark rights or clearance.

Recommendation: honour the chosen presentation name for this private candidate,
but **resolve the adjacent mailing-services collision before public branding**.
Check relevant trademark registers (DPMA/EUIPO/WIPO and intended markets),
software/app stores, domains and confusion risk; obtain qualified advice if
needed. This was a brief web search, not a register search or legal opinion.
Adding “Mail” alone does not establish distinctiveness or permission.

## Original visual direction

The new symbol combines a compact **B** with two folded-letter counters and a
copper paper-fold corner. Petrol/teal is the primary colour; copper is an accent,
not the only carrier of meaning. Light, dark and one-colour vectors and raster
previews are in [brand/](../brand/). The artwork is newly drawn geometry, not a
modified Convey/Geary/GNOME logo. It is a candidate identity, not an installed
app-icon change. See [asset provenance](../brand/README.md).

## Safe technical identity/migration plan — not executed

1. Resolve name clearance and choose a reverse-DNS application ID in a namespace
   the owner controls. Do not invent an owned domain or silently reuse
   `net.donnybeelo.Convey` for an independent public distribution.
2. Inventory Meson `convey_id`, executable/resources, desktop/AppStream and
   `.doap` metadata, icons, gettext domain, D-Bus names/services, GSettings schema
   IDs/paths, portals and Flatpak manifests/permissions. Review links/repository
   rename redirects separately. Keep upstream attribution in the app/about/docs.
3. Define explicit opt-in migration for config/cache/data, GOA/keyring references
   and sandbox profile paths. Back up with consent. Never copy credentials to
   new locations implicitly, start two writers against one mail store, or delete
   the old profile. Retain a documented rollback path.
4. Test clean install, upstream coexistence, upgrade/migration and rollback with
   synthetic data on supported desktops. Check notifications, tray, launcher,
   schemas, file handlers, translations and uninstall behaviour.
5. Only after owner approval update technical identity in a dedicated change;
   rebuild and accept-test. Decide source visibility, repository rename and
   binary publication separately. No switches are performed by this branch.
