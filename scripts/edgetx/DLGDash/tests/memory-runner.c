/* Native Lua 5.3 allocation regression, not an EdgeTX hardware heap emulator.
 * cc -I <lua>/src memory-runner.c <lua>/src/liblua.a -lm -o memory-runner
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

typedef struct {
  size_t used, peak, limit;
  char stage[160];
} Memory;

static void *allocate(void *ud, void *ptr, size_t old, size_t size) {
  Memory *m = ud;
  if (!ptr) old = 0;
  if (!size) { free(ptr); m->used -= old; return NULL; }
  size_t next = m->used - old + size;
  if (m->limit && next > m->limit) return NULL;
  void *result = realloc(ptr, size);
  if (result) {
    m->used = next;
    if (next > m->peak) m->peak = next;
  }
  return result;
}

static int stage(lua_State *L) {
  void *ud;
  lua_getallocf(L, &ud);
  Memory *m = ud;
  snprintf(m->stage, sizeof(m->stage), "%s", luaL_checkstring(L, 1));
  return 0;
}

int main(int argc, char **argv) {
  if (argc < 3) {
    fprintf(stderr, "Usage: memory-runner memory-spec.lua runtime-root [limit-bytes] [setup|telemetry]\n");
    return 2;
  }
  Memory m = {0};
  m.limit = argc > 3 ? strtoul(argv[3], NULL, 10) : 0;
  lua_State *L = lua_newstate(allocate, &m);
  if (!L) return 2;
  luaL_openlibs(L);
  lua_pushstring(L, argv[2]); lua_setglobal(L, "__root");
  lua_pushstring(L, argc > 4 ? argv[4] : "setup"); lua_setglobal(L, "__scenario");
  lua_pushcfunction(L, stage); lua_setglobal(L, "__stage");
  int status = luaL_loadfile(L, argv[1]);
  if (!status) status = lua_pcall(L, 0, 0, 0);
  if (status) fprintf(stderr, "%s at %s\n", lua_tostring(L, -1), m.stage);
  lua_gc(L, LUA_GCCOLLECT, 0);
  printf("%s: peak=%zu retained=%zu limit=%zu pointer=%zu-bit\n",
         status ? "FAIL" : "PASS", m.peak, m.used, m.limit, sizeof(void *) * 8);
  lua_close(L);
  return status ? 1 : 0;
}
