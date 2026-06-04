import { deflateSync } from 'node:zlib';
import { writeFileSync } from 'node:fs';

const width = 2500;
const height = 843;
const png = Buffer.alloc(width * height * 4, 255);

const font = {
  A: ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
  B: ['11110', '10001', '10001', '11110', '10001', '10001', '11110'],
  C: ['01111', '10000', '10000', '10000', '10000', '10000', '01111'],
  D: ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
  E: ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
  F: ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
  G: ['01111', '10000', '10000', '10011', '10001', '10001', '01111'],
  H: ['10001', '10001', '10001', '11111', '10001', '10001', '10001'],
  I: ['11111', '00100', '00100', '00100', '00100', '00100', '11111'],
  J: ['00111', '00010', '00010', '00010', '00010', '10010', '01100'],
  K: ['10001', '10010', '10100', '11000', '10100', '10010', '10001'],
  L: ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
  M: ['10001', '11011', '10101', '10101', '10001', '10001', '10001'],
  N: ['10001', '11001', '10101', '10011', '10001', '10001', '10001'],
  O: ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
  P: ['11110', '10001', '10001', '11110', '10000', '10000', '10000'],
  Q: ['01110', '10001', '10001', '10001', '10101', '10010', '01101'],
  R: ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
  S: ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
  T: ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
  U: ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
  V: ['10001', '10001', '10001', '10001', '10001', '01010', '00100'],
  W: ['10001', '10001', '10001', '10101', '10101', '10101', '01010'],
  X: ['10001', '10001', '01010', '00100', '01010', '10001', '10001'],
  Y: ['10001', '10001', '01010', '00100', '00100', '00100', '00100'],
  Z: ['11111', '00001', '00010', '00100', '01000', '10000', '11111'],
  ' ': ['00000', '00000', '00000', '00000', '00000', '00000', '00000'],
};

function rgba(hex) {
  return [
    Number.parseInt(hex.slice(1, 3), 16),
    Number.parseInt(hex.slice(3, 5), 16),
    Number.parseInt(hex.slice(5, 7), 16),
    255,
  ];
}

function setPixel(x, y, color) {
  if (x < 0 || x >= width || y < 0 || y >= height) return;
  const offset = (y * width + x) * 4;
  png[offset] = color[0];
  png[offset + 1] = color[1];
  png[offset + 2] = color[2];
  png[offset + 3] = color[3];
}

function fillRect(x, y, w, h, color) {
  for (let row = y; row < y + h; row++) {
    for (let col = x; col < x + w; col++) {
      setPixel(col, row, color);
    }
  }
}

function fillRoundedRect(x, y, w, h, r, color) {
  for (let row = y; row < y + h; row++) {
    for (let col = x; col < x + w; col++) {
      const dx = col < x + r ? x + r - col : col >= x + w - r ? col - (x + w - r - 1) : 0;
      const dy = row < y + r ? y + r - row : row >= y + h - r ? row - (y + h - r - 1) : 0;
      if (dx * dx + dy * dy <= r * r) setPixel(col, row, color);
    }
  }
}

function textWidth(text, scale) {
  return text.length * 6 * scale - scale;
}

function drawText(text, x, y, scale, color) {
  let cursor = x;
  for (const raw of text) {
    const glyph = font[raw.toUpperCase()] ?? font[' '];
    glyph.forEach((line, row) => {
      [...line].forEach((bit, col) => {
        if (bit === '1') {
          fillRect(cursor + col * scale, y + row * scale, scale, scale, color);
        }
      });
    });
    cursor += 6 * scale;
  }
}

function drawCenteredText(text, y, scale, color) {
  drawText(text, Math.round((width - textWidth(text, scale)) / 2), y, scale, color);
}

const bg = rgba('#f7fbf8');
const green = rgba('#06c755');
const deep = rgba('#216b57');
const white = rgba('#ffffff');
const mint = rgba('#dff9e8');

fillRect(0, 0, width, height, bg);
fillRoundedRect(92, 86, 2316, 671, 56, green);
fillRoundedRect(146, 140, 2208, 563, 42, white);
fillRoundedRect(910, 568, 680, 112, 56, white);
fillRoundedRect(930, 588, 640, 72, 36, mint);
drawCenteredText('VEEVA MEMBER SYSTEM', 235, 14, deep);
drawCenteredText('OPEN LIFF TEST', 410, 16, green);
drawCenteredText('TAP TO START', 610, 9, deep);

const scanlines = Buffer.alloc((width * 4 + 1) * height);
for (let y = 0; y < height; y++) {
  const rowStart = y * (width * 4 + 1);
  scanlines[rowStart] = 0;
  png.copy(scanlines, rowStart + 1, y * width * 4, (y + 1) * width * 4);
}

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) {
      crc = crc & 1 ? 0xedb88320 ^ (crc >>> 1) : crc >>> 1;
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const typeBuffer = Buffer.from(type);
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuffer, data])));
  return Buffer.concat([length, typeBuffer, data, crc]);
}

const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(width, 0);
ihdr.writeUInt32BE(height, 4);
ihdr[8] = 8;
ihdr[9] = 6;

writeFileSync(
  new URL('./veeva-rich-menu-test.png', import.meta.url),
  Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(scanlines)),
    chunk('IEND', Buffer.alloc(0)),
  ]),
);
