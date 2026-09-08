const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const radios = require('../radios.json');
assert.equal(new Set(radios.map(r => r.board)).size, radios.length, 'Duplicate radio');
const targetIndex = process.argv.indexOf('--target');
const target = targetIndex < 0 ? null : process.argv[targetIndex + 1];
assert(target === null || ['Color', 'Monochrome'].includes(target), 'Invalid screen target');
const sdIndex = process.argv.indexOf('--sd-root');
assert(sdIndex < 0 || process.argv[sdIndex + 1], 'Missing SD root');
for (const radio of radios.filter(r => !target || r.screen === target)) {
  assert(['Color', 'Monochrome'].includes(radio.screen));
  assert(radio.screen === 'Color' ? [320, 480, 800].includes(radio.width) && [240, 272, 320, 480].includes(radio.height) : [128, 212].includes(radio.width) && radio.height === 64);
  const args = [radio.screen === 'Color' ? 'run.cjs' : 'run-mono.cjs', '--radio', radio.board];
  if (sdIndex >= 0) args.push('--sd-root', process.argv[sdIndex + 1]);
  const result = spawnSync(process.execPath, args, { cwd: __dirname, encoding: 'utf8' });
  if (result.status !== 0) throw Error(radio.board + ': ' + result.stdout + result.stderr + (result.error || ''));
  console.log(radio.board + ' ' + radio.width + 'x' + radio.height + ': PASS (simulated APIs/fonts, not hardware)');
}
