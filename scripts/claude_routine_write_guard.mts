#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { accessSync, constants, lstatSync, readFileSync, readdirSync, realpathSync, statSync } from 'node:fs';
import { basename, dirname, isAbsolute, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { object } from './claude_permissions.mts';
import { permissionSource, shellWord, WRAPPER, type PermissionSource } from './claude_routine_permissions.mts';

const loneCall = 'Hatsu routine write: prepare the payload separately and run one plain Nen write call. Use bare nen, the verified gh_token_env.sh -- nen form, or Ten’s verified session binding with the installed wrapper.';
type Scan = { parts: string[][]; complex: boolean };
type Command = { wrapper?: string; session?: string; canonical: boolean };
const shell = /^(?:sh|bash|dash|zsh|ksh)$/;

// Recognize shell words and command boundaries without evaluating shell text.
function scan(command: string, level = 0, expansionOnly = false): Scan {
  if (level > 32) return { parts: [], complex: true };
  const parts: string[][] = [];
  let words: string[] = [];
  let word = '';
  let started = false;
  let complex = false;
  let quote = '';
  let quotedWord = false;
  let redirect = '';
  let pipeline = 0;
  const shellsReadingInput = new Set<number>();
  const delimiters: { text: string; stripTabs: boolean; quoted: boolean; pipeline: number }[] = [];
  const hereStrings: { text: string; pipeline: number }[] = [];

  const finishWord = () => {
    if (!started) return;
    if (redirect) {
      if (redirect === '<<' || redirect === '<<-') delimiters.push({ text: word, stripTabs: redirect === '<<-', quoted: quotedWord, pipeline });
      if (redirect === '<<<') hereStrings.push({ text: word, pipeline });
      redirect = '';
    } else {
      words.push(word);
    }
    started = false;
    quotedWord = false;
    word = '';
  };
  const finishPart = () => {
    finishWord();
    if (words.length) {
      if (shellReadsInput(unwrap(words))) shellsReadingInput.add(pipeline);
      parts.push(words);
    }
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
    if (expansionOnly) {
      if (c === '\\') at++;
      else if ((c === '$' && next === '(') || c === '`') at = nested(at, c === '`' ? '`' : ')');
      continue;
    }
    if (c === quote) { quote = ''; continue; }
    if (quote === "'") { word += c; continue; }
    if (c === '\\') {
      started = true;
      quotedWord = true;
      if (next === '\n' || next === undefined) complex = true;
      if (next !== undefined && next !== '\n') word += next;
      at++;
      continue;
    }
    if ((c === '$' && next === '(') || c === '`' || (!quote && (c === '<' || c === '>') && next === '(')) {
      started = true;
      complex = true;
      at = nested(at, c === '`' ? '`' : ')');
      continue;
    }
    if (quote) { word += c; continue; }
    if (c === "'" || c === '"') { quote = c; quotedWord = true; started = true; continue; }
    if (c === '#' && !started) {
      complex = true;
      const end = command.indexOf('\n', at);
      at = end < 0 ? command.length : end - 1;
      continue;
    }
    if (c === ' ' || c === '\t') { finishWord(); continue; }
    if (c === '<' || c === '>' || (c === '&' && next === '>')) {
      if (started && !quotedWord && /^\d+$/.test(word)) { word = ''; started = false; }
      else finishWord();
      redirect = /^(?:<<<|<<-|<<|<>|<&|>>|>\||>&|&>>|&>|[<>])/.exec(command.slice(at))![0];
      at += redirect.length - 1;
      complex = true;
      continue;
    }
    if (';|&()\n\r'.includes(c)) {
      complex = true;
      finishPart();
      if (c !== '|' || next === '|') pipeline++;
      if (c === '|' && next === '&') at++;
      if (c === '\n') {
        for (const body of hereStrings.splice(0)) {
          if (shellsReadingInput.has(body.pipeline)) parts.push(...scan(body.text, level + 1).parts);
        }
        for (const delimiter of delimiters.splice(0)) {
          let start = at + 1;
          const body: string[] = [];
          while (start <= command.length) {
            const end = command.indexOf('\n', start);
            const line = command.slice(start, end < 0 ? command.length : end);
            at = end < 0 ? command.length : end;
            if ((delimiter.stripTabs ? line.replace(/^\t+/, '') : line) === delimiter.text) break;
            body.push(line);
            if (end < 0) break;
            start = end + 1;
          }
          const executesInput = shellsReadingInput.has(delimiter.pipeline);
          if (executesInput || !delimiter.quoted) parts.push(...scan(body.join('\n'), level + 1, !executesInput).parts);
        }
        shellsReadingInput.clear();
      }
      continue;
    }
    started = true;
    word += c;
  }
  finishPart();
  for (const body of hereStrings) if (shellsReadingInput.has(body.pipeline)) parts.push(...scan(body.text, level + 1).parts);
  return { parts, complex: complex || Boolean(quote) };
}

const wrappers: Record<string, RegExp> = {
  command: /^$/, builtin: /^$/, noglob: /^$/, nohup: /^$/,
  exec: /^(?:-a)$/, env: /^(?:-u|-C|--unset|--chdir)$/,
  time: /^(?:-f|-o|--format|--output)$/,
  timeout: /^(?:-s|-k|--signal|--kill-after)$/,
  nice: /^(?:-n|--adjustment)$/,
  stdbuf: /^(?:-[ioe]|--input|--output|--error)$/,
  xargs: /^(?:-[aEILnPs]|--arg-file|--eof|--replace|--max-lines|--max-args|--max-procs|--max-chars|--delimiter|-d)$/,
};
const shellPrefix = /^(?:then|do|elif|if|while|until|!)$/;

function shellReadsInput(words: string[]): boolean {
  if (!shell.test(basename(words[0] ?? ''))) return false;
  for (const arg of words.slice(1)) {
    if (arg === '--') continue;
    if (!arg.startsWith('-')) return false;
    if (/^-[a-z]*c[a-z]*$/.test(arg)) return false;
    if (/^-[a-z]*s[a-z]*$/.test(arg)) return true;
  }
  return true;
}

function unwrap(words: string[]) {
  let at = 0;
  while (at < words.length) {
    const name = basename(words[at]);
    if (shellPrefix.test(name) || /^[A-Za-z_][A-Za-z0-9_]*=/.test(words[at])) { at++; continue; }
    if (!Object.hasOwn(wrappers, name)) break;
    at++;
    while (at < words.length && words[at].startsWith('-')) {
      const option = words[at++];
      if (option === '--') break;
      if (name === 'command' && /^-[vV]/.test(option)) return [];
      if (wrappers[name].test(option)) at++;
    }
    if (name === 'timeout') at++;
  }
  return words.slice(at);
}

function classify(words: string[], prefixes: string[][], depth: number): Command | null {
  const direct = (argv: string[]) => prefixes.some((prefix) =>
    prefix.every((word, index) => (index === 0 ? basename(argv[index] ?? '') : argv[index]) === word));
  if (direct(words)) return { canonical: words[0] === 'nen' };
  if (!words.length || depth > 8) return null;
  if (basename(words[0]) === basename(WRAPPER)) {
    const nen = words.findIndex((word, index) => index > 0 && basename(word) === 'nen');
    if (nen > 0 && direct(words.slice(nen))) {
      if (nen === 4 && words[1] === '--path' && words[3] === '--' && words[4] === 'nen') {
        return { wrapper: words[0], session: words[2], canonical: isAbsolute(words[0]) };
      }
      return { wrapper: words[0], canonical: nen === 2 && words[1] === '--' && words[2] === 'nen' };
    }
  }
  const unwrapped = unwrap(words);
  if (unwrapped.length < words.length) {
    const inner = classify(unwrapped, prefixes, depth + 1);
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
  if (!found) return { refusal: null, wrapper: null, session: null };
  const wrapper = found.wrapper ?? null;
  const session = found.session ?? null;
  const spelling = wrapper ? `${shellWord(wrapper)}${session ? ` --path ${shellWord(session)}` : ''} -- ` : '';
  const plain = prefixes.some((prefix) => {
    const start = `${spelling}${prefix.join(' ')}`;
    return command.trimStart() === start || command.trimStart().startsWith(`${start} `);
  });
  return { refusal: found.canonical && !scanned.complex && plain ? null : loneCall, wrapper, session };
}

function verifySession(bin: string, root: string): boolean {
  try {
    const parent = dirname(bin);
    const owner = process.getuid?.();
    if (owner === undefined || !isAbsolute(bin) || bin.includes(':') || basename(bin) !== 'bin' ||
        resolve(bin) !== bin || realpathSync(bin) !== join(realpathSync(parent), 'bin') ||
        lstatSync(parent).isSymbolicLink() ||
        ![parent, bin].every((path) => {
          const stat = statSync(path);
          return stat.isDirectory() && stat.uid === owner && !(stat.mode & 0o022);
        }) || (statSync(parent).mode & 0o077) || readdirSync(bin).join() !== 'nen') return false;
    const link = join(bin, 'nen');
    if (!lstatSync(link).isSymbolicLink()) return false;
    const binary = realpathSync(link);
    const stat = statSync(binary);
    if (!stat.isFile() || stat.uid !== owner || (stat.mode & 0o022)) return false;
    accessSync(binary, constants.X_OK);
    const declaration = JSON.parse(readFileSync(join(root, 'nen/contract.json'), 'utf8'));
    const pin = declaration.dependency.bootstrap.sha256[`${process.platform}-${process.arch}`];
    return typeof pin === 'string' && createHash('sha256').update(readFileSync(binary)).digest('hex') === pin;
  } catch {
    return false;
  }
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
  const { refusal, wrapper, session } = checkRoutineWrite(input.tool_input.command, source);
  if (refusal) return refusal;
  if (wrapper && (typeof input.cwd !== 'string' || !verifyWrapper(wrapper, input.cwd, root))) {
    return 'Hatsu routine write: the requested token wrapper could not be verified against the installed Hatsu wrapper. Use the verified installed path or bare nen.';
  }
  if (session && (wrapper !== join(realpathSync(root), WRAPPER) || !verifySession(session, root))) {
    return 'Hatsu routine write: Ten’s private session bin or its pinned Nen binary could not be verified.';
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
    process.exitCode = 2;
  }
}
