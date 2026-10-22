#!/usr/bin/env node
// Render one tagged release interval from a repository's own changelog.
// RENDERED BY hatsu:tenkai from `templates/release_changelog.mts`.
import { readFileSync, writeFileSync } from "node:fs";

type Heading = { level: number; label: string; start: number; end: number };

const [changelog, tag, previous, notesPath, titlePath, countPath] = process.argv.slice(2);
if (!changelog || !tag || !notesPath || !titlePath || !countPath) {
  console.error("release-changelog: expected changelog, tag, previous, notes, title, count");
  process.exit(2);
}

let source: string;
try {
  source = readFileSync(changelog, "utf8");
} catch (error) {
  console.error(`release-changelog: cannot read ${changelog}: ${String(error)}`);
  process.exit(2);
}

const headings: Heading[] = [];
const lines = source.split(/(?<=\n)/);
let offset = 0;
let fence: string | undefined;
for (const line of lines) {
  const trimmed = line.replace(/\r?\n$/, "");
  const marker = trimmed.match(/^\s{0,3}(`{3,}|~{3,})/);
  if (marker) {
    const char = marker[1][0];
    if (!fence) fence = char;
    else if (fence === char) fence = undefined;
  } else if (!fence) {
    const match = trimmed.match(/^(#{2,6})[ \t]+(.+?)[ \t]*$/);
    if (match) {
      headings.push({ level: match[1].length, label: match[2], start: offset, end: offset + line.length });
    }
  }
  offset += line.length;
}

const word = (label: string) => label.split(/[ \t]/, 1)[0];
const anchor = headings.find((heading) => word(heading.label).toLowerCase() === "unreleased")
  ?? headings.find((heading) => word(heading.label).startsWith("v"));
if (!anchor) process.exit(4);

const sections = headings.filter((heading) => heading.level === anchor.level);
const start = sections.findIndex((heading) => word(heading.label) === tag);
if (start < 0) process.exit(3);
const end = previous ? sections.findIndex((heading, index) => index > start && word(heading.label) === previous) : -1;
if (previous && end < 0 && headings.some((heading) => word(heading.label) === previous)) process.exit(3);
const selected = sections.slice(start, end < 0 ? undefined : end);
const notes = selected.map((heading, index) => {
  const next = sections[sections.indexOf(heading) + 1];
  const limit = next?.start ?? source.length;
  return source.slice(heading.start, limit).trimEnd();
}).join("\n\n") + "\n";

writeFileSync(notesPath, notes);
writeFileSync(titlePath, sections[start].label + "\n");
writeFileSync(countPath, String(selected.filter((heading) => word(heading.label).startsWith("v")).length) + "\n");
