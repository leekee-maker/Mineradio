import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const root = process.cwd();
const sourcePath = path.join(root, 'docs/ui-design/selfradio-mobile-1-flow.svg');
const outputDir = path.join(root, 'docs/ui-design/mobile-1-flow');
const source = await readFile(sourcePath, 'utf8');
const defs = source.match(/<defs>[\s\S]*?<\/defs>/)?.[0];

if (!defs) throw new Error('SVG defs not found');

const screens = [
  ['<!-- 01 Home -->', '<!-- 02 Search -->', '01-home.svg'],
  ['<!-- 02 Search -->', '<!-- 03 Library -->', '02-search.svg'],
  ['<!-- 03 Library -->', '<!-- 04 Playlist -->', '03-library.svg'],
  ['<!-- 04 Playlist -->', '<!-- 05 Immersive Player -->', '04-playlist.svg'],
  ['<!-- 05 Immersive Player -->', '<!-- 06 Lyrics -->', '05-player.svg'],
  ['<!-- 06 Lyrics -->', '<!-- 07 Queue & Source -->', '06-lyrics.svg'],
  ['<!-- 07 Queue & Source -->', '<!-- 08 Accounts -->', '07-queue-source.svg'],
  ['<!-- 08 Accounts -->', '</svg>', '08-platform-accounts.svg'],
];

await mkdir(outputDir, { recursive: true });

for (const [startMarker, endMarker, fileName] of screens) {
  const start = source.indexOf(startMarker);
  const end = source.indexOf(endMarker, start + startMarker.length);
  if (start < 0 || end < 0) throw new Error(`Screen markers not found: ${fileName}`);

  const block = source.slice(start + startMarker.length, end).trim();
  const localBlock = block.replace(/transform="translate\([^)]*\)"/, 'transform="translate(0 0)"');
  const output = `<svg xmlns="http://www.w3.org/2000/svg" width="410" height="900" viewBox="0 0 410 900">\n${defs}\n${localBlock}\n</svg>\n`;
  await writeFile(path.join(outputDir, fileName), output);
}

console.log(`Created ${screens.length} screen SVGs in ${outputDir}`);
