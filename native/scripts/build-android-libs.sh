#!/bin/sh
# Cross-compiles rapfi_core and pikafish_core as Android .so files (arm64-v8a
# only — covers effectively all real Android devices in use) and drops them
# into the Flutter app's jniLibs directory, where Android's build
# automatically bundles them into the APK.
#
# Not run automatically by `flutter build` — these binaries aren't committed
# to git (same reasoning as the iOS build-ios*/ static libs: rebuild from
# source rather than track compiled output), so run this once after a fresh
# clone (or after native/rapfi, native/pikafish, or native/wrapper change)
# before building for Android.
#
# Requires the Android SDK + NDK (side-by-side package
# "ndk;27.0.12077973", installed here via `brew install --cask
# android-commandlinetools` + `sdkmanager`) — see 开发日志.md 阶段 4 for how
# this was set up.
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WRAPPER_DIR="$ROOT/native/wrapper"
JNI_DIR="$ROOT/app/android/app/src/main/jniLibs/arm64-v8a"

: "${ANDROID_HOME:?Set ANDROID_HOME to the Android SDK root}"
NDK_VERSION=$(ls "$ANDROID_HOME/ndk" | sort -V | tail -1)
NDK="$ANDROID_HOME/ndk/$NDK_VERSION"
[ -d "$NDK" ] || { echo "NDK not found under $ANDROID_HOME/ndk" >&2; exit 1; }

cmake -B "$WRAPPER_DIR/build-android" \
    -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-24 \
    -DCMAKE_BUILD_TYPE=Release \
    "$WRAPPER_DIR"

cmake --build "$WRAPPER_DIR/build-android" --target rapfi_core pikafish_core -j

mkdir -p "$JNI_DIR"
cp "$WRAPPER_DIR/build-android/librapfi_core.so" "$JNI_DIR/"
cp "$WRAPPER_DIR/build-android/libpikafish_core.so" "$JNI_DIR/"
echo "Copied librapfi_core.so and libpikafish_core.so to $JNI_DIR"
