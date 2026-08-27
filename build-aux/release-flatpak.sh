#!/bin/bash
# Build and sign a Convey release into the shared Flatpak repo,
# ready to publish to releases.donnybeelo.net.
#
# Usage: build-aux/release-flatpak.sh [repo-dir]
#
# The repo is shared across applications: building here adds/updates only
# Convey's refs and leaves any other app in place. Assumes the manifest's
# convey module is pinned to the release tag and that the tag is pushed --
# the build clones from the remote, not from this working tree.
set -euo pipefail

KEY=4C92025983552C03                      # "Donny Beelo Releases"
MANIFEST=net.donnybeelo.Convey.yml
APP_ID=net.donnybeelo.Convey
REPO=${1:-$HOME/git/donnybeelo-releases}
ARCH=$(flatpak --default-arch)

cd "$(dirname "$0")/.."

# git cannot track empty directories, so a fresh clone of the release repo
# lacks refs/remotes and friends, and ostree fails with
# "Listing refs: opendir(refs/remotes)".
mkdir -p "$REPO"/{refs/heads,refs/mirrors,refs/remotes,state,extensions,tmp/cache}

flatpak-builder --user --force-clean --disable-rofiles-fuse \
  --repo="$REPO" --gpg-sign="$KEY" --default-branch=stable \
  build-flathub "$MANIFEST"

# The Debug extension is ~3x the app itself and nobody fetches it from a
# personal repo; drop it before the objects get published.
ostree --repo="$REPO" refs --delete "runtime/$APP_ID.Debug/$ARCH/stable" || true

# --prune only drops objects no ref points at, so other apps in the shared
# repo are unaffected.
flatpak build-update-repo "$REPO" \
  --title="Daniel Elia's Flatpaks" \
  --comment="Flatpak releases by Daniel Elia" \
  --homepage="https://donnybeelo.net" \
  --default-branch=stable \
  --generate-static-deltas --prune \
  --gpg-sign="$KEY"

echo
echo "Repo updated: $REPO ($(du -sh "$REPO" | cut -f1))"
echo "index.html, CNAME, .nojekyll and the .flatpakrepo are kept as published;"
echo "add a row to index.html when a new application appears."
echo "Publish with: cd $REPO && git add -A && git commit && git push"
