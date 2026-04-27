#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

PIDFILE="$REPO_DIR/.hablotengo_emulator.pid"
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping hablotengo emulator (PID $PID)..."
        kill "$PID"
        for i in {1..5}; do
            if ! kill -0 "$PID" 2>/dev/null; then break; fi
            sleep 1
        done
        if kill -0 "$PID" 2>/dev/null; then kill -9 "$PID"; fi
    fi
    rm "$PIDFILE"
else
    echo "No PID file found. Is the emulator running?"
fi

# Kill any stale java processes holding our ports (8082, 9152)
for PORT in 8082 9152; do
    JAVA_PID=$(lsof -ti :"$PORT" 2>/dev/null)
    if [ -n "$JAVA_PID" ]; then
        echo "Killing stale process on port $PORT (PID $JAVA_PID)..."
        kill "$JAVA_PID" 2>/dev/null
    fi
done
