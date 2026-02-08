const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const inputs = [
  'C:/Users/PGNK2128/Downloads/assets/maxime-photo.jpeg',
  'C:/Users/PGNK2128/Downloads/Maxime_Photo.jpeg',
  'C:/Users/PGNK2128/Downloads/Maxime_Photo.jpg'
];

const input = inputs.find((p) => fs.existsSync(p));
if (!input) {
  console.error('Input image not found.');
  process.exit(1);
}

const outputs = [
  'C:/Users/PGNK2128/Godot-MCP/docs/assets/maxime-portrait-round.png',
  'C:/Users/PGNK2128/Downloads/assets/maxime-portrait-round.png'
];

async function run() {
  const trimmedResult = await sharp(input)
    .ensureAlpha()
    .trim({ threshold: 12 })
    .toBuffer({ resolveWithObject: true });

  const { data, info } = trimmedResult;
  const size = Math.max(info.width, info.height);
  const padX = Math.floor((size - info.width) / 2);
  const padY = Math.floor((size - info.height) / 2);

  let image = sharp(data)
    .ensureAlpha()
    .extend({
      top: padY,
      bottom: size - info.height - padY,
      left: padX,
      right: size - info.width - padX,
      background: { r: 0, g: 0, b: 0, alpha: 0 }
    });

  const circleSvg = Buffer.from(
    `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
      <circle cx="${size / 2}" cy="${size / 2}" r="${size / 2}" fill="white" />
    </svg>`
  );
  const mask = await sharp(circleSvg).resize(size, size).png().toBuffer();

  const roundedBuffer = await image
    .composite([{ input: mask, blend: 'dest-in' }])
    .png()
    .toBuffer();

  for (const out of outputs) {
    const dir = path.dirname(out);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(out, roundedBuffer);
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
