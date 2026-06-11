#!/bin/bash
# Prevent multiple simultaneous instances of the WhatsApp MCP server.
#
# Claude Desktop sometimes spawns two parallel instances (e.g. a normal chat
# together with a Project Cowork). Both try to connect to WhatsApp as the same
# companion device, producing a "Stream Errored (conflict)" loop. A PID
# lockfile lets only the first instance run; later ones exit cleanly.

cd "$(dirname "$0")"

LOCKFILE="./start-mcp.lock"

# If a lockfile exists, decide whether its owner is still alive.
if [ -f "$LOCKFILE" ]; then
  OTHER_PID=$(cat "$LOCKFILE")
  if kill -0 "$OTHER_PID" 2>/dev/null; then
    echo "[whatsapp-mcp] another instance already running (PID $OTHER_PID), exiting" >&2
    exit 0
  fi
  rm -f "$LOCKFILE"
fi

# Claim the lock. We write node's PID (not the wrapper's), so that when node
# dies the lockfile naturally points to a dead PID and the stale-cleanup above
# removes it on next launch. We can do this because `exec` replaces the
# current shell with node — same PID.
echo "$$" > "$LOCKFILE"

# Use exec so node inherits stdin/stdout DIRECTLY from Claude Desktop.
# This is essential for MCP stdio protocol: any shell sitting between Claude
# and node would break JSON-RPC message passing.
exec /usr/local/bin/node ./src/main.ts
