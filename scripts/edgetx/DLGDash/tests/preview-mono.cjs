// Integer nearest-neighbor enlargement, with no interpolation of mono pixels.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { PNG } = require('pngjs');
const root = path.resolve(__dirname, '../../../..');
const samples = {
  x9d: 'verification-x9d/x9d-0-6-100-1.png',
  gx12: 'verification-gx12/gx12-0-6-100-1.png',
  'gx12-servos': 'verification-gx12/gx12-1-6-100-2.png',
  'gx12-settings': 'verification-gx12/row-1-8-1.png',
  zorro: 'verification-zorro-legacy/zorro-0-6-100-1.png',
  'zorro-servos': 'verification-zorro-legacy/zorro-1-6-100-2.png',
  'zorro-settings': 'verification-zorro-legacy/row-1-8-1.png'
};
fs.mkdirSync(path.join(root, 'docs/images'), { recursive: true });
for (const [name, file] of Object.entries(samples)) {
  const source = PNG.sync.read(fs.readFileSync(path.join(root, 'output/DLGDash-v1.0', file)));
  fs.writeFileSync(path.join(root, 'docs/images', name + '.png'), PNG.sync.write(source));
  const factor = name === 'x9d' ? 3 : 4;
  const result = new PNG({ width: source.width * factor, height: source.height * factor });
  for (let y = 0; y < result.height; y++) for (let x = 0; x < result.width; x++) {
    const p = (Math.floor(y / factor) * source.width + Math.floor(x / factor)) * 4;
    assert([0, 255].includes(source.data[p]), 'Native mono render must have no grey pixels');
    source.data.copy(result.data, (y * result.width + x) * 4, p, p + 4);
  }
  fs.writeFileSync(path.join(root, 'docs/images', name + '-large.png'), PNG.sync.write(result));
  console.log(`${name}: ${factor}x integer-pixel preview`);
}
