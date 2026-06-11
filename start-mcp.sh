#!/bin/bash
# Ensure a single WhatsApp MCP server instance, with a "take-over" model.
#
# WhatsApp allows only one active companion-device connection. With Claude Code
# we always want the NEWEST session to win: when a window is closed (sometimes
# without terminating the spawned node process) the old instance can survive as
# an orphan holding the connection. So on launch, if a previous instance is
# still alive, we terminate it and take over — this makes restart/Reconnect
# always succeed.
#
# Trade-off: opening two Claude Code windows on this project at once would make
# them supersede each other. That's acceptable — you can't have two WhatsApp
# companion connections anyway.

cd "$(dirname "$0")"

LOCKFILE="./start-mcp.lock"

# If a previous instance is recorded and still alive, supersede it.
if [ -f "$LOCKFILE" ]; then
  OTHER_PID=$(cat "$LOCKFILE")
  if kill -0 "$OTHER_PID" 2>/dev/null; then
    echo "[whatsapp-mcp] superseding previous instance (PID $OTHER_PID)" >&2
    kill "$OTHER_PID" 2>/dev/null
    # give it a moment to release the WhatsApp connection, then force-kill
    for i in 1 2 3 4 5; do kill -0 "$OTHER_PID" 2>/dev/null || break; sleep 1; done
    kill -9 "$OTHER_PID" 2>/dev/null
  fi
  rm -f "$LOCKFILE"
fi

# Claim the lock. We write node's PID (not the wrapper's): `exec` replaces this
# shell with node — same PID — so when node dies the lockfile points to a dead
# PID and the stale-cleanup above removes it on next launch.
echo "$$" > "$LOCKFILE"

# Use exec so node inherits stdin/stdout DIRECTLY from Claude Code.
# This is essential for the MCP stdio protocol: any shell sitting between the
# client and node would break JSON-RPC message passing.
exec /usr/local/bin/node ./src/main.ts
