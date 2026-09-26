import { loadFont } from "@remotion/fonts";
import { staticFile } from "remotion";

// Fonts are bundled in public/fonts (SIL Open Font License, via Fontsource)
// so rendering works offline and in CI.

const LATIN =
  "U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD";
const VIETNAMESE =
  "U+0102-0103,U+0110-0111,U+0128-0129,U+0168-0169,U+01A0-01A1,U+01AF-01B0,U+0300-0301,U+0303-0304,U+0308-0309,U+0323,U+0329,U+1EA0-1EF9,U+20AB";

const load = (
  family: string,
  file: string,
  weights: string[],
  subsets: { name: string; range: string }[] = [{ name: "latin", range: LATIN }],
) => {
  for (const weight of weights) {
    for (const subset of subsets) {
      loadFont({
        family,
        url: staticFile(`fonts/${file}-${subset.name}-${weight}-normal.woff2`),
        weight,
        unicodeRange: subset.range,
      });
    }
  }
  return family;
};

export const titleFont = load("Oswald", "oswald", ["500", "700"]);

export const bodyFont = load("Be Vietnam Pro", "be-vietnam-pro", ["500", "700"], [
  { name: "latin", range: LATIN },
  { name: "vietnamese", range: VIETNAMESE },
]);

export const scriptFont = load("Great Vibes", "great-vibes", ["400"]);

export const techFont = load("Orbitron", "orbitron", ["500", "700"]);
