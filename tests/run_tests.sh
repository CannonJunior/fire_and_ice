#!/usr/bin/env bash
# run_tests.sh — Run the Fire & Ice cockpit UI Playwright test suite.
#
# Usage:
#   ./tests/run_tests.sh [--headed]
#
# Prerequisites:
#   pip install playwright
#   playwright install chromium
#
# The game must be running at http://localhost:8009.
# Start it with:  ./start.sh  (from the repo root)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

PYTHON="${PYTHON:-python3}"
TEST_FILE="$SCRIPT_DIR/test_cockpit_ui.py"
SCREENSHOT_DIR="/tmp/test_screenshots"

# ── Preflight checks ───────────────────────────────────────────────────────────

echo "========================================================"
echo "  Fire & Ice — Cockpit UI Test Suite"
echo "========================================================"
echo ""

# Check Python
if ! command -v "$PYTHON" &>/dev/null; then
    echo "ERROR: python3 not found. Install Python 3.8+."
    exit 1
fi

# Check Playwright installed
if ! "$PYTHON" -c "import playwright" 2>/dev/null; then
    echo "Playwright not found. Installing..."
    "$PYTHON" -m pip install playwright
    "$PYTHON" -m playwright install chromium
fi

# Soft-check that the server is reachable (non-fatal; game may need a moment)
echo -n "Checking http://localhost:8009 ... "
if curl -sf --max-time 5 http://localhost:8009 > /dev/null 2>&1; then
    echo "OK"
else
    echo "WARNING: server did not respond. Tests may fail on T01."
    echo "  Start the game first:  ./start.sh"
fi

echo ""
echo "Screenshots will be saved to: $SCREENSHOT_DIR"
echo ""

# ── Run ────────────────────────────────────────────────────────────────────────

"$PYTHON" "$TEST_FILE" "$@"
EXIT_CODE=$?

echo ""
echo "Screenshots:"
ls -lh "$SCREENSHOT_DIR"/*.png 2>/dev/null || echo "  (none)"

exit $EXIT_CODE
