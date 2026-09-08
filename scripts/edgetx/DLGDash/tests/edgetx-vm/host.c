/* Native C API checks and moving-stack stress, not a radio or font emulator. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
static const char *root;
static char frame[160];
static int color_id;
static unsigned long draws;
static void *move_alloc(void *ud, void *ptr, size_t old, size_t size) {
  if (!size) { free(ptr); return NULL; }
  void *next = malloc(size);
  if (!next) return NULL;
  if (ptr) { memcpy(next, ptr, old < size ? old : size); free(ptr); }
  return next;
}
static int checked(lua_State *L) {
  for (int i = 1; i <= lua_gettop(L); i++) luaL_checknumber(L, i);
  draws++;
  return 0;
}
static int noop(lua_State *L) { return 0; }
static int bitmap(lua_State *L) { lua_pushnil(L); return 1; }
static int begin_frame(lua_State *L) {
  snprintf(frame, sizeof(frame), "%s", luaL_checkstring(L, 1));
  return 0;
}
static int rgb(lua_State *L) {
  for (int i = 1; i <= 3; i++) luaL_checknumber(L, i);
  lua_pushinteger(L, ++color_id * 65536);
  return 1;
}
static int measure(lua_State *L) {
  const char *text = luaL_checkstring(L, 1);
  int font = luaL_checkinteger(L, 2) % 65536;
  const int heights[] = { 20, 20, 12, 17, 29, 40, 69 };
  if (font < 0 || font > 6) return luaL_error(L, "unknown font");
  lua_pushinteger(L, (int)strlen(text) * heights[font] / 2);
  lua_pushinteger(L, heights[font]);
  return 2;
}
static int draw_text(lua_State *L) {
  luaL_checknumber(L, 1); luaL_checknumber(L, 2);
  luaL_checkstring(L, 3); luaL_checknumber(L, 4);
  draws++;
  return 0;
}
static int draw_pixmap(lua_State *L) {
  luaL_checknumber(L, 1); luaL_checknumber(L, 2); luaL_checkstring(L, 3);
  draws++;
  return 0;
}
static int mono_radio(lua_State *L) {
  lua_pushstring(L, "t14"); lua_pushinteger(L, 128);
  lua_pushboolean(L, 0); lua_pushinteger(L, 10);
  return 4;
}
static int load_script(lua_State *L) {
  char filename[1024];
  const char *path = luaL_checkstring(L, 1);
  const char *prefix = "/WIDGETS/DLGDash/";
  if (strncmp(path, prefix, strlen(prefix)) != 0 || strstr(path, "..")) return luaL_error(L, "bad script path");
  snprintf(filename, sizeof(filename), "%s/%s", root, path + strlen(prefix));
  if (luaL_loadfile(L, filename)) return lua_error(L);
  return 1;
}
static void expose(lua_State *L, const char *name, lua_CFunction func) {
  lua_pushcfunction(L, func); lua_setglobal(L, name);
}
int main(int argc, char **argv) {
  if (argc != 3) { fprintf(stderr, "Usage: edgetx-vm spec.lua runtime-root\n"); return 2; }
  root = argv[2];
  lua_State *L = lua_newstate(move_alloc, NULL);
  if (!L) return 2;
  luaL_openlibs(L);
  lua_pushinteger(L, 10); lua_setglobal(L, "__firmwareMinor");
  expose(L, "loadScript", load_script);
  expose(L, "__rgb", rgb); expose(L, "__measure", measure);
  expose(L, "__rect", checked); expose(L, "__line", checked); expose(L, "__text", draw_text);
  expose(L, "__bitmap", bitmap); expose(L, "__bitmapSize", noop); expose(L, "__mask", noop);
  expose(L, "__begin", begin_frame); expose(L, "__end", noop);
  expose(L, "__radio", mono_radio); expose(L, "__clear", noop);
  expose(L, "__pixmap", draw_pixmap); expose(L, "__fontRegression", noop);
  expose(L, "__brand", noop); expose(L, "__v16Layout", noop); expose(L, "__altStatus", noop);
  int status = luaL_loadfile(L, argv[1]);
  if (!status) status = lua_pcall(L, 0, 0, 0);
  if (status) fprintf(stderr, "%s [frame %s]\n", lua_tostring(L, -1), frame);
  printf("%s: %lu checked native draw calls; pointer=%zu-bit\n", status ? "FAIL" : "PASS", draws, sizeof(void *) * 8);
  lua_close(L);
  return status ? 1 : 0;
}
