const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const lz4 = require('lz4js');

module.exports = function firmwareFont(name, family = '') {
  const src = fs.readFileSync(path.join(__dirname, 'reference', family, `lv_font_${name}.c`), 'utf8');
  const prop = key => Number(src.match(new RegExp(`\\.${key} = (\\d+)`))[1]);
  const hex = src.match(/lz4FontData\[\][^=]*=\s*\{([\s\S]*?)\};/)[1].match(/0x[\da-f]+/gi);
  const compressed = Uint8Array.from(hex, x => Number(x));
  const bytes = new Uint8Array(prop('uncomp_size'));
  assert.equal(lz4.decompressBlock(compressed, bytes, 0, compressed.length, 0), bytes.length);
  const data = Buffer.from(bytes);
  const cmaps = [...src.matchAll(/\{ \.range_start = (\d+), \.range_length = (\d+), \.glyph_id_start = (\d+), \.list_length = (\d+), \.type = (\d+), \.unicode_list = (\d+), \.glyph_id_ofs_list = (\d+) \}/g)].map(m => m.slice(1).map(Number));
  function id(code) {
    for (const [start, len, first, count, type, unicode, ofs] of cmaps) {
      if (code < start || code >= start + len) continue;
      const rel = code - start;
      if (type === 2) return first + rel;
      if (type === 0) return first + data[ofs + rel];
      for (let i = 0; i < count; i++) {
        if (data.readUInt16LE(unicode + i * 2) === rel) return first + (type === 3 ? i : data.readUInt16LE(ofs + i * 2));
      }
    }
    return 0;
  }
  function glyph(code, next) {
    const gi = id(code), ni = id(next);
    const p = gi * 8, packed = data.readUInt32LE(p);
    let kern = 0;
    if (ni && prop('kern_classes')) {
      const lc = data[prop('left_class_mapping') + gi], rc = data[prop('right_class_mapping') + ni];
      if (lc && rc) kern = data.readInt8(prop('class_pair_values') + (lc - 1) * prop('right_class_cnt') + rc - 1);
    }
    const advance = ((packed >>> 20) + ((kern * prop('kern_scale')) >> 4) + 8) >> 4;
    return { bitmap: prop('glyph_bitmap') + (packed & 0xfffff), advance, w: data[p + 4], h: data[p + 5], x: data.readInt8(p + 6), y: data.readInt8(p + 7) };
  }
  const font = { name, data, height: prop('line_height'), baseline: prop('base_line'), glyph, hasGlyph: code => id(code) > 0 };
  font.measure = text => {
    const codes = [...text].map(ch => ch.codePointAt(0));
    return codes.reduce((sum, ch, i) => sum + glyph(ch, codes[i + 1] || 0).advance, 0);
  };
  return font;
};
