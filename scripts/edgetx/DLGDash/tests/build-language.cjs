const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { GlobalFonts, createCanvas } = require('@napi-rs/canvas');
const fontPath = process.env.DLG_CN_FONT || 'C:/Windows/Fonts/NotoSansSC-VF.ttf';
assert(GlobalFonts.registerFromPath(fontPath, 'DLG Chinese'), 'Chinese font unavailable');
const phrases = require('./zh.json');
const output = path.resolve(__dirname, '../lang/zh');
fs.mkdirSync(output, { recursive: true });
const lines = ['-- Generated from tests/zh.json using Noto Sans SC (SIL OFL 1.1).', 'return {'];
const monoOutput = path.resolve(output, '../mono');
fs.mkdirSync(monoOutput, { recursive: true });
const monoLines = [lines[0], 'return {'];
let index = 0;
const largeOnly = process.argv.includes('--large-only');
for (const [key, text] of Object.entries(phrases)) {
  const name = 'l' + String(++index).padStart(3, '0');
  lines.push(`  [${JSON.stringify(key)}] = "${name}",`);
  for (const size of largeOnly ? [28, 34] : [14, 17, 21, 28, 34]) {
    const measure = createCanvas(1, 1).getContext('2d');
    let font, metrics;
    for (let pixels = size - 1; pixels >= 10; pixels--) {
      font = `600 ${pixels}px "DLG Chinese"`;
      measure.font = font;
      metrics = measure.measureText(text);
      if (metrics.actualBoundingBoxAscent + metrics.actualBoundingBoxDescent <= size) break;
    }
    const width = Math.ceil(Math.max(metrics.width, metrics.actualBoundingBoxRight) + Math.max(0, metrics.actualBoundingBoxLeft)) + 2;
    const canvas = createCanvas(width, size), ctx = canvas.getContext('2d');
    ctx.font = font;
    // EdgeTX Bitmap.toMask ignores alpha and inverts RGB luminance.
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, width, size);
    ctx.fillStyle = '#000000';
    const glyphHeight = metrics.actualBoundingBoxAscent + metrics.actualBoundingBoxDescent;
    assert(glyphHeight <= size, `${text}: glyph exceeds row height`);
    ctx.fillText(text, 1 + Math.max(0, metrics.actualBoundingBoxLeft), (size - glyphHeight) / 2 + metrics.actualBoundingBoxAscent);
    fs.writeFileSync(path.join(output, `${name}_${size}.png`), canvas.toBuffer('image/png'));
  }
  if (largeOnly) continue;
  const measure = createCanvas(1, 1).getContext('2d');
  measure.font = '400 13px "DLG Chinese"';
  const metrics = measure.measureText(text), height = 14;
  const canvasWidth = Math.ceil(Math.max(metrics.width, metrics.actualBoundingBoxRight)) + 2;
  const mono = createCanvas(canvasWidth, height), ctx = mono.getContext('2d');
  ctx.font = measure.font;
  ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, canvasWidth, height);
  ctx.fillStyle = '#000'; ctx.fillText(text, 1, (height - metrics.actualBoundingBoxAscent - metrics.actualBoundingBoxDescent) / 2 + metrics.actualBoundingBoxAscent);
  const pixels = ctx.getImageData(0, 0, canvasWidth, height).data;
  let width = canvasWidth;
  const threshold = 200;
  while (width > 1 && Array.from({ length: height }, (_, y) => pixels[(y * canvasWidth + width - 1) * 4]).every(v => v >= threshold)) width--;
  const ink = Array.from(pixels).filter((v, i) => i % 4 === 0 && v < threshold).length;
  assert(ink > width * height * 0.08, text + ': monochrome strokes too faint');
  monoLines.push(`  [${JSON.stringify(key)}] = { "${name}", ${width} },`);
  // EdgeTX 2.11 drawPixmap accepts BMP files up to half the display width.
  for (let x = 0, part = 1; x < width; x += 64, part++) {
    const tileWidth = Math.min(64, width - x), stride = Math.ceil(tileWidth / 8) * 4;
    const offset = 14 + 40 + 64, bmp = Buffer.alloc(offset + stride * height);
    bmp.write('BM'); bmp.writeUInt32LE(bmp.length, 2); bmp.writeUInt32LE(offset, 10);
    bmp.writeUInt32LE(40, 14); bmp.writeInt32LE(tileWidth, 18); bmp.writeInt32LE(height, 22);
    bmp.writeUInt16LE(1, 26); bmp.writeUInt16LE(4, 28); bmp.writeUInt32LE(stride * height, 34);
    bmp.writeUInt32LE(16, 46);
    for (let i = 0; i < 16; i++) bmp.fill(i * 17, 54 + i * 4, 57 + i * 4);
    for (let y = 0; y < height; y++) for (let xx = 0; xx < tileWidth; xx++) {
      const level = pixels[(y * canvasWidth + x + xx) * 4] < threshold ? 0 : 15;
      bmp[offset + (height - 1 - y) * stride + (xx >> 1)] |= level << (xx % 2 ? 0 : 4);
    }
    fs.writeFileSync(path.join(monoOutput, `${name}_${part}.bmp`), bmp);
  }
}
lines.push('}');
monoLines.push('}');
if (!largeOnly) {
  fs.writeFileSync(path.resolve(output, '../zh.lua'), lines.join('\n') + '\n');
  fs.writeFileSync(path.resolve(output, '../mono.lua'), monoLines.join('\n') + '\n');
}
console.log(`Built ${index} Chinese labels (${largeOnly ? 'large sizes only' : 'all sizes'}) using Noto Sans SC.`);
