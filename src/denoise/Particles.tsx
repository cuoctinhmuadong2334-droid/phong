import { useLayoutEffect, useRef } from "react";
import { Easing, useCurrentFrame, useVideoConfig } from "remotion";
import { mulberry32 } from "./NoiseCanvas";

export type Box = { x: number; y: number; w: number; h: number };

/**
 * Stray noise grains that drift into the letters. Each grain twinkles where it is,
 * then flies to a point sampled from the logo and fades as it lands.
 */
export const Particles: React.FC<{
  points: [number, number][];
  box: Box;
  start: number;
  duration: number;
}> = ({ points, box, start, duration }) => {
  const frame = useCurrentFrame();
  const { width, height } = useVideoConfig();
  const ref = useRef<HTMLCanvasElement>(null);
  useLayoutEffect(() => {
    const ctx = ref.current?.getContext("2d");
    if (!ctx) return;
    ctx.clearRect(0, 0, width, height);
    const local = frame - start;
    if (local < 0 || local > duration) return;
    const rand = mulberry32(42);
    const ease = Easing.inOut(Easing.cubic);
    const flight = duration * 0.55;
    for (let i = 0; i < points.length; i++) {
      const sx = rand() * width;
      const sy = rand() * height;
      const delay = rand() * (duration - flight - 8);
      const size = 1.5 + rand() * 2.5;
      const twinkle = rand() * 6.28;
      const t = Math.min(1, Math.max(0, (local - delay) / flight));
      const e = ease(t);
      const tx = box.x + points[i][0] * box.w;
      const ty = box.y + points[i][1] * box.h;
      const x = sx + (tx - sx) * e;
      const y = sy + (ty - sy) * e;
      const appear = Math.min(1, local / 8);
      const alpha =
        t >= 1 ? 0 : appear * (t === 0 ? 0.35 + 0.35 * Math.sin(local / 3 + twinkle) : 1 - t * 0.6);
      if (alpha <= 0) continue;
      ctx.fillStyle = `rgba(255,255,255,${alpha})`;
      ctx.fillRect(x, y, size, size);
    }
  });
  return <canvas ref={ref} width={width} height={height} style={{ position: "absolute" }} />;
};
