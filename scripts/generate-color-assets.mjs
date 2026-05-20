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

// Brand palette per SSAM Brand Identity Guide.
//
// Light theme is the brand's canonical mode: cream-dominant backgrounds,
// charcoal text, deep-green for identity, heritage gold for accents.
// Dark theme inverts to charcoal surfaces with cream text so brand
// colours stay legible.
//
// Role-named tokens (Background, Ink, etc.) are aliases over the brand
// neutrals so existing view code keeps working as the theme evolves.
const PALETTE = {
  // Brand colors
  BrandGreen:      { light: '#0F5A2D', dark: '#2A7E3F' },
  BrandGreenDark:  { light: '#093F1F', dark: '#0F5A2D' },
  BrandGold:       { light: '#B4962D', dark: '#D4AC3B' },

  // Brand neutrals
  Cream:           { light: '#F0E5CC', dark: '#1A1814' },
  Pale:            { light: '#F7EFDC', dark: '#241F18' },
  Charcoal:        { light: '#1A1A1A', dark: '#F0E5CC' },
  Grey:            { light: '#7C7C7C', dark: '#A89F8E' },
  Light:           { light: '#D5CCB8', dark: '#3A332A' },

  // Role aliases (used by views; map onto the neutrals above)
  Background:      { light: '#F0E5CC', dark: '#1A1814' },  // = Cream / dark cream-tinted
  BackgroundSoft:  { light: '#F7EFDC', dark: '#241F18' },  // = Pale / slightly lighter dark
  Ink:             { light: '#1A1A1A', dark: '#F0E5CC' },  // = Charcoal / Cream
  InkMuted:        { light: '#7C7C7C', dark: '#A89F8E' },  // = Grey
  Line:            { light: '#D5CCB8', dark: '#3A332A' },  // = Light / dark warm grey
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
