import assert from 'node:assert/strict'
import type { RegisterCase } from './register-case.ts'

import { CHIP_HEIGHT, chip } from '../chip.ts'
import type { Tone } from '../chip.ts'

const TONES: Tone[] = ['accent', 'ref', 'success', 'merged', 'warning', 'info', 'surface', 'code', 'muted', 'done']

const luminance = (hex: string) => {
  const [r, g, b] = [1, 3, 5].map(i => {
    const c = parseInt(hex.slice(i, i + 2), 16) / 255
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
  })
  return 0.2126 * r! + 0.7152 * g! + 0.0722 * b!
}

export function chipCases(test: RegisterCase): void {
  test('every tone draws one height and one corner radius', () => {
    for (const tone of TONES) {
      const c = chip('label', tone)
      assert.equal(c.height, CHIP_HEIGHT)
      assert.ok(c.source.includes(`height="${CHIP_HEIGHT}" rx="6"`))
    }
  })

  test('every tone keeps its text at WCAG AA contrast or better', () => {
    for (const tone of TONES) {
      const source = chip('label', tone).source
      const bg = /<rect[^>]*fill="(#[0-9A-F]{6})"/.exec(source)![1]!
      const fg = /<text[^>]*fill="(#[0-9A-F]{6})"/.exec(source)![1]!
      const [hi, lo] = [luminance(bg), luminance(fg)].sort((a, b) => b - a)
      assert.ok((hi! + 0.05) / (lo! + 0.05) >= 4.5)
    }
  })

  test('a stage chip carries its meaning in a smaller second word', () => {
    const c = chip('ren', 'accent', { minor: 'build', bold: true })
    assert.ok(c.source.includes('font-size="9"'))
    assert.ok(c.source.includes('>build</text>'))
    assert.equal(c.alt, 'ren (build)')
  })

  test('text is escaped and long code names are clipped', () => {
    assert.ok(chip('a<b&c', 'code', { mono: true }).source.includes('a&lt;b&amp;c'))
    assert.equal(chip('x'.repeat(80), 'code', { mono: true }).alt.length, 56)
  })

  test('the current stage draws its dotted ring on the fill edge, led by the progress glyph', () => {
    const c = chip('ren', 'accent', { minor: 'build', bold: true, style: 'dotted', icons: ['progress'] })
    assert.equal(c.height, CHIP_HEIGHT)
    // One rect carries both fill and dotted stroke, so nothing sits between them.
    assert.match(c.source, /<rect [^>]*fill="#B4532A" stroke="#FFFFFF"[^>]*stroke-dasharray/)
    assert.equal(c.source.match(/<rect /g)!.length, 1)
    assert.ok(c.source.includes('<circle'))
    assert.ok(!chip('ren', 'accent').source.includes('stroke-dasharray'))
  })

  test('a stage still to go has no fill and a straight white outline', () => {
    const c = chip('aka', 'muted', { minor: 'publish', style: 'outline' })
    assert.match(c.source, /<rect [^>]*fill="none" stroke="#FFFFFF"/)
    assert.ok(!c.source.includes('stroke-dasharray'))
    assert.ok(c.source.includes('font-weight="500" fill="#FFFFFF"'))
  })

  test('a label on a filled surface has no fill and a full white ring', () => {
    const c = chip('Next step', 'info', { style: 'line' })
    assert.match(c.source, /<rect [^>]*fill="none" stroke="#FFFFFF" stroke-opacity="1"/)
    assert.ok(c.source.includes('fill="#FFFFFF"'))
    assert.ok(!c.source.includes('#1D4ED8'))
  })

  test('a completed stage leads with a checkmark and widens to fit it', () => {
    const plain = chip('ten', 'done', { minor: 'warm-up' })
    const checked = chip('ten', 'done', { minor: 'warm-up', icons: ['done'] })
    assert.ok(checked.source.includes('stroke-linejoin="round"'))
    assert.equal(checked.width, plain.width + 14)
    assert.equal(checked.height, CHIP_HEIGHT)
  })

  test('headline sizes grow the chip and its glyphs but keep the corners', () => {
    const sm = chip('ren', 'accent', { icons: ['progress'] })
    const md = chip('This session', 'accent', { size: 'md' })
    const lg = chip('ren', 'accent', { size: 'lg', icons: ['progress'] })
    assert.deepEqual([sm.height, md.height, lg.height], [20, 23, 34])
    for (const c of [sm, md, lg]) assert.ok(c.source.includes('rx="6"'))
    assert.ok(lg.source.includes('scale(1.6)'))
    assert.ok(lg.width > sm.width)
  })

  test('a blocked path is a button-sized chip with near-black text on the button grey', () => {
    const c = chip('Publish', 'blocked', { size: 'button' })
    assert.equal(c.height, 28)
    assert.ok(c.source.includes('fill="#3A3A38"'))
    assert.ok(c.source.includes('fill="#1A1A19"'))
  })
}
