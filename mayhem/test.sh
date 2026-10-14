#!/usr/bin/env bash
#
# mayhem/test.sh — RUN the esi_gzip_kat binary mayhem/build.sh already built (never compiles here).
#
# esi_gzip_kat (mayhem/harnesses/esi_gzip_kat.cc) gzips two fixed texts through the real EsiGzip
# (plugins/esi/lib/EsiGzip.cc) and asserts, per case, that the call succeeds, the output starts with
# the gzip magic bytes, the downstream length stream_finish reports equals the output size, and zlib
# gunzips it back to exactly the input. Upstream's ESI tests need a running server, so this is the
# assertion-based test for the encoder.
#
# A no-op/`exit(0)` neuter of the binary produces NO markers at all, so this script fails as soon as
# it can't find the expected "match=1" / "failures=0" lines — not just "did it exit 0".
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

KAT_BIN="/mayhem/esi_gzip_kat"
if [ ! -x "$KAT_BIN" ]; then
  echo "MISSING esi_gzip_kat: $KAT_BIN (mayhem/build.sh should have built it)" >&2
  emit_ctrf "trafficserver-esi-gzip-kat" 0 1
  exit 1
fi

out="$("$KAT_BIN" 2>&1)"; rc=$?
echo "=== esi_gzip_kat ===" >&2
echo "$out" >&2

# 2 cases x 4 checks = 8
match_count="$(printf '%s\n' "$out" | grep -c 'match=1' || true)"
summary_line="$(printf '%s\n' "$out" | grep -E '^ESI_GZIP_KAT SUMMARY failures=' | tail -1 || true)"

passed=0
failed=0
if [ "$rc" -eq 0 ] && [ "$summary_line" = "ESI_GZIP_KAT SUMMARY failures=0" ] && [ "${match_count:-0}" -eq 8 ]; then
  passed=8
else
  echo "esi_gzip_kat did not produce the expected passing markers (rc=$rc, matches=${match_count:-0}, summary='${summary_line}')" >&2
  failed=8
fi

emit_ctrf "trafficserver-esi-gzip-kat" "$passed" "$failed"
