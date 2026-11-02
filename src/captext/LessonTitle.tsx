import { useEffect, useMemo, useState } from "react";
import {
  AbsoluteFill,
  continueRender,
  delayRender,
  Easing,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { fitText, measureText } from "@remotion/layout-utils";
import { Sparkle } from "../chalpha/Fx";
import { clamp } from "../chalpha/Scenes";
import { handFont, roundFont } from "../fonts";
import timeline from "./lessonTimeline.json";

// "Bài tập / TRẢ GIAO BÓNG" title card: white sticker-style letters that drop in and squash,
// a blue washi-tape label with handwriting, and a pickleball that bounces beside the text.
// Every timing comes from lessonTimeline.json, which tools/make_sfx_lesson.py reads as well,
// so the sound effects land on the same moments as the picture.

export const LESSON_FPS = 60;
export const LESSON_SECONDS = timeline.seconds;

const WHITE = "#ffffff";
const BLUE = "#1a5cff";
const NAVY = "#0a2370";
const TEXT_WIDTH = 860;

// Tight contact shadow + soft long one, as in the MẮC LỖI motion.
const SHADOW =
  "drop-shadow(0 3px 3px rgba(0,0,0,0.55)) drop-shadow(0 12px 20px rgba(0,0,0,0.45))";

const EASE_OUT = Easing.bezier(0.16, 1, 0.3, 1);
const EASE_IN = Easing.bezier(0.55, 0, 1, 0.45);
const EASE_IN_OUT = Easing.bezier(0.65, 0, 0.35, 1);
const EASE_BACK = Easing.bezier(0.34, 1.56, 0.64, 1);

const rise = (t: number, start: number, duration: number, curve = EASE_OUT) =>
  interpolate(t, [start, start + duration], [0, 1], { ...clamp, easing: curve });

/** Damped wobble that starts at 1 at `t0` (squash on impact, jiggle after a bounce). */
const wobble = (t: number, t0: number, decay: number, freq: number) =>
  t < t0 ? 0 : Math.exp(-decay * (t - t0)) * Math.cos(freq * (t - t0));

// ---------------------------------------------------------------------------------------
const L1 = timeline.line1;
const L2 = timeline.line2;
const letters1 = Array.from(L1.text);
const letters2 = Array.from(L2.text);
const landTime1 = (i: number) => L1.start + i * L1.stagger + L1.fall;
const landTime2 = (i: number) => L2.start + i * L2.stagger + L2.rise;
const EXIT = timeline.exit;
const SEGMENTS = timeline.ball.segments;
const BALL_CONTACTS = SEGMENTS.map((s) => s.t1);

const useFitted = () => {
  const [handle] = useState(() => delayRender("lesson fonts"));
  const [size, setSize] = useState<number | null>(null);
  useEffect(() => {
    Promise.all([
      document.fonts.load(`800 100px "${roundFont}"`, L1.text + L2.text),
      document.fonts.load(`400 100px "${handFont}"`, "Bài tập"),
    ])
      .then(() => document.fonts.ready)
      .then(() => {
        setSize(
          fitText({
            text: L1.text,
            withinWidth: TEXT_WIDTH,
            fontFamily: roundFont,
            fontWeight: 800,
            letterSpacing: "0.02em",
          }).fontSize,
        );
        continueRender(handle);
      });
  }, [handle]);
  return size;
};

type LetterProps = {
  ch: string;
  size: number;
  style?: React.CSSProperties;
};

const Letter: React.FC<LetterProps> = ({ ch, size, style }) => {
  if (ch === " ") return <span style={{ display: "inline-block", width: size * 0.3 }} />;
  const depth = Math.round(size * 0.085);
  const extrude = Array.from({ length: depth }, (_, i) => `0 ${i + 1}px 0 ${NAVY}`).join(", ");
  return (
    <span
      style={{
        display: "inline-block",
        fontFamily: roundFont,
        fontWeight: 800,
        fontSize: size,
        lineHeight: 0.95,
        letterSpacing: "0.02em",
        color: WHITE,
        WebkitTextStroke: `${size * 0.075}px ${BLUE}`,
        paintOrder: "stroke fill",
        textShadow: extrude,
        transformOrigin: "50% 100%",
        ...style,
      }}
    >
      {ch}
    </span>
  );
};

// --- tape label -------------------------------------------------------------------------
const zigzag = (w: number, h: number, tooth = 14, depth = 9) => {
  const pts: string[] = [];
  const n = Math.round(h / tooth);
  pts.push(`${depth}px 0`, `${w - depth}px 0`);
  for (let i = 0; i < n; i++) {
    pts.push(`${w}px ${(i + 0.5) * tooth}px`, `${w - depth}px ${(i + 1) * tooth}px`);
  }
  pts.push(`${w - depth}px ${h}px`, `${depth}px ${h}px`);
  for (let i = n; i > 0; i--) {
    pts.push(`0px ${(i - 0.5) * tooth}px`, `${depth}px ${(i - 1) * tooth}px`);
  }
  return `polygon(${pts.join(",")})`;
};

const STAR =
  "M0 -34 L10 -11 L35 -11 L15 5 L22 30 L0 15 L-22 30 L-15 5 L-35 -11 L-10 -11 Z";

const Tape: React.FC<{ t: number; size: number }> = ({ t, size }) => {
  const w = size * 2.45;
  const h = size * 0.82;
  const intro = rise(t, timeline.tapeIn, 0.5, EASE_BACK);
  const out = rise(t, EXIT.tape, 0.45, EASE_IN);
  const rot = -12 + 7 * intro - 14 * out;
  const [w0, w1] = timeline.write;
  const write = rise(t, w0, w1 - w0, (x) => x);
  const underline = rise(t, w1 - 0.02, 0.22, EASE_IN_OUT);
  const star = rise(t, 0.34, 0.3, EASE_BACK);
  const dashes = rise(t, 0.38, 0.22, EASE_OUT);
  const textSize = size * 0.64;
  return (
    <div
      style={{
        position: "absolute",
        left: -size * 0.12,
        top: -h * 1.02,
        width: w,
        height: h,
        transform: `translateX(${-out * 900}px) rotate(${rot}deg) scale(${intro})`,
        transformOrigin: "20% 60%",
      }}
    >
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: `linear-gradient(180deg, #2f78ff, ${BLUE} 55%, #1448d0)`,
          clipPath: zigzag(w, h),
        }}
      />
      <div
        style={{
          position: "absolute",
          inset: h * 0.09,
          border: "3px dashed rgba(255,255,255,0.38)",
          borderRadius: 10,
        }}
      />
      <div
        style={{
          position: "absolute",
          left: w * 0.1,
          top: h * 0.1,
          fontFamily: handFont,
          fontSize: textSize,
          lineHeight: 1.25,
          color: WHITE,
          clipPath: `inset(-20% ${(1 - write) * 100}% -20% 0)`,
          textShadow: `0 3px 0 ${NAVY}`,
          whiteSpace: "pre",
        }}
      >
        Bài tập
      </div>
      <svg
        width={w}
        height={h}
        viewBox={`0 0 ${w} ${h}`}
        style={{ position: "absolute", left: 0, top: 0, overflow: "visible" }}
      >
        <path
          d={`M ${w * 0.1} ${h * 0.86} Q ${w * 0.3} ${h * 0.97} ${w * 0.5} ${h * 0.86} T ${w * 0.84} ${h * 0.88}`}
          stroke={WHITE}
          strokeWidth={6}
          strokeLinecap="round"
          fill="none"
          pathLength={1}
          strokeDasharray={1}
          strokeDashoffset={1 - underline}
          opacity={0.9}
        />
        {[0, 1, 2].map((i) => (
          <line
            key={i}
            x1={w + 22 + i * 4}
            y1={h * 0.18 + i * 20}
            x2={w + 22 + i * 4 + 30 - i * 6}
            y2={h * 0.18 + i * 20 - 10 + i * 5}
            stroke={WHITE}
            strokeWidth={7}
            strokeLinecap="round"
            pathLength={1}
            strokeDasharray={1}
            strokeDashoffset={1 - dashes}
          />
        ))}
        <g transform={`translate(${w + 6} ${-h * 0.2}) rotate(14) scale(${star})`}>
          <path d={STAR} fill={WHITE} stroke={NAVY} strokeWidth={5} strokeLinejoin="round" />
        </g>
      </svg>
    </div>
  );
};

// --- pickleball --------------------------------------------------------------------------
const HOLES = [
  [-0.38, -0.3],
  [0.1, -0.5],
  [0.45, -0.18],
  [-0.1, -0.05],
  [0.3, 0.3],
  [-0.5, 0.2],
  [-0.02, 0.5],
  [0.62, 0.1],
];

const ballAt = (t: number) => {
  for (const s of SEGMENTS) {
    if (t >= s.t0 && t < s.t1) {
      const u = (t - s.t0) / (s.t1 - s.t0);
      const h = s.kind === "fall" ? 1100 * (1 - u * u) : s.H * 4 * u * (1 - u);
      return { h, x: s.x0 + (s.x1 - s.x0) * u, flying: true, u, seg: s };
    }
  }
  const last = SEGMENTS[SEGMENTS.length - 1];
  if (t >= last.t1) return { h: 0, x: last.x1, flying: false, u: 1, seg: last, gone: true };
  return { h: 0, x: 0, flying: false, u: 0, seg: SEGMENTS[0], gone: false };
};

const Ball: React.FC<{ t: number; x: number; groundY: number; r: number }> = ({
  t,
  x,
  groundY,
  r,
}) => {
  if (t < SEGMENTS[0].t0) return null;
  const b = ballAt(t);
  const x1 = x + b.x;
  if (x1 > 1300) return null;
  // squash on every landing, stretch while flying fast
  let squash = 0;
  for (let i = 0; i < SEGMENTS.length; i++) {
    const s = SEGMENTS[i];
    const amp = s.kind === "fall" ? 0.38 : Math.min(0.34, 0.1 + s.H / 900);
    squash += amp * wobble(t, s.t1, 12, 36);
  }
  const sy = 1 - squash + (b.flying && b.h > 20 ? 0.06 : 0);
  const sx = 1 + squash * 0.8;
  const spin = t * 540 + b.x * 0.6;
  const shadowK = 1 - Math.min(b.h, 600) / 800;
  return (
    <>
      <div
        style={{
          position: "absolute",
          left: x1 - r * 0.9 * shadowK,
          top: groundY - 8,
          width: r * 1.8 * shadowK,
          height: 18,
          borderRadius: "50%",
          background: "rgba(0,0,0,0.45)",
          opacity: 1 - Math.min(b.h, 420) / 420,
          filter: "blur(4px)",
        }}
      />
      <svg
        width={r * 2}
        height={r * 2}
        viewBox="-50 -50 100 100"
        style={{
          position: "absolute",
          left: x1 - r,
          top: groundY - r * 2 - b.h,
          transform: `scale(${sx}, ${sy})`,
          transformOrigin: "50% 100%",
          overflow: "visible",
        }}
      >
        <defs>
          <radialGradient id="lt-ball" cx="0.35" cy="0.3" r="0.8">
            <stop offset="0" stopColor="#fff7a8" />
            <stop offset="0.55" stopColor="#ffd83a" />
            <stop offset="1" stopColor="#e0a800" />
          </radialGradient>
        </defs>
        <circle r={48} fill="url(#lt-ball)" stroke={NAVY} strokeWidth={4} />
        <g transform={`rotate(${spin})`}>
          {HOLES.map(([hx, hy], i) => (
            <circle key={i} cx={hx * 40} cy={hy * 40} r={6.5} fill="#b98a00" opacity={0.85} />
          ))}
        </g>
        <ellipse cx={-17} cy={-24} rx={11} ry={6} fill="white" opacity={0.7} transform="rotate(-35 -17 -24)" />
      </svg>
    </>
  );
};

// ----------------------------------------------------------------------------------------
export const LessonTitleText: React.FC<{ shadow?: boolean }> = ({ shadow = false }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const size = useFitted();

  const geo = useMemo(() => {
    if (!size) return null;
    const bong = measureText({
      text: L2.text,
      fontFamily: roundFont,
      fontSize: size,
      fontWeight: 800,
      letterSpacing: "0.02em",
    }).width;
    return { bong };
  }, [size]);

  if (!size || !geo) return <AbsoluteFill />;

  const lineH = size * 0.95;
  const stroke = size * 0.075;
  const depth = Math.round(size * 0.085);
  const ballR = size * 0.42;

  // line 1: letters drop from above and squash
  const letter1 = (i: number): React.CSSProperties => {
    const land = landTime1(i);
    const fall = L1.fall;
    const start = land - fall;
    const out = rise(t, EXIT.letters + (letters1.length - 1 - i) * 0.025, 0.42, EASE_IN);
    if (t < start || out >= 1) return { visibility: "hidden" };
    const p = Math.min(1, Math.max(0, (t - start) / fall));
    const y = -(1 - p * p) * 1000;
    const sq = wobble(t, land, 10, 34);
    const falling = t < land;
    const sy = falling ? 1.16 : 1 - 0.3 * sq;
    const sx = falling ? 0.92 : 1 + 0.22 * sq;
    const sway = t > land + 0.45 ? Math.sin(t * 3.1 + i * 0.8) : 0;
    return {
      transform: `translate(${out * (i % 2 ? 60 : -60)}px, ${y + out * 1300}px) rotate(${sway * 1.4 + out * (i % 2 ? 25 : -25)}deg) scale(${sx}, ${sy})`,
    };
  };
  // line 2: letters jump up from below; the last two jiggle when the ball lands next to them
  const letter2 = (i: number): React.CSSProperties => {
    const land = landTime2(i);
    const start = land - L2.rise;
    const out = rise(t, EXIT.letters + 0.05 + (letters2.length - 1 - i) * 0.025, 0.42, EASE_IN);
    if (t < start || out >= 1) return { visibility: "hidden" };
    const p = rise(t, start, L2.rise, EASE_BACK);
    const y = (1 - p) * 520;
    const sway = t > land + 0.45 ? Math.sin(t * 3.1 + (i + 3) * 0.8) : 0;
    let jiggle = 0;
    if (i >= letters2.length - 2) {
      BALL_CONTACTS.slice(0, 4).forEach((c, k) => {
        jiggle += (i === letters2.length - 1 ? 7 : 4) * (k % 2 ? -1 : 1) * wobble(t, c, 9, 38) * Math.sin(38 * (t - c));
      });
    }
    return {
      transform: `translate(${out * (i % 2 ? -60 : 60)}px, ${y + out * 1300}px) rotate(${sway * 1.4 + jiggle + out * (i % 2 ? -25 : 25)}deg)`,
    };
  };

  const groundY = lineH * 2 + depth * 0.4;
  const ballX = geo.bong + ballR * 1.7;

  const idle = Math.sin(t * 2.1) * 0.35;
  const sparkAt = (s: number) => Math.round(s * fps);

  return (
    <AbsoluteFill
      style={{
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <div
        style={{
          position: "relative",
          width: TEXT_WIDTH,
          height: lineH * 2,
          transform: `rotate(${idle}deg)`,
          filter: shadow ? SHADOW : undefined,
        }}
      >
        <div style={{ position: "absolute", left: stroke / 2, top: 0, whiteSpace: "pre" }}>
          {letters1.map((ch, i) => (
            <Letter key={i} ch={ch} size={size} style={letter1(i)} />
          ))}
        </div>
        <div style={{ position: "absolute", left: stroke / 2, top: lineH, whiteSpace: "pre" }}>
          {letters2.map((ch, i) => (
            <Letter key={i} ch={ch} size={size} style={letter2(i)} />
          ))}
        </div>
        <Ball t={t} x={ballX} groundY={groundY} r={ballR} />
        <Tape t={t} size={size} />
        {timeline.sparkles.map((s, i) => (
          <Sparkle
            key={i}
            x={[size * 1.2, size * 3.6, size * 4.5][i]}
            y={[lineH * 0.25, lineH * 1.1, lineH * 0.2][i]}
            size={[88, 70, 60][i]}
            at={sparkAt(s)}
          />
        ))}
      </div>
    </AbsoluteFill>
  );
};

export const LessonTitleAlpha: React.FC = () => <LessonTitleText shadow />;
