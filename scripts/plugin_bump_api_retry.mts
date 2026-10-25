#!/usr/bin/env node
// HA#381: bounded, fixed-endpoint reads for plugin-bump-check.yml.
// The workflow executes this file only from its trusted checkout. Pull-request
// code remains data, and callers cannot choose a method, URL, header, or body.
import { writeFileSync, rmSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const ATTEMPTS = 3;
const BACKOFF_MS = [250, 750];
const PREFIX_LIMIT = 160;
const REQUEST_TIMEOUT_MS = 10_000;
const PAGE_SIZE = 100;
// GitHub documents a hard 3,000-file response maximum for this endpoint:
// https://docs.github.com/en/rest/pulls/pulls?apiVersion=2022-11-28#list-pull-requests-files
// Reaching the ceiling is ambiguous (exactly 3,000 or silently truncated), so
// the guard fails closed instead of claiming it saw the whole pull request.
const MAX_FILES = 3_000;
const MAX_PAGES = MAX_FILES / PAGE_SIZE;

type FetchLike = (input: string | URL, init?: RequestInit) => Promise<Response>;
type SleepLike = (milliseconds: number) => Promise<void>;

export type PluginBumpInputs = {
  changedFiles: string[];
  baseManifest: string | null;
};

type ReadOptions = {
  fetchImpl?: FetchLike;
  sleepImpl?: SleepLike;
  token?: string;
  apiBase?: string;
  requestTimeoutMs?: number;
  onRetry?: (line: string) => void;
};

function fail(message: string): never {
  throw new Error(message);
}

function repository(value: string): string {
  if (!/^[A-Za-z0-9][A-Za-z0-9_.-]*\/[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(value)) {
    fail('expected --repo owner/repository');
  }
  return value;
}

function positiveInteger(value: string): string {
  if (!/^[1-9][0-9]*$/.test(value) || !Number.isSafeInteger(Number(value))) {
    fail('expected --pr positive integer');
  }
  return value;
}

function revision(value: string): string {
  if (!/^[0-9a-fA-F]{40}$/.test(value)) fail('expected --base-sha 40 hexadecimal characters');
  return value.toLowerCase();
}

export function sanitizedPrefix(body: string): string {
  const printable = body
    .replace(/[\u0000-\u001f\u007f-\u009f]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return printable.slice(0, PREFIX_LIMIT) || '<empty>';
}

function statusText(status: number): string {
  return status > 0 ? String(status) : '<none>';
}

function parseJson(body: string): unknown | null {
  try {
    return JSON.parse(body) as unknown;
  } catch {
    return null;
  }
}

function retryable(status: number, parsed: unknown | null): boolean {
  return status >= 500 || parsed === null;
}

async function sleep(milliseconds: number): Promise<void> {
  await new Promise<void>((resolve) => setTimeout(resolve, milliseconds));
}

async function timedFetchBody(
  fetchImpl: FetchLike,
  url: string,
  init: RequestInit,
  timeoutMs: number,
): Promise<{ status: number; body: string }> {
  const controller = new AbortController();
  let timer: ReturnType<typeof setTimeout> | undefined;
  const request = (async () => {
    const response = await fetchImpl(url, { ...init, signal: controller.signal });
    return { status: response.status, body: await response.text() };
  })();
  const timeout = new Promise<never>((_resolve, reject) => {
    timer = setTimeout(() => {
      controller.abort();
      reject(new Error(`request timed out after ${timeoutMs}ms`));
    }, timeoutMs);
  });
  try {
    return await Promise.race([request, timeout]);
  } finally {
    if (timer !== undefined) clearTimeout(timer);
  }
}

async function getJson(
  label: string,
  url: string,
  token: string,
  options: ReadOptions,
  accept = 'application/vnd.github+json',
): Promise<{ status: number; body: string; value: unknown }> {
  const fetchImpl = options.fetchImpl ?? fetch;
  const sleepImpl = options.sleepImpl ?? sleep;
  const timeoutMs = options.requestTimeoutMs ?? REQUEST_TIMEOUT_MS;
  if (!Number.isSafeInteger(timeoutMs) || timeoutMs < 1) fail('request timeout must be a positive integer');
  let last = 'request was not attempted';

  for (let attempt = 1; attempt <= ATTEMPTS; attempt += 1) {
    try {
      const response = await timedFetchBody(fetchImpl, url, {
        method: 'GET',
        headers: {
          Accept: accept,
          Authorization: `Bearer ${token}`,
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'hatsu-plugin-bump-check',
        },
      }, timeoutMs);
      const value = parseJson(response.body);
      last = `HTTP ${statusText(response.status)}; body prefix: ${sanitizedPrefix(response.body)}`;
      if (!retryable(response.status, value)) return { status: response.status, body: response.body, value };
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      last = `HTTP <none>; body prefix: ${sanitizedPrefix(detail)}`;
    }

    if (attempt < ATTEMPTS) {
      const delay = BACKOFF_MS[attempt - 1];
      options.onRetry?.(`${label}: transient ${last}; retry ${attempt + 1}/${ATTEMPTS} after ${delay}ms`);
      await sleepImpl(delay);
    }
  }

  fail(`${label}: failed after ${ATTEMPTS} attempts (${last})`);
}

function assertStatus(label: string, response: { status: number; body: string }, expected: number): void {
  if (response.status !== expected) {
    fail(`${label}: HTTP ${statusText(response.status)}; body prefix: ${sanitizedPrefix(response.body)}`);
  }
}

export async function readPluginBumpInputs(
  repoArg: string,
  prArg: string,
  baseShaArg: string,
  options: ReadOptions = {},
): Promise<PluginBumpInputs> {
  const repo = repository(repoArg);
  const pr = positiveInteger(prArg);
  const baseSha = revision(baseShaArg);
  const token = options.token ?? process.env.GH_TOKEN ?? '';
  if (!token) fail('GH_TOKEN is required');
  const apiBase = (options.apiBase ?? 'https://api.github.com').replace(/\/$/, '');

  // A manifest 404 is meaningful only after this succeeds.
  const base = await getJson('base commit lookup', `${apiBase}/repos/${repo}/commits/${baseSha}`, token, options);
  assertStatus('base commit lookup', base, 200);
  if (typeof base.value !== 'object' || base.value === null || Array.isArray(base.value) ||
      typeof (base.value as { sha?: unknown }).sha !== 'string' ||
      (base.value as { sha: string }).sha.length === 0 ||
      (base.value as { sha: string }).sha !== baseSha) {
    fail(`base commit lookup: HTTP 200; body prefix: ${sanitizedPrefix(base.body)}`);
  }

  const changedFiles: string[] = [];
  for (let page = 1; page <= MAX_PAGES; page += 1) {
    const files = await getJson(
      `changed-files page ${page}`,
      `${apiBase}/repos/${repo}/pulls/${pr}/files?per_page=${PAGE_SIZE}&page=${page}`,
      token,
      options,
    );
    assertStatus(`changed-files page ${page}`, files, 200);
    if (!Array.isArray(files.value)) {
      fail(`changed-files page ${page}: HTTP 200; body prefix: ${sanitizedPrefix(files.body)}`);
    }
    for (const row of files.value) {
      if (typeof row !== 'object' || row === null || Array.isArray(row) ||
          typeof (row as { filename?: unknown }).filename !== 'string' ||
          (row as { filename: string }).filename.length === 0) {
        fail(`changed-files page ${page}: HTTP 200; body prefix: ${sanitizedPrefix(files.body)}`);
      }
      const file = row as { filename: string; previous_filename?: unknown };
      const hasPrevious = Object.hasOwn(file, 'previous_filename');
      if (hasPrevious && (typeof file.previous_filename !== 'string' || file.previous_filename.length === 0)) {
        fail(`changed-files page ${page}: HTTP 200; body prefix: ${sanitizedPrefix(files.body)}`);
      }
      if (/[\u0000-\u001f\u007f]/.test(file.filename) ||
          (hasPrevious && /[\u0000-\u001f\u007f]/.test(file.previous_filename as string))) {
        fail(`changed-files page ${page}: HTTP 200; body prefix: ${sanitizedPrefix(files.body)}`);
      }
      changedFiles.push(file.filename);
      if (hasPrevious) changedFiles.push(file.previous_filename as string);
    }
    if (files.value.length < PAGE_SIZE) break;
    if (page === MAX_PAGES) {
      fail(`changed-files: reached GitHub's ${MAX_FILES}-file response maximum; refusing a potentially truncated file list`);
    }
  }

  const manifest = await getJson(
    'base manifest lookup',
    `${apiBase}/repos/${repo}/contents/.claude-plugin/plugin.json?ref=${baseSha}`,
    token,
    options,
    'application/vnd.github.raw+json',
  );
  if (manifest.status === 404) return { changedFiles, baseManifest: null };
  assertStatus('base manifest lookup', manifest, 200);
  if (typeof manifest.value !== 'object' || manifest.value === null) {
    fail(`base manifest lookup: HTTP 200; body prefix: ${sanitizedPrefix(manifest.body)}`);
  }
  return { changedFiles, baseManifest: `${manifest.body.trimEnd()}\n` };
}

export function writePluginBumpInputFiles(
  inputs: PluginBumpInputs,
  changedFilesPath: string,
  baseManifestPath: string,
): 'present' | 'absent' {
  writeFileSync(changedFilesPath, inputs.changedFiles.map((path) => `${path}\n`).join(''), { mode: 0o600 });
  rmSync(baseManifestPath, { force: true });
  rmSync(`${baseManifestPath}.absent`, { force: true });
  if (inputs.baseManifest === null) {
    writeFileSync(`${baseManifestPath}.absent`, '', { mode: 0o600 });
    return 'absent';
  }
  writeFileSync(baseManifestPath, inputs.baseManifest, { mode: 0o600 });
  return 'present';
}

type Cli = {
  repo: string;
  pr: string;
  baseSha: string;
  changedFiles: string;
  baseManifest: string;
};

function parseCli(args: string[]): Cli {
  const values = new Map<string, string>();
  for (let index = 0; index < args.length; index += 2) {
    const flag = args[index];
    const value = args[index + 1];
    if (!value || !['--repo', '--pr', '--base-sha', '--changed-files', '--base-manifest'].includes(flag)) {
      fail('usage: node scripts/plugin_bump_api_retry.mts --repo owner/repo --pr N --base-sha SHA --changed-files PATH --base-manifest PATH');
    }
    if (values.has(flag)) fail(`duplicate ${flag}`);
    values.set(flag, value);
  }
  if (values.size !== 5) fail('all five named arguments are required');
  return {
    repo: values.get('--repo')!,
    pr: values.get('--pr')!,
    baseSha: values.get('--base-sha')!,
    changedFiles: values.get('--changed-files')!,
    baseManifest: values.get('--base-manifest')!,
  };
}

async function main(): Promise<void> {
  const cli = parseCli(process.argv.slice(2));
  const inputs = await readPluginBumpInputs(cli.repo, cli.pr, cli.baseSha, {
    onRetry: (line) => console.error(line),
  });
  if (writePluginBumpInputFiles(inputs, cli.changedFiles, cli.baseManifest) === 'absent') {
    console.log(`base .claude-plugin/plugin.json legitimately absent at ${cli.baseSha} (HTTP 404 after confirmed base) -- sentinel written`);
  } else {
    console.log(`base .claude-plugin/plugin.json read at ${cli.baseSha} (HTTP 200)`);
  }
  console.log(`changed files: ${inputs.changedFiles.length}`);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main().catch((error) => {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`::error::plugin-bump API inputs: ${message}`);
    process.exitCode = 1;
  });
}
