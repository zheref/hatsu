#!/usr/bin/env node
// HA#381, HA#545: bounded, fixed-endpoint reads for plugin-bump-check.yml and readiness_ci_verdict.mts.
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
// Open PR enumeration stops fail-closed above 1,000 open PRs targeting the base branch.
const MAX_OPEN_PR_PAGES = 10;

type FetchLike = (input: string | URL, init?: RequestInit) => Promise<Response>;
type SleepLike = (milliseconds: number) => Promise<void>;

export type OpenPrVersion = {
  number: number;
  version: string;
  files: string[];
};

export type PluginBumpInputs = {
  changedFiles: string[];
  baseManifest: string | null;
  baseRef: string;
  baseTipSha: string;
  openPrs: OpenPrVersion[];
};

type ReadOptions = {
  fetchImpl?: FetchLike;
  sleepImpl?: SleepLike;
  token?: string;
  apiBase?: string;
  requestTimeoutMs?: number;
  expectedHead?: string;
  onRetry?: (line: string) => void;
};

export class SupersededError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'SupersededError';
  }
}

function fail(message: string): never {
  throw new Error(message);
}

function repository(value: string): string {
  if (!/^[A-Za-z0-9][A-Za-z0-9_.-]*\/[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(value)) {
    fail('expected --repo owner/repository');
  }
  return value;
}

function positiveInteger(value: string, label = '--pr'): string {
  if (!/^[1-9][0-9]*$/.test(value) || !Number.isSafeInteger(Number(value))) {
    fail(`expected ${label} positive integer`);
  }
  return value;
}

function revision(value: string, label = '--base-sha'): string {
  if (!/^[0-9a-fA-F]{40}$/.test(value)) fail(`expected ${label} 40 hexadecimal characters`);
  return value.toLowerCase();
}

function validBranchRef(value: string): string {
  if (!value || value.includes('..') || value.includes('//') || !/^[A-Za-z0-9][A-Za-z0-9._/-]{0,199}$/.test(value)) {
    fail(`invalid PR base ref: ${sanitizedPrefix(value)}`);
  }
  return value;
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

function isObjectRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

async function readPullFiles(
  labelPrefix: string,
  apiBase: string,
  repo: string,
  pr: string,
  token: string,
  options: ReadOptions,
  allowNotFound = false,
): Promise<string[] | null> {
  const changedFiles: string[] = [];
  for (let page = 1; page <= MAX_PAGES; page += 1) {
    const label = `${labelPrefix} page ${page}`;
    const files = await getJson(
      label,
      `${apiBase}/repos/${repo}/pulls/${pr}/files?per_page=${PAGE_SIZE}&page=${page}`,
      token,
      options,
    );
    if (allowNotFound && files.status === 404) return null;
    assertStatus(label, files, 200);
    if (!Array.isArray(files.value)) {
      fail(`${label}: HTTP 200; body prefix: ${sanitizedPrefix(files.body)}`);
    }
    for (const row of files.value) {
      if (!isObjectRecord(row) ||
          typeof row.filename !== 'string' ||
          row.filename.length === 0) {
        fail(`${label}: HTTP 200; body prefix: ${sanitizedPrefix(files.body)}`);
      }
      const hasPrevious = Object.hasOwn(row, 'previous_filename');
      if (hasPrevious && (typeof row.previous_filename !== 'string' || row.previous_filename.length === 0)) {
        fail(`${label}: HTTP 200; body prefix: ${sanitizedPrefix(files.body)}`);
      }
      if (/[\u0000-\u001f\u007f-\u009f]/.test(row.filename) ||
          (hasPrevious && /[\u0000-\u001f\u007f-\u009f]/.test(row.previous_filename as string))) {
        fail(`${label}: HTTP 200; body prefix: ${sanitizedPrefix(files.body)}`);
      }
      changedFiles.push(row.filename);
      if (hasPrevious) changedFiles.push(row.previous_filename as string);
    }
    if (files.value.length < PAGE_SIZE) break;
    if (page === MAX_PAGES) {
      fail(`${labelPrefix}: reached GitHub's ${MAX_FILES}-file response maximum; refusing a potentially truncated file list`);
    }
  }
  return changedFiles;
}

async function readManifestAtRef(
  label: string,
  apiBase: string,
  repo: string,
  ref: string,
  token: string,
  options: ReadOptions,
  allowMalformedSibling = false,
): Promise<{ raw: string; version: string | null } | null> {
  const accept = allowMalformedSibling ? 'application/vnd.github+json' : 'application/vnd.github.raw+json';
  const manifest = await getJson(
    label,
    `${apiBase}/repos/${repo}/contents/.claude-plugin/plugin.json?ref=${encodeURIComponent(ref)}`,
    token,
    options,
    accept,
  );
  if (manifest.status === 404) return null;
  assertStatus(label, manifest, 200);
  if (allowMalformedSibling) {
    // Under application/vnd.github+json, GitHub returns a JSON envelope; direct mock responses
    // may also pass `{ version }`. Non-regular files (directories/symlinks) or syntactically
    // invalid sibling manifests return null so one broken PR cannot fail unrelated PRs.
    if (Array.isArray(manifest.value) || !isObjectRecord(manifest.value)) return null;
    if ('type' in manifest.value) {
      if (manifest.value.type !== 'file' || manifest.value.encoding !== 'base64' || typeof manifest.value.content !== 'string') {
        return null;
      }
      const decoded = parseJson(Buffer.from(manifest.value.content, 'base64').toString('utf8'));
      if (!isObjectRecord(decoded)) return null;
      const version = typeof decoded.version === 'string' && decoded.version.length > 0 ? decoded.version : null;
      return { raw: '', version };
    }
    const version = typeof manifest.value.version === 'string' && manifest.value.version.length > 0
      ? manifest.value.version
      : null;
    return { raw: '', version };
  }
  if (!isObjectRecord(manifest.value)) {
    fail(`${label}: HTTP 200; body prefix: ${sanitizedPrefix(manifest.body)}`);
  }
  const version = typeof manifest.value.version === 'string' && manifest.value.version.length > 0
    ? manifest.value.version
    : null;
  return { raw: `${manifest.body.trimEnd()}\n`, version };
}

export async function readPluginBumpInputs(
  repoArg: string,
  prArg: string,
  baseShaArg: string | null,
  options: ReadOptions = {},
): Promise<PluginBumpInputs> {
  const repo = repository(repoArg);
  const pr = positiveInteger(prArg);
  const eventBaseSha = baseShaArg !== null ? revision(baseShaArg) : null;
  const expectedHead = options.expectedHead !== undefined ? revision(options.expectedHead, '--expected-head') : null;
  const token = options.token ?? process.env.GH_TOKEN ?? '';
  if (!token) fail('GH_TOKEN is required');
  const apiBase = (options.apiBase ?? 'https://api.github.com').replace(/\/$/, '');

  // Confirm the event base commit when supplied before inspecting the PR or live base tip.
  if (eventBaseSha !== null) {
    const base = await getJson('base commit lookup', `${apiBase}/repos/${repo}/commits/${eventBaseSha}`, token, options);
    assertStatus('base commit lookup', base, 200);
    if (!isObjectRecord(base.value) ||
        typeof base.value.sha !== 'string' ||
        base.value.sha.length === 0 ||
        base.value.sha.toLowerCase() !== eventBaseSha) {
      fail(`base commit lookup: HTTP 200; body prefix: ${sanitizedPrefix(base.body)}`);
    }
  }

  const prRes = await getJson('pull request lookup', `${apiBase}/repos/${repo}/pulls/${pr}`, token, options);
  assertStatus('pull request lookup', prRes, 200);
  if (!isObjectRecord(prRes.value) || !isObjectRecord(prRes.value.base) || !isObjectRecord(prRes.value.head)) {
    fail(`pull request lookup: HTTP 200; body prefix: ${sanitizedPrefix(prRes.body)}`);
  }
  const rawBaseRef = typeof prRes.value.base.ref === 'string' ? prRes.value.base.ref : '';
  const baseRef = validBranchRef(rawBaseRef);
  const prHeadSha = typeof prRes.value.head.sha === 'string' ? prRes.value.head.sha : '';
  if (!/^[0-9a-fA-F]{40}$/.test(prHeadSha)) {
    fail(`pull request lookup: HTTP 200; body prefix: ${sanitizedPrefix(prRes.body)}`);
  }
  if (expectedHead !== null && prHeadSha.toLowerCase() !== expectedHead) {
    throw new SupersededError(`pull request head moved from ${expectedHead} to ${prHeadSha.toLowerCase()}`);
  }

  // Always resolve the CURRENT tip of baseRef (HA#545 AC-1/AC-3), never assuming an event base SHA stays current.
  const encodedBasePath = baseRef.split('/').map(encodeURIComponent).join('/');
  const liveBase = await getJson('live base tip lookup', `${apiBase}/repos/${repo}/commits/${encodedBasePath}`, token, options);
  assertStatus('live base tip lookup', liveBase, 200);
  if (!isObjectRecord(liveBase.value) || typeof liveBase.value.sha !== 'string' || !/^[0-9a-fA-F]{40}$/.test(liveBase.value.sha)) {
    fail(`live base tip lookup: HTTP 200; body prefix: ${sanitizedPrefix(liveBase.body)}`);
  }
  const baseTipSha = liveBase.value.sha.toLowerCase();

  const changedFiles = await readPullFiles('changed-files', apiBase, repo, pr, token, options);
  if (changedFiles === null) fail('changed-files: unexpected null file list');

  const manifest = await readManifestAtRef('base manifest lookup', apiBase, repo, baseTipSha, token, options, false);
  const baseVersion = manifest?.version ?? null;

  // Inspect open sibling PRs targeting the same base branch for bumped shipped-surface collisions (HA#545 AC-2).
  // Fail closed when head.repo is null (deleted fork) or belongs to another repo.
  const openPrs: OpenPrVersion[] = [];
  const prNumber = Number(pr);
  const normalizedRepo = repo.toLowerCase();
  for (let page = 1; page <= MAX_OPEN_PR_PAGES; page += 1) {
    const label = `open pulls page ${page}`;
    const openRes = await getJson(
      label,
      `${apiBase}/repos/${repo}/pulls?state=open&base=${encodeURIComponent(baseRef)}&per_page=${PAGE_SIZE}&page=${page}`,
      token,
      options,
    );
    assertStatus(label, openRes, 200);
    if (!Array.isArray(openRes.value)) {
      fail(`${label}: HTTP 200; body prefix: ${sanitizedPrefix(openRes.body)}`);
    }
    for (const row of openRes.value) {
      if (!isObjectRecord(row) ||
          typeof row.number !== 'number' ||
          !Number.isSafeInteger(row.number) ||
          row.number < 1 ||
          !isObjectRecord(row.head) ||
          typeof row.head.sha !== 'string' ||
          !/^[0-9a-fA-F]{40}$/.test(row.head.sha)) {
        fail(`${label}: HTTP 200; body prefix: ${sanitizedPrefix(openRes.body)}`);
      }
      if (row.number === prNumber) continue;
      const headRepo = isObjectRecord(row.head.repo) && typeof row.head.repo.full_name === 'string'
        ? row.head.repo.full_name
        : null;
      if (headRepo === null || headRepo.toLowerCase() !== normalizedRepo) continue;
      const otherSha = row.head.sha.toLowerCase();
      const otherManifest = await readManifestAtRef(
        `open PR #${row.number} manifest lookup`,
        apiBase,
        repo,
        otherSha,
        token,
        options,
        true,
      );
      if (!otherManifest || otherManifest.version === null) continue;
      if (baseVersion !== null && otherManifest.version === baseVersion) continue;
      const otherFiles = await readPullFiles(
        `open PR #${row.number} changed-files`,
        apiBase,
        repo,
        String(row.number),
        token,
        options,
        true,
      );
      if (otherFiles === null) continue;
      openPrs.push({ number: row.number, version: otherManifest.version, files: otherFiles });
    }
    if (openRes.value.length < PAGE_SIZE) break;
    if (page === MAX_OPEN_PR_PAGES) {
      fail(`open pulls: reached GitHub's ${MAX_OPEN_PR_PAGES * PAGE_SIZE}-PR pagination ceiling; refusing partial collision scan`);
    }
  }

  return {
    changedFiles,
    baseManifest: manifest?.raw ?? null,
    baseRef,
    baseTipSha,
    openPrs,
  };
}

export function writePluginBumpInputFiles(
  inputs: PluginBumpInputs,
  changedFilesPath: string,
  baseManifestPath: string,
): 'present' | 'absent' {
  rmSync(changedFilesPath, { force: true });
  writeFileSync(changedFilesPath, inputs.changedFiles.map((path) => `${path}\n`).join(''), { mode: 0o600 });
  rmSync(baseManifestPath, { force: true });
  rmSync(`${baseManifestPath}.absent`, { force: true });
  rmSync(`${baseManifestPath}.open-prs.json`, { force: true });
  writeFileSync(
    `${baseManifestPath}.open-prs.json`,
    `${JSON.stringify({ baseRef: inputs.baseRef, baseTipSha: inputs.baseTipSha, openPrs: inputs.openPrs })}\n`,
    { mode: 0o600 },
  );
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
  baseSha: string | null;
  baseFromPr: boolean;
  expectedHead?: string;
  changedFiles: string;
  baseManifest: string;
};

function parseCli(args: string[]): Cli {
  const usage = 'usage: node scripts/plugin_bump_api_retry.mts --repo owner/repo --pr N (--base-sha SHA | --base-from-pr [--expected-head SHA]) --changed-files PATH --base-manifest PATH';
  const values = new Map<string, string>();
  let baseFromPr = false;
  for (let index = 0; index < args.length;) {
    const flag = args[index];
    if (flag === '--base-from-pr') {
      if (baseFromPr) fail('duplicate --base-from-pr');
      baseFromPr = true;
      index += 1;
      continue;
    }
    const value = args[index + 1];
    if (!value || !['--repo', '--pr', '--base-sha', '--expected-head', '--changed-files', '--base-manifest'].includes(flag)) {
      fail(usage);
    }
    if (values.has(flag)) fail(`duplicate ${flag}`);
    values.set(flag, value);
    index += 2;
  }
  if (baseFromPr && values.has('--base-sha')) fail('--base-from-pr cannot be combined with --base-sha');
  if (!baseFromPr && !values.has('--base-sha')) fail('either --base-sha or --base-from-pr is required');
  for (const required of ['--repo', '--pr', '--changed-files', '--base-manifest']) {
    if (!values.has(required)) fail(`${required} is required`);
  }
  return {
    repo: values.get('--repo')!,
    pr: values.get('--pr')!,
    baseSha: values.get('--base-sha') ?? null,
    baseFromPr,
    expectedHead: values.get('--expected-head'),
    changedFiles: values.get('--changed-files')!,
    baseManifest: values.get('--base-manifest')!,
  };
}

async function main(): Promise<void> {
  const cli = parseCli(process.argv.slice(2));
  const inputs = await readPluginBumpInputs(cli.repo, cli.pr, cli.baseSha, {
    expectedHead: cli.expectedHead,
    onRetry: (line) => console.error(line),
  });
  const baseState = writePluginBumpInputFiles(inputs, cli.changedFiles, cli.baseManifest);
  if (baseState === 'absent') {
    console.log(`base .claude-plugin/plugin.json legitimately absent at ${inputs.baseTipSha} (${inputs.baseRef}, HTTP 404 after confirmed base) -- sentinel written`);
  } else {
    console.log(`base .claude-plugin/plugin.json read at ${inputs.baseTipSha} (${inputs.baseRef}, HTTP 200)`);
  }
  console.log(`changed files: ${inputs.changedFiles.length}`);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main().catch((error) => {
    if (error instanceof SupersededError) {
      console.error(`::warning::plugin-bump API inputs superseded: ${error.message}`);
      process.exitCode = 8;
      return;
    }
    const message = error instanceof Error ? error.message : String(error);
    console.error(`::error::plugin-bump API inputs: ${message}`);
    process.exitCode = 1;
  });
}
