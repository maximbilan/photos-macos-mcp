#!/usr/bin/env bash
set -euo pipefail

BIN_NAME="PhotosMCP"
SERVER_NAME="${PHOTOS_MCP_SERVER_NAME:-photos}"
INSTALL_DIR="${PHOTOS_MCP_INSTALL_DIR:-$HOME/.local/bin}"
CLAUDE_SCOPE="${PHOTOS_MCP_CLAUDE_SCOPE:-user}"
CLAUDE_DESKTOP_CONFIG_DEFAULT="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

SKIP_CLAUDE_DESKTOP=0
SKIP_CLAUDE_CODE=0
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

Build and install ${BIN_NAME}, then register it with Claude Desktop/Claude Code.

Options:
  --name <server-name>       MCP server name in config (default: ${SERVER_NAME})
  --install-dir <dir>        Install directory for binary (default: ${INSTALL_DIR})
  --scope <scope>            Claude Code scope: local|user|project (default: ${CLAUDE_SCOPE})
  --skip-claude-desktop      Do not edit Claude Desktop config
  --skip-claude-code         Do not run 'claude mcp add'
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

build_binary() {
  local repo_root="$1"
  command -v swift >/dev/null 2>&1 || fail "Swift is required to build from source."

  log "Building ${BIN_NAME}..."
  swift build -c release --package-path "$repo_root"
}

install_binary() {
  local repo_root="$1"
  local source_bin="$repo_root/.build/release/$BIN_NAME"

  [[ -x "$source_bin" ]] || fail "Build output not found: $source_bin"
  mkdir -p "$INSTALL_DIR"
  install -m 0755 "$source_bin" "$INSTALL_DIR/$BIN_NAME"
  log "Installed $INSTALL_DIR/$BIN_NAME"
}

configure_claude_desktop() {
  local target_bin="$1"
  local config_path="${CLAUDE_DESKTOP_CONFIG:-$CLAUDE_DESKTOP_CONFIG_DEFAULT}"

  command -v python3 >/dev/null 2>&1 || {
    log "Skipping Claude Desktop config update (python3 not found)."
    return 0
  }

  mkdir -p "$(dirname "$config_path")"
  python3 - "$config_path" "$SERVER_NAME" "$target_bin" <<'PY'
import json
import os
import sys

config_path, server_name, command_path = sys.argv[1:4]

config = {}
if os.path.exists(config_path):
    with open(config_path, "r", encoding="utf-8") as f:
        raw = f.read().strip()
    if raw:
        config = json.loads(raw)

if not isinstance(config, dict):
    raise SystemExit(f"Config root must be an object: {config_path}")

mcp_servers = config.get("mcpServers")
if not isinstance(mcp_servers, dict):
    mcp_servers = {}

mcp_servers[server_name] = {"command": command_path, "args": []}
config["mcpServers"] = mcp_servers

with open(config_path, "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PY

  log "Updated Claude Desktop config: $config_path"
}

configure_claude_code() {
  local target_bin="$1"
  if ! command -v claude >/dev/null 2>&1; then
    log "Skipping Claude Code registration (claude CLI not found)."
    return 0
  fi

  case "$CLAUDE_SCOPE" in
    local|user|project) ;;
    *) fail "Invalid scope '$CLAUDE_SCOPE'. Use: local|user|project" ;;
  esac

  claude mcp remove --scope "$CLAUDE_SCOPE" "$SERVER_NAME" >/dev/null 2>&1 || true
  claude mcp add --scope "$CLAUDE_SCOPE" "$SERVER_NAME" -- "$target_bin"
  log "Registered server in Claude Code (scope: $CLAUDE_SCOPE)."
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
      --skip-claude-desktop)
        SKIP_CLAUDE_DESKTOP=1
        shift
        ;;
      --skip-claude-code)
        SKIP_CLAUDE_CODE=1
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
  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  parse_args "$@"

  build_binary "$repo_root"
  install_binary "$repo_root"

  if confirm_default_yes "Register with detected Claude clients? [Y/n]: "; then
    if [[ "$SKIP_CLAUDE_DESKTOP" -eq 0 ]]; then
      configure_claude_desktop "$INSTALL_DIR/$BIN_NAME"
    fi
    if [[ "$SKIP_CLAUDE_CODE" -eq 0 ]]; then
      configure_claude_code "$INSTALL_DIR/$BIN_NAME"
    fi
  else
    log "Skipping client registration."
  fi

  log "Install complete."
}

main "$@"
