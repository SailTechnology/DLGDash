/* Minimal ROM libraries for EdgeTX v2.10.1's Lua fork, not upstream Lua. */
#define linit_c
#define LUA_LIB
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "lstring.h"
#include "ltable.h"
#include "lstate.h"
extern LROT_TABLE(base_func);
extern LROT_TABLE(strlib);
extern LROT_TABLE(mathlib);
extern LROT_TABLE(bitlib);
extern LROT_TABLE(tablib);
static int globals_index(lua_State *L) {
  TString *key = rawtsvalue(L->top - 1);
  const TValue *value = luaH_getstr((Table *)LROT_TABLEREF(base_func), key);
  setobj2s(L, L->top - 1, value);
  return 1;
}
LROT_BEGIN(rotables_meta, NULL, LROT_MASK_INDEX)
  LROT_FUNCENTRY(__index, globals_index)
LROT_END(rotables_meta, NULL, LROT_MASK_INDEX)
LROT_BEGIN(rotables, LROT_TABLEREF(rotables_meta), 0)
  /* Keep _G removable so specs can exercise firmware without that global. */
  LROT_TABENTRY(string, strlib)
  LROT_TABENTRY(math, mathlib)
  LROT_TABENTRY(bit32, bitlib)
  /* Match small-radio builds without the optional table library. */
LROT_END(rotables, LROT_TABLEREF(rotables_meta), 0)
LUALIB_API void luaL_openlibs(lua_State *L) {
  luaL_requiref(L, "_G", luaopen_base, 1); lua_pop(L, 1);
  luaL_requiref(L, "debug", luaopen_debug, 1); lua_pop(L, 1);
}
