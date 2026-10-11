import * as zlib from 'node:zlib';

// 极简 PNG 读写：只支持 8 位 RGBA、非隔行 —— 图集和图标正好都是这个格式。
// 手边没有 ImageMagick / PIL，所以用 Node 自带的 zlib 自己解、自己编。
//
// 被 slice.ts（切图集）和 make-icon.ts（做应用图标）共用。

// ---------------- CRC32 ----------------

const CRC_TABLE: number[] = (() => {
  const table: number[] = [];
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) {
      c = (c & 1) !== 0 ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
    }
    table.push(c >>> 0);
  }
  return table;
})();

function crc32(buf: Buffer): number {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) {
    c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) >>> 0;
}

// ---------------- PNG 解码（8 位 RGBA、非隔行） ----------------

export class Bitmap {
  readonly width: number;
  readonly height: number;
  readonly data: Buffer;

  constructor(width: number, height: number, data: Buffer) {
    this.width = width;
    this.height = height;
    this.data = data;
  }
}

export function decodePng(buf: Buffer): Bitmap {
  let off = 8;
  let width = 0;
  let height = 0;
  let colorType = -1;
  let bitDepth = 0;
  const idat: Buffer[] = [];

  while (off < buf.length) {
    const len = buf.readUInt32BE(off);
    const type = buf.subarray(off + 4, off + 8).toString('ascii');
    const data = buf.subarray(off + 8, off + 8 + len);
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8];
      colorType = data[9];
      if (data[12] !== 0) {
        throw new Error('不支持隔行扫描的 PNG');
      }
    } else if (type === 'IDAT') {
      idat.push(data);
    }
    off += 12 + len;
  }
  if (bitDepth !== 8 || colorType !== 6) {
    throw new Error(`只处理 8 位 RGBA，实际是位深 ${bitDepth} 颜色类型 ${colorType}`);
  }

  const raw = zlib.inflateSync(Buffer.concat(idat));
  const bpp = 4;
  const stride = width * bpp;
  const out = Buffer.alloc(height * stride);
  let pos = 0;

  for (let y = 0; y < height; y++) {
    const filter = raw[pos++];
    const line = raw.subarray(pos, pos + stride);
    pos += stride;
    const cur = out.subarray(y * stride, (y + 1) * stride);
    const prev = y > 0 ? out.subarray((y - 1) * stride, y * stride) : null;

    for (let i = 0; i < stride; i++) {
      const a = i >= bpp ? cur[i - bpp] : 0;
      const b = prev ? prev[i] : 0;
      const c = (prev && i >= bpp) ? prev[i - bpp] : 0;
      let v = line[i];
      if (filter === 1) {
        v += a;
      } else if (filter === 2) {
        v += b;
      } else if (filter === 3) {
        v += (a + b) >> 1;
      } else if (filter === 4) {
        const p = a + b - c;
        const pa = Math.abs(p - a);
        const pb = Math.abs(p - b);
        const pc = Math.abs(p - c);
        v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c);
      }
      cur[i] = v & 0xff;
    }
  }
  return new Bitmap(width, height, out);
}

// ---------------- PNG 编码（统一用 0 号滤波，逐行重编码） ----------------

export function encodePng(bmp: Bitmap): Buffer {
  const stride = bmp.width * 4;
  const raw = Buffer.alloc(bmp.height * (stride + 1));
  for (let y = 0; y < bmp.height; y++) {
    raw[y * (stride + 1)] = 0;
    bmp.data.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride);
  }

  const chunk = (type: string, data: Buffer): Buffer => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length, 0);
    const typed = Buffer.concat([Buffer.from(type, 'ascii'), data]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(typed), 0);
    return Buffer.concat([len, typed, crc]);
  };

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(bmp.width, 0);
  ihdr.writeUInt32BE(bmp.height, 4);
  ihdr[8] = 8;   // 位深
  ihdr[9] = 6;   // RGBA
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0))
  ]);
}
