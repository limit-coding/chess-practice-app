#!/bin/sh
# Downloads Pikafish's NNUE network file (not in git: ~50MB binary, fetched
# on demand instead — see 开发日志.md 阶段 4). Needed before building the app
# (declared as a Flutter asset in app/pubspec.yaml) and handy for native
# smoke-testing (native/wrapper/pikafish_test_main.c looks for it in its cwd).
set -eu

URL="https://github.com/official-pikafish/Networks/releases/download/master-net/pikafish.nnue"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEST="$ROOT/app/assets/pikafish.nnue"

mkdir -p "$(dirname "$DEST")"

if [ -f "$DEST" ]; then
    echo "Already have $DEST, skipping download"
else
    echo "Downloading $URL -> $DEST"
    curl -sL --max-time 300 -o "$DEST" "$URL"
fi

# native/wrapper smoke tests run with that directory as cwd.
ln -f "$DEST" "$ROOT/native/wrapper/pikafish.nnue"
