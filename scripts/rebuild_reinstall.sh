#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# One-click developer flow:
# - rebuild from local source
# - reinstall binary
# - re-register MCP config for Claude Desktop + Claude Code
"$SCRIPT_DIR/install.sh" --yes "$@"
