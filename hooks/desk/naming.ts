// Turns an effort id (a branch slug such as `opus/kurapika/ha-473-delegate-bounded-waits-v2`
// or `claude/hatsu-session-dashboard-06b5c3`) into something a person reads.

export type EffortName = {
  title: string
  ref: string | null
  surface: string | null
  model: string | null
  persona: string | null
}

const SURFACES: Record<string, string> = {
  claude: 'Claude Code',
  'claude-code': 'Claude Code',
  codex: 'Codex',
  cursor: 'Cursor',
  antigravity: 'Antigravity',
}

const MODELS = new Set([
  'opus', 'fable', 'sonnet', 'haiku', 'sol', 'gpt', 'astra', 'argon', 'grok', 'gemini',
])

const PERSONAS = new Set([
  'kurapika', 'gon', 'hisoka', 'phinks', 'uvogin', 'feitan', 'chrollo', 'illumi', 'netero',
  'nobunaga', 'shalnark', 'leorio', 'shizuku', 'satotz', 'lippo', 'buhara', 'bisky',
])

const capital = (word: string) => (word ? word[0]!.toUpperCase() + word.slice(1) : word)

export function humanize(slug: string): string {
  const words = slug
    .replace(/-[0-9a-f]{6}$/, '')
    .split(/[-_]+/)
    .filter(Boolean)
  if (words.length === 0) {
    return slug
  }

  return [capital(words[0]!), ...words.slice(1)].join(' ')
}

export function parseEffort(id: string): EffortName {
  const parts = id.split('/').filter(Boolean)
  let surface: string | null = null
  let model: string | null = null
  let persona: string | null = null
  const rest: string[] = []
  for (const [i, part] of parts.entries()) {
    const key = part.toLowerCase()
    const isLast = i === parts.length - 1
    if (!isLast && surface === null && key in SURFACES) {
      surface = SURFACES[key]!
    } else if (!isLast && model === null && MODELS.has(key)) {
      model = key
    } else if (!isLast && persona === null && PERSONAS.has(key)) {
      persona = capital(key)
    } else {
      rest.push(part)
    }
  }

  const slug = rest[rest.length - 1] ?? id
  const issue = /^([a-z]{2})-(?:is-)?#?(\d+)(?:-(.*))?$/i.exec(decodeURIComponent(slug))
  if (issue) {
    const ref = `${issue[1]!.toUpperCase()}#${issue[2]}`
    return { title: issue[3] ? humanize(issue[3]) : `Issue ${ref}`, ref, surface, model, persona }
  }

  return { title: humanize(slug), ref: null, surface, model, persona }
}

/** `nen repo resolve` prints `owner/name  (CODE)  via origin`. */
export function repoCode(resolved: string): { slug: string; code: string } | null {
  const match = /^(\S+\/\S+)\s+\(([A-Z]+)\)/m.exec(resolved)

  return match ? { slug: match[1]!, code: match[2]! } : null
}

export const ago = (min: number) =>
  min < 1 ? 'just now' : min < 60 ? `${min}m` : min < 1440 ? `${Math.floor(min / 60)}h` : `${Math.floor(min / 1440)}d`

export const short = (text: string | null, n: number) =>
  text === null ? '' : text.length > n ? `${text.slice(0, n - 1)}…` : text

/** A worktree's identifying folder. Codex nests each as `<name>/<repo>`, so a last folder that only
 * repeats the repository's name gives way to its parent: `ha-148-coverage-audit/hatsu` → `ha-148-coverage-audit`. */
export function worktreeName(path: string, repoFolder: string): string {
  const parts = path.split('/').filter(Boolean)
  const last = parts[parts.length - 1] ?? path

  return last === repoFolder && parts.length > 1 ? parts[parts.length - 2]! : last
}
