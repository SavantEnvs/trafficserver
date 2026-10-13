# BASE predates upstream's `if(TS_USE_QUIC OR TS_USE_QMUX)` around src/iocore/net/quic, so with
# QUIC off nothing defines ts::quic, yet tests/fuzzing/CMakeLists.txt links fuzz_http3frame to it
# unconditionally and generation fails. An empty INTERFACE target satisfies that link; fuzz_http3frame
# itself is never built.
if(NOT TARGET ts::quic)
  add_library(mayhem_quic_stub INTERFACE)
  add_library(ts::quic ALIAS mayhem_quic_stub)
endif()
