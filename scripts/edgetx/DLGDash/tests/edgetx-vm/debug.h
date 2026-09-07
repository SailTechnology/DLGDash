/* Host logging only; the firmware interpreter is compiled unchanged. */
#define TRACE(...) ((void)0)
#define TRACE_LUA_INTERNALS(...) ((void)0)
#define TRACE_DEBUG_WP(...) printf(__VA_ARGS__)
