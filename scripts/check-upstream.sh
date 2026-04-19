#!/usr/bin/env bash
# Check upstream davebcn87/pi-autoresearch for commits since our pinned SHA.
# Exits 0 if in sync, 1 if there are new commits to consider porting.
#
# Usage:
#   bash scripts/check-upstream.sh         # human-readable report
#   bash scripts/check-upstream.sh --ci    # machine-readable (for GitHub Actions)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_URL="https://github.com/davebcn87/pi-autoresearch"

# Extract pinned SHA from UPSTREAM.md (the single source of truth).
PINNED_SHA=$(grep -E '^\| Pinned commit \|' "$ROOT/UPSTREAM.md" \
  | sed -E 's/.*`([a-f0-9]+)`.*/\1/')

if [ -z "$PINNED_SHA" ]; then
  echo "error: could not extract pinned SHA from UPSTREAM.md" >&2
  exit 2
fi

MODE="${1:-human}"

# Fetch upstream HEAD without cloning the full repo.
UPSTREAM_HEAD=$(git ls-remote "$UPSTREAM_URL" HEAD | awk '{print $1}')

if [ -z "$UPSTREAM_HEAD" ]; then
  echo "error: could not fetch upstream HEAD from $UPSTREAM_URL" >&2
  exit 2
fi

if [ "$PINNED_SHA" = "$UPSTREAM_HEAD" ]; then
  if [ "$MODE" = "--ci" ]; then
    echo "in_sync=true"
    echo "pinned=$PINNED_SHA"
    echo "upstream=$UPSTREAM_HEAD"
  else
    echo "✅ in sync with upstream ($PINNED_SHA)"
  fi
  exit 0
fi

# Out of sync — shallow-clone and list commits between pinned and HEAD.
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

git clone --quiet --filter=blob:none "$UPSTREAM_URL" "$TMPDIR/upstream"
cd "$TMPDIR/upstream"

# Guard: pinned SHA may have been force-pushed away.
if ! git cat-file -e "$PINNED_SHA" 2>/dev/null; then
  if [ "$MODE" = "--ci" ]; then
    echo "in_sync=false"
    echo "error=pinned_sha_not_found"
    echo "pinned=$PINNED_SHA"
    echo "upstream=$UPSTREAM_HEAD"
  else
    echo "⚠️  pinned SHA $PINNED_SHA not found in upstream (force-push?)"
    echo "    upstream HEAD: $UPSTREAM_HEAD"
  fi
  exit 1
fi

COMMIT_COUNT=$(git rev-list --count "$PINNED_SHA..$UPSTREAM_HEAD")

if [ "$MODE" = "--ci" ]; then
  echo "in_sync=false"
  echo "pinned=$PINNED_SHA"
  echo "upstream=$UPSTREAM_HEAD"
  echo "new_commits=$COMMIT_COUNT"
  echo "---log---"
  git log --oneline "$PINNED_SHA..$UPSTREAM_HEAD"
  echo "---files---"
  git diff --name-only "$PINNED_SHA..$UPSTREAM_HEAD"
  exit 1
fi

echo "🔔 upstream has $COMMIT_COUNT new commit(s) since $PINNED_SHA"
echo ""
echo "Commits:"
git log --oneline "$PINNED_SHA..$UPSTREAM_HEAD" | sed 's/^/  /'
echo ""
echo "Files changed:"
git diff --name-only "$PINNED_SHA..$UPSTREAM_HEAD" | sed 's/^/  /'
echo ""
echo "To review in detail:"
echo "  open ${UPSTREAM_URL}/compare/${PINNED_SHA}...${UPSTREAM_HEAD}"
exit 1
