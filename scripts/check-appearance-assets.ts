// node scripts/check-appearance-assets.ts
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { decodePng } from '../Android/tools/png.ts';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const hash = (file: string) => createHash('sha256').update(fs.readFileSync(file)).digest('hex');
for (const file of ['atlas.json', 'atlas.png', 'atlas-bw.png']) {
  const hashes = ['Android', 'Apple Platform', 'HarmonyOS'].map(p => hash(path.join(root, p, 'assets', file)));
  assert.equal(new Set(hashes).size, 1, `三端原图/槽位表不一致：${file}`);
}
const slots = JSON.parse(fs.readFileSync(path.join(root, 'Android/assets/atlas.json'), 'utf8')).slots;
assert.equal(slots.length, 116);
for (const prefix of ['cw_', 'cw_bw_']) {
  for (const slot of slots) {
    const name = `${prefix}${slot.name}`;
    const files = [
      `Android/app/src/main/res/drawable-nodpi/${name}.png`,
      `Apple Platform/ComplexSweeper-Apple/Assets.xcassets/${name}.imageset/${name}.png`,
      `HarmonyOS/entry/src/main/resources/base/media/${name}.png`,
    ].map(f => path.join(root, f));
    assert.equal(new Set(files.map(hash)).size, 1, `三端切图不一致：${name}`);
    const image = decodePng(fs.readFileSync(files[0]));
    assert.equal(image.width, slot.w, name);
    assert.equal(image.height, slot.h, name);
    let visible = false;
    for (let i = 0; i < image.data.length; i += 4) {
      if (image.data[i + 3] > 0) visible = true;
      if (prefix === 'cw_bw_') {
        assert.equal(image.data[i], image.data[i + 1], name);
        assert.equal(image.data[i], image.data[i + 2], name);
        if (slot.name !== 'icon') assert.equal(image.data[i + 3], 255, name);
      }
    }
    assert.ok(visible, `空白素材：${name}`);
  }
}
console.log('三端原图与槽位表一致；232张切图的SHA-256、尺寸、非空与黑白灰度检查通过');
