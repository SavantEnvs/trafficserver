// Drives the ESI plugin's gzip encoder (plugins/esi/lib/EsiGzip.cc), which upstream's own
// tests/fuzzing/fuzz_esi.cc never reaches. The fuzz bytes are tiled into a 1 MiB block, and the
// first byte picks how many times that block is fed through EsiGzip::stream_encode (1 << shift).
// ESI handles whole response bodies, so a multi-GiB stream is the case that exercises the encoder's
// cumulative byte counters.
#include <cstdint>
#include <cstring>
#include <string>

#include "EsiGzip.h"

namespace
{
constexpr size_t kMaxInput = 1025;
constexpr size_t kBlock    = 1 << 20;
constexpr int    kMaxShift = 12;

// stream_finish() reports the downstream length as int& or int64_t& depending on the revision.
template <typename G>
bool
finish(G &gz, std::string &out)
{
  if constexpr (requires(int64_t &len) { gz.stream_finish(out, len); }) {
    int64_t len = 0;
    return gz.stream_finish(out, len);
  } else {
    int len = 0;
    return gz.stream_finish(out, len);
  }
}
} // namespace

extern "C" int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  if (size < 2 || size > kMaxInput) {
    return -1;
  }

  const unsigned reps  = 1u << (data[0] % (kMaxShift + 1));
  const size_t   chunk = size - 1;

  std::string block(kBlock, '\0');
  for (size_t i = 0; i < kBlock; i += chunk) {
    memcpy(block.data() + i, data + 1, chunk < kBlock - i ? chunk : kBlock - i);
  }

  EsiGzip     gz;
  std::string out;
  for (unsigned i = 0; i < reps; ++i) {
    if (!gz.stream_encode(block.data(), static_cast<int>(block.size()), out)) {
      return 0;
    }
  }
  finish(gz, out);
  return 0;
}
