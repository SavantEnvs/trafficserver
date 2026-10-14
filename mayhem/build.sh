#!/usr/bin/env bash
#
# mayhem/build.sh — build the ESI gzip encoder harness (mayhem/harnesses/fuzz_esi_gzip.cc) against
# plugins/esi/lib/EsiGzip.cc, plus its known-answer test for mayhem/test.sh.
#
# The ESI parser harness upstream ships (tests/fuzzing/fuzz_esi.cc) is disabled in its CMake and never
# reaches the gzip encoder, so this layer adds its own. EsiGzip.cc needs only zlib and the plugin API
# header (TSError is stubbed in mayhem/harnesses/ts_stub.cc), so it is compiled directly, with the
# fuzz and test builds kept apart. No network access is needed.
#
# Build contract (base image ENV): CC, CXX, LIB_FUZZING_ENGINE, SANITIZER_FLAGS, DEBUG_FLAGS, SRC,
# STANDALONE_FUZZ_MAIN.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer -g}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${SRC:=/mayhem}"
: "${STANDALONE_FUZZ_MAIN:=/opt/mayhem/StandaloneFuzzTargetMain.c}"

cd "$SRC"

BUILD="$SRC/mayhem-build"
GEN="$BUILD/gen"
rm -rf "$BUILD"
mkdir -p "$GEN/ts"

# ts/ts.h includes the generated ts/apidefs.h; cmake fills in the version only. Only the declarations
# are used, so any version will do.
sed -e 's/@TS_VERSION_STRING@/0.0.0/' -e 's/@TS_VERSION_NUMBER@/0/' \
    -e 's/@TS_VERSION_MAJOR@/0/' -e 's/@TS_VERSION_MINOR@/0/' -e 's/@TS_VERSION_MICRO@/0/' \
    include/ts/apidefs.h.in > "$GEN/ts/apidefs.h"

INCLUDES=(-I"$GEN" -I"$SRC/include" -I"$SRC/lib/swoc/include" -I"$SRC/plugins/esi/lib" -I"$SRC/plugins/esi/common")
CXXFLAGS=(-std=c++20 "${INCLUDES[@]}")
ESI_SRC="$SRC/plugins/esi/lib/EsiGzip.cc"
H="$SRC/mayhem/harnesses"

# 1) Sanitized libFuzzer harness. The fuzzed library code carries the coverage and sanitizer flags too.
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/lsan_off.c" -o "$BUILD/lsan_off.o"
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$BUILD/standalone_main.o"
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link "${CXXFLAGS[@]}" \
  -c "$H/fuzz_esi_gzip.cc" -o "$BUILD/fuzz_esi_gzip.o"
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link "${CXXFLAGS[@]}" \
  -c "$ESI_SRC" -o "$BUILD/EsiGzip.o"
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS "${CXXFLAGS[@]}" -c "$H/ts_stub.cc" -o "$BUILD/ts_stub.o"
# ts/ts.h's DbgCtl.h pulls in libswoc, so build its sources in as well.
SWOC_OBJS=()
for f in "$SRC"/lib/swoc/src/*.cc; do
  o="$BUILD/swoc_$(basename "$f" .cc).o"
  $CXX $SANITIZER_FLAGS $DEBUG_FLAGS "${CXXFLAGS[@]}" -c "$f" -o "$o"
  SWOC_OBJS+=("$o")
done

OBJS=("$BUILD/fuzz_esi_gzip.o" "$BUILD/EsiGzip.o" "$BUILD/ts_stub.o" "${SWOC_OBJS[@]}" "$BUILD/lsan_off.o")
$CXX $SANITIZER_FLAGS "${OBJS[@]}" $LIB_FUZZING_ENGINE -lz -o "$SRC/fuzz_esi_gzip"
# 2) Standalone reproducer: the same objects with LLVM's run-once driver instead of libFuzzer.
$CXX $SANITIZER_FLAGS "${OBJS[@]}" "$BUILD/standalone_main.o" -lz -o "$SRC/fuzz_esi_gzip-standalone"

# 3) Known-answer test for mayhem/test.sh: plain flags, no sanitizers.
$CXX -O1 $DEBUG_FLAGS "${CXXFLAGS[@]}" "$H/esi_gzip_kat.cc" "$ESI_SRC" "$H/ts_stub.cc" "$SRC"/lib/swoc/src/*.cc -lz -o "$SRC/esi_gzip_kat"

echo "build.sh complete:"
ls -la "$SRC/fuzz_esi_gzip" "$SRC/fuzz_esi_gzip-standalone" "$SRC/esi_gzip_kat"
