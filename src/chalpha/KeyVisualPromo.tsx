import {
  AbsoluteFill,
  Easing,
  Img,
  interpolate,
  random,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { bodyFont } from "../fonts";
import { COLORS, CONTENT } from "./content";
import { clamp } from "./Scenes";

// Motion version of the 1080x1920 key visual. The photo (product, floor, glassware)
// stays untouched in `plate.jpg`; only the logo, badge and headline were lifted off
// the flat blue sky into their own layers so they can animate in.

export const CH_ALPHA_KV_DURATION = 450;

type Box = [x: number, y: number, w: number, h: number];

const LAYERS: Record<string, Box> = {
  logo: [55, 64, 297, 81],
  badge: [864, 47, 160, 129],
  line1: [128, 309, 817, 84],
  line2: [287, 392, 505, 80],
};
const PRODUCT: Box = [183, 947, 807, 530];
const PRODUCT_CENTER = { x: PRODUCT[0] + PRODUCT[2] / 2, y: PRODUCT[1] + PRODUCT[3] / 2 };

const kv = (name: string) => staticFile(`chalpha/kv/${name}`);

const Layer: React.FC<{ name: string; style?: React.CSSProperties }> = ({ name, style }) => {
  const [x, y, w, h] = LAYERS[name];
  return (
    <Img
      src={kv(`${name}.png`)}
      style={{ position: "absolute", left: x, top: y, width: w, height: h, ...style }}
    />
  );
};

const BUBBLES = new Array(22).fill(true).map((_, i) => ({
  x: random(`kx-${i}`) * 1080,
  y: random(`ky-${i}`) * 1100,
  r: 5 + random(`kr-${i}`) * 16,
  speed: 0.4 + random(`ks-${i}`) * 1.1,
}));

// Soft light beams and drifting bubbles, kept to the sky above the product.
const Atmosphere: React.FC = () => {
  const frame = useCurrentFrame();
  const sky = "linear-gradient(180deg, black 0%, black 38%, transparent 52%)";
  return (
    <AbsoluteFill style={{ WebkitMaskImage: sky, maskImage: sky }}>
      {[-30, -14, 0, 14, 30].map((angle, i) => (
        <div
          key={angle}
          style={{
            position: "absolute",
            left: 540 - 70,
            top: -260,
            width: 140,
            height: 1500,
            transformOrigin: "50% 0%",
            transform: `rotate(${angle + Math.sin(frame / 45 + i) * 5}deg)`,
            background:
              "linear-gradient(180deg, rgba(170,205,255,0.16), rgba(170,205,255,0) 75%)",
            filter: "blur(22px)",
            mixBlendMode: "screen",
          }}
        />
      ))}
      {BUBBLES.map((b, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            left: b.x + Math.sin(frame / 35 + i) * 12,
            top: ((((b.y - frame * b.speed) % 1150) + 1150) % 1150) - 50,
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

// Glossy highlight sweeping across the product, clipped to its silhouette.
const ProductShine: React.FC<{ sweeps: number[] }> = ({ sweeps }) => {
  const frame = useCurrentFrame();
  const [x, y, w, h] = PRODUCT;
  const start = [...sweeps].reverse().find((s) => frame >= s) ?? sweeps[0];
  const p = interpolate(frame, [start, start + 45], [-25, 125], {
    ...clamp,
    easing: Easing.inOut(Easing.quad),
  });
  const mask = `url(${kv("product-mask.png")})`;
  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        width: w,
        height: h,
        WebkitMaskImage: mask,
        WebkitMaskSize: "100% 100%",
        maskImage: mask,
        maskSize: "100% 100%",
        background: `linear-gradient(105deg, rgba(255,255,255,0) ${p - 9}%, rgba(255,255,255,0.7) ${p}%, rgba(255,255,255,0) ${p + 9}%)`,
      }}
    />
  );
};

/**
 * The key-visual photo with its camera, atmosphere, product shine and title layers.
 * `pullback`: start close on the product and pull back to the full poster.
 * `settle`: start slightly zoomed in and ease back (used when returning to the poster).
 * Children are overlays placed in poster coordinates (they move with the camera).
 * `fx` adds motion blur to the camera move and a light bloom as the titles come in.
 */
export const KeyVisualStage: React.FC<{
  camera: "pullback" | "settle";
  animateTitles: boolean;
  sweeps: number[];
  duration: number;
  fx?: boolean;
  children?: React.ReactNode;
}> = ({ camera, animateTitles, sweeps, duration, fx = false, children }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const pullback = camera === "pullback";
  const pullbackAt = (f: number) =>
    pullback
      ? interpolate(f, [0, 80], [1, 0], { ...clamp, easing: Easing.inOut(Easing.cubic) })
      : 0;
  const u = pullbackAt(frame);
  const motionBlur = fx ? Math.abs(u - pullbackAt(frame + 1)) * 50 : 0;
  const bloom = (p: number) => {
    const g = fx && animateTitles ? interpolate(p, [0, 0.5, 1], [0, 1, 0.15]) : 0;
    return g > 0.01 ? `drop-shadow(0 0 ${18 * g}px rgba(255,255,255,${0.9 * g}))` : undefined;
  };
  const settle = pullback
    ? 1
    : interpolate(frame, [0, 40], [1.1, 1], { ...clamp, easing: Easing.out(Easing.cubic) });
  const driftFrom = pullback ? 80 : 40;
  const push = interpolate(frame, [driftFrom, duration], [1, pullback ? 1.035 : 1.025], clamp);

  const logo = animateTitles ? spring({ frame: frame - 52, fps, config: { damping: 200 } }) : 1;
  const badge = animateTitles ? spring({ frame: frame - 64, fps, config: { damping: 11 } }) : 1;
  const reveal = (start: number) =>
    animateTitles
      ? interpolate(frame, [start, start + 28], [0, 1], {
          ...clamp,
          easing: Easing.out(Easing.cubic),
        })
      : 1;
  const line = (p: number): React.CSSProperties => ({
    clipPath: `inset(-20% ${(1 - p) * 100}% -20% 0)`,
    transform: `translateY(${(1 - p) * 18}px)`,
    filter: bloom(p),
  });

  return (
    <AbsoluteFill style={{ backgroundColor: "#00308a", overflow: "hidden" }}>
      <AbsoluteFill
        style={{ transformOrigin: "540px 1000px", transform: `scale(${push * settle})` }}
      >
        <AbsoluteFill
          style={{
            transformOrigin: `${PRODUCT_CENTER.x}px ${PRODUCT_CENTER.y}px`,
            transform: `translate(${-46 * u}px, ${-200 * u}px) scale(${1 + 0.3 * u})`,
            filter: motionBlur > 0.05 ? `blur(${motionBlur}px)` : undefined,
          }}
        >
          <Img src={kv("plate.jpg")} style={{ position: "absolute", width: 1080, height: 1920 }} />
          <Atmosphere />
          <ProductShine sweeps={sweeps} />
          <Layer
            name="logo"
            style={{
              opacity: logo,
              transform: `translateX(${(1 - logo) * -70}px)`,
              filter: bloom(logo),
            }}
          />
          <Layer
            name="badge"
            style={{
              opacity: interpolate(badge, [0, 0.5], [0, 1], clamp),
              transform: `scale(${0.4 + 0.6 * badge}) rotate(${(1 - badge) * -20 + Math.sin(frame / 22) * 1.2 * badge}deg)`,
            }}
          />
          <Layer name="line1" style={line(reveal(70))} />
          <Layer name="line2" style={line(reveal(86))} />
          {children}
        </AbsoluteFill>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

const Check: React.FC<{ scale: number }> = ({ scale }) => (
  <div
    style={{
      flexShrink: 0,
      width: 60,
      height: 60,
      borderRadius: "50%",
      background: "white",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      transform: `scale(${scale})`,
    }}
  >
    <svg width="34" height="34" viewBox="0 0 24 24">
      <path
        d="M4 12.5 L9.5 18 L20 6"
        fill="none"
        stroke={COLORS.blue}
        strokeWidth="3.4"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  </div>
);

const glassPill: React.CSSProperties = {
  background: "rgba(255,255,255,0.14)",
  border: "1.5px solid rgba(255,255,255,0.35)",
};

const BENEFIT_DELAYS = [135, 165, 195];

const Benefits: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <div
      style={{
        position: "absolute",
        top: 540,
        left: 64,
        right: 64,
        display: "flex",
        flexDirection: "column",
        gap: 18,
      }}
    >
      {CONTENT.benefits.map((benefit, i) => {
        const d = BENEFIT_DELAYS[i];
        const e = spring({ frame: frame - d, fps, config: { damping: 15 } });
        const check = spring({ frame: frame - d - 10, fps, config: { damping: 10 } });
        return (
          <div
            key={benefit}
            style={{
              ...glassPill,
              display: "flex",
              alignItems: "center",
              gap: 22,
              padding: "16px 28px 16px 16px",
              borderRadius: 48,
              opacity: interpolate(e, [0, 0.4], [0, 1], clamp),
              transform: `translateY(${interpolate(e, [0, 1], [40, 0])}px)`,
            }}
          >
            <Check scale={check} />
            <div
              style={{
                fontFamily: bodyFont,
                fontSize: 34,
                fontWeight: 700,
                lineHeight: 1.3,
                color: "white",
                textShadow: "0 2px 8px rgba(0,0,0,0.25)",
              }}
            >
              {benefit}
            </div>
          </div>
        );
      })}
    </div>
  );
};

// Ingredient chips in the empty sky between the headline and the product.
export const KvIngredients: React.FC<{ start: number }> = ({ start }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const label = spring({ frame: frame - start, fps, config: { damping: 200 } });
  return (
    <div
      style={{
        position: "absolute",
        top: 590,
        left: 60,
        right: 60,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 26,
        fontFamily: bodyFont,
      }}
    >
      <div
        style={{
          fontSize: 30,
          fontWeight: 700,
          letterSpacing: 6,
          color: "rgba(255,255,255,0.9)",
          opacity: label,
          transform: `translateY(${interpolate(label, [0, 1], [20, 0])}px)`,
        }}
      >
        THÀNH PHẦN
      </div>
      <div style={{ display: "flex", flexWrap: "wrap", justifyContent: "center", gap: 18 }}>
        {CONTENT.ingredients.map((item, i) => {
          const t = spring({ frame: frame - start - 6 - i * 6, fps, config: { damping: 14 } });
          return (
            <div
              key={item}
              style={{
                ...glassPill,
                fontSize: 34,
                fontWeight: 700,
                color: "white",
                padding: "14px 30px",
                borderRadius: 999,
                textShadow: "0 2px 8px rgba(0,0,0,0.25)",
                opacity: interpolate(t, [0, 0.4], [0, 1], clamp),
                transform: `translateY(${interpolate(t, [0, 1], [30, 0])}px) scale(${interpolate(t, [0, 1], [0.9, 1])})`,
              }}
            >
              + {item}
            </div>
          );
        })}
      </div>
    </div>
  );
};

// Pack info and order button on the light floor below the product.
// `fx` adds a shimmer across the button and ripples radiating from it.
export const KvCallToAction: React.FC<{ start: number; fx?: boolean }> = ({
  start,
  fx = false,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pack = spring({ frame: frame - start, fps, config: { damping: 200 } });
  const button = spring({ frame: frame - start - 12, fps, config: { damping: 10 } });
  const pulseFrom = start + 30;
  const pulse = frame > pulseFrom ? 1 + Math.max(0, Math.sin((frame - pulseFrom) / 6)) * 0.05 : 1;
  const since = frame - pulseFrom;
  const ripples = fx ? [0, 18].filter((lag) => since >= lag).map((lag) => ((since - lag) % 36) / 36) : [];
  const shimmer = interpolate(((frame - start - 20) % 50 + 50) % 50, [0, 30], [-60, 160], clamp);
  return (
    <div
      style={{
        position: "absolute",
        top: 1556,
        left: 0,
        right: 0,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 22,
        fontFamily: bodyFont,
      }}
    >
      <div
        style={{
          fontSize: 34,
          fontWeight: 500,
          color: COLORS.blueDark,
          opacity: pack,
          transform: `translateY(${interpolate(pack, [0, 1], [20, 0])}px)`,
        }}
      >
        {CONTENT.pack}
      </div>
      <div style={{ position: "relative", transform: `scale(${button * pulse})` }}>
        {ripples.map((t, i) => (
          <div
            key={i}
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: 999,
              border: `4px solid ${COLORS.red}`,
              opacity: 0.6 * (1 - t),
              transform: `scale(${1 + 0.18 * t}, ${1 + 0.5 * t})`,
            }}
          />
        ))}
        <div
          style={{
            position: "relative",
            overflow: "hidden",
            fontSize: 50,
            fontWeight: 800,
            color: "white",
            background: COLORS.red,
            borderRadius: 999,
            padding: "20px 72px",
            boxShadow: "0 16px 36px rgba(215,20,26,0.35)",
          }}
        >
          {CONTENT.cta}
          {fx && frame > start + 20 && (
            <div
              style={{
                position: "absolute",
                inset: 0,
                background: `linear-gradient(105deg, rgba(255,255,255,0) ${shimmer - 14}%, rgba(255,255,255,0.55) ${shimmer}%, rgba(255,255,255,0) ${shimmer + 14}%)`,
              }}
            />
          )}
        </div>
      </div>
    </div>
  );
};

/**
 * Mandatory notice, fixed on screen (outside the camera). `onLight` sits on the key
 * visual's light floor; `onDark` is for the dark-blue illustrated scenes.
 */
export const Disclaimer: React.FC<{
  tone: "onLight" | "onDark";
  fadeInAt?: number;
  opacity?: number;
}> = ({ tone, fadeInAt, opacity = 1 }) => {
  const frame = useCurrentFrame();
  const fade =
    fadeInAt === undefined ? 1 : interpolate(frame, [fadeInAt, fadeInAt + 20], [0, 1], clamp);
  return (
    <div
      style={{
        position: "absolute",
        top: 1800,
        left: 90,
        right: 90,
        textAlign: "center",
        fontFamily: bodyFont,
        fontSize: 24,
        fontWeight: 500,
        lineHeight: 1.4,
        color: tone === "onLight" ? "#4a4f5c" : "rgba(255,255,255,0.8)",
        opacity: fade * opacity,
      }}
    >
      {CONTENT.disclaimer}
    </div>
  );
};

export const ChAlphaKeyVisualPromo: React.FC = () => (
  <AbsoluteFill>
    <KeyVisualStage
      camera="pullback"
      animateTitles
      sweeps={[12, 245, 385]}
      duration={CH_ALPHA_KV_DURATION}
    >
      <Benefits />
      <KvCallToAction start={290} />
    </KeyVisualStage>
    <Disclaimer tone="onLight" fadeInAt={15} />
  </AbsoluteFill>
);
