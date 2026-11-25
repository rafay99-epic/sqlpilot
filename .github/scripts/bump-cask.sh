#!/bin/bash
# Points the sqlpilot cask in rafay99-epic/homebrew-apps at a freshly published
# release: rewrites its version and sha256 and pushes to the tap's main. On the
# first release, adds the cask from packaging/homebrew/sqlpilot.rb. Adapted from
# Vitals' bump-cask.sh.
#
#   VERSION=0.42 TAP_TOKEN=... .github/scripts/bump-cask.sh /abs/path/SQLPilot.dmg
#
# TAP_TOKEN: fine-grained PAT with Contents: Read & Write on homebrew-apps.
set -euo pipefail

VERSION="${VERSION:?VERSION env var required}"
DMG="${1:?path to the .dmg required}"
: "${TAP_TOKEN:?TAP_TOKEN env var required}"
CASK=sqlpilot
TEMPLATE="$(cd "$(dirname "$0")/../.." && pwd)/packaging/homebrew/$CASK.rb"

SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
echo "Bumping $CASK cask to $VERSION ($SHA)"

REMOTE="https://x-access-token:${TAP_TOKEN}@github.com/rafay99-epic/homebrew-apps.git"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
git clone --quiet "$REMOTE" "$WORK"
cd "$WORK"

CASK_FILE="Casks/$CASK.rb"
[ -f "$CASK_FILE" ] || cp "$TEMPLATE" "$CASK_FILE"
# Only the two pinned lines in the top stanza (2-space indent). BSD sed.
sed -i '' -E \
  -e "s|^  version \"[^\"]*\"|  version \"$VERSION\"|" \
  -e "s|^  sha256 \"[0-9a-f]*\"|  sha256 \"$SHA\"|" \
  "$CASK_FILE"

if git diff --quiet -- "$CASK_FILE" && git ls-files --error-unmatch "$CASK_FILE" >/dev/null 2>&1; then
  echo "::notice::$CASK cask already at $VERSION."
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add "$CASK_FILE"
git commit --quiet -m "$CASK $VERSION"

# Sibling repos push to the same tap; re-sync and retry on a race.
for attempt in 1 2 3 4 5; do
  if git push --quiet "$REMOTE" HEAD:main 2>/dev/null; then
    echo "::notice::Pushed $CASK $VERSION to the homebrew-apps tap."
    exit 0
  fi
  echo "Push rejected (attempt $attempt), rebasing on the tap's main..."
  git pull --quiet --rebase "$REMOTE" main
done
echo "::error::Could not push the $CASK cask bump after 5 attempts."
exit 1
