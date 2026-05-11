#!/bin/bash

# Fire & Ice Game Start Script
# Checks if port 8009 is in use and kills the process if needed
# Then starts the Flutter web server

set -e

PORT=8009
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "  Fire & Ice Aviation Game Launcher"
echo "========================================="
echo ""

# Kill stale Flutter processes from previous sessions
STALE_PIDS=$(ps aux | grep -E 'flutter.*(run|web-server|web-port)' | grep -v grep | awk '{print $2}' || true)
if [ ! -z "$STALE_PIDS" ]; then
    STALE_COUNT=$(echo "$STALE_PIDS" | wc -w)
    echo "Found $STALE_COUNT stale Flutter process(es), cleaning up..."
    echo "$STALE_PIDS" | xargs kill -9 2>/dev/null || true
    sleep 1
    echo "Stale processes killed"
else
    echo "No stale Flutter processes found"
fi

# Also kill any defunct dart processes from previous flutter runs
DEFUNCT_PIDS=$(ps aux | grep -E 'dart.*(flutter_tool|frontend_server)' | grep -v grep | awk '{print $2}' || true)
if [ ! -z "$DEFUNCT_PIDS" ]; then
    DEFUNCT_COUNT=$(echo "$DEFUNCT_PIDS" | wc -w)
    echo "Found $DEFUNCT_COUNT stale Dart subprocess(es), cleaning up..."
    echo "$DEFUNCT_PIDS" | xargs kill -9 2>/dev/null || true
    sleep 1
    echo "Stale Dart subprocesses killed"
fi

# Check if port 8009 is still in use after cleanup
echo "Checking if port $PORT is available..."
PORT_PID=$(lsof -ti:$PORT 2>/dev/null || echo "")

if [ ! -z "$PORT_PID" ]; then
    echo "Port $PORT is still in use by process $PORT_PID"
    echo "Killing process $PORT_PID..."
    kill -9 $PORT_PID 2>/dev/null || true
    sleep 1
    echo "Process killed successfully"
else
    echo "Port $PORT is available"
fi

echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "Error: Flutter is not installed or not in PATH"
    echo "Please install Flutter from https://docs.flutter.dev/get-started/install"
    exit 1
fi

echo "Flutter version:"
flutter --version | head -n 1

echo ""

# Determine the actual game directory
GAME_DIR="$PROJECT_DIR/fire_and_ice_game"

# Check if we have a Flutter project
if [ ! -f "$GAME_DIR/pubspec.yaml" ]; then
    echo "Error: No Flutter project found at $GAME_DIR"
    exit 1
fi

cd "$GAME_DIR"

# Get Flutter dependencies
echo "Getting Flutter dependencies..."
flutter pub get

echo ""
echo "========================================="
echo "  Starting Fire & Ice on http://localhost:$PORT"
echo "========================================="
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Start Flutter web server on port 8009
flutter run -d web-server --web-port=$PORT --web-hostname=localhost
