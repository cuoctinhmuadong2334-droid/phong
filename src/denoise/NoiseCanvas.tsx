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
  // repaint the noise every `step` frames (keeps grain from shimmering at 60fps)
  step?: number;
  style?: React.CSSProperties;
}> = ({ w, h, seed, paint, step = 1, style }) => {
  const frame = useCurrentFrame();
  const ref = useRef<HTMLCanvasElement>(null);
  useLayoutEffect(() => {
    const ctx = ref.current?.getContext("2d");
    if (!ctx) return;
    const img = ctx.createImageData(w, h);
    paint(img.data, w, h, mulberry32(seed * 100003 + Math.floor(frame / step) * 7919));
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

/** Luminance grain (random light and dark specks) for the "noisy photo". */
export const grain =
  (intensity: number): Painter =>
  (d, w, h, rand) => {
    for (let i = 0; i < w * h; i++) {
      const v = rand() < 0.5 ? 0 : 255;
      d[i * 4] = d[i * 4 + 1] = d[i * 4 + 2] = v;
      d[i * 4 + 3] = intensity * 255 * rand();
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
