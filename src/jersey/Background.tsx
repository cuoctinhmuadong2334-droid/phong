import { AbsoluteFill, interpolate, random, useCurrentFrame } from "remotion";

const LIGHTS = new Array(40).fill(true).map((_, i) => ({
  x: random(`x-${i}`) * 1080,
  y: 760 + random(`y-${i}`) * 300,
  r: 2 + random(`r-${i}`) * 5,
  phase: random(`p-${i}`) * Math.PI * 2,
}));

export const Background: React.FC = () => {
  const frame = useCurrentFrame();
  const sweep = Math.sin(frame / 40) * 6;

  return (
    <AbsoluteFill
      style={{
        background:
          "radial-gradient(ellipse at 50% 30%, #1a7a3a 0%, #0b4420 45%, #031a0c 100%)",
        overflow: "hidden",
      }}
    >
      {[-38, -20, -6, 8, 22, 40].map((angle, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            left: 540 - 60,
            top: -200,
            width: 120,
            height: 1300,
            transformOrigin: "50% 0%",
            transform: `rotate(${angle + sweep}deg)`,
            background:
              "linear-gradient(180deg, rgba(160,255,170,0.22), rgba(160,255,170,0) 70%)",
            filter: "blur(18px)",
          }}
        />
      ))}
      <div
        style={{
          position: "absolute",
          left: -100,
          right: -100,
          bottom: -120,
          height: 420,
          background:
            "radial-gradient(ellipse at 50% 100%, rgba(255,200,60,0.28), rgba(255,200,60,0) 70%)",
        }}
      />
      {LIGHTS.map((l, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            left: l.x,
            top: l.y,
            width: l.r * 2,
            height: l.r * 2,
            borderRadius: "50%",
            background: "#ffd96b",
            opacity: interpolate(Math.sin(frame / 12 + l.phase), [-1, 1], [0.15, 0.7]),
            filter: "blur(1.5px)",
          }}
        />
      ))}
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(180deg, rgba(0,0,0,0) 55%, rgba(0,0,0,0.55) 100%)",
        }}
      />
    </AbsoluteFill>
  );
};
