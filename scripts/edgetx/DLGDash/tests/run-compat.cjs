const fs = require('node:fs');
const path = require('node:path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const root = path.resolve(__dirname, '..');
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
lua.lua_pushjsfunction(L, () => {
  const name = to_jsstring(lua.lua_tolstring(L, 1)).replace('/WIDGETS/DLGDash/', '');
  if (!['compat.lua', 'locale.lua'].includes(name)) throw Error('Unexpected module ' + name);
  const source = fs.readFileSync(path.join(root, name));
  if (lauxlib.luaL_loadbuffer(L, source, source.length, to_luastring('@' + name)) !== lua.LUA_OK) throw Error(to_jsstring(lua.lua_tolstring(L, -1)));
  return 1;
});
lua.lua_setglobal(L, to_luastring('loadScript'));
const spec = fs.readFileSync(path.join(__dirname, 'test-compat.lua'));
if (lauxlib.luaL_loadbuffer(L, spec, spec.length, to_luastring('@test-compat.lua')) !== lua.LUA_OK || lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) throw Error(to_jsstring(lua.lua_tolstring(L, -1)));
