import {
  AbsoluteFill,
  Easing,
  interpolate,
  random,
  Sequence,
  useCurrentFrame,
  useVideoConfig,
  spring,
} from "remotion";
import { bodyFont } from "../fonts";
import { COLORS, CONTENT } from "./content";
import { AMPOULE_IMAGE, Product } from "./Product";
import { BenefitCard, centered, clamp, useEnter } from "./Scenes";

const BUBBLES = new Array(30).fill(true).map((_, i) => ({
  x: random(`sx-${i}`) * 1080,
  y: random(`sy-${i}`) * 1920,
  r: 6 + random(`sr-${i}`) * 22,
  speed: 0.5 + random(`ss-${i}`) * 1.3,
}));

const StatsBackground: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{
        background: "linear-gradient(180deg, #0a2470 0%, #1f4fae 45%, #4f8ae0 80%, #7fb2f7 100%)",
        overflow: "hidden",
      }}
    >
      {BUBBLES.map((b, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            left: b.x,
            top: ((((b.y - frame * b.speed) % 2020) + 2020) % 2020) - 100,
            width: b.r * 2,
            height: b.r * 2,
            borderRadius: "50%",
            background:
              "radial-gradient(circle at 35% 35%, rgba(255,255,255,0.5), rgba(255,255,255,0.08) 65%, rgba(255,255,255,0) 70%)",
          }}
        />
      ))}
    </AbsoluteFill>
  );
};

// Ampoule keyframes (global frame -> centre x/y and height), eased between.
const KEYS = [
  { f: 0, x: 540, y: 950, h: 880 },
  { f: 100, x: 540, y: 950, h: 880 },
  { f: 128, x: 790, y: 1000, h: 940 },
  { f: 330, x: 790, y: 1000, h: 940 },
  { f: 358, x: 540, y: 480, h: 640 },
  { f: 450, x: 540, y: 480, h: 640 },
  { f: 478, x: 540, y: 790, h: 900 },
];

const Ampoule: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const frames = KEYS.map((k) => k.f);
  const ease = { ...clamp, easing: Easing.inOut(Easing.cubic) };
  const x = interpolate(frame, frames, KEYS.map((k) => k.x), ease);
  const y = interpolate(frame, frames, KEYS.map((k) => k.y), ease);
  const h = interpolate(frame, frames, KEYS.map((k) => k.h), ease);
  const w = h / AMPOULE_IMAGE.ratio;
  const enter = spring({ frame: frame - 4, fps, config: { damping: 13 } });
  const float = Math.sin(frame / 20) * 12;
  return (
    <div
      style={{
        position: "absolute",
        left: x - w / 2,
        top: y - h / 2 + float + (1 - enter) * 1300,
        transform: `rotate(${(1 - enter) * -40 + Math.sin(frame / 30) * 2}deg)`,
      }}
    >
      <Product width={w} image={AMPOULE_IMAGE} sweepEvery={80} glow={false} />
    </div>
  );
};

const Header: React.FC = () => {
  const enter = useEnter();
  const t = enter(0, 200);
  return (
    <div style={{ ...centered, top: 130, opacity: t }}>
      <div style={{ fontSize: 88, fontWeight: 800, lineHeight: 1.1 }}>{CONTENT.productName}</div>
      <div style={{ fontSize: 34, fontWeight: 700, letterSpacing: 2, marginTop: 14, opacity: 0.9 }}>
        {CONTENT.brandLine}
      </div>
    </div>
  );
};

const IntroScene: React.FC = () => {
  const enter = useEnter();
  const [line1, line2] = CONTENT.tagline.split("\n");
  const l1 = enter(30, 200);
  const l2 = enter(40, 12);
  return (
    <AbsoluteFill>
      <div style={{ ...centered, top: 1420 }}>
        <div
          style={{
            fontSize: 56,
            fontWeight: 700,
            opacity: l1,
            transform: `translateY(${interpolate(l1, [0, 1], [40, 0])}px)`,
          }}
        >
          {line1}
        </div>
        <div
          style={{
            fontSize: 80,
            fontWeight: 800,
            background: COLORS.red,
            padding: "4px 34px",
            borderRadius: 20,
            marginTop: 12,
            transform: `scale(${l2})`,
          }}
        >
          {line2}
        </div>
      </div>
    </AbsoluteFill>
  );
};

const Triangle: React.FC<{ up: boolean }> = ({ up }) => (
  <svg width="64" height="56" viewBox="0 0 64 56">
    <path d={up ? "M32 0 L64 56 L0 56 Z" : "M0 0 L64 0 L32 56 Z"} fill="white" />
  </svg>
);

const StatBlock: React.FC<{
  top: number;
  delay: number;
  value: number;
  up: boolean;
  label: string;
}> = ({ top, delay, value, up, label }) => {
  const frame = useCurrentFrame();
  const enter = useEnter();
  const t = enter(delay, 200);
  const count = interpolate(frame, [delay, delay + 40], [0, value], {
    ...clamp,
    easing: Easing.out(Easing.cubic),
  });
  const lines = interpolate(frame, [delay, delay + 25], [0, 1], clamp);
  return (
    <div style={{ position: "absolute", left: 90, top, width: 470, fontFamily: bodyFont, color: "white" }}>
      <div
        style={{
          position: "absolute",
          left: 0,
          top: -20,
          width: 3,
          height: 330 * lines,
          background: "white",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: -40,
          top: 190,
          width: 500 * lines,
          height: 3,
          background: "white",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: -9,
          top: 182,
          width: 20,
          height: 20,
          background: "white",
          transform: `scale(${lines})`,
        }}
      />
      <div
        style={{
          position: "absolute",
          left: 24,
          top: 10,
          display: "flex",
          alignItems: "center",
          gap: 14,
          opacity: t,
          transform: `translateY(${interpolate(t, [0, 1], [30, 0])}px)`,
        }}
      >
        <Triangle up={up} />
        <span style={{ fontSize: 170, fontWeight: 800, lineHeight: 1 }}>{Math.round(count)}</span>
        <span style={{ fontSize: 80, fontWeight: 700, alignSelf: "flex-end", marginBottom: 6 }}>%</span>
      </div>
      <div
        style={{
          position: "absolute",
          left: 24,
          top: 212,
          width: 430,
          fontSize: 38,
          fontWeight: 500,
          lineHeight: 1.35,
          opacity: interpolate(frame, [delay + 15, delay + 30], [0, 1], clamp),
        }}
      >
        {label}
      </div>
    </div>
  );
};

const RingStat: React.FC<{ delay: number }> = ({ delay }) => {
  const frame = useCurrentFrame();
  const enter = useEnter();
  const pop = enter(delay, 12);
  const { value, label } = CONTENT.ringStat;
  const progress = interpolate(frame, [delay + 5, delay + 50], [0, value / 100], {
    ...clamp,
    easing: Easing.out(Easing.cubic),
  });
  const r = 125;
  const c = 2 * Math.PI * r;
  return (
    <div
      style={{
        position: "absolute",
        left: 60,
        top: 1150,
        width: 480,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        fontFamily: bodyFont,
        color: "white",
        transform: `scale(${pop})`,
      }}
    >
      <div style={{ position: "relative", width: 300, height: 300 }}>
        <svg width="300" height="300" viewBox="0 0 300 300">
          <circle cx="150" cy="150" r={r} fill="none" stroke="rgba(255,255,255,0.2)" strokeWidth="16" />
          <circle
            cx="150"
            cy="150"
            r={r}
            fill="none"
            stroke="white"
            strokeWidth="16"
            strokeLinecap="round"
            strokeDasharray={c}
            strokeDashoffset={c * (1 - progress)}
            transform="rotate(-90 150 150)"
          />
        </svg>
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontSize: 92,
            fontWeight: 800,
          }}
        >
          {Math.round(progress * 100)}%
        </div>
      </div>
      <div
        style={{
          marginTop: 18,
          fontSize: 36,
          fontWeight: 500,
          lineHeight: 1.35,
          textAlign: "center",
          opacity: interpolate(frame, [delay + 20, delay + 35], [0, 1], clamp),
        }}
      >
        {label}
      </div>
    </div>
  );
};

const StatsScene: React.FC = () => (
  <AbsoluteFill>
    {CONTENT.stats.map((s, i) => (
      <StatBlock
        key={s.label}
        top={440 + i * 360}
        delay={30 + i * 50}
        value={s.value}
        up={s.direction === "up"}
        label={s.label}
      />
    ))}
    <RingStat delay={130} />
  </AbsoluteFill>
);

const BenefitScene: React.FC = () => {
  const enter = useEnter();
  return (
    <AbsoluteFill>
      <div
        style={{
          position: "absolute",
          top: 880,
          left: 60,
          right: 60,
          display: "flex",
          flexDirection: "column",
          gap: 26,
        }}
      >
        {CONTENT.benefits.map((benefit, i) => (
          <BenefitCard
            key={benefit}
            text={benefit}
            index={i}
            enter={enter(20 + i * 18, 15)}
            check={enter(32 + i * 18, 10)}
          />
        ))}
      </div>
    </AbsoluteFill>
  );
};

const CtaScene: React.FC = () => {
  const frame = useCurrentFrame();
  const enter = useEnter();
  const name = enter(20, 200);
  const button = enter(34, 10);
  const pulse = 1 + Math.max(0, Math.sin((frame - 40) / 6)) * 0.05;
  return (
    <AbsoluteFill>
      <div
        style={{
          ...centered,
          top: 1260,
          opacity: name,
          transform: `translateY(${interpolate(name, [0, 1], [40, 0])}px)`,
        }}
      >
        <div style={{ fontSize: 84, fontWeight: 800 }}>{CONTENT.productName}</div>
        <div style={{ fontSize: 38, fontWeight: 500, marginTop: 4 }}>{CONTENT.pack}</div>
      </div>
      <div style={{ ...centered, top: 1470 }}>
        <div
          style={{
            fontSize: 56,
            fontWeight: 800,
            background: COLORS.red,
            borderRadius: 999,
            padding: "24px 80px",
            boxShadow: "0 0 0 8px rgba(255,255,255,0.3), 0 20px 50px rgba(0,0,0,0.35)",
            transform: `scale(${button * pulse})`,
          }}
        >
          {CONTENT.cta}
        </div>
      </div>
    </AbsoluteFill>
  );
};

const FADE = 12;
const SCENES = [
  { from: 0, duration: 340, Component: Header },
  { from: 0, duration: 110, Component: IntroScene },
  { from: 100, duration: 240, Component: StatsScene },
  { from: 330, duration: 130, Component: BenefitScene },
  { from: 450, duration: 110, Component: CtaScene },
];

export const CH_ALPHA_STATS_DURATION = 560;

export const ChAlphaStatsPromo: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill>
      <StatsBackground />
      {SCENES.map(({ from, duration, Component }, i) => {
        const isLast = from + duration >= CH_ALPHA_STATS_DURATION;
        const opacity = interpolate(
          frame - from,
          [0, FADE, duration - FADE, duration],
          [from === 0 ? 1 : 0, 1, 1, isLast ? 1 : 0],
          clamp,
        );
        return (
          <Sequence key={i} from={from} durationInFrames={duration}>
            <AbsoluteFill style={{ opacity }}>
              <Component />
            </AbsoluteFill>
          </Sequence>
        );
      })}
      <Ampoule />
      <div
        style={{
          position: "absolute",
          top: 1680,
          left: 90,
          right: 90,
          textAlign: "center",
          fontFamily: bodyFont,
          fontSize: 26,
          fontWeight: 500,
          lineHeight: 1.4,
          color: "rgba(255,255,255,0.85)",
        }}
      >
        {CONTENT.disclaimer}
      </div>
    </AbsoluteFill>
  );
};
