#!/usr/bin/env node
// generate-color-assets.mjs
//
// Generates *.colorset folders inside Assets.xcassets from the palette in
// spec §15. Idempotent — re-run after editing PALETTE.

import { writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const iosRoot = resolve(here, '..');
const assets = resolve(iosRoot, 'SSAMAU/SSAMAU/Assets.xcassets');

const PALETTE = {
  BrandGreen:      { light: '#1A5C2E', dark: '#2A7E3F' },
  BrandGreenDark:  { light: '#0E3A1C', dark: '#1A5C2E' },
  BrandGold:       { light: '#B8932A', dark: '#D4AC3B' },
  Background:      { light: '#FFFFFF', dark: '#0F1419' },
  BackgroundSoft:  { light: '#F9FAFB', dark: '#1A1F26' },
  Ink:             { light: '#1F2937', dark: '#E5E7EB' },
  InkMuted:        { light: '#6B7280', dark: '#9CA3AF' },
  Line:            { light: '#E5E7EB', dark: '#374151' },
};

function hexToComponents(hex) {
  const m = /^#([0-9a-fA-F]{6})$/.exec(hex);
  if (!m) throw new Error(`Bad hex: ${hex}`);
  const [r, g, b] = [0, 2, 4].map(i => '0x' + m[1].slice(i, i + 2).toUpperCase());
  return { red: r, green: g, blue: b, alpha: '1.000' };
}

function colorEntry(hex, dark = false) {
  const entry = {
    color: {
      'color-space': 'srgb',
      components: hexToComponents(hex),
    },
    idiom: 'universal',
  };
  if (dark) {
    entry.appearances = [{ appearance: 'luminosity', value: 'dark' }];
  }
  return entry;
}

function colorset({ light, dark }) {
  return {
    colors: [colorEntry(light, false), colorEntry(dark, true)],
    info: { author: 'xcode', version: 1 },
  };
}

for (const [name, palette] of Object.entries(PALETTE)) {
  const dir = resolve(assets, `${name}.colorset`);
  await mkdir(dir, { recursive: true });
  const json = JSON.stringify(colorset(palette), null, 2) + '\n';
  await writeFile(resolve(dir, 'Contents.json'), json, 'utf8');
  console.log(`Wrote ${name}.colorset (light ${palette.light}, dark ${palette.dark})`);
}
