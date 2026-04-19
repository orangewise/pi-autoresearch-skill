#!/usr/bin/env bash
# Copy the autoresearch helper scripts into the current project so paths in
# autoresearch.md are project-relative and portable across machines and CI.
#
# Typical invocation from within Claude Code (where CLAUDE_PLUGIN_ROOT is set):
#   bash "${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/scripts/install-into-project.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p scripts/autoresearch
cp "$SCRIPT_DIR/log.sh"            scripts/autoresearch/log.sh
cp "$SCRIPT_DIR/results.sh"        scripts/autoresearch/results.sh
cp "$SCRIPT_DIR/bench-template.sh" scripts/autoresearch/bench-template.sh
chmod +x scripts/autoresearch/*.sh

echo "✅ autoresearch scripts installed at scripts/autoresearch/"
echo "   - scripts/autoresearch/log.sh"
echo "   - scripts/autoresearch/results.sh"
echo "   - scripts/autoresearch/bench-template.sh"
echo ""
echo "Commit these so future sessions on other machines have everything they need:"
echo "   git add scripts/autoresearch && git commit -m 'add autoresearch helper scripts'"
