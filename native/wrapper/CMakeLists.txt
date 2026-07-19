# Builds the Rapfi engine core (without its CLI main) plus the C bridge as a
# static library, and a plain-C test executable used by step 0.4's acceptance
# check. The same rapfi_core target is what the iOS app links against later.
cmake_minimum_required(VERSION 3.18)
project(rapfi_bridge CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(RAPFI_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../rapfi/Rapfi)

# CORE_SOURCES from Rapfi's own CMakeLists.txt, minus main.cpp (we provide our
# own entry) and minus the optional command modules (tuning/selfplay/... need
# extra external deps and are CLI-only).
set(RAPFI_CORE_SOURCES
    command/argutils.cpp
    command/benchmark.cpp
    command/command.cpp
    command/gomocup.cpp
    core/compressor.cpp
    core/hash.cpp
    core/iohelper.cpp
    core/utils.cpp
    core/platform.cpp
    core/version.cpp
    database/dbclient.cpp
    database/dbutils.cpp
    database/dbtypes.cpp
    database/yxdbstorage.cpp
    eval/eval.cpp
    eval/evaluator.cpp
    eval/mix9svqnnue.cpp
    eval/mix10nnue.cpp
    game/board.cpp
    game/movegen.cpp
    game/pattern.cpp
    search/hashtable.cpp
    search/movepick.cpp
    search/opening.cpp
    search/searchcommon.cpp
    search/searchoutput.cpp
    search/searchthread.cpp
    search/timecontrol.cpp
    search/ab/history.cpp
    search/ab/search.cpp
    search/mcts/node.cpp
    search/mcts/search.cpp
    config.cpp
    internalConfig.cpp
)
list(TRANSFORM RAPFI_CORE_SOURCES PREPEND ${RAPFI_DIR}/)

add_subdirectory(${RAPFI_DIR}/external/cpptoml cpptoml)
add_subdirectory(${RAPFI_DIR}/external/cxxopts cxxopts)
add_subdirectory(${RAPFI_DIR}/external/lz4 lz4)
add_subdirectory(${RAPFI_DIR}/external/simde simde)

add_library(rapfi_core STATIC ${RAPFI_CORE_SOURCES} rapfi_bridge.cpp)
target_include_directories(rapfi_core
    PRIVATE ${RAPFI_DIR}
    PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(rapfi_core PRIVATE cpptoml cxxopts lz4 simde)

if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64"
   OR CMAKE_OSX_ARCHITECTURES MATCHES "arm64"
   OR CMAKE_SYSTEM_NAME STREQUAL "iOS")
    target_compile_definitions(rapfi_core PRIVATE USE_NEON)
endif()

add_executable(bridge_test test_main.c)
target_link_libraries(bridge_test PRIVATE rapfi_core)

# --- Pikafish (Xiangqi engine, UCI) -----------------------------------------
# Same idea as rapfi_core: list Pikafish's own source files directly (minus
# main.cpp, which pikafish_bridge.cpp replaces) rather than using its
# Makefile, and minus the x86-64 zstd assembly fast path (huf_decompress_amd64.S
# — irrelevant on arm64, and compiles to an empty translation unit on non-ELF
# platforms anyway per its own __ELF__ guard, so excluding it outright is simpler).
set(PIKAFISH_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../pikafish/src)

file(GLOB_RECURSE PIKAFISH_ALL_SOURCES CONFIGURE_DEPENDS ${PIKAFISH_DIR}/*.cpp)
list(FILTER PIKAFISH_ALL_SOURCES EXCLUDE REGEX "/(main|universal)/|/main\\.cpp$")

add_library(pikafish_core STATIC ${PIKAFISH_ALL_SOURCES} pikafish_bridge.cpp)
target_include_directories(pikafish_core
    PRIVATE ${PIKAFISH_DIR}
    PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_features(pikafish_core PRIVATE cxx_std_17)
# Matches upstream's own Makefile flags (CXXFLAGS): built without exceptions.
target_compile_options(pikafish_core PRIVATE -fno-exceptions)
# We bypass Pikafish's own Makefile (same reasoning as rapfi_core above), so
# its arch-derived defines have to be set by hand. These match what its
# Makefile computes for `ARCH=apple-silicon` (bits=64, popcnt=yes, neon=yes,
# arm_version=8) — the right baseline for arm64 macOS/iOS device/simulator.
# `dotprod=yes` (-march=armv8.2-a+dotprod) is deliberately left off for now:
# it needs -march support we haven't verified across the iOS toolchain/
# simulator, and NEON alone is enough to get a working build first.
target_compile_definitions(pikafish_core PRIVATE IS_64BIT USE_POPCNT USE_NEON=8)

add_executable(pikafish_bridge_test pikafish_test_main.c)
target_link_libraries(pikafish_bridge_test PRIVATE pikafish_core)
