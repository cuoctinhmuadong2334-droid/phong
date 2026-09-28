import { AbsoluteFill, random, useCurrentFrame } from "remotion";
import { COLORS } from "./content";

const BUBBLES = new Array(36).fill(true).map((_, i) => ({
  x: random(`bx-${i}`) * 1080,
  y: random(`by-${i}`) * 1920,
  r: 6 + random(`br-${i}`) * 26,
  speed: 0.6 + random(`bs-${i}`) * 1.6,
  drift: random(`bd-${i}`) * Math.PI * 2,
}));

// Deep-blue backdrop with collagen-like bubbles drifting upward.
export const Background: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{
        background: `radial-gradient(ellipse at 50% 35%, ${COLORS.blue} 0%, ${COLORS.blueDark} 70%, #041237 100%)`,
        overflow: "hidden",
      }}
    >
      {BUBBLES.map((b, i) => {
        const y = (((b.y - frame * b.speed) % 2020) + 2020) % 2020 - 100;
        const x = b.x + Math.sin(frame / 40 + b.drift) * 20;
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: x,
              top: y,
              width: b.r * 2,
              height: b.r * 2,
              borderRadius: "50%",
              background:
                "radial-gradient(circle at 35% 35%, rgba(255,255,255,0.55), rgba(143,211,255,0.12) 60%, rgba(143,211,255,0) 70%)",
              border: "1px solid rgba(255,255,255,0.15)",
            }}
          />
        );
      })}
    </AbsoluteFill>
  );
};
