#!/usr/bin/env bash
set -euo pipefail

BIN_NAME="PhotosMCP"
SERVER_NAME="${PHOTOS_MCP_SERVER_NAME:-photos}"
INSTALL_DIR="${PHOTOS_MCP_INSTALL_DIR:-$HOME/.local/bin}"
CLAUDE_SCOPE="${PHOTOS_MCP_CLAUDE_SCOPE:-user}"
CLAUDE_DESKTOP_CONFIG_DEFAULT="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

REMOVE_BINARY=1
REMOVE_CLAUDE_DESKTOP=1
REMOVE_CLAUDE_CODE=1
AUTO_YES=0

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Unregister PhotosMCP from Claude clients and remove installed binary.

Options:
  --name <server-name>       MCP server name in config (default: ${SERVER_NAME})
  --install-dir <dir>        Install directory for binary (default: ${INSTALL_DIR})
  --scope <scope>            Claude Code scope: local|user|project (default: ${CLAUDE_SCOPE})
  --keep-binary              Do not remove installed binary
  --skip-claude-desktop      Do not edit Claude Desktop config
  --skip-claude-code         Do not run 'claude mcp remove'
  -y, --yes                  Skip confirmation prompts
  -h, --help                 Show this help

Env vars:
  PHOTOS_MCP_SERVER_NAME
  PHOTOS_MCP_INSTALL_DIR
  PHOTOS_MCP_CLAUDE_SCOPE
  CLAUDE_DESKTOP_CONFIG
EOF
}

confirm_default_yes() {
  local prompt="$1"
  local input=""

  if [[ "$AUTO_YES" -eq 1 ]]; then
    return 0
  fi

  if [[ -r /dev/tty ]]; then
    printf '%s' "$prompt" > /dev/tty
    IFS= read -r input < /dev/tty || true
  elif [[ -t 0 ]]; then
    printf '%s' "$prompt"
    IFS= read -r input || true
  else
    return 0
  fi

  case "$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')" in
    ""|y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

remove_from_claude_desktop() {
  local config_path="${CLAUDE_DESKTOP_CONFIG:-$CLAUDE_DESKTOP_CONFIG_DEFAULT}"
  [[ -f "$config_path" ]] || {
    log "Claude Desktop config not found, skipping: $config_path"
    return 0
  }

  command -v python3 >/dev/null 2>&1 || {
    log "Skipping Claude Desktop config update (python3 not found)."
    return 0
  }

  python3 - "$config_path" "$SERVER_NAME" <<'PY'
import json
import sys

config_path, server_name = sys.argv[1:3]
with open(config_path, "r", encoding="utf-8") as f:
    raw = f.read().strip()
if not raw:
    raise SystemExit(0)

config = json.loads(raw)
if not isinstance(config, dict):
    raise SystemExit(f"Config root must be an object: {config_path}")

mcp_servers = config.get("mcpServers")
if isinstance(mcp_servers, dict) and server_name in mcp_servers:
    del mcp_servers[server_name]
    config["mcpServers"] = mcp_servers
    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2)
        f.write("\n")
PY

  log "Removed '${SERVER_NAME}' from Claude Desktop config."
}

remove_from_claude_code() {
  if ! command -v claude >/dev/null 2>&1; then
    log "Skipping Claude Code unregistration (claude CLI not found)."
    return 0
  fi

  case "$CLAUDE_SCOPE" in
    local|user|project) ;;
    *) fail "Invalid scope '$CLAUDE_SCOPE'. Use: local|user|project" ;;
  esac

  claude mcp remove --scope "$CLAUDE_SCOPE" "$SERVER_NAME" >/dev/null 2>&1 || true
  log "Removed '${SERVER_NAME}' from Claude Code (scope: $CLAUDE_SCOPE)."
}

remove_binary() {
  local target="$INSTALL_DIR/$BIN_NAME"
  if [[ -f "$target" ]]; then
    rm -f "$target"
    log "Removed binary: $target"
  else
    log "Binary not found, skipping: $target"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)
        SERVER_NAME="$2"
        shift 2
        ;;
      --install-dir)
        INSTALL_DIR="$2"
        shift 2
        ;;
      --scope)
        CLAUDE_SCOPE="$2"
        shift 2
        ;;
      --keep-binary)
        REMOVE_BINARY=0
        shift
        ;;
      --skip-claude-desktop)
        REMOVE_CLAUDE_DESKTOP=0
        shift
        ;;
      --skip-claude-code)
        REMOVE_CLAUDE_CODE=0
        shift
        ;;
      -y|--yes)
        AUTO_YES=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "Unknown argument: $1"
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  if ! confirm_default_yes "Uninstall '${SERVER_NAME}' from local clients and remove binary? [Y/n]: "; then
    log "Cancelled."
    exit 0
  fi

  if [[ "$REMOVE_CLAUDE_DESKTOP" -eq 1 ]]; then
    remove_from_claude_desktop
  fi
  if [[ "$REMOVE_CLAUDE_CODE" -eq 1 ]]; then
    remove_from_claude_code
  fi
  if [[ "$REMOVE_BINARY" -eq 1 ]]; then
    remove_binary
  fi

  log "Uninstall complete."
}

main "$@"
