import {
  AbsoluteFill,
  Easing,
  interpolate,
  random,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Background } from "./Background";
import { COLORS } from "./content";
import { Sparkle } from "./Fx";
import { Joint } from "./Joint";
import { clamp } from "./Scenes";

// "...thoải mái di chuyển, vung vợt" — a paddle swings through and smashes a pickleball.
// All timings are frames local to the scene.

const HIT = 50;
const PIVOT = { x: 470, y: 1250 };
const REACH = 380; // pivot -> centre of the paddle face
const CONTACT = { x: 660, y: 860 };

const angleAt = (f: number) =>
  f < 30
    ? interpolate(f, [0, 30], [-30, -48], {
        ...clamp,
        easing: Easing.out(Easing.quad),
      })
    : f < HIT
      ? interpolate(f, [30, HIT], [-48, 25], {
          ...clamp,
          easing: Easing.in(Easing.quad),
        })
      : interpolate(f, [HIT, 72], [25, 55], {
          ...clamp,
          easing: Easing.out(Easing.cubic),
        });

const ballAt = (f: number) => {
  if (f <= HIT) {
    const t = interpolate(f, [8, HIT], [0, 1], clamp);
    const [p0, c, p1] = [{ x: 1000, y: 420 }, { x: 860, y: 520 }, CONTACT];
    const u = 1 - t;
    return {
      x: u * u * p0.x + 2 * u * t * c.x + t * t * p1.x,
      y: u * u * p0.y + 2 * u * t * c.y + t * t * p1.y,
      s: 1,
    };
  }
  const t = interpolate(f, [HIT, HIT + 14], [0, 1], {
    ...clamp,
    easing: Easing.out(Easing.quad),
  });
  return {
    x: CONTACT.x + (1250 - CONTACT.x) * t,
    y: CONTACT.y + (120 - CONTACT.y) * t,
    s: 1 - 0.45 * t,
  };
};

const Court: React.FC = () => {
  const xl = (y: number) => 180 - ((y - 1180) / 740) * 400;
  const xr = (y: number) => 900 + ((y - 1180) / 740) * 400;
  const line = {
    stroke: "rgba(255,255,255,0.85)",
    strokeWidth: 6,
    fill: "none",
  };
  return (
    <svg width={1080} height={1920} style={{ position: "absolute" }}>
      <defs>
        <linearGradient id="court" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#2a78d0" />
          <stop offset="1" stopColor="#123f86" />
        </linearGradient>
      </defs>
      <polygon
        points="180,1180 900,1180 1300,1920 -220,1920"
        fill="url(#court)"
      />
      <polygon points="180,1180 900,1180 1300,1920 -220,1920" {...line} />
      <line x1={xl(1420)} y1={1420} x2={xr(1420)} y2={1420} {...line} />
      {/* Net */}
      <rect
        x={150}
        y={1120}
        width={780}
        height={60}
        fill="rgba(255,255,255,0.12)"
      />
      <line
        x1={150}
        y1={1120}
        x2={930}
        y2={1120}
        stroke="white"
        strokeWidth={8}
      />
      <line
        x1={150}
        y1={1112}
        x2={150}
        y2={1185}
        stroke="white"
        strokeWidth={10}
      />
      <line
        x1={930}
        y1={1112}
        x2={930}
        y2={1185}
        stroke="white"
        strokeWidth={10}
      />
    </svg>
  );
};

const Paddle: React.FC<{ angle: number }> = ({ angle }) => (
  <svg
    width={340}
    height={600}
    viewBox="-170 -580 340 600"
    style={{
      position: "absolute",
      left: PIVOT.x - 170,
      top: PIVOT.y - 580,
      transformOrigin: "170px 580px",
      transform: `rotate(${angle}deg)`,
      filter: "drop-shadow(0 20px 30px rgba(0,0,0,0.45))",
    }}
  >
    <defs>
      <linearGradient id="paddle-face" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stopColor="#ff3b40" />
        <stop offset="1" stopColor={COLORS.red} />
      </linearGradient>
    </defs>
    <rect x={-28} y={-215} width={56} height={215} rx={14} fill="#10204a" />
    {[0, 1, 2, 3, 4].map((i) => (
      <line
        key={i}
        x1={-28}
        y1={-190 + i * 38}
        x2={28}
        y2={-170 + i * 38}
        stroke="#2c4a8a"
        strokeWidth={6}
      />
    ))}
    <path
      d="M-150 -420 Q-150 -560 0 -560 Q150 -560 150 -420 L150 -270 Q150 -205 0 -205 Q-150 -205 -150 -270 Z"
      fill="url(#paddle-face)"
      stroke="#14141a"
      strokeWidth={12}
    />
    <path
      d="M-150 -330 L150 -380 L150 -350 L-150 -300 Z"
      fill="white"
      opacity={0.85}
    />
    <path
      d="M-110 -500 Q0 -540 110 -500"
      stroke="rgba(255,255,255,0.4)"
      strokeWidth={10}
      fill="none"
    />
  </svg>
);

const Ball: React.FC<{
  x: number;
  y: number;
  scale: number;
  opacity?: number;
}> = ({ x, y, scale, opacity = 1 }) => {
  const holes = [
    [-18, -20],
    [14, -26],
    [-2, 0],
    [24, 6],
    [-26, 14],
    [8, 26],
  ];
  return (
    <svg
      width={110}
      height={110}
      viewBox="-55 -55 110 110"
      style={{
        position: "absolute",
        left: x - 55,
        top: y - 55,
        transform: `scale(${scale})`,
        opacity,
        filter: "drop-shadow(0 10px 18px rgba(0,0,0,0.35))",
      }}
    >
      <defs>
        <radialGradient id="pb-ball" cx="0.35" cy="0.3" r="0.75">
          <stop offset="0" stopColor="#fff27a" />
          <stop offset="1" stopColor="#e3b400" />
        </radialGradient>
      </defs>
      <circle r={52} fill="url(#pb-ball)" />
      {holes.map(([hx, hy], i) => (
        <circle key={i} cx={hx} cy={hy} r={7} fill="#8a6a00" opacity={0.75} />
      ))}
    </svg>
  );
};

const SPEED_LINES = new Array(14).fill(true).map((_, i) => ({
  x: 200 + random(`sl-x-${i}`) * 700,
  y: 200 + random(`sl-y-${i}`) * 800,
  len: 120 + random(`sl-l-${i}`) * 180,
  delay: random(`sl-d-${i}`) * 8,
}));

export const PickleballScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const angle = angleAt(frame);
  const ball = ballAt(frame);
  const swoosh = interpolate(frame, [32, 42, 54, 62], [0, 0.9, 0.9, 0], clamp);
  const fromA = (-48 * Math.PI) / 180;
  const toA = (angle * Math.PI) / 180;
  const arcPt = (a: number) => ({
    x: PIVOT.x + REACH * Math.sin(a),
    y: PIVOT.y - REACH * Math.cos(a),
  });
  const a0 = arcPt(fromA);
  const a1 = arcPt(toA);
  const badge = spring({ frame: frame - 64, fps, config: { damping: 11 } });
  const check = spring({ frame: frame - 74, fps, config: { damping: 9 } });
  const camera = interpolate(frame, [0, 105], [1, 1.06], clamp);

  return (
    <AbsoluteFill>
      <Background />
      <AbsoluteFill
        style={{
          transformOrigin: "540px 1000px",
          transform: `scale(${camera})`,
        }}
      >
        <Court />
        {SPEED_LINES.map((l, i) => {
          const t = (frame - HIT - l.delay) / 14;
          if (t < 0 || t > 1) return null;
          return (
            <div
              key={i}
              style={{
                position: "absolute",
                left: l.x + 260 * t,
                top: l.y - 300 * t,
                width: l.len,
                height: 5,
                borderRadius: 3,
                background:
                  "linear-gradient(90deg, rgba(255,255,255,0), rgba(255,255,255,0.8))",
                transform: "rotate(-48deg)",
                opacity: Math.sin(Math.PI * t),
              }}
            />
          );
        })}
        {swoosh > 0 && (
          <svg
            width={1080}
            height={1920}
            style={{ position: "absolute", opacity: swoosh }}
          >
            <defs>
              <linearGradient
                id="swoosh"
                x1={a0.x}
                y1={a0.y}
                x2={a1.x}
                y2={a1.y}
                gradientUnits="userSpaceOnUse"
              >
                <stop offset="0" stopColor="white" stopOpacity="0" />
                <stop offset="1" stopColor="white" stopOpacity="0.85" />
              </linearGradient>
            </defs>
            <path
              d={`M ${a0.x} ${a0.y} A ${REACH} ${REACH} 0 0 1 ${a1.x} ${a1.y}`}
              stroke="url(#swoosh)"
              strokeWidth={70}
              strokeLinecap="round"
              fill="none"
              style={{ filter: "blur(4px)" }}
            />
          </svg>
        )}
        {frame > HIT &&
          [4, 3, 2, 1].map((k) => {
            const g = ballAt(frame - k * 2);
            return (
              <Ball
                key={k}
                x={g.x}
                y={g.y}
                scale={g.s}
                opacity={0.12 * (5 - k)}
              />
            );
          })}
        <Paddle angle={angle} />
        {frame >= 8 && frame < HIT + 16 && (
          <Ball x={ball.x} y={ball.y} scale={ball.s} />
        )}
        {(() => {
          const t = (frame - HIT) / 16;
          if (t < 0 || t > 1) return null;
          const r = 40 + 200 * Easing.out(Easing.cubic)(t);
          return (
            <div
              style={{
                position: "absolute",
                left: CONTACT.x - r,
                top: CONTACT.y - r,
                width: r * 2,
                height: r * 2,
                borderRadius: "50%",
                border: `${10 * (1 - t)}px solid rgba(255,230,120,${1 - t})`,
                background: `radial-gradient(circle, rgba(255,255,255,${0.8 * (1 - t)}), rgba(255,255,255,0) 60%)`,
              }}
            />
          );
        })()}
        <Sparkle x={CONTACT.x} y={CONTACT.y} size={240} at={HIT} />
        {/* "...mà không lo mài mòn sụn": healthy joint badge */}
        <div
          style={{
            position: "absolute",
            left: 540 - 160,
            top: 170,
            width: 320,
            height: 320,
            borderRadius: "50%",
            background: "rgba(255,255,255,0.14)",
            border: "2px solid rgba(255,255,255,0.4)",
            boxShadow: `0 0 60px rgba(143,211,255,${0.6 * badge})`,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            opacity: interpolate(badge, [0, 0.4], [0, 1], clamp),
            transform: `scale(${badge})`,
          }}
        >
          <Joint width={190} health={1} inflammation={0} flow={0} />
          <div
            style={{
              position: "absolute",
              right: 6,
              bottom: 14,
              width: 96,
              height: 96,
              borderRadius: "50%",
              background: COLORS.blue,
              border: "5px solid white",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              transform: `scale(${check})`,
            }}
          >
            <svg width="54" height="54" viewBox="0 0 24 24">
              <path
                d="M4 12.5 L9.5 18 L20 6"
                fill="none"
                stroke="white"
                strokeWidth="3.4"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
