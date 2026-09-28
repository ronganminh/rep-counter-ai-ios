// RepCoach AI app icon — Concept 2 "Vòng đếm + khớp" (bản cuối).
// Source of truth: design-handoff/design/app-icon.dc.html (section #c2 + #play).
//
// Geometry on a 100 × 100 grid, centre (50, 50):
//   ring   r = 30, stroke 10, round caps, 300° clockwise from 12 o'clock
//          (60° gap at top-left, 210°–270°)
//   joint  centre (24.02, 35), r = 9, 3.5 background-coloured outline
//   colour #C8FF2E on a diagonal gradient #18181B → #0B0B0C
// Android adaptive layers use a 108 × 108 grid with the glyph translated (4, 4).

export const LIME = '#C8FF2E';
export const BG_TOP = '#18181B';
export const BG_BOTTOM = '#0B0B0C';
export const DOT_OUTLINE = '#0F0F11';

const RING = 'M50 20 A30 30 0 1 1 24.02 35';
const DOT = { cx: 24.02, cy: 35, r: 9, outline: 3.5 };

const gradient = (id) =>
  `<linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1">` +
  `<stop offset="0" stop-color="${BG_TOP}"/><stop offset="1" stop-color="${BG_BOTTOM}"/></linearGradient>`;

// Glyph on an opaque background: the joint's outline is painted in `outline`,
// exactly as in the design file.
export function glyphPainted(color = LIME, outline = DOT_OUTLINE) {
  return (
    `<path d="${RING}" stroke="${color}" stroke-width="10" stroke-linecap="round" fill="none"/>` +
    `<circle cx="${DOT.cx}" cy="${DOT.cy}" r="${DOT.r}" fill="${color}" stroke="${outline}" stroke-width="${DOT.outline}"/>`
  );
}

// Glyph for transparent layers: the joint's outline is cut out of the ring
// instead of painted, so it reads correctly on any wallpaper or system tint.
// Visually identical: lime dot r = 7.25, clear gap out to r = 10.75.
export function glyphKnockout(id, color = LIME) {
  const inner = DOT.r - DOT.outline / 2;
  const outer = DOT.r + DOT.outline / 2;
  return (
    `<defs><mask id="${id}" maskUnits="userSpaceOnUse" x="-10" y="-10" width="120" height="120">` +
    `<rect x="-10" y="-10" width="120" height="120" fill="#fff"/>` +
    `<circle cx="${DOT.cx}" cy="${DOT.cy}" r="${outer}" fill="#000"/></mask></defs>` +
    `<path d="${RING}" stroke="${color}" stroke-width="10" stroke-linecap="round" fill="none" mask="url(#${id})"/>` +
    `<circle cx="${DOT.cx}" cy="${DOT.cy}" r="${inner}" fill="${color}"/>`
  );
}

const svg = (viewBox, body) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}">${body}</svg>\n`;

// Square, full-bleed, no rounding (App Store / Play Store masks it).
export const iosIcon = () =>
  svg('0 0 100 100', `<defs>${gradient('bg')}</defs><rect width="100" height="100" fill="url(#bg)"/>${glyphPainted()}`);

// iOS 18 dark appearance: glyph only, transparent background.
export const iosDark = () => svg('0 0 100 100', glyphKnockout('cut'));

// iOS 18 tinted appearance: light grey glyph on black.
export const iosTinted = () =>
  svg('0 0 100 100', `<rect width="100" height="100" fill="#000"/>${glyphPainted('#DADAD2', '#000')}`);

// Android adaptive layers (108 dp canvas).
export const androidForeground = () =>
  svg('0 0 108 108', `<g transform="translate(4 4)">${glyphKnockout('cut')}</g>`);
export const androidBackground = () =>
  svg('0 0 108 108', `<defs>${gradient('bg')}</defs><rect width="108" height="108" fill="url(#bg)"/>`);
export const androidMonochrome = () =>
  svg('0 0 108 108', `<g transform="translate(4 4)">${glyphKnockout('cut', '#FFFFFF')}</g>`);

// Pre-O legacy launcher icons: the 72 dp visible area, masked like the
// design's "Bo góc" (rx 14 / 72) and "Tròn" previews.
function androidLegacy(clip) {
  return svg(
    '18 18 72 72',
    `<defs>${gradient('bg')}<clipPath id="m">${clip}</clipPath></defs>` +
      `<g clip-path="url(#m)"><rect width="108" height="108" fill="url(#bg)"/>` +
      `<g transform="translate(4 4)">${glyphPainted()}</g></g>`
  );
}
export const androidLegacySquare = () => androidLegacy('<rect x="18" y="18" width="72" height="72" rx="14"/>');
export const androidLegacyRound = () => androidLegacy('<circle cx="54" cy="54" r="36"/>');

// In-app mark shown next to the "RepCoach AI" wordmark (1.3em), as used on
// every design page: #141416 tile with a 10 % white hairline.
export const brandMark = () =>
  svg(
    '0 0 100 100',
    `<rect width="100" height="100" rx="22.37" fill="#141416"/>` +
      `<rect x="0.5" y="0.5" width="99" height="99" rx="22" fill="none" stroke="#FFFFFF" stroke-opacity="0.10"/>` +
      glyphPainted(LIME, '#141416')
  );

// Glyph alone on transparent — for splash screens and custom placements.
export const brandGlyph = () => svg('0 0 100 100', glyphKnockout('cut'));

// Splash: glyph centred on #0B0B0C. The 100-grid glyph is drawn at 720 px
// inside 1152 px, so its furthest point (r 40.75) stays inside Android 12's
// 768 px icon circle.
export const splash = () =>
  svg('0 0 1152 1152', `<rect width="1152" height="1152" fill="${BG_BOTTOM}"/><g transform="translate(216 216) scale(7.2)">${glyphPainted(LIME, BG_BOTTOM)}</g>`);
