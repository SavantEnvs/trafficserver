// Known-answer test for plugins/esi/lib/EsiGzip.cc, run by mayhem/test.sh. Each case gzips fixed
// text in two pieces through EsiGzip, then checks the stream's framing and decompresses it with
// zlib to compare against the original bytes.
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>

#include <zlib.h>

#include "EsiGzip.h"

template <typename G>
bool
finish(G &gz, std::string &out, int64_t &len)
{
  if constexpr (requires(int64_t &l) { gz.stream_finish(out, l); }) {
    return gz.stream_finish(out, len);
  } else {
    int l = 0;
    bool ok = gz.stream_finish(out, l);
    len = l;
    return ok;
  }
}

static int failures = 0;

static void
check(const char *name, bool ok)
{
  printf("KAT %s match=%d\n", name, ok ? 1 : 0);
  if (!ok) {
    ++failures;
  }
}

static bool
gunzip(const std::string &in, std::string &out)
{
  z_stream zs;
  memset(&zs, 0, sizeof(zs));
  if (inflateInit2(&zs, MAX_WBITS + 16) != Z_OK) {
    return false;
  }
  zs.next_in  = reinterpret_cast<Bytef *>(const_cast<char *>(in.data()));
  zs.avail_in = in.size();
  char buf[4096];
  int  rc;
  do {
    zs.next_out  = reinterpret_cast<Bytef *>(buf);
    zs.avail_out = sizeof(buf);
    rc           = inflate(&zs, Z_NO_FLUSH);
    if (rc != Z_OK && rc != Z_STREAM_END) {
      inflateEnd(&zs);
      return false;
    }
    out.append(buf, sizeof(buf) - zs.avail_out);
  } while (rc != Z_STREAM_END);
  inflateEnd(&zs);
  return true;
}

static void
run_case(const char *name, const std::string &a, const std::string &b)
{
  EsiGzip     gz;
  std::string out;
  int64_t     len = -1;
  bool        ok  = gz.stream_encode(a, out) && gz.stream_encode(b, out) && finish(gz, out, len);
  check((std::string(name) + "_encode").c_str(), ok);
  check((std::string(name) + "_magic").c_str(), out.size() > 18 && static_cast<uint8_t>(out[0]) == 0x1f && static_cast<uint8_t>(out[1]) == 0x8b);
  check((std::string(name) + "_length").c_str(), len == static_cast<int64_t>(out.size()));
  std::string plain;
  check((std::string(name) + "_roundtrip").c_str(), gunzip(out, plain) && plain == a + b);
}

int
main()
{
  run_case("hello", "Hello, ", "ESI world!");
  run_case("repeat", std::string(100000, 'x'), "<esi:include src=\"/a\"/>");
  printf("ESI_GZIP_KAT SUMMARY failures=%d\n", failures);
  return failures ? 1 : 0;
}
