// Renders every RepCoach AI app-icon asset listed in DESIGN_HANDOFF.md §9.1.
//
//   node tool/app_icon/generate.mjs
//
// Needs Playwright (Chromium) and Python 3 with Pillow (used to strip the
// alpha channel from files the stores require to be opaque).
import { mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';
import * as G from './glyph.mjs';

const require = createRequire(import.meta.url);
let chromium;
try {
  ({ chromium } = require('playwright'));
} catch {
  const globalRoot = execFileSync('npm', ['root', '-g']).toString().trim();
  ({ chromium } = require(join(globalRoot, 'playwright')));
}

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const out = (p) => {
  const full = join(ROOT, p);
  mkdirSync(dirname(full), { recursive: true });
  return full;
};
const opaque = [];

const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: 1 });

async function renderSvg(svgText, size, file, { flatten = false } = {}) {
  await page.setViewportSize({ width: size, height: size });
  const sized = svgText.replace('<svg ', `<svg width="${size}" height="${size}" `);
  await page.setContent(
    `<!doctype html><style>html,body{margin:0;background:transparent}svg{display:block}</style>${sized}`
  );
  await page.screenshot({ path: out(file), omitBackground: true, clip: { x: 0, y: 0, width: size, height: size } });
  if (flatten) opaque.push(out(file));
}

function writeText(file, text) {
  writeFileSync(out(file), text);
}

// ── Vector masters ───────────────────────────────────────────────────────────
const masters = {
  'ios-icon.svg': G.iosIcon(),
  'ios-dark.svg': G.iosDark(),
  'ios-tinted.svg': G.iosTinted(),
  'android-foreground.svg': G.androidForeground(),
  'android-background.svg': G.androidBackground(),
  'android-monochrome.svg': G.androidMonochrome(),
  'android-legacy.svg': G.androidLegacySquare(),
  'android-legacy-round.svg': G.androidLegacyRound(),
};
for (const [name, text] of Object.entries(masters)) writeText(`assets/icon/master/${name}`, text);
writeText('assets/brand/mark.svg', G.brandMark());
writeText('assets/brand/glyph.svg', G.brandGlyph());

// ── iOS ──────────────────────────────────────────────────────────────────────
await renderSvg(G.iosIcon(), 1024, 'assets/icon/ios/AppIcon-1024.png', { flatten: true });
await renderSvg(G.iosDark(), 1024, 'assets/icon/ios/AppIcon-dark-1024.png');
await renderSvg(G.iosTinted(), 1024, 'assets/icon/ios/AppIcon-tinted-1024.png', { flatten: true });

// Drop-in asset catalog (Xcode 15+, single size with iOS 18 appearances).
const set = 'assets/icon/ios/AppIcon.appiconset';
await renderSvg(G.iosIcon(), 1024, `${set}/AppIcon-1024.png`, { flatten: true });
await renderSvg(G.iosDark(), 1024, `${set}/AppIcon-dark-1024.png`);
await renderSvg(G.iosTinted(), 1024, `${set}/AppIcon-tinted-1024.png`, { flatten: true });
writeText(
  `${set}/Contents.json`,
  JSON.stringify(
    {
      images: [
        { filename: 'AppIcon-1024.png', idiom: 'universal', platform: 'ios', size: '1024x1024' },
        {
          appearances: [{ appearance: 'luminosity', value: 'dark' }],
          filename: 'AppIcon-dark-1024.png',
          idiom: 'universal',
          platform: 'ios',
          size: '1024x1024',
        },
        {
          appearances: [{ appearance: 'luminosity', value: 'tinted' }],
          filename: 'AppIcon-tinted-1024.png',
          idiom: 'universal',
          platform: 'ios',
          size: '1024x1024',
        },
      ],
      info: { author: 'xcode', version: 1 },
    },
    null,
    2
  ) + '\n'
);

// ── Android ──────────────────────────────────────────────────────────────────
// xxxhdpi layers for flutter_launcher_icons.
await renderSvg(G.androidForeground(), 432, 'assets/icon/android/ic_launcher_foreground.png');
await renderSvg(G.androidBackground(), 432, 'assets/icon/android/ic_launcher_background.png', { flatten: true });
await renderSvg(G.androidMonochrome(), 432, 'assets/icon/android/ic_launcher_monochrome.png');

// Ready-made res/ tree for projects that don't run the generator.
const densities = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
for (const [d, k] of Object.entries(densities)) {
  const res = `assets/icon/android/res/mipmap-${d}`;
  await renderSvg(G.androidForeground(), 108 * k, `${res}/ic_launcher_foreground.png`);
  await renderSvg(G.androidBackground(), 108 * k, `${res}/ic_launcher_background.png`, { flatten: true });
  await renderSvg(G.androidMonochrome(), 108 * k, `${res}/ic_launcher_monochrome.png`);
  await renderSvg(G.androidLegacySquare(), 48 * k, `${res}/ic_launcher.png`);
  await renderSvg(G.androidLegacyRound(), 48 * k, `${res}/ic_launcher_round.png`);
}
const adaptive =
  '<?xml version="1.0" encoding="utf-8"?>\n' +
  '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n' +
  '    <background android:drawable="@mipmap/ic_launcher_background" />\n' +
  '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n' +
  '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n' +
  '</adaptive-icon>\n';
writeText('assets/icon/android/res/mipmap-anydpi-v26/ic_launcher.xml', adaptive);
writeText('assets/icon/android/res/mipmap-anydpi-v26/ic_launcher_round.xml', adaptive);

// ── Google Play ──────────────────────────────────────────────────────────────
await renderSvg(G.iosIcon(), 512, 'play/icon-512.png', { flatten: true });

const iconTile = G.iosIcon()
  .replace('<svg ', '<svg width="280" height="280" style="display:block" ')
  .replace('<rect width="100" height="100" fill', '<rect width="100" height="100" rx="22.37" fill');
const watermark =
  `<svg width="620" height="620" viewBox="0 0 100 100" style="position:absolute;right:-150px;top:-60px;opacity:0.06">` +
  `<path d="M50 20 A30 30 0 1 1 24.02 35" stroke="${G.LIME}" stroke-width="4" stroke-linecap="round" fill="none"/></svg>`;
// Headless Chromium may not reach Google Fonts directly, so fetch the CSS and
// font files with curl (which honours the environment's proxy) and inline them.
const curl = (url, binary = false) =>
  execFileSync('curl', ['-sSfL', '-A', 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/140 Safari/537.36', url], {
    encoding: binary ? 'buffer' : 'utf8',
    maxBuffer: 64 * 1024 * 1024,
  });
const fontCss = curl(
  'https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@800&family=Inter:wght@500&display=block'
).replace(/url\((https:[^)]+)\)/g, (_, url) => `url(data:font/woff2;base64,${curl(url, true).toString('base64')})`);

await page.setViewportSize({ width: 1024, height: 500 });
await page.setContent(`<!doctype html><html><head><meta charset="utf-8">
<style>${fontCss}</style>
<style>html,body{margin:0}*{box-sizing:border-box}body{-webkit-font-smoothing:antialiased;color:#F4F4F0}</style></head><body>
<div style="position:relative;width:1024px;height:500px;overflow:hidden;background:linear-gradient(120deg,#161618 0%,#0B0B0C 60%);display:flex;align-items:center;gap:56px;padding:0 88px">
 ${watermark}
 <div style="flex:none;border-radius:64px;box-shadow:0 30px 60px rgba(0,0,0,0.5),0 0 0 1px rgba(255,255,255,0.08);overflow:hidden">${iconTile}</div>
 <div style="position:relative;display:flex;flex-direction:column;gap:22px;min-width:0">
  <span style="font:800 96px/0.9 'Barlow Condensed';text-transform:uppercase;letter-spacing:-0.005em;white-space:nowrap">RepCoach<span style="color:${G.LIME};margin-left:0.18em">AI</span></span>
  <span style="font:500 28px/1.35 Inter;color:#C9C9CE;text-wrap:balance;max-width:520px">Đếm rep bằng camera. AI nhận xét sau mỗi buổi.</span>
 </div>
</div></body></html>`, { waitUntil: 'networkidle' });
const fontsOk = await page.evaluate(async () => {
  await document.fonts.ready;
  const loaded = [...document.fonts].filter((f) => f.status === 'loaded').map((f) => f.family.replace(/"/g, ''));
  return loaded.includes('Barlow Condensed') && loaded.includes('Inter');
});
if (!fontsOk) throw new Error('Barlow Condensed / Inter did not load — feature graphic would use fallback fonts.');
await page.screenshot({ path: out('play/feature-graphic-1024x500.png'), clip: { x: 0, y: 0, width: 1024, height: 500 } });
opaque.push(out('play/feature-graphic-1024x500.png'));

// ── Splash (flutter_native_splash) ───────────────────────────────────────────
await renderSvg(G.splash(), 1152, 'assets/brand/splash.png', { flatten: true });

await browser.close();

// Stores reject icons with an alpha channel: flatten the opaque ones to RGB.
execFileSync('python3', [
  '-c',
  'import sys\nfrom PIL import Image\nfor p in sys.argv[1:]:\n    Image.open(p).convert("RGB").save(p, optimize=True)',
  ...opaque,
]);

console.log('App icon assets written.');
