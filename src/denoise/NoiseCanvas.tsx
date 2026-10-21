import { useLayoutEffect, useRef } from "react";
import { useCurrentFrame } from "remotion";

// Deterministic per-frame noise so every render of a frame is identical.
export const mulberry32 = (seed: number) => () => {
  seed = (seed + 0x6d2b79f5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};

type Painter = (data: Uint8ClampedArray, w: number, h: number, rand: () => number) => void;

/** Low-res canvas repainted every frame and scaled up without smoothing (chunky grain). */
export const PixelCanvas: React.FC<{
  w: number;
  h: number;
  seed: number;
  paint: Painter;
  style?: React.CSSProperties;
}> = ({ w, h, seed, paint, style }) => {
  const frame = useCurrentFrame();
  const ref = useRef<HTMLCanvasElement>(null);
  useLayoutEffect(() => {
    const ctx = ref.current?.getContext("2d");
    if (!ctx) return;
    const img = ctx.createImageData(w, h);
    paint(img.data, w, h, mulberry32(seed * 100003 + frame * 7919));
    ctx.putImageData(img, 0, 0);
  });
  return (
    <canvas
      ref={ref}
      width={w}
      height={h}
      style={{ position: "absolute", imageRendering: "pixelated", ...style }}
    />
  );
};

/**
 * TV static. `amountAt(x)` (x in 0..1 across the screen) scales the noise so a sweep
 * can clean the picture column by column.
 */
export const screenStatic =
  (amountAt: (x: number) => number, band: number): Painter =>
  (d, w, h, rand) => {
    const cols = new Float32Array(w);
    for (let x = 0; x < w; x++) cols[x] = amountAt(x / w);
    for (let y = 0; y < h; y++) {
      // a bright rolling band, like a detuned signal
      const by = Math.abs(y / h - band);
      const boost = by < 0.06 ? 1 + 0.5 * (1 - by / 0.06) : 1;
      for (let x = 0; x < w; x++) {
        const a = cols[x];
        const i = (y * w + x) * 4;
        if (a <= 0.001) {
          d[i + 3] = 255;
          continue;
        }
        const r = rand();
        const v = Math.min(255, r * r * 255 * 1.6 * boost) * a;
        d[i] = d[i + 1] = d[i + 2] = v;
        d[i + 3] = 255;
      }
    }
  };

/** Black specks on a transparent canvas — "noise" inside the letters. */
export const specks =
  (density: number): Painter =>
  (d, w, h, rand) => {
    for (let i = 0; i < w * h; i++) {
      if (rand() < density) {
        d[i * 4 + 3] = 140 + rand() * 115;
      }
    }
  };
