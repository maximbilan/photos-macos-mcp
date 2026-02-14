#!/bin/bash
# Wrapper to run PhotosMCP and log any errors for debugging
LOGFILE="${TMPDIR:-/tmp}/photos-mcp.log"
exec 2>>"$LOGFILE"
echo "--- PhotosMCP started $(date) ---" >>"$LOGFILE"
exec "/Users/max/Developer/photos-macos-mcp/.build/release/PhotosMCP" "$@"
