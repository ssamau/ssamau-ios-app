#!/usr/bin/env node
// strings-to-localizable.mjs
//
// Ports the web app's i18n catalog (assets/js/lib/strings/{ar,en}.js) into
// Localizable.strings files for the iOS app. Run after the web catalog
// changes — see spec §17.3.
//
// Usage:
//   node scripts/strings-to-localizable.mjs [WEB_REPO_PATH]
//
// Defaults WEB_REPO_PATH to "~/Desktop/SSAMAU Website/ssamau-site".
// Writes to:
//   SSAMAU/SSAMAU/Resources/Localizable.strings              (English)
//   SSAMAU/SSAMAU/Resources/ar.lproj/Localizable.strings     (Arabic)

import { writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { homedir } from 'node:os';

const here = dirname(fileURLToPath(import.meta.url));
const iosRoot = resolve(here, '..');

const webRepoArg = process.argv[2];
const webRepo = webRepoArg
  ? resolve(webRepoArg)
  : resolve(homedir(), 'Desktop/SSAMAU Website/ssamau-site');

const sources = [
  {
    lang: 'en',
    src: resolve(webRepo, 'assets/js/lib/strings/en.js'),
    out: resolve(iosRoot, 'SSAMAU/SSAMAU/Resources/Localizable.strings'),
  },
  {
    lang: 'ar',
    src: resolve(webRepo, 'assets/js/lib/strings/ar.js'),
    out: resolve(iosRoot, 'SSAMAU/SSAMAU/Resources/ar.lproj/Localizable.strings'),
  },
];

function escapeValue(value) {
  // Localizable.strings escaping. Source values may contain backslash,
  // double-quote, newline, tab. {var} interpolation tokens pass through
  // unchanged — ErrorLocalization handles them at runtime.
  return value
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n')
    .replace(/\t/g, '\\t');
}

async function convert({ lang, src, out }) {
  const mod = await import(pathToFileURL(src).href);
  const catalog = mod.default;
  if (!catalog || typeof catalog !== 'object') {
    throw new Error(`No default export in ${src}`);
  }

  const keys = Object.keys(catalog).sort();
  const lines = [
    '/*',
    `  Localizable.strings  (${lang})`,
    `  Auto-generated from ${src.replace(homedir(), '~')}`,
    `  by scripts/strings-to-localizable.mjs — do not hand-edit.`,
    '*/',
    '',
  ];
  for (const key of keys) {
    const value = catalog[key];
    if (typeof value !== 'string') {
      console.warn(`Skipping non-string value at key "${key}"`);
      continue;
    }
    lines.push(`"${key}" = "${escapeValue(value)}";`);
  }
  lines.push('');

  await mkdir(dirname(out), { recursive: true });
  await writeFile(out, lines.join('\n'), 'utf8');
  console.log(`Wrote ${keys.length} keys → ${out.replace(iosRoot + '/', '')}`);
}

for (const source of sources) {
  await convert(source);
}
