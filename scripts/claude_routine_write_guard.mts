#!/usr/bin/env node
import { accessSync, constants, readFileSync, realpathSync, statSync } from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { object } from './claude_permissions.mts';
import { permissionSource, shellWord, WRAPPER, type PermissionSource } from './claude_routine_permissions.mts';

const loneCall = 'Hatsu routine write: prepare the payload file separately, then run one plain Nen write call. Use bare nen or the verified gh_token_env.sh -- nen form, without a shell wrapper, redirects, substitutions, or a joined command.';
type Scan = { parts: string[][]; complex: boolean };

// Recognize shell words and command boundaries without evaluating shell text.
function scan(command: string, level = 0): Scan {
  if (level > 32) return { parts: [], complex: true };
  const parts: string[][] = [];
  let words: string[] = [];
  let word = '';
  let started = false;
  let complex = false;
  let quote = '';
  let heredoc: 'normal' | 'strip-tabs' | '' = '';
  const delimiters: { text: string; stripTabs: boolean }[] = [];

  const finishWord = () => {
    if (!started) return;
    if (heredoc) {
      delimiters.push({ text: word, stripTabs: heredoc === 'strip-tabs' });
      heredoc = '';
    } else {
      words.push(word);
    }
    started = false;
    word = '';
  };
  const finishPart = () => {
    finishWord();
    if (words.length) parts.push(words);
    words = [];
  };
  const nested = (at: number, end: string) => {
    const start = at + (end === ')' ? 2 : 1);
    let depth = 1;
    let nestedQuote = '';
    let cursor = start;
    for (; cursor < command.length; cursor++) {
      const character = command[cursor];
      if (character === '\\' && nestedQuote !== "'") { cursor++; continue; }
      if (character === nestedQuote) { nestedQuote = ''; continue; }
      if (!nestedQuote && (character === "'" || character === '"')) { nestedQuote = character; continue; }
      if (nestedQuote) continue;
      if (character === '(' && end === ')') depth++;
      if (character === end && --depth === 0) break;
    }
    parts.push(...scan(command.slice(start, cursor), level + 1).parts);
    return cursor;
  };

  for (let at = 0; at < command.length; at++) {
    const c = command[at];
    const next = command[at + 1];
    if (c === quote) { quote = ''; continue; }
    if (quote === "'") { word += c; continue; }
    if (c === '\\') {
      started = true;
      if (next === '\n' || next === undefined) complex = true;
      if (next !== undefined && next !== '\n') word += next;
      at++;
      continue;
    }
    if ((c === '$' && next === '(') || c === '`') {
      started = true;
      complex = true;
      at = nested(at, c === '`' ? '`' : ')');
      continue;
    }
    if (quote) { word += c; continue; }
    if (c === "'" || c === '"') { quote = c; started = true; continue; }
    if (c === '#' && !started) {
      complex = true;
      const end = command.indexOf('\n', at);
      at = end < 0 ? command.length : end - 1;
      continue;
    }
    if (c === ' ' || c === '\t') { finishWord(); continue; }
    if (c === '<' && next === '<' && command[at + 2] !== '<') {
      finishPart();
      heredoc = command[at + 2] === '-' ? 'strip-tabs' : 'normal';
      at += heredoc === 'strip-tabs' ? 2 : 1;
      complex = true;
      continue;
    }
    if (';|&()<>\n\r'.includes(c)) {
      complex = true;
      finishPart();
      if (c === '\n') {
        for (const delimiter of delimiters.splice(0)) {
          let start = at + 1;
          while (start <= command.length) {
            const end = command.indexOf('\n', start);
            const line = command.slice(start, end < 0 ? command.length : end);
            at = end < 0 ? command.length : end;
            if ((delimiter.stripTabs ? line.replace(/^\t+/, '') : line) === delimiter.text || end < 0) break;
            start = end + 1;
          }
        }
      }
      continue;
    }
    started = true;
    word += c;
  }
  finishPart();
  return { parts, complex: complex || Boolean(quote) };
}

const shell = /^(?:sh|bash|dash|zsh|ksh)$/;
const commandPrefix = /^(?:command|env|exec|time|then|do|elif|if|while|until|!)$/;

function classify(words: string[], prefixes: string[][], depth: number): { wrapper?: string; canonical: boolean } | null {
  const direct = (argv: string[]) => prefixes.some((prefix) =>
    prefix.every((word, index) => (index === 0 ? basename(argv[index] ?? '') : argv[index]) === word));
  if (direct(words)) return { canonical: words[0] === 'nen' };
  if (!words.length || depth > 8) return null;
  if (basename(words[0]) === basename(WRAPPER)) {
    const nen = words.findIndex((word, index) => index > 0 && basename(word) === 'nen');
    if (nen > 0 && direct(words.slice(nen))) {
      return { wrapper: words[0], canonical: nen === 2 && words[1] === '--' && words[2] === 'nen' };
    }
  }
  if (commandPrefix.test(basename(words[0])) || /^[A-Za-z_][A-Za-z0-9_]*=/.test(words[0])) {
    const inner = classify(words.slice(1), prefixes, depth + 1);
    return inner && { ...inner, canonical: false };
  }
  if (shell.test(basename(words[0]))) {
    const commandFlag = words.findIndex((word, index) => index > 0 && /^-[a-z]*c[a-z]*$/.test(word));
    if (commandFlag > 0 && words[commandFlag + 1]) {
      const inner = scan(words[commandFlag + 1]).parts
        .map((part) => classify(part, prefixes, depth + 1)).find(Boolean);
      if (inner) return { ...inner, canonical: false };
    }
  }
  return null;
}

export function checkRoutineWrite(command: string, source: PermissionSource) {
  const prefixes = source.claude_routine_writes.map(({ prefix }) => prefix.split(' '));
  const scanned = scan(command.trim());
  const found = scanned.parts.map((part) => classify(part, prefixes, 0)).find(Boolean);
  if (!found) return { refusal: null, wrapper: null };
  const wrapper = found.wrapper ?? null;
  const spelling = wrapper ? `${shellWord(wrapper)} -- ` : '';
  const plain = prefixes.some((prefix) => {
    const start = `${spelling}${prefix.join(' ')}`;
    return command.trimStart() === start || command.trimStart().startsWith(`${start} `);
  });
  return { refusal: found.canonical && !scanned.complex && plain ? null : loneCall, wrapper };
}

export function verifyWrapper(wrapper: string, cwd: string, root: string): boolean {
  if (![WRAPPER, `./${WRAPPER}`].includes(wrapper) && !wrapper.startsWith('/')) return false;
  try {
    const installed = join(realpathSync(root), WRAPPER);
    const requested = resolve(realpathSync(cwd), wrapper);
    accessSync(requested, constants.X_OK);
    if (realpathSync(installed) !== installed || realpathSync(requested) !== requested) return false;
    const original = statSync(installed);
    const candidate = statSync(requested);
    return original.isFile() && candidate.isFile() && original.size === candidate.size &&
      readFileSync(requested).equals(readFileSync(installed));
  } catch {
    return false;
  }
}

export function checkHookInput(input: unknown, root: string): string | null {
  if (!object(input) || input.tool_name !== 'Bash' || !object(input.tool_input) ||
      typeof input.tool_input.command !== 'string') return null;
  const source = permissionSource(join(root, 'contracts/permissions.json'));
  const { refusal, wrapper } = checkRoutineWrite(input.tool_input.command, source);
  if (refusal) return refusal;
  if (wrapper && (typeof input.cwd !== 'string' || !verifyWrapper(wrapper, input.cwd, root))) {
    return 'Hatsu routine write: the requested token wrapper could not be verified against the installed Hatsu wrapper. Use the verified installed path or bare nen.';
  }
  return null;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const input = JSON.parse(readFileSync(0, 'utf8')) as unknown;
    const refusal = checkHookInput(input, dirname(dirname(fileURLToPath(import.meta.url))));
    if (refusal) {
      console.error(refusal);
      process.exitCode = 2;
    }
  } catch {
    console.error('Hatsu routine write: the command check could not read its input or catalogue');
    process.exitCode = 1;
  }
}
