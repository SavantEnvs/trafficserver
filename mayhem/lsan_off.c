/*
 * mayhem/lsan_off.c - the sanctioned build-time LeakSanitizer off-switch (SPEC §6.2 item 15).
 *
 * Turns off ONLY the leak check at exit; ASan and UBSan stay fully active. Compiled once by
 * mayhem/build.sh with the same sanitizer flags as the targets and appended to
 * CMAKE_EXE_LINKER_FLAGS, so it is linked into every sanitized binary the harness ships:
 * fuzz_hpack, fuzz_http, fuzz_json, fuzz_proxy_protocol, fuzz_rec_http, fuzz_yamlcpp, their six
 * *-standalone reproducers, and the (also ASan-built) http_kat_test oracle.
 */
int __lsan_is_turned_off(void) { return 1; }
