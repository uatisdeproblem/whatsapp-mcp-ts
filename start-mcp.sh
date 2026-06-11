#!/bin/bash
# Prevent multiple simultaneous instances of the WhatsApp MCP server.
#
# Claude Desktop sometimes spawns two parallel instances (e.g. a normal chat
# together with a Project Cowork). Both try to connect to WhatsApp as the same
# companion device, producing a "Stream Errored (conflict)" loop. A PID
# lockfile lets only the first instance run; later ones exit cleanly.

# Keep the cwd at the script's directory so ./src/main.ts and ./start-mcp.lock
# resolve correctly regardless of where this is launched from.
cd "$(dirname "$0")"

LOCKFILE="./start-mcp.lock"

# If a lockfile exists, decide whether its owner is still alive.
if [ -f "$LOCKFILE" ]; then
  OTHER_PID=$(cat "$LOCKFILE")
  if kill -0 "$OTHER_PID" 2>/dev/null; then
    # Another instance is genuinely running: bail out with exit 0 so Claude
    # Desktop does NOT treat this as a failure and retry in a loop.
    echo "[whatsapp-mcp] another instance already running (PID $OTHER_PID), exiting" >&2
    exit 0
  fi
  # Stale lockfile (owner is gone): remove it and continue.
  rm -f "$LOCKFILE"
fi

# Claim the lock with our own PID.
echo "$$" > "$LOCKFILE"

# Launch node as a child (not exec) so this shell stays alive to clean up.
/usr/local/bin/node ./src/main.ts &
NODE_PID=$!

# Remove the lockfile on any exit; on Ctrl+C / kill, forward the signal to
# node first so it shuts down cleanly, then let the EXIT trap remove the lock.
trap 'rm -f "$LOCKFILE"' EXIT
trap 'kill -TERM "$NODE_PID" 2>/dev/null' INT TERM

wait "$NODE_PID"
