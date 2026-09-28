import { interpolate, interpolateColors, random, useCurrentFrame } from "remotion";
import { COLORS } from "./content";

type Props = {
  width: number;
  /** 0 = worn cartilage, 1 = healthy cartilage */
  health: number;
  /** 0..1 red inflammation glow */
  inflammation: number;
  /** 0..1 collagen particles flowing into the cartilage */
  flow: number;
};

const PARTICLES = new Array(28).fill(true).map((_, i) => ({
  angle: random(`pa-${i}`) * Math.PI * 2,
  dist: 260 + random(`pd-${i}`) * 160,
  offset: random(`po-${i}`),
  size: 5 + random(`ps-${i}`) * 7,
}));

// Simplified knee joint (femur + tibia) in a 600x800 viewBox.
export const Joint: React.FC<Props> = ({ width, health, inflammation, flow }) => {
  const frame = useCurrentFrame();
  const cartColor = interpolateColors(health, [0, 1], ["#c98f8f", COLORS.cartilage]);
  const thickness = interpolate(health, [0, 1], [6, 22]);
  const dash = `${interpolate(health, [0, 1], [22, 400])} ${interpolate(health, [0, 1], [16, 0])}`;
  const pulse = 0.75 + Math.sin(frame / 5) * 0.25;

  return (
    <svg width={width} height={(width * 800) / 600} viewBox="0 0 600 800">
      <defs>
        <radialGradient id="joint-inflam">
          <stop offset="0" stopColor="#ff2a2a" stopOpacity="0.9" />
          <stop offset="1" stopColor="#ff2a2a" stopOpacity="0" />
        </radialGradient>
        <radialGradient id="joint-heal">
          <stop offset="0" stopColor={COLORS.cartilage} stopOpacity="0.8" />
          <stop offset="1" stopColor={COLORS.cartilage} stopOpacity="0" />
        </radialGradient>
        <linearGradient id="joint-bone" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stopColor="#d9ccb2" />
          <stop offset="0.45" stopColor={COLORS.bone} />
          <stop offset="1" stopColor="#cbbd9f" />
        </linearGradient>
      </defs>

      <circle cx="300" cy="415" r={260} fill="url(#joint-heal)" opacity={health * 0.7} />

      {/* Femur */}
      <path
        d="M220,0 L380,0 L385,260 C470,290 480,390 400,400 C350,405 330,385 300,385 C270,385 250,405 200,400 C120,390 130,290 215,260 Z"
        fill="url(#joint-bone)"
        stroke="#b8a888"
        strokeWidth="3"
      />
      {/* Tibia */}
      <path
        d="M150,440 C150,425 450,425 450,440 L440,500 C400,520 390,540 385,560 L380,800 L220,800 L215,560 C210,540 200,520 160,500 Z"
        fill="url(#joint-bone)"
        stroke="#b8a888"
        strokeWidth="3"
      />

      {/* Cartilage */}
      <g
        fill="none"
        stroke={cartColor}
        strokeWidth={thickness}
        strokeLinecap="round"
        strokeDasharray={dash}
      >
        <path d="M150,352 C160,404 240,408 300,390 C360,408 440,404 450,352" />
        <path d="M168,432 C220,420 380,420 432,432" />
      </g>

      <circle
        cx="300"
        cy="412"
        r={170 * pulse}
        fill="url(#joint-inflam)"
        opacity={inflammation}
      />

      {PARTICLES.map((p, i) => {
        const t = ((frame / 45 + p.offset) % 1) * flow;
        const d = p.dist * (1 - t);
        return (
          <circle
            key={i}
            cx={300 + Math.cos(p.angle) * d}
            cy={412 + Math.sin(p.angle) * d * 0.8}
            r={p.size * (1 - t * 0.6)}
            fill="white"
            opacity={flow * interpolate(t, [0, 0.15, 0.85, 1], [0, 1, 1, 0])}
            style={{ filter: "drop-shadow(0 0 8px #8fd3ff)" }}
          />
        );
      })}
    </svg>
  );
};
