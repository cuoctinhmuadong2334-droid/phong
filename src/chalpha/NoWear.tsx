import {
  AbsoluteFill,
  Easing,
  interpolate,
  random,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { bodyFont } from "../fonts";
import { COLORS } from "./content";
import { Sparkle, useShake } from "./Fx";
import { Joint } from "./Joint";
import { clamp } from "./Scenes";

// "...mà không lo mài mòn sụn": friction sparks fly at the cartilage, a shield
// deflects every one of them, then a stamp slams in. Frames are relative to `start`.

const CENTER = { x: 540, y: 760 }; // cartilage gap of the big joint
const SHIELD = { rx: 250, ry: 82 };
const STAMP_AT = 24;

const SPARKS = new Array(14).fill(true).map((_, i) => {
  const side = i % 2 === 0 ? -1 : 1;
  return {
    side,
    y: CENTER.y + (random(`nw-y-${i}`) - 0.5) * 120,
    at: 5 + Math.floor(i / 2) * 2 + random(`nw-d-${i}`) * 2,
    len: 120 + random(`nw-l-${i}`) * 90,
  };
});

const IMPACT_FRAMES = 7; // travel time of a spark to the shield

const Spark: React.FC<{ frame: number; s: (typeof SPARKS)[number] }> = ({ frame, s }) => {
  const t = (frame - s.at) / IMPACT_FRAMES;
  const hitX = CENTER.x + s.side * SHIELD.rx;
  if (t < 0) return null;
  if (t <= 1) {
    // incoming red/orange friction streak
    const x = hitX + s.side * 560 * (1 - Easing.in(Easing.quad)(t));
    return (
      <div
        style={{
          position: "absolute",
          left: s.side < 0 ? x - s.len : x,
          top: s.y - 6,
          width: s.len,
          height: 12,
          borderRadius: 6,
          background:
            s.side < 0
              ? "linear-gradient(90deg, rgba(255,60,30,0), #ff5a2a 60%, #fff3c4)"
              : "linear-gradient(90deg, #fff3c4, #ff5a2a 40%, rgba(255,60,30,0))",
          boxShadow: "0 0 24px rgba(255,70,30,1), 0 0 8px rgba(255,220,150,0.9)",
        }}
      />
    );
  }
  // deflected: small cyan burst at the shield
  const b = (frame - s.at - IMPACT_FRAMES) / 10;
  if (b > 1) return null;
  const r = 14 + 70 * Easing.out(Easing.cubic)(b);
  return (
    <div
      style={{
        position: "absolute",
        left: hitX - r,
        top: s.y - r,
        width: r * 2,
        height: r * 2,
        borderRadius: "50%",
        background: `radial-gradient(circle, rgba(255,255,255,${1 - b}), rgba(143,211,255,${0.8 * (1 - b)}) 40%, rgba(143,211,255,0) 70%)`,
      }}
    />
  );
};

export const NoWearMoment: React.FC<{ start: number }> = ({ start }) => {
  const frame = useCurrentFrame() - start;
  const { fps } = useVideoConfig();
  const shake = useShake([start + STAMP_AT], 10);
  if (frame < 0) return null;

  const dim = interpolate(frame, [0, 8], [0, 1], clamp);
  const joint = spring({ frame, fps, config: { damping: 15 } });
  const shield = spring({ frame: frame - 4, fps, config: { damping: 12 } });
  // the shield flares each time a spark lands on it
  const hits = SPARKS.reduce(
    (acc, s) => acc + interpolate(frame - s.at - IMPACT_FRAMES, [0, 2, 10], [0, 1, 0], clamp),
    0,
  );
  const flare = Math.min(1, hits);
  const stamp = spring({ frame: frame - STAMP_AT, fps, config: { damping: 11, mass: 0.8 } });
  const shock = (frame - STAMP_AT) / 18;

  return (
    <AbsoluteFill style={{ transform: shake }}>
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at 50% 40%, rgba(10,36,99,0.92), rgba(2,8,30,0.98))",
          opacity: dim,
        }}
      />
      {/* big healthy joint */}
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: CENTER.y - 288,
          display: "flex",
          justifyContent: "center",
          opacity: joint,
          transform: `scale(${0.6 + 0.4 * joint})`,
          transformOrigin: `${CENTER.x}px 288px`,
        }}
      >
        <Joint width={420} health={1} inflammation={0} flow={0} />
      </div>
      {/* protective shield around the cartilage */}
      <div
        style={{
          position: "absolute",
          left: CENTER.x - SHIELD.rx,
          top: CENTER.y - SHIELD.ry,
          width: SHIELD.rx * 2,
          height: SHIELD.ry * 2,
          borderRadius: "50%",
          border: `${4 + 4 * flare}px solid rgba(143,211,255,${0.75 + 0.25 * flare})`,
          background: `radial-gradient(ellipse, rgba(143,211,255,${0.08 + 0.25 * flare}), rgba(143,211,255,0) 70%)`,
          boxShadow: `0 0 ${30 + 50 * flare}px rgba(143,211,255,0.85), inset 0 0 ${20 + 30 * flare}px rgba(143,211,255,0.6)`,
          opacity: shield,
          transform: `scale(${(0.5 + 0.5 * shield) * (1 + 0.06 * flare)})`,
        }}
      />
      {SPARKS.map((s, i) => (
        <Spark key={i} frame={frame} s={s} />
      ))}
      {/* stamp */}
      {shock >= 0 && shock <= 1 && (
        <div
          style={{
            position: "absolute",
            left: 540 - (120 + 420 * shock),
            top: 300 - (60 + 210 * shock),
            width: 2 * (120 + 420 * shock),
            height: 2 * (60 + 210 * shock),
            borderRadius: "50%",
            border: `${8 * (1 - shock)}px solid rgba(255,255,255,${0.8 * (1 - shock)})`,
          }}
        />
      )}
      <div
        style={{
          position: "absolute",
          top: 190,
          left: 0,
          right: 0,
          display: "flex",
          justifyContent: "center",
          opacity: interpolate(stamp, [0, 0.25], [0, 1], clamp),
          transform: `scale(${2.2 - 1.2 * stamp}) rotate(${-6 * stamp}deg)`,
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 22,
            padding: "22px 40px 22px 24px",
            borderRadius: 30,
            border: "6px solid white",
            background: `linear-gradient(135deg, ${COLORS.blueLight}, ${COLORS.blue})`,
            boxShadow: "0 0 50px rgba(143,211,255,0.7), 0 20px 40px rgba(0,0,0,0.4)",
            fontFamily: bodyFont,
            color: "white",
          }}
        >
          <div
            style={{
              width: 92,
              height: 92,
              borderRadius: "50%",
              background: "white",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              flexShrink: 0,
            }}
          >
            <svg width="58" height="58" viewBox="0 0 24 24">
              <path
                d="M4 12.5 L9.5 18 L20 6"
                fill="none"
                stroke={COLORS.blue}
                strokeWidth="3.6"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </div>
          <div style={{ fontSize: 58, fontWeight: 800, lineHeight: 1.1 }}>
            KHÔNG LO
            <br />
            MÀI MÒN SỤN
          </div>
        </div>
      </div>
      <Sparkle x={250} y={210} size={90} at={start + STAMP_AT + 4} />
      <Sparkle x={850} y={380} size={70} at={start + STAMP_AT + 9} />
    </AbsoluteFill>
  );
};
