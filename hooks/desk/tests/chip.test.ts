import { expect, test } from 'claude-code/testing'

import { CHIP_HEIGHT, chip } from '../chip'
import type { Tone } from '../chip'

const TONES: Tone[] = ['accent', 'ref', 'success', 'merged', 'warning', 'info', 'surface', 'code', 'muted', 'done']

const luminance = (hex: string) => {
  const [r, g, b] = [1, 3, 5].map(i => {
    const c = parseInt(hex.slice(i, i + 2), 16) / 255
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
  })
  return 0.2126 * r! + 0.7152 * g! + 0.0722 * b!
}

test('every tone draws one height and one corner radius', async () => {
  for (const tone of TONES) {
    const c = chip('label', tone)
    expect(c.height).toBe(CHIP_HEIGHT)
    expect(c.source).toContain(`height="${CHIP_HEIGHT}" rx="6"`)
  }
})

test('every tone keeps its text at WCAG AA contrast or better', async () => {
  for (const tone of TONES) {
    const source = chip('label', tone).source
    const bg = /<rect[^>]*fill="(#[0-9A-F]{6})"/.exec(source)![1]!
    const fg = /<text[^>]*fill="(#[0-9A-F]{6})"/.exec(source)![1]!
    const [hi, lo] = [luminance(bg), luminance(fg)].sort((a, b) => b - a)
    expect((hi! + 0.05) / (lo! + 0.05)).toBeGreaterThanOrEqual(4.5)
  }
})

test('a stage chip carries its meaning in a smaller second word', async () => {
  const c = chip('ren', 'accent', { minor: 'build', bold: true })
  expect(c.source).toContain('font-size="9"')
  expect(c.source).toContain('>build</text>')
  expect(c.alt).toBe('ren (build)')
})

test('text is escaped and long code names are clipped', async () => {
  expect(chip('a<b&c', 'code', { mono: true }).source).toContain('a&lt;b&amp;c')
  expect(chip('x'.repeat(80), 'code', { mono: true }).alt.length).toBe(56)
})

test('the current stage draws its dotted ring on the fill edge, led by the progress glyph', async () => {
  const c = chip('ren', 'accent', { minor: 'build', bold: true, style: 'dotted', icons: ['progress'] })
  expect(c.height).toBe(CHIP_HEIGHT)
  // One rect carries both fill and dotted stroke, so nothing sits between them.
  expect(c.source).toMatch(/<rect [^>]*fill="#B4532A" stroke="#FFFFFF"[^>]*stroke-dasharray/)
  expect(c.source.match(/<rect /g)!.length).toBe(1)
  expect(c.source).toContain('<circle')
  expect(chip('ren', 'accent').source).not.toContain('stroke-dasharray')
})

test('a stage still to go has no fill and a straight white outline', async () => {
  const c = chip('aka', 'muted', { minor: 'publish', style: 'outline' })
  expect(c.source).toMatch(/<rect [^>]*fill="none" stroke="#FFFFFF"/)
  expect(c.source).not.toContain('stroke-dasharray')
  expect(c.source).toContain('font-weight="500" fill="#FFFFFF"')
})

test('a label on a filled surface has no fill and a full white ring', async () => {
  const c = chip('Next step', 'info', { style: 'line' })
  expect(c.source).toMatch(/<rect [^>]*fill="none" stroke="#FFFFFF" stroke-opacity="1"/)
  expect(c.source).toContain('fill="#FFFFFF"')
  expect(c.source).not.toContain('#1D4ED8')
})

test('a completed stage leads with a checkmark and widens to fit it', async () => {
  const plain = chip('ten', 'done', { minor: 'warm-up' })
  const checked = chip('ten', 'done', { minor: 'warm-up', icons: ['done'] })
  expect(checked.source).toContain('stroke-linejoin="round"')
  expect(checked.width).toBe(plain.width + 14)
  expect(checked.height).toBe(CHIP_HEIGHT)
})

test('headline sizes grow the chip and its glyphs but keep the corners', async () => {
  const sm = chip('ren', 'accent', { icons: ['progress'] })
  const md = chip('This session', 'accent', { size: 'md' })
  const lg = chip('ren', 'accent', { size: 'lg', icons: ['progress'] })
  expect([sm.height, md.height, lg.height]).toEqual([20, 23, 34])
  for (const c of [sm, md, lg]) expect(c.source).toContain('rx="6"')
  expect(lg.source).toContain('scale(1.6)')
  expect(lg.width).toBeGreaterThan(sm.width)
})

test('a blocked path is a button-sized chip with near-black text on the button grey', async () => {
  const c = chip('Publish', 'blocked', { size: 'button' })
  expect(c.height).toBe(28)
  expect(c.source).toContain('fill="#3A3A38"')
  expect(c.source).toContain('fill="#1A1A19"')
})
