const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const { PNG } = require('pngjs');
const radio = process.argv.includes('--x9d') ? 'x9d' : process.argv.includes('--zorro') ? 'zorro' : process.argv.includes('--t14') ? 't14' : 'gx12';
const legacy = process.argv.includes('--legacy');
const minor = legacy ? 7 : radio === 't14' ? 10 : 11;
const width = radio === 'x9d' ? 212 : 128, height = 64;
const root = path.resolve(__dirname, '..');
const sdIndex = process.argv.indexOf('--sd-root');
assert(sdIndex < 0 || process.argv[sdIndex + 1], '--sd-root needs an extracted SD directory');
const sdRoot = sdIndex < 0 ? null : path.resolve(process.argv[sdIndex + 1]);
function runtimeFile(file) {
  if (!sdRoot) return path.join(root, file);
  if (file === 'DLG.lua') return path.join(sdRoot, 'SCRIPTS/TELEMETRY', file);
  if (file === 'DLGSetup.lua') return path.join(sdRoot, 'SCRIPTS/TOOLS', file);
  return path.join(sdRoot, 'WIDGETS/DLGDash', file);
}
const output = path.resolve(root, '../../../output/DLGDash-v1.0/verification-' + radio + (legacy ? '-legacy' : '') + (sdRoot ? '-package' : ''));
fs.mkdirSync(output, { recursive: true });
const font = [PNG.sync.read(fs.readFileSync(path.join(__dirname, 'reference/mono-05x07.png'))), PNG.sync.read(fs.readFileSync(path.join(__dirname, 'reference/mono-10x14.png')))];
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
let image, bounds = [], commands = [], name, frames = [];
function str(i) { return to_jsstring(lua.lua_tolstring(L, i)); }
function num(i) {
  assert.equal(lua.lua_type(L, i), lua.LUA_TNUMBER, 'LCD argument ' + i + ' must be a number');
  return lua.lua_tonumber(L, i);
}
function expose(key, fn) {
  lua.lua_pushjsfunction(L, () => {
    try { return fn(); } catch (e) { return lauxlib.luaL_error(L, to_luastring(key + ': ' + e.message)); }
  }); lua.lua_setglobal(L, to_luastring(key));
}
function pixel(x, y, black) {
  x = Math.round(x); y = Math.round(y);
  assert(x >= 0 && y >= 0 && x < width && y < height, name + ': out-of-screen pixel ' + x + ',' + y);
  const p = (y * width + x) * 4;
  image.data[p] = image.data[p + 1] = image.data[p + 2] = black ? 0 : 255; image.data[p + 3] = 255;
}
function textBounds(b) {
  assert(b.x >= 0 && b.y >= 0 && b.x + b.w <= width && b.y + b.h <= height, name + ': outside ' + JSON.stringify(b));
  for (const a of bounds) assert(!(b.x < a.x + a.w && b.x + b.w > a.x && b.y < a.y + a.h && b.y + b.h > a.y), name + ': overlap ' + b.text + ' / ' + a.text);
  bounds.push(b); commands.push(b);
}
expose('__radio', () => { lua.lua_pushstring(L, to_luastring(radio)); lua.lua_pushinteger(L, width); lua.lua_pushboolean(L, legacy); lua.lua_pushinteger(L, minor); return 4; });
expose('__begin', () => { name = str(1); image = new PNG({ width, height }); image.data.fill(255); bounds = []; commands = []; return 0; });
expose('__clear', () => { if (image) { image.data.fill(255); bounds = []; commands = []; } return 0; });
// Fengari delegates memory to JS; the native memory runner exercises real GC.
expose('collectgarbage', () => 0);
expose('__text', () => {
  if (!image) return 0;
  const x = num(1), y = num(2), text = str(3), flags = num(4), large = (flags & 1024) !== 0;
  assert.equal(flags, 16 + (large ? 1024 : 0), 'Use stable fixed-width monochrome font');
  const fw = large ? 10 : 5, fh = large ? 16 : 7, source = font[large ? 1 : 0];
  textBounds({ text, x, y, w: text.length * (fw + 1), h: fh, large });
  [...text].forEach((ch, i) => {
    const code = ch.charCodeAt(0); assert(code >= 32 && code <= 126);
    const tile = code - 32, ox = tile % 16 * fw, oy = Math.floor(tile / 16) * (large ? 16 : 8);
    const sentinel = Array.from({ length: fw }, (_, xx) => {
      for (let yy = 0; yy < (large ? 16 : 8); yy++) {
        const p = ((oy + yy) * source.width + ox + xx) * 4;
        if (source.data[p] >= 128 || source.data[p + 1] >= 128 || source.data[p + 2] >= 128) return false;
      }
      return true;
    });
    for (let yy = 0; yy < fh; yy++) for (let xx = 0; xx < fw; xx++) {
      const p = ((oy + yy) * source.width + ox + xx) * 4;
      // The firmware's sentinel columns are white when FIXEDWIDTH is set.
      const black = !sentinel[xx] && source.data[p] < 128 && source.data[p + 1] < 128 && source.data[p + 2] < 128;
      if (black) pixel(x + i * (fw + 1) + xx, y + yy, true);
    }
  }); return 0;
});
expose('__line', () => {
  if (!image) return 0;
  const [x, y, xx, yy] = [1, 2, 3, 4].map(num), steps = Math.max(Math.abs(xx - x), Math.abs(yy - y), 1);
  for (let i = 0; i <= steps; i++) pixel(x + (xx - x) * i / steps, y + (yy - y) * i / steps, true);
  commands.push({ line: [x, y, xx, yy] }); return 0;
});
expose('__rect', () => {
  if (!image) return 0;
  const [x, y, w, h] = [1, 2, 3, 4].map(num);
  for (let i = 0; i < w; i++) { pixel(x + i, y, true); pixel(x + i, y + h - 1, true); }
  for (let i = 0; i < h; i++) { pixel(x, y + i, true); pixel(x + w - 1, y + i, true); } return 0;
});
expose('__pixmap', () => {
  if (!image) return 0;
  const file = str(3).replace('/WIDGETS/DLGDash/', ''), bmp = fs.readFileSync(runtimeFile(file));
  const w = bmp.readInt32LE(18), h = bmp.readInt32LE(22), offset = bmp.readUInt32LE(10), stride = Math.ceil(w / 8) * 4;
  assert(w <= width / 2); assert.equal(bmp.readUInt16LE(28), 4);
  const x = num(1), y = num(2); textBounds({ text: file, x, y, w, h });
  let ink = 0;
  for (let yy = 0; yy < h; yy++) for (let xx = 0; xx < w; xx++) {
    const b = bmp[offset + (h - 1 - yy) * stride + (xx >> 1)];
    const black = ((b >> (xx % 2 ? 0 : 4)) & 15) === 0;
    if (black) ink++; pixel(x + xx, y + yy, black);
  }
  assert(ink > 0 || w <= 2, 'Blank Chinese bitmap ' + file); return 0;
});
expose('__end', () => {
  assert(bounds.length > 0, 'Blank frame');
  assert(image.data.some((v, i) => i % 4 < 3 && v === 0), 'No ink in frame');
  fs.writeFileSync(path.join(output, name + '.png'), PNG.sync.write(image));
  fs.writeFileSync(path.join(output, name + '.json'), JSON.stringify(commands, null, 2));
  frames.push(name + '.png'); image = undefined; return 0;
});
expose('__fontRegression', () => {
  // Official 5x7 column bytes: '.' = ff ff 40 ff ff, 'i' = ff 44 7d 40 ff.
  for (const x of [4, 6, 7, 9, 10, 12, 16]) for (let y = 0; y < 7; y++) {
    assert.equal(image.data[(y * width + x) * 4], 255, 'FIXEDWIDTH must blank ff sentinel columns');
  }
  assert.equal(image.data[(6 * width + 8) * 4], 0, 'Decimal point is one dot, not a vertical bar');
  return 0;
});
expose('loadScript', () => {
  const file = str(1).replace('/WIDGETS/DLGDash/', ''); assert(!file.includes('..'));
  assert(!['draw.lua', 'locale.lua', 'main.lua', 'color-settings.lua'].includes(file), 'Monochrome must not compile color renderers');
  const script = fs.readFileSync(runtimeFile(file));
  if (lauxlib.luaL_loadbuffer(L, script, script.length, to_luastring('@' + file)) !== lua.LUA_OK) throw Error(str(-1));
  return 1;
});
const spec = fs.readFileSync(path.join(root, 'test_mono.lua'));
if (lauxlib.luaL_loadbuffer(L, spec, spec.length, to_luastring('@test_mono.lua')) !== lua.LUA_OK || lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) throw Error(str(-1));
console.log(`${radio}: ${frames.length} native bitmap-font renders, zero overlaps or out-of-screen pixels.`);
fs.writeFileSync(path.join(output, 'result.json'), JSON.stringify({ radio, firmware: '2.' + minor, width, height, frames, status: 'PASS', hardware: false }, null, 2));
