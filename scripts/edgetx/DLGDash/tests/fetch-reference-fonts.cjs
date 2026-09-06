// Test-only assets, fetched from the pinned official EdgeTX release.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const references = require('./reference-fonts.json');
const digest = data => crypto.createHash('sha256').update(data).digest('hex');
async function main() {
  for (const item of references) {
    const destination = path.join(__dirname, 'reference', item.file);
    if (fs.existsSync(destination) && digest(fs.readFileSync(destination)) === item.sha256) continue;
    let data;
    for (const host of ['raw', 'api']) {
      try {
        const url = host === 'raw' ? `https://raw.githubusercontent.com/EdgeTX/edgetx/v2.11.3/${item.source}`
          : `https://api.github.com/repos/EdgeTX/edgetx/contents/${item.source}?ref=v2.11.3`;
        const response = await fetch(url, { signal: AbortSignal.timeout(20000) });
        if (!response.ok) throw Error('HTTP ' + response.status);
        data = host === 'raw' ? Buffer.from(await response.arrayBuffer()) : Buffer.from((await response.json()).content, 'base64');
        if (digest(data) !== item.sha256) throw Error('Reference hash mismatch: ' + item.file);
        break;
      } catch (error) { if (host === 'api') throw error; }
    }
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.writeFileSync(destination, data);
    console.log('Verified reference: ' + item.file);
  }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
