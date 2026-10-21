import { random } from "remotion";

// A studio "photo" built in SVG: a camera body seen head-on with a big lens, on a
// dark backdrop with bokeh. The lens is the shape that match-cuts into the "o".

export type Lens = { cx: number; cy: number; r: number };

export const lensFor = (width: number, height: number): Lens => {
  const r = Math.min(width, height) * 0.36;
  return width >= height
    ? { cx: width / 2, cy: height * 0.5, r }
    : { cx: width / 2, cy: height * 0.45, r };
};

const BOKEH = new Array(16).fill(true).map((_, i) => ({
  x: random(`bk-x-${i}`),
  y: random(`bk-y-${i}`),
  r: 30 + random(`bk-r-${i}`) * 90,
  warm: random(`bk-c-${i}`) > 0.5,
  o: 0.15 + random(`bk-o-${i}`) * 0.3,
}));

export const LensPhoto: React.FC<{ width: number; height: number; lens: Lens }> = ({
  width,
  height,
  lens,
}) => {
  const { cx, cy, r } = lens;
  const bodyW = Math.min(width * 0.86, r * 3.6);
  const bodyH = r * 2.35;
  const ring = (f: number) => r * f;
  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} style={{ position: "absolute" }}>
      <defs>
        <radialGradient id="lp-bg" cx="0.5" cy="0.45" r="0.75">
          <stop offset="0" stopColor="#1b2440" />
          <stop offset="0.6" stopColor="#0b0f1d" />
          <stop offset="1" stopColor="#030409" />
        </radialGradient>
        <linearGradient id="lp-body" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#30333b" />
          <stop offset="0.5" stopColor="#1a1c21" />
          <stop offset="1" stopColor="#0c0d10" />
        </linearGradient>
        <pattern id="lp-leather" width="6" height="6" patternUnits="userSpaceOnUse">
          <circle cx="3" cy="3" r="1.1" fill="rgba(255,255,255,0.05)" />
        </pattern>
        <radialGradient id="lp-barrel" cx="0.4" cy="0.35" r="0.75">
          <stop offset="0" stopColor="#4a4e57" />
          <stop offset="0.6" stopColor="#1e2026" />
          <stop offset="1" stopColor="#0a0b0d" />
        </radialGradient>
        <radialGradient id="lp-glass" cx="0.45" cy="0.42" r="0.65">
          <stop offset="0" stopColor="#05060f" />
          <stop offset="0.45" stopColor="#141c4a" />
          <stop offset="0.8" stopColor="#2a1d5c" />
          <stop offset="1" stopColor="#0b0a1c" />
        </radialGradient>
        <linearGradient id="lp-coat" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#3cffb4" stopOpacity="0.55" />
          <stop offset="0.5" stopColor="#7a5cff" stopOpacity="0.45" />
          <stop offset="1" stopColor="#ff4fd8" stopOpacity="0.5" />
        </linearGradient>
        <filter id="lp-blur20">
          <feGaussianBlur stdDeviation="20" />
        </filter>
        <filter id="lp-blur6">
          <feGaussianBlur stdDeviation="6" />
        </filter>
        <path
          id="lp-text-path"
          d={`M ${cx - ring(0.82)} ${cy} A ${ring(0.82)} ${ring(0.82)} 0 0 1 ${cx + ring(0.82)} ${cy}`}
        />
      </defs>

      <rect width={width} height={height} fill="url(#lp-bg)" />
      <g filter="url(#lp-blur20)">
        {BOKEH.map((b, i) => (
          <circle
            key={i}
            cx={b.x * width}
            cy={b.y * height}
            r={b.r}
            fill={b.warm ? "#ffb35c" : "#5cc8ff"}
            opacity={b.o}
          />
        ))}
      </g>

      {/* camera body */}
      <rect
        x={cx - bodyW / 2}
        y={cy - bodyH * 0.52}
        width={bodyW}
        height={bodyH}
        rx={r * 0.22}
        fill="url(#lp-body)"
      />
      <rect
        x={cx - bodyW / 2}
        y={cy - bodyH * 0.52}
        width={bodyW}
        height={bodyH}
        rx={r * 0.22}
        fill="url(#lp-leather)"
      />
      <rect
        x={cx - bodyW / 2 + r * 0.25}
        y={cy - bodyH * 0.52 - r * 0.12}
        width={r * 0.5}
        height={r * 0.16}
        rx={r * 0.05}
        fill="#24262c"
      />
      <circle cx={cx + bodyW / 2 - r * 0.35} cy={cy - bodyH * 0.35} r={r * 0.06} fill="#c8202a" />
      <rect
        x={cx - bodyW / 2}
        y={cy - bodyH * 0.52}
        width={bodyW}
        height={bodyH}
        rx={r * 0.22}
        fill="none"
        stroke="rgba(255,255,255,0.12)"
        strokeWidth={3}
      />

      {/* lens */}
      <circle cx={cx} cy={cy} r={ring(1.04)} fill="rgba(0,0,0,0.6)" filter="url(#lp-blur6)" />
      <circle cx={cx} cy={cy} r={ring(1)} fill="url(#lp-barrel)" stroke="rgba(255,255,255,0.25)" strokeWidth={3} />
      <circle
        cx={cx}
        cy={cy}
        r={ring(0.935)}
        fill="none"
        stroke="rgba(255,255,255,0.18)"
        strokeWidth={ring(0.07)}
        strokeDasharray="3 5"
      />
      <circle cx={cx} cy={cy} r={ring(0.885)} fill="none" stroke="#d0202a" strokeWidth={5} />
      <circle cx={cx} cy={cy} r={ring(0.86)} fill="#0d0e11" />
      <text
        fontFamily="Arial, Helvetica, sans-serif"
        fontSize={ring(0.055)}
        letterSpacing={ring(0.012)}
        fill="rgba(255,255,255,0.55)"
      >
        <textPath href="#lp-text-path" startOffset="50%" textAnchor="middle">
          50mm 1:1.2 · Ø77
        </textPath>
      </text>
      <circle cx={cx} cy={cy} r={ring(0.72)} fill="#08090b" stroke="rgba(255,255,255,0.1)" strokeWidth={2} />
      <circle cx={cx} cy={cy} r={ring(0.64)} fill="url(#lp-glass)" />
      <circle cx={cx} cy={cy} r={ring(0.47)} fill="none" stroke="rgba(120,140,255,0.25)" strokeWidth={2} />
      <circle cx={cx} cy={cy} r={ring(0.3)} fill="none" stroke="rgba(160,120,255,0.25)" strokeWidth={2} />
      <polygon
        points={new Array(6)
          .fill(0)
          .map((_, i) => {
            const a = (i / 6) * Math.PI * 2 + 0.3;
            return `${cx + Math.cos(a) * ring(0.2)},${cy + Math.sin(a) * ring(0.2)}`;
          })
          .join(" ")}
        fill="#020205"
        opacity={0.85}
      />
      {/* multi-coating reflections */}
      <path
        d={`M ${cx - ring(0.55)} ${cy - ring(0.1)} A ${ring(0.58)} ${ring(0.58)} 0 0 1 ${cx + ring(0.1)} ${cy - ring(0.56)}`}
        stroke="url(#lp-coat)"
        strokeWidth={ring(0.06)}
        fill="none"
        strokeLinecap="round"
        filter="url(#lp-blur6)"
      />
      <path
        d={`M ${cx + ring(0.18)} ${cy + ring(0.38)} A ${ring(0.42)} ${ring(0.42)} 0 0 0 ${cx + ring(0.42)} ${cy + ring(0.05)}`}
        stroke="url(#lp-coat)"
        strokeWidth={ring(0.04)}
        fill="none"
        strokeLinecap="round"
        opacity={0.8}
      />
      <ellipse
        cx={cx - ring(0.26)}
        cy={cy - ring(0.3)}
        rx={ring(0.16)}
        ry={ring(0.08)}
        transform={`rotate(-35 ${cx - ring(0.26)} ${cy - ring(0.3)})`}
        fill="rgba(255,255,255,0.55)"
        filter="url(#lp-blur6)"
      />
      <circle cx={cx - ring(0.12)} cy={cy - ring(0.4)} r={ring(0.025)} fill="white" opacity={0.9} />
    </svg>
  );
};
