// EsiGzip.cc reports errors through the Traffic Server plugin API's TSError. Both harnesses link
// this no-op instead of the whole API library, which needs a running server.
#include <ts/ts.h>

void
TSError(const char *, ...)
{
}
