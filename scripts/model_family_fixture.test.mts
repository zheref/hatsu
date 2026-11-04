import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test, expect } from 'vitest';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const json = (path: string): any => JSON.parse(readFileSync(join(root, path), 'utf8'));
const expected = [
  ['claude', 'Claude', "hatsu:direct's primary pick is on the Claude line (Anthropic)"],
  ['gpt', 'GPT', "hatsu:direct's primary pick is on the GPT line (OpenAI)"],
  ['gemini', 'Gemini', "hatsu:direct's primary pick is on the Gemini line (Google)"],
  ['grok', 'Grok', "hatsu:direct's primary pick is on the Grok line (xAI, served by Cursor)"],
  ['composer', 'Composer', "hatsu:direct's primary pick is on Cursor's Composer line"],
];

test('install-only model family declares all five canonical lines without changing classifier axes', () => {
  const taxonomy = json('contracts/classify.taxonomy.json');
  expect(Object.keys(taxonomy.axes)).toEqual(['lang', 'job']);
  expect(taxonomy.families.model).toEqual({ prefix: 'model/', color: '0e8a16', keys: expected.map(([key, title, description]) => ({ key, title, description })) });
  expect(taxonomy.axes.lang.keys).toHaveLength(5);
  expect(taxonomy.axes.job.keys).toHaveLength(39);
});

test('model metadata exactly matches the existing declaration that installation must preserve', () => {
  const labels = json('nen/labels.json').labels.filter((label: { name: string }) => label.name.startsWith('model/'));
  expect(labels).toEqual(expected.map(([key, , description]) => ({ name: `model/${key}`, color: '0e8a16', description })));
});

test('direct names the installer route and keeps verdict application separate', () => {
  const label = json('contracts/direct.registry.json').publish.label;
  expect(label.declaredIn).toContain('nen classify install --taxonomy contracts/classify.taxonomy.json --write');
  expect(label.declaredIn).not.toContain('declared by hand');
  expect(label.verb).toContain('nen label apply');
});
