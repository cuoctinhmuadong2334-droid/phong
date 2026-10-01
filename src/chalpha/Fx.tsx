import { AbsoluteFill, Easing, interpolate, random, useCurrentFrame } from "remotion";
import { COLORS } from "./content";
import { clamp } from "./Scenes";

// Small reusable motion effects for the story edit.

const easeOut = Easing.out(Easing.cubic);

/** Four-point star glint that pops, spins a little and fades. */
export const Sparkle: React.FC<{ x: number; y: number; size: number; at: number }> = ({
  x,
  y,
  size,
  at,
}) => {
  const frame = useCurrentFrame();
  const t = (frame - at) / 20;
  if (t < 0 || t > 1) return null;
  const s = Math.sin(Math.PI * t);
  return (
    <svg
      width={size}
      height={size}
      viewBox="-50 -50 100 100"
      style={{
        position: "absolute",
        left: x - size / 2,
        top: y - size / 2,
        transform: `scale(${s}) rotate(${t * 90}deg)`,
        filter: "drop-shadow(0 0 10px rgba(255,255,255,0.9))",
      }}
    >
      <path d="M0 -50 Q6 -6 50 0 Q6 6 0 50 Q-6 6 -50 0 Q-6 -6 0 -50 Z" fill="white" />
    </svg>
  );
};

/** Pain beats: red shock-wave rings from the joint and a red pulse at the screen edges. */
export const PainFx: React.FC<{ cx: number; cy: number; beats: number[] }> = ({
  cx,
  cy,
  beats,
}) => {
  const frame = useCurrentFrame();
  const edge = Math.max(
    0,
    ...beats.map((b) => interpolate(frame - b, [0, 4, 22], [0, 1, 0], clamp)),
  );
  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      {beats.flatMap((b) =>
        [0, 7].map((lag) => {
          const t = (frame - b - lag) / 28;
          if (t < 0 || t > 1) return null;
          const r = 70 + 300 * easeOut(t);
          return (
            <div
              key={`${b}-${lag}`}
              style={{
                position: "absolute",
                left: cx - r,
                top: cy - r,
                width: r * 2,
                height: r * 2,
                borderRadius: "50%",
                border: `${8 * (1 - t)}px solid rgba(255,70,70,${0.75 * (1 - t)})`,
                boxShadow: `0 0 ${30 * (1 - t)}px rgba(255,40,40,${0.5 * (1 - t)})`,
              }}
            />
          );
        }),
      )}
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at 50% 50%, rgba(255,0,0,0) 50%, rgba(255,30,30,0.45) 100%)",
          opacity: edge,
        }}
      />
    </AbsoluteFill>
  );
};

/** Short decaying camera jolt after each beat. */
export const useShake = (beats: number[], amplitude = 6) => {
  const frame = useCurrentFrame();
  const a = beats.reduce(
    (acc, b) => acc + interpolate(frame - b, [0, 2, 10], [0, amplitude, 0], clamp),
    0,
  );
  return `translate(${Math.sin(frame * 2.7) * a}px, ${Math.cos(frame * 3.4) * a}px)`;
};

const BURST_PARTICLES = new Array(12).fill(true).map((_, i) => ({
  angle: (i / 12) * Math.PI * 2 + random(`ba-${i}`) * 0.4,
  dist: 160 + random(`bd-${i}`) * 140,
  size: 6 + random(`bs-${i}`) * 8,
}));

/** Healing flash on the joint: cyan ring, glow and particles flying outward. */
export const HealBurst: React.FC<{ cx: number; cy: number; at: number[] }> = ({ cx, cy, at }) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      {at.map((start) => {
        const t = (frame - start) / 26;
        if (t < 0 || t > 1) return null;
        const e = easeOut(t);
        const r = 50 + 260 * e;
        return (
          <AbsoluteFill key={start}>
            <div
              style={{
                position: "absolute",
                left: cx - 260,
                top: cy - 260,
                width: 520,
                height: 520,
                borderRadius: "50%",
                background: `radial-gradient(circle, rgba(143,211,255,${0.7 * (1 - t)}) 0%, rgba(143,211,255,0) 60%)`,
              }}
            />
            <div
              style={{
                position: "absolute",
                left: cx - r,
                top: cy - r,
                width: r * 2,
                height: r * 2,
                borderRadius: "50%",
                border: `${6 * (1 - t)}px solid rgba(143,211,255,${0.9 * (1 - t)})`,
              }}
            />
            {BURST_PARTICLES.map((p, i) => (
              <div
                key={i}
                style={{
                  position: "absolute",
                  left: cx + Math.cos(p.angle) * p.dist * e - p.size / 2,
                  top: cy + Math.sin(p.angle) * p.dist * e - p.size / 2,
                  width: p.size,
                  height: p.size,
                  borderRadius: "50%",
                  background: "white",
                  opacity: 1 - t,
                  boxShadow: `0 0 12px ${COLORS.cartilage}`,
                }}
              />
            ))}
          </AbsoluteFill>
        );
      })}
    </AbsoluteFill>
  );
};

/** Soft light leak drifting diagonally across the frame. */
export const LightLeak: React.FC<{ start: number; duration: number }> = ({ start, duration }) => {
  const frame = useCurrentFrame();
  const t = (frame - start) / duration;
  if (t < 0 || t > 1) return null;
  return (
    <AbsoluteFill style={{ mixBlendMode: "screen", pointerEvents: "none" }}>
      <div
        style={{
          position: "absolute",
          width: 900,
          height: 900,
          left: -500 + 1400 * t,
          top: -200 + 500 * t,
          borderRadius: "50%",
          background:
            "radial-gradient(circle, rgba(160,220,255,0.55) 0%, rgba(120,170,255,0.18) 40%, rgba(120,170,255,0) 70%)",
          opacity: Math.sin(Math.PI * t),
          filter: "blur(10px)",
        }}
      />
    </AbsoluteFill>
  );
};
