import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import {
  SupersededError,
  readPluginBumpInputs,
  sanitizedPrefix,
  writePluginBumpInputFiles,
} from './plugin_bump_api_retry.mts';

const repo = 'zheref/hatsu';
const base = 'a'.repeat(40);
const prHead = 'c'.repeat(40);

function response(status: number, body: unknown): Response {
  return new Response(typeof body === 'string' ? body : JSON.stringify(body), { status });
}

export type PluginBumpApiRetryFixtureCase = {
  name: string;
  run: () => Promise<void>;
};

export const pluginBumpApiRetryFixtureCases: PluginBumpApiRetryFixtureCase[] = [
  {
    name: 'retries transient non-JSON and 5xx responses with bounded backoff',
    run: async () => {
      const replies = [
        () => response(200, { sha: base }),
        () => response(200, { base: { ref: 'main' }, head: { sha: prHead } }),
        () => response(200, { sha: base }),
        () => response(200, 'upstream hiccup'),
        () => response(502, { message: 'bad gateway' }),
        () => response(200, [{ filename: 'README.md' }]),
        () => response(503, { message: 'try later' }),
        () => response(200, { version: '0.143.3' }),
        () => response(200, []),
      ];
      const calls: Array<{ input: string | URL; init?: RequestInit }> = [];
      const fetchImpl = async (input: string | URL, init?: RequestInit) => {
        calls.push({ input, init });
        const next = replies.shift();
        assert(next, 'unexpected fetch');
        return next();
      };
      const delays: number[] = [];
      const retries: string[] = [];
      const result = await readPluginBumpInputs(repo, '381', base.toUpperCase(), {
        token: 'fixture-token', fetchImpl,
        sleepImpl: async (delay) => { delays.push(delay); },
        onRetry: (line) => retries.push(line),
      });
      assert.deepEqual(result.changedFiles, ['README.md']);
      assert.match(result.baseManifest ?? '', /0\.143\.3/);
      assert.equal(result.baseRef, 'main');
      assert.equal(result.baseTipSha, base);
      assert.deepEqual(result.openPrs, []);
      assert.deepEqual(delays, [250, 750, 250]);
      assert.equal(retries.length, 3);
      assert.equal(calls.length, 9);
      const manifestCall = calls.find((c) => String(c.input).includes('/contents/.claude-plugin/plugin.json'));
      assert(manifestCall, 'expected manifest lookup');
      assert.equal((manifestCall.init?.headers as Record<string, string>).Accept, 'application/vnd.github.raw+json');
      const root = mkdtempSync(join(tmpdir(), 'hatsu-plugin-bump-api-present-'));
      try {
        const changed = join(root, 'changed.txt');
        const manifest = join(root, 'base.json');
        assert.equal(writePluginBumpInputFiles(result, changed, manifest), 'present');
        assert.equal(readFileSync(changed, 'utf8'), 'README.md\n');
        assert.match(readFileSync(manifest, 'utf8'), /0\.143\.3/);
        assert.equal(existsSync(`${manifest}.absent`), false);
        assert.deepEqual(JSON.parse(readFileSync(`${manifest}.open-prs.json`, 'utf8')), {
          baseRef: 'main',
          baseTipSha: base,
          openPrs: [],
        });
      } finally {
        rmSync(root, { recursive: true, force: true });
      }
    },
  },
  {
    name: 'writes the 404 sentinel only after a real base is confirmed',
    run: async () => {
      const replies = [
        () => response(200, { sha: base }),
        () => response(200, { base: { ref: 'main' }, head: { sha: prHead } }),
        () => response(200, { sha: base }),
        () => response(200, []),
        () => response(404, { message: 'Not Found' }),
        () => response(200, []),
      ];
      const result = await readPluginBumpInputs(repo, '381', base, {
        token: 'fixture-token',
        fetchImpl: async () => {
          const next = replies.shift();
          assert(next, 'unexpected fetch');
          return next();
        },
        sleepImpl: async () => {},
      });
      assert.deepEqual(result, {
        changedFiles: [],
        baseManifest: null,
        baseRef: 'main',
        baseTipSha: base,
        openPrs: [],
      });
      const root = mkdtempSync(join(tmpdir(), 'hatsu-plugin-bump-api-'));
      try {
        const changed = join(root, 'changed.txt');
        const manifest = join(root, 'base.json');
        assert.equal(writePluginBumpInputFiles(result, changed, manifest), 'absent');
        assert.equal(readFileSync(changed, 'utf8'), '');
        assert.equal(existsSync(manifest), false);
        assert.equal(existsSync(`${manifest}.absent`), true);
        assert.equal(existsSync(`${manifest}.open-prs.json`), true);
      } finally {
        rmSync(root, { recursive: true, force: true });
      }
    },
  },
  {
    name: 'fails closed before manifest lookup when base confirmation persists non-JSON',
    run: async () => {
      let calls = 0;
      await assert.rejects(readPluginBumpInputs(repo, '381', base, {
        token: 'fixture-token',
        fetchImpl: async () => { calls += 1; return response(200, '<html>temporary</html>'); },
        sleepImpl: async () => {},
      }), /base commit lookup: failed after 3 attempts \(HTTP 200; body prefix: <html>temporary<\/html>\)/);
      assert.equal(calls, 3);
      await assert.rejects(readPluginBumpInputs(repo, '381', base, {
        token: 'fixture-token', requestTimeoutMs: 0,
      }), /request timeout must be a positive integer/);
    },
  },
  {
    name: 'rejects malformed or mismatched base identities before manifest lookup',
    run: async () => {
      const invalidBases: unknown[] = [
        [],
        {},
        { sha: 7 },
        { sha: '' },
        { sha: 'b'.repeat(40) },
      ];
      for (const invalidBase of invalidBases) {
        let calls = 0;
        await assert.rejects(readPluginBumpInputs(repo, '381', base.toUpperCase(), {
          token: 'fixture-token',
          fetchImpl: async () => { calls += 1; return response(200, invalidBase); },
          sleepImpl: async () => {},
        }), /base commit lookup: HTTP 200; body prefix:/);
        assert.equal(calls, 1, 'an invalid base identity reached a later API endpoint');
      }
    },
  },
  {
    name: 'fails closed after three persistent server errors with sanitized diagnostics',
    run: async () => {
      const hostile = `wait\r\n::warning title=forged::oops ${'x'.repeat(240)}`;
      let calls = 0;
      await assert.rejects(readPluginBumpInputs(repo, '381', base, {
        token: 'fixture-token',
        fetchImpl: async () => { calls += 1; return response(503, hostile); },
        sleepImpl: async () => {},
      }), /failed after 3 attempts \(HTTP 503; body prefix: wait ::warning title=forged::oops/);
      assert.equal(calls, 3);
      assert.doesNotMatch(sanitizedPrefix(hostile), /[\r\n]/);
      assert(sanitizedPrefix(hostile).length <= 160);
    },
  },
  {
    name: 'aborts a request whose response body never settles and exhausts the bounded attempts',
    run: async () => {
      const signals: AbortSignal[] = [];
      const fetchImpl = async (_input: string | URL, init?: RequestInit) => {
        signals.push(init?.signal as AbortSignal);
        return { status: 200, text: () => new Promise<string>(() => {}) } as Response;
      };
      await assert.rejects(readPluginBumpInputs(repo, '381', base, {
        token: 'fixture-token', fetchImpl, requestTimeoutMs: 2, sleepImpl: async () => {},
      }), /failed after 3 attempts \(HTTP <none>; body prefix: request timed out after 2ms\)/);
      assert.equal(signals.length, 3);
      assert(signals.every((signal) => signal instanceof AbortSignal && signal.aborted));
    },
  },
  {
    name: 'fails closed at GitHub’s documented 3,000-file response ceiling',
    run: async () => {
      let calls = 0;
      const fetchImpl = async () => {
        calls += 1;
        if (calls === 1) return response(200, { sha: base });
        if (calls === 2) return response(200, { base: { ref: 'main' }, head: { sha: prHead } });
        if (calls === 3) return response(200, { sha: base });
        return response(200, Array.from({ length: 100 }, (_, index) => ({ filename: `p${calls}-${index}` })));
      };
      await assert.rejects(readPluginBumpInputs(repo, '381', base, {
        token: 'fixture-token', fetchImpl, sleepImpl: async () => {},
      }), /reached GitHub's 3000-file response maximum/);
      assert.equal(calls, 33);
    },
  },
  {
    name: 'preserves renamed paths and remains deterministic for a body-only rerun',
    run: async () => {
      const oneRun = () => {
        const replies = [
          () => response(200, { sha: base }),
          () => response(200, { base: { ref: 'main' }, head: { sha: prHead } }),
          () => response(200, { sha: base }),
          () => response(200, [{ filename: 'new.md', previous_filename: 'old.md' }]),
          () => response(200, { version: '0.143.3' }),
          () => response(200, []),
        ];
        return readPluginBumpInputs(repo, '381', base, {
          token: 'fixture-token',
          fetchImpl: async () => {
            const next = replies.shift();
            assert(next, 'unexpected fetch');
            return next();
          },
          sleepImpl: async () => {},
        });
      };
      const first = await oneRun();
      const edited = await oneRun();
      assert.deepEqual(edited, first);
      assert.deepEqual(first.changedFiles, ['new.md', 'old.md']);
    },
  },
  {
    name: 'rejects malformed and empty changed-file path fields',
    run: async () => {
      const malformedRows: unknown[] = [
        {},
        { filename: 7 },
        { filename: '' },
        { filename: 'outside.md', previous_filename: 7 },
        { filename: 'outside.md', previous_filename: '' },
        { filename: 'outside\u0085.md' },
      ];
      for (const malformedRow of malformedRows) {
        const replies = [
          () => response(200, { sha: base }),
          () => response(200, { base: { ref: 'main' }, head: { sha: prHead } }),
          () => response(200, { sha: base }),
          () => response(200, [malformedRow]),
        ];
        await assert.rejects(readPluginBumpInputs(repo, '381', base, {
          token: 'fixture-token',
          fetchImpl: async () => {
            const next = replies.shift();
            assert(next, 'unexpected fetch');
            return next();
          },
          sleepImpl: async () => {},
        }), /changed-files page 1: HTTP 200; body prefix:/);
        assert.equal(replies.length, 0, 'a malformed changed-file row reached manifest lookup');
      }
    },
  },
  {
    name: 'reads manifest from the live base tip even when event baseSha moved ahead (HA#545 AC-1)',
    run: async () => {
      const movedTip = 'b'.repeat(40);
      const urls: string[] = [];
      const replies = [
        () => response(200, { sha: base }),
        () => response(200, { base: { ref: 'main' }, head: { sha: prHead } }),
        () => response(200, { sha: movedTip }),
        () => response(200, [{ filename: 'scripts/plugin_bump_check.sh' }]),
        () => response(200, { version: '0.170.1' }),
        () => response(200, []),
      ];
      const result = await readPluginBumpInputs(repo, '381', base, {
        token: 'fixture-token',
        fetchImpl: async (input) => {
          urls.push(String(input));
          const next = replies.shift();
          assert(next, 'unexpected fetch');
          return next();
        },
        sleepImpl: async () => {},
      });
      assert.equal(result.baseTipSha, movedTip);
      assert.match(result.baseManifest ?? '', /0\.170\.1/);
      assert(urls.some((u) => u.includes(`ref=${movedTip}`)));
    },
  },
  {
    name: 'collects bumped open sibling PRs, ignores self/forks/unbumped/404s, and fails closed on open-PR ceiling (HA#545 AC-2)',
    run: async () => {
      const s1 = '1'.repeat(40);
      const s2 = '2'.repeat(40);
      const s3 = '3'.repeat(40);
      const s4 = '4'.repeat(40);
      const s5 = '5'.repeat(40);
      const s6 = '6'.repeat(40);
      const s7 = '7'.repeat(40);
      const s8 = '8'.repeat(40);
      const s9 = '9'.repeat(40);
      const replies = [
        () => response(200, { base: { ref: 'main' }, head: { sha: prHead } }),
        () => response(200, { sha: base }),
        () => response(200, [{ filename: 'claude/skills/aka/SKILL.md' }]),
        () => response(200, { version: '0.170.0' }),
        () => response(200, [
          { number: 381, head: { sha: prHead, repo: { full_name: repo } } },
          { number: 382, head: { sha: s1, repo: { full_name: 'fork/hatsu' } } },
          { number: 387, head: { sha: s6, repo: null } }, // deleted fork
          { number: 383, head: { sha: s2, repo: { full_name: repo } } },
          { number: 384, head: { sha: s3, repo: { full_name: repo } } },
          { number: 388, head: { sha: s7, repo: { full_name: repo } } },
          { number: 389, head: { sha: s8, repo: { full_name: repo } } },
          { number: 390, head: { sha: s9, repo: { full_name: repo } } },
          { number: 385, head: { sha: s4, repo: { full_name: repo } } },
          { number: 386, head: { sha: s5, repo: { full_name: repo } } },
        ]),
        () => response(200, { version: '0.170.0' }), // 383 unbumped
        () => response(404, { message: 'Gone' }),     // 384 manifest gone
        () => response(200, { type: 'file', encoding: 'base64', content: Buffer.from('{not-json').toString('base64') }), // 388 malformed sibling
        () => response(200, []),                      // 389 array sibling
        () => response(200, { type: 'symlink', target: '../x' }), // 390 symlink sibling
        () => response(200, { version: '0.170.1' }), // 385 bumped
        () => response(404, { message: 'Gone' }),     // 385 files 404 (race)
        () => response(200, { version: '0.170.1' }), // 386 bumped
        () => response(200, [{ filename: 'claude/skills/ten/SKILL.md' }]),
      ];
      const result = await readPluginBumpInputs(repo, '381', null, {
        token: 'fixture-token',
        expectedHead: prHead,
        fetchImpl: async () => {
          const next = replies.shift();
          assert(next, 'unexpected fetch');
          return next();
        },
        sleepImpl: async () => {},
      });
      assert.equal(replies.length, 0);
      assert.deepEqual(result.openPrs, [
        { number: 386, version: '0.170.1', files: ['claude/skills/ten/SKILL.md'] },
      ]);

      // Expected head mismatch throws SupersededError
      await assert.rejects(
        readPluginBumpInputs(repo, '381', null, {
          token: 'fixture-token',
          expectedHead: 'd'.repeat(40),
          fetchImpl: async () => response(200, { base: { ref: 'main' }, head: { sha: prHead } }),
          sleepImpl: async () => {},
        }),
        SupersededError,
      );

      // Pagination ceiling at 1,000 open PRs fails closed
      let pageCalls = 0;
      const fullPage = Array.from({ length: 100 }, (_, i) => ({
        number: 1000 + i,
        head: { sha: 'f'.repeat(40), repo: { full_name: 'fork/hatsu' } },
      }));
      await assert.rejects(
        readPluginBumpInputs(repo, '381', null, {
          token: 'fixture-token',
          fetchImpl: async (input) => {
            pageCalls += 1;
            const url = String(input);
            if (url.endsWith('/pulls/381')) return response(200, { base: { ref: 'main' }, head: { sha: prHead } });
            if (url.includes('/commits/main')) return response(200, { sha: base });
            if (url.includes('/pulls/381/files')) return response(200, [{ filename: 'README.md' }]);
            if (url.includes('/contents/')) return response(200, { version: '0.170.0' });
            return response(200, fullPage);
          },
          sleepImpl: async () => {},
        }),
        /1000-PR pagination ceiling/,
      );
      assert.equal(pageCalls, 14);
    },
  },
];
