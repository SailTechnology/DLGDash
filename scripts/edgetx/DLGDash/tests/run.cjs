const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const { PNG } = require('pngjs');
const firmwareFont = require('./font.cjs');
const root = path.resolve(__dirname, '..');
const v16 = process.argv.includes('--v16');
const radio = v16 ? 'v16' : 'pa01';
const screenWidth = v16 ? 480 : 320, screenHeight = v16 ? 272 : 240;
const output = path.resolve(root, '../../../output/DLGDash-v1.0/verification-' + radio);
fs.mkdirSync(output, { recursive: true });

// Decode the same LVGL bitmap fonts used by EdgeTX v2.11.3 on PA01 (sml).
const fonts = [null, ...['bold_STD', 'XXS', 'XS', 'L', 'bold_XL', 'bold_XXL'].map(name => firmwareFont('en_' + name, v16 ? 'std' : ''))];
const colors = [];
const frames = [];
let image, commands, textBounds, frameName;
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
lua.lua_pushnil(L); lua.lua_setglobal(L, to_luastring('_G'));
function argString(i) { return to_jsstring(lua.lua_tolstring(L, i)); }
function argNumber(i) { return lua.lua_tonumber(L, i); }
function expose(name, fn) {
  lua.lua_pushjsfunction(L, state => {
    try { return fn(state); }
    catch (error) { return lauxlib.luaL_error(L, to_luastring(name + ': ' + error.message)); }
  });
  lua.lua_setglobal(L, to_luastring(name));
}
function pixel(x, y, rgb, alpha = 1) {
  x = Math.round(x); y = Math.round(y);
  assert(x >= 0 && x < image.width && y >= 0 && y < image.height, `${frameName}: pixel out of bounds ${x},${y}`);
  const offset = (y * image.width + x) * 4;
  for (let c = 0; c < 3; c++) image.data[offset + c] = Math.round(image.data[offset + c] * (1 - alpha) + rgb[c] * alpha);
  image.data[offset + 3] = 255;
}
function color(flags) { return colors[Math.floor(flags / 65536) - 1] || [255, 255, 255]; }
function checkBounds(bounds) {
  const { x, y, w, h, text } = bounds;
  assert(x >= 0 && y >= 0 && x + w <= screenWidth && y + h <= screenHeight, `${frameName}: label outside screen ${JSON.stringify(bounds)}`);
  for (const b of textBounds) {
    assert(!(x < b.x + b.w && x + w > b.x && y < b.y + b.h && y + h > b.y), `${frameName}: label overlap '${text}' / '${b.text}'`);
  }
  textBounds.push(bounds); commands.push(bounds);
}
const bitmaps = new Map();
const phrases = Object.values(require('./zh.json'));
expose('__bitmap', () => {
  const name = argString(1).replace(/^\/WIDGETS\/DLGDash\//, '');
  assert(!name.includes('..'));
  if (!bitmaps.has(name)) {
    const png = PNG.sync.read(fs.readFileSync(path.join(root, name)));
    const pixels = [...png.data].filter((v, i) => i % 4 === 0 && v < 200).length;
    assert(pixels > 5, name + ': blank label');
    bitmaps.set(name, png);
  }
  lua.lua_pushstring(L, to_luastring(name)); return 1;
});
expose('__bitmapSize', () => {
  const bitmap = bitmaps.get(argString(1));
  lua.lua_pushinteger(L, bitmap.width); lua.lua_pushinteger(L, bitmap.height); return 2;
});
expose('__mask', () => {
  if (!image) return 0;
  const name = argString(1), x = argNumber(2), y = argNumber(3), rgb = color(argNumber(4));
  const png = bitmaps.get(name);
  const index = Number(name.match(/l(\d+)_/)[1]) - 1;
  checkBounds({ kind: 'text', text: phrases[index], x, y, w: png.width, h: png.height, font: 'Noto Sans SC bitmap' });
  for (let yy = 0; yy < png.height; yy++) for (let xx = 0; xx < png.width; xx++) {
    const p = (yy * png.width + xx) * 4;
    const level = Math.floor(((png.data[p] >> 4) + (png.data[p + 1] >> 4) + (png.data[p + 2] >> 4)) / 3);
    pixel(x + xx, y + yy, rgb, (15 - level) / 15);
  }
  return 0;
});
expose('__fixture', () => {
  const name = argString(1);
  assert(!name.includes('..'));
  lua.lua_pushstring(L, to_luastring(fs.readFileSync(path.join(__dirname, 'fixtures', name), 'utf8'))); return 1;
});
expose('__rgb', () => {
  colors.push([argNumber(1), argNumber(2), argNumber(3)]);
  lua.lua_pushinteger(L, colors.length * 65536); return 1;
});
expose('__measure', () => {
  const font = fonts[argNumber(2) % 65536];
  assert(font, 'Unknown font');
  lua.lua_pushinteger(L, font.measure(argString(1)));
  lua.lua_pushinteger(L, font.height); return 2;
});
expose('__begin', () => {
  frameName = argString(1);
  image = new PNG({ width: screenWidth, height: screenHeight });
  commands = []; textBounds = [];
  return 0;
});
expose('__rect', () => {
  if (!image) return 0;
  const [x, y, w, h, flags] = [1, 2, 3, 4, 5].map(argNumber);
  commands.push({ kind: 'rect', x, y, w, h });
  for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) pixel(xx, yy, color(flags));
  return 0;
});
expose('__line', () => {
  if (!image) return 0;
  const [x1, y1, x2, y2, , flags] = [1, 2, 3, 4, 5, 6].map(argNumber);
  const n = Math.max(Math.abs(x2 - x1), Math.abs(y2 - y1), 1);
  commands.push({ kind: 'line', x1, y1, x2, y2 });
  for (let i = 0; i <= n; i++) pixel(x1 + (x2 - x1) * i / n, y1 + (y2 - y1) * i / n, color(flags));
  return 0;
});
expose('__text', () => {
  if (!image) return 0;
  const x = argNumber(1), y = argNumber(2), text = argString(3), flags = argNumber(4);
  const font = fonts[flags % 65536];
  const bounds = { kind: 'text', text, x, y, w: font.measure(text), h: font.height, font: font.name };
  checkBounds(bounds);
  const codes = [...text].map(ch => ch.codePointAt(0));
  let cursor = x;
  for (let i = 0; i < codes.length; i++) {
    const g = font.glyph(codes[i], codes[i + 1] || 0);
    for (let yy = 0; yy < g.h; yy++) for (let xx = 0; xx < g.w; xx++) {
      const bit = yy * g.w + xx, byte = font.data[g.bitmap + (bit >> 1)];
      const alpha = ((bit % 2 === 0 ? byte >> 4 : byte) & 15) / 15;
      if (alpha) pixel(cursor + g.x + xx, y + font.height - font.baseline - g.h - g.y + yy, color(flags), alpha);
    }
    cursor += g.advance;
  }
  return 0;
});
expose('__end', () => {
  assert(commands.some(cmd => cmd.kind === 'text'), `${frameName}: blank frame`);
  fs.writeFileSync(path.join(output, `${frameName}.png`), PNG.sync.write(image));
  fs.writeFileSync(path.join(output, `${frameName}.json`), JSON.stringify(commands, null, 2));
  frames.push(`${frameName}.png`);
  image = undefined;
  return 0;
});
expose('__servoFont', () => {
  const count = argNumber(1);
  const outputs = commands.filter(c => c.kind === 'text' && c.y >= 146 && c.x < 172 && /^[+-]\d+$/.test(c.text));
  assert.equal(outputs.length, count, 'All output readouts must be present');
  for (const output of outputs) assert.equal(output.font, 'en_L', `${output.text}: servo font must stay at 23px`);
  const units = commands.filter(c => c.kind === 'text' && c.y >= 146 && c.x < 172 && c.text === '%');
  assert.equal(units.length, count, 'Each output keeps its percent unit');
  const grid = commands.filter(c => c.kind === 'line' && c.x1 === 197 && c.x2 === 314);
  assert.equal(grid.length, 3, 'Expanded graph grid spans 118 pixels');
  assert.equal(grid[2].y1 - grid[0].y1, 69, 'Expanded graph plot height');
  return 0;
});
expose('__altStatus', () => {
  const missing = lua.lua_toboolean(L, 1);
  const label = commands.some(c => c.kind === 'text' && (c.text === 'NO ALT' || c.text === '\u65e0\u9ad8\u5ea6'));
  assert.equal(label, missing, `${frameName}: altitude status must follow validity, not packet freshness`);
  return 0;
});
expose('__brand', () => {
  const fullscreen = lua.lua_toboolean(L, 1);
  assert(commands.some(c => c.kind === 'text' && c.y < 24 && c.x > screenWidth - 70 && c.text === (fullscreen ? 'SET' : 'Sail')), 'Home author tag and fullscreen settings entry must stay separate');
  return 0;
});
expose('__v16Layout', () => {
  const servos = argNumber(1), height = argNumber(2);
  const bottom = height >= 260 ? 176 : 150;
  const outputs = commands.filter(c => c.kind === 'text' && c.y >= bottom && c.x < 259 && /^[+-]\d+$/.test(c.text));
  assert.equal(outputs.length, servos);
  const expected = (height - bottom) / (servos / 2) - 5 >= 29 ? 'en_L' : 'en_bold_STD';
  for (const value of outputs) assert.equal(value.font, expected, value.text + ': fixed V16 output font');
  assert(commands.some(c => c.kind === 'line' && c.x2 - c.x1 >= 180 && c.x1 > 250 && c.y1 === c.y2), 'V16 uses its wider graph area');
  return 0;
});
expose('loadScript', () => {
  const name = argString(1).replace(/^\/WIDGETS\/DLGDash\//, '');
  assert(!name.includes('..'));
  const script = fs.readFileSync(path.join(root, name));
  const status = lauxlib.luaL_loadbuffer(L, script, script.length, to_luastring('@' + name));
  if (status !== lua.LUA_OK) throw Error(argString(-1));
  return 1;
});
const specName = v16 ? 'test_v16.lua' : 'test_widget.lua';
const spec = fs.readFileSync(path.join(root, specName));
if (lauxlib.luaL_loadbuffer(L, spec, spec.length, to_luastring('@' + specName)) !== lua.LUA_OK || lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) {
  throw Error(argString(-1));
}
const files = [...new Set(frames)];
console.log(`${radio.toUpperCase()}: ${files.length} real-font screenshots, zero text overlaps / out-of-screen draws.`);
console.log(`Font heights: ${fonts.filter(Boolean).map(f => `${f.name}=${f.height}`).join(', ')}`);
fs.writeFileSync(path.join(output, 'result.json'), JSON.stringify({ screen: `${radio.toUpperCase()} ${screenWidth}x${screenHeight}`, fonts: 'EdgeTX v2.11.3 ' + (v16 ? 'std' : 'sml'), stringMetatable: false, screenshots: files, status: 'PASS' }, null, 2));
