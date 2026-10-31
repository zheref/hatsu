// One rounded tag drawn as SVG, so every tag on the desk shares a height, a corner radius
// and a fill whose text contrasts with it (white on each fill is at least 4.5:1, WCAG AA).

export type Tone =
  | 'accent' | 'ref' | 'success' | 'merged' | 'warning' | 'info' | 'surface' | 'code' | 'muted' | 'done' | 'blocked'

const TONES: Record<Tone, { bg: string; fg: string }> = {
  accent: { bg: '#B4532A', fg: '#FFFFFF' },
  ref: { bg: '#6D28D9', fg: '#FFFFFF' },
  success: { bg: '#15803D', fg: '#FFFFFF' },
  done: { bg: '#15803D', fg: '#FFFFFF' },
  merged: { bg: '#7E22CE', fg: '#FFFFFF' },
  warning: { bg: '#B45309', fg: '#FFFFFF' },
  info: { bg: '#1D4ED8', fg: '#FFFFFF' },
  surface: { bg: '#0F766E', fg: '#FFFFFF' },
  code: { bg: '#334155', fg: '#F1F5F9' },
  muted: { bg: '#334155', fg: '#E2E8F0' },
  // A path that cannot run yet, drawn as a button: the desktop's button grey with near-black text,
  // deliberately below contrast so it reads as unavailable. The one exception to the AA rule above.
  blocked: { bg: '#3A3A38', fg: '#1A1A19' },
}

/**
 * `fill` is a solid tag; `dotted` adds a dotted ring on the fill's own edge; `outline` is no fill and a
 * dimmed white ring; `line` is no fill and a full white ring, for a label on a filled surface.
 */
export type ChipStyle = 'fill' | 'dotted' | 'outline' | 'line'
/** `done` marks a completed stage; `progress` the stage in progress; `person` a stage the maintainer owns. */
export type ChipIcon = 'done' | 'progress' | 'person'
/** `sm` is every ordinary tag; `md` and `lg` headline one thing. Corners are the same at every size. */
export type ChipSize = 'sm' | 'md' | 'lg' | 'button'

const SIZES: Record<ChipSize, { height: number; pad: number; gap: number; icon: number; main: number; minor: number }> = {
  sm: { height: 20, pad: 8, gap: 4, icon: 10, main: 11, minor: 9 },
  md: { height: 23, pad: 9, gap: 4, icon: 11, main: 12, minor: 10 },
  lg: { height: 34, pad: 12, gap: 6, icon: 16, main: 17, minor: 13 },
  // The desktop's button: a blocked path drawn in a button's place.
  button: { height: 28, pad: 12, gap: 5, icon: 12, main: 13, minor: 11 },
}

export const CHIP_HEIGHT = SIZES.sm.height
const RADIUS = 6
const OUTLINE = '#FFFFFF'
// The meaning word's tint; a stage still to go draws its outline in the same tint.
const MINOR_OPACITY = 0.55
const SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif"
const MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"

const escape = (text: string) =>
  text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')

const clip = (text: string, max: number) => (text.length > max ? `${text.slice(0, max - 1)}…` : text)

// Monospace advances 0.6em; the sans estimate is held to its width with textLength.
const widthOf = (text: string, px: number, mono: boolean, bold: boolean) =>
  Math.ceil(text.length * px * (mono ? 0.6 : bold ? 0.6 : 0.56))

// Each glyph is drawn in a 10 x 10 cell, then placed and scaled to the chip's icon size.
function glyph(icon: ChipIcon, x: number, y: number, size: number, color: string): string {
  const shape =
    icon === 'done'
      ? // A checkmark.
        `<path d="M1 5l2.8 2.8L9 1.8" fill="none" stroke="${color}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>`
      : icon === 'progress'
        ? // A ring with its right half filled: under way, not done.
          `<circle cx="5" cy="5" r="4" fill="none" stroke="${color}" stroke-width="1.4"/><path d="M5 1a4 4 0 0 1 0 8z" fill="${color}"/>`
        : // A head over shoulders.
          `<g fill="${color}"><circle cx="5" cy="2" r="2.6"/><path d="M0 10.5a5 4.5 0 0 1 10 0z"/></g>`

  return `<g transform="translate(${x} ${y}) scale(${size / 10})">${shape}</g>`
}

export type Chip = { source: string; width: number; height: number; alt: string }

/**
 * A tag: `text` in the main size, and an optional `minor` word after it in a smaller
 * size (a stage's meaning), led by any `icons`. `mono` sets code names in a monospace face.
 */
export function chip(
  text: string,
  tone: Tone,
  options: { minor?: string; mono?: boolean; bold?: boolean; icons?: ChipIcon[]; style?: ChipStyle; size?: ChipSize } = {},
): Chip {
  const z = SIZES[options.size ?? 'sm']
  const main = clip(text, 56)
  const mono = options.mono ?? false
  const bold = options.bold ?? false
  const icons = options.icons ?? []
  const style = options.style ?? 'fill'
  const { bg } = TONES[tone]
  const fg = style === 'outline' || style === 'line' ? OUTLINE : TONES[tone].fg
  const mainW = widthOf(main, z.main, mono, bold)
  const minorW = options.minor ? widthOf(options.minor, z.minor, false, false) : 0
  const lead = icons.length * (z.icon + z.gap)
  const width = z.pad + lead + mainW + (options.minor ? z.gap + minorW : 0) + z.pad
  const height = z.height
  const baseline = height / 2 + z.main * 0.35
  const family = mono ? MONO : SANS

  // A stroke sits inside the box by half its width, on the fill's edge: no gap between them.
  const edge = `x="0.75" y="0.75" width="${width - 1.5}" height="${height - 1.5}" rx="${RADIUS}"`
  const body =
    style === 'outline' || style === 'line'
      ? `<rect ${edge} fill="none" stroke="${OUTLINE}" stroke-opacity="${style === 'line' ? 1 : MINOR_OPACITY}" stroke-width="1.5"/>`
      : style === 'dotted'
        ? `<rect ${edge} fill="${bg}" stroke="${OUTLINE}" stroke-width="1.5" stroke-dasharray="1.5 2" stroke-linecap="round"/>`
        : `<rect width="${width}" height="${height}" rx="${RADIUS}" fill="${bg}"/>`
  const glyphs = icons.map((icon, i) => glyph(icon, z.pad + i * (z.icon + z.gap), (height - z.icon) / 2, z.icon, fg)).join('')
  const minor = options.minor
    ? `<text x="${z.pad + lead + mainW + z.gap}" y="${baseline}" font-family="${SANS}" font-size="${z.minor}" fill="${fg}" fill-opacity="${MINOR_OPACITY}" textLength="${minorW}" lengthAdjust="spacingAndGlyphs">${escape(options.minor)}</text>`
    : ''
  const source =
    `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">` +
    body +
    glyphs +
    `<text x="${z.pad + lead}" y="${baseline}" font-family="${family}" font-size="${z.main}" font-weight="${bold ? 700 : 500}" fill="${fg}" textLength="${mainW}" lengthAdjust="spacingAndGlyphs">${escape(main)}</text>` +
    minor +
    `</svg>`

  return { source, width, height, alt: options.minor ? `${main} (${options.minor})` : main }
}
