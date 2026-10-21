import {
  AbsoluteFill,
  Easing,
  Img,
  interpolate,
  random,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Sparkle } from "../chalpha/Fx";
import { clamp } from "../chalpha/Scenes";
import { Divider } from "./BeforeAfter";
import { LensPhoto, lensFor } from "./LensPhoto";
import { grain, PixelCanvas, specks } from "./NoiseCanvas";

// "Denoise" logo film for a media company:
// a grainy studio photo of a camera lens is cleaned with a before/after wipe, the
// camera pushes into the lens, the lens match-cuts into the "o" of the logo, the other
// letters rise in (each one blurred and noisy), and a denoise beam cleans them.
// All timings are in seconds so the film plays the same at any frame rate.

export const DENOISE_SECONDS = 15;
export const DENOISE_FPS = 60;

const RATIO = 0.22551; // logo height / width
const LOGO = staticFile("denoise/logo.png");

// Smooth, "editorial" curves (similar to After Effects easy-ease presets).
const EASE_OUT = Easing.bezier(0.16, 1, 0.3, 1);
const EASE_IN_OUT = Easing.bezier(0.65, 0, 0.35, 1);
const EASE_IN = Easing.bezier(0.55, 0, 1, 0.45);

type Box = { x: number; y: number; w: number; h: number };

// Letter boxes relative to the logo box (from the logo artwork); `at` = entrance time (s).
const LETTERS = [
  { name: "D", x: 0.0313, y: 0.1338, w: 0.1708, h: 0.7424, at: 6.2 },
  { name: "e1", x: 0.2158, y: 0.3914, w: 0.1253, h: 0.4646, at: 6.35 },
  { name: "n", x: 0.3605, y: 0.4015, w: 0.1321, h: 0.4596, at: 6.5 },
  { name: "o", x: 0.5108, y: 0.3914, w: 0.1287, h: 0.4798, at: 0 },
  { name: "i", x: 0.6589, y: 0.1843, w: 0.0421, h: 0.6768, at: 6.65 },
  { name: "s", x: 0.7181, y: 0.4015, w: 0.1162, h: 0.4596, at: 6.8 },
  { name: "e2", x: 0.8457, y: 0.3813, w: 0.1287, h: 0.4949, at: 6.95 },
] as const;

// Timeline (seconds)
const T = {
  photoIn: [0, 0.6],
  wipe: [1.2, 3.4],
  glint: 3.55,
  push: [3.7, 5.4],
  match: 5.3,
  oSettle: [5.35, 6.9],
  letterIn: 1.0,
  denoise: [8.3, 10.8],
  final: 10.8,
  shine: [11.4, 12.9],
} as const;
const PUSH_SCALE = 1.38;

const ease = (t: number, range: readonly [number, number], curve: (x: number) => number) =>
  interpolate(t, range, [0, 1], { ...clamp, easing: curve });

const maskStyle = (src: string): React.CSSProperties => ({
  WebkitMaskImage: `url(${src})`,
  WebkitMaskSize: "100% 100%",
  maskImage: `url(${src})`,
  maskSize: "100% 100%",
});

/** One letter: blur plus speckle noise masked to the glyph, both scaled by `noise`. */
const Letter: React.FC<{
  name: string;
  box: Box;
  noise: number; // 0 clean .. 1 fully noisy
  extraBlur?: number;
  style?: React.CSSProperties;
}> = ({ name, box, noise, extraBlur = 0, style }) => {
  const { fps } = useVideoConfig();
  const src = staticFile(`denoise/letter-${name}.png`);
  const blur = 4.5 * noise + extraBlur;
  return (
    <div
      style={{
        position: "absolute",
        left: box.x,
        top: box.y,
        width: box.w,
        height: box.h,
        filter: blur > 0.05 ? `blur(${blur}px)` : undefined,
        ...style,
      }}
    >
      <Img src={src} style={{ position: "absolute", width: box.w, height: box.h }} />
      {noise > 0.01 && (
        <div style={{ position: "absolute", inset: 0, opacity: noise, ...maskStyle(src) }}>
          <PixelCanvas
            w={Math.max(4, Math.round(box.w / 3))}
            h={Math.max(4, Math.round(box.h / 3))}
            seed={name.length * 13 + name.charCodeAt(0)}
            paint={specks(0.5)}
            step={Math.round(fps / 12)}
            style={{ width: box.w, height: box.h }}
          />
        </div>
      )}
    </div>
  );
};

const BURST = new Array(36).fill(true).map((_, i) => ({
  u: random(`b-u-${i}`),
  v: random(`b-v-${i}`),
  angle: -Math.PI / 2 + (random(`b-a-${i}`) - 0.5) * 2.2,
  dist: 50 + random(`b-d-${i}`) * 120,
  size: 2 + random(`b-s-${i}`) * 4,
  life: 0.7 + random(`b-l-${i}`) * 0.5,
}));

/** Soft noise grains drifting off a letter as it is cleaned. */
const Burst: React.FC<{ box: Box; at: number }> = ({ box, at }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps - at;
  if (t < 0 || t > 1.3) return null;
  return (
    <>
      {BURST.map((p, i) => {
        const k = t / p.life;
        if (k > 1) return null;
        const e = EASE_OUT(k);
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: box.x + p.u * box.w + Math.cos(p.angle) * p.dist * e,
              top: box.y + p.v * box.h + Math.sin(p.angle) * p.dist * e - 30 * k * k,
              width: p.size,
              height: p.size,
              borderRadius: "50%",
              background: "white",
              opacity: (1 - k) * 0.9,
              boxShadow: "0 0 8px rgba(160,200,255,0.9)",
            }}
          />
        );
      })}
    </>
  );
};

export const DenoiseLogo: React.FC = () => {
  const frame = useCurrentFrame();
  const { width, height, fps } = useVideoConfig();
  const t = frame / fps;

  const logoW = width >= height ? 1100 : 900;
  const box: Box = {
    x: (width - logoW) / 2,
    y: (height - logoW * RATIO) / 2,
    w: logoW,
    h: logoW * RATIO,
  };
  const letterBox = (l: (typeof LETTERS)[number]): Box => ({
    x: box.x + l.x * box.w,
    y: box.y + l.y * box.h,
    w: l.w * box.w,
    h: l.h * box.h,
  });
  const lens = lensFor(width, height);

  // --- Photo: noisy -> before/after wipe -> push into the lens ---------------------
  const photoIn = ease(t, T.photoIn, EASE_OUT);
  const wipePx = interpolate(ease(t, T.wipe, EASE_IN_OUT), [0, 1], [-0.02, 1.02]) * width;
  const drift = interpolate(t, [0, T.push[0]], [1, 1.04], clamp);
  const pushK = ease(t, T.push, EASE_IN);
  const photoScale = drift * interpolate(pushK, [0, 1], [1, PUSH_SCALE / 1.04]);
  const pushBlur = interpolate(t, [T.push[1] - 0.45, T.push[1]], [0, 4], clamp);
  const ringGlow = interpolate(t, [T.match - 0.4, T.match + 0.05], [0, 1], clamp);
  const photoOut = interpolate(t, [T.match - 0.05, T.match + 0.3], [1, 0], clamp);
  const flash = interpolate(t, [T.match - 0.1, T.match + 0.02, T.match + 0.35], [0, 0.2, 0], clamp);
  const showPhoto = t < T.match + 0.35;

  // --- Letters ----------------------------------------------------------------------
  const oBox = letterBox(LETTERS[3]);
  const oStartScale = (2 * lens.r * PUSH_SCALE * 0.94) / oBox.w;
  const settle = ease(t, T.oSettle, EASE_OUT);
  const oScale = Math.exp(Math.log(oStartScale) * (1 - settle)); // scale in log space reads as constant speed
  const oDx = (lens.cx - (oBox.x + oBox.w / 2)) * (1 - settle);
  const oDy = (lens.cy - (oBox.y + oBox.h / 2)) * (1 - settle);

  const beamAt = (time: number) =>
    interpolate(ease(time, T.denoise, EASE_IN_OUT), [0, 1], [box.x - 120, box.x + box.w + 120]);
  const beam = beamAt(t);
  // a letter cleans over the beam's passage plus a soft margin either side
  const cleanOf = (b: Box) => interpolate(beam, [b.x - 40, b.x + b.w + 40], [0, 1], { ...clamp, easing: EASE_IN_OUT });
  const burstAt = (b: Box) => {
    for (let s = T.denoise[0]; s <= T.denoise[1]; s += 1 / fps) {
      if (beamAt(s) >= b.x + b.w / 2) return s;
    }
    return T.denoise[1];
  };

  const finalPush = interpolate(t, [T.final - 2, DENOISE_SECONDS], [1, 1.045], clamp);
  const grainIn = ease(t, [T.final, T.final + 0.9], EASE_OUT);
  const shine = interpolate(ease(t, T.shine, EASE_IN_OUT), [0, 1], [-20, 120]);
  const at = (s: number) => Math.round(s * fps);

  return (
    <AbsoluteFill style={{ backgroundColor: "black", overflow: "hidden" }}>
      <AbsoluteFill
        style={{
          background: "radial-gradient(ellipse at 50% 50%, rgba(40,70,160,0.32), rgba(0,0,0,0) 60%)",
          opacity: interpolate(t, [T.match, T.match + 0.8], [0, 1], clamp),
        }}
      />

      {showPhoto && (
        <AbsoluteFill
          style={{
            opacity: photoIn * photoOut,
            transformOrigin: `${lens.cx}px ${lens.cy}px`,
            transform: `scale(${photoScale})`,
            filter: pushBlur > 0.05 ? `blur(${pushBlur}px)` : undefined,
          }}
        >
          <LensPhoto width={width} height={height} lens={lens} />
          {/* noisy version of the photo, to the right of the before/after divider */}
          <AbsoluteFill style={{ clipPath: `inset(0 0 0 ${Math.max(0, wipePx)}px)` }}>
            <AbsoluteFill style={{ filter: "blur(2.2px) saturate(0.8) brightness(0.92)" }}>
              <LensPhoto width={width} height={height} lens={lens} />
            </AbsoluteFill>
            <PixelCanvas
              w={Math.round(width / 2)}
              h={Math.round(height / 2)}
              seed={5}
              paint={grain(0.5)}
              step={Math.round(fps / 24)}
              style={{ width, height }}
            />
          </AbsoluteFill>
          <Sparkle x={lens.cx - lens.r * 0.12} y={lens.cy - lens.r * 0.4} size={120} at={at(T.glint)} />
          <div
            style={{
              position: "absolute",
              left: lens.cx - lens.r,
              top: lens.cy - lens.r,
              width: lens.r * 2,
              height: lens.r * 2,
              borderRadius: "50%",
              border: `${8 * ringGlow}px solid rgba(255,255,255,${ringGlow})`,
              boxShadow: `0 0 ${50 * ringGlow}px rgba(170,210,255,${ringGlow})`,
            }}
          />
        </AbsoluteFill>
      )}
      {t >= T.wipe[0] - 0.15 && t <= T.wipe[1] + 0.15 && (
        <Divider
          x={wipePx}
          top={0}
          height={height}
          opacity={interpolate(
            t,
            [T.wipe[0] - 0.15, T.wipe[0] + 0.05, T.wipe[1] - 0.05, T.wipe[1] + 0.15],
            [0, 1, 1, 0],
            clamp,
          )}
        />
      )}

      {t >= T.match - 0.1 && (
        <AbsoluteFill style={{ transformOrigin: "50% 50%", transform: `scale(${finalPush})` }}>
          {LETTERS.map((l) => {
            const b = letterBox(l);
            const noise = 1 - cleanOf(b);
            if (l.name === "o") {
              return (
                <Letter
                  key={l.name}
                  name={l.name}
                  box={b}
                  noise={noise}
                  extraBlur={6 * (1 - settle)}
                  style={{
                    opacity: interpolate(t, [T.match - 0.1, T.match + 0.25], [0, 1], clamp),
                    transform: `translate(${oDx}px, ${oDy}px) scale(${oScale})`,
                  }}
                />
              );
            }
            const p = ease(t, [l.at, l.at + T.letterIn], EASE_OUT);
            if (p <= 0) return null;
            return (
              <Letter
                key={l.name}
                name={l.name}
                box={b}
                noise={noise}
                extraBlur={10 * (1 - p)}
                style={{
                  opacity: interpolate(p, [0, 0.5], [0, 1], clamp),
                  transform: `translateY(${(1 - p) * box.h * 0.55}px) scale(${0.9 + 0.1 * p})`,
                }}
              />
            );
          })}
          {LETTERS.map((l) => (
            <Burst key={l.name} box={letterBox(l)} at={burstAt(letterBox(l))} />
          ))}

          {t >= T.final && (
            <>
              <Img
                src={staticFile("denoise/logo-grain.png")}
                style={{
                  position: "absolute",
                  left: box.x,
                  top: box.y,
                  width: box.w,
                  height: box.h,
                  opacity: grainIn * (0.88 + 0.12 * Math.sin(t * 3)),
                }}
              />
              <div
                style={{
                  position: "absolute",
                  left: box.x,
                  top: box.y,
                  width: box.w,
                  height: box.h,
                  ...maskStyle(LOGO),
                  background: `linear-gradient(105deg, rgba(120,170,255,0) ${shine - 12}%, rgba(160,205,255,0.85) ${shine}%, rgba(120,170,255,0) ${shine + 12}%)`,
                }}
              />
              <Sparkle x={box.x + box.w * 0.03} y={box.y + box.h * 0.25} size={70} at={at(12.1)} />
              <Sparkle x={box.x + box.w * 0.985} y={box.y + box.h * 0.72} size={60} at={at(12.6)} />
              <Sparkle x={box.x + box.w * 0.68} y={box.y + box.h * 0.1} size={50} at={at(13.1)} />
            </>
          )}
        </AbsoluteFill>
      )}

      {t >= T.denoise[0] - 0.15 && t <= T.denoise[1] + 0.15 && (
        <div
          style={{
            position: "absolute",
            left: beam - 2,
            top: box.y - box.h * 1.2,
            width: 4,
            height: box.h * 3.4,
            background:
              "linear-gradient(180deg, rgba(255,255,255,0), white 25%, white 75%, rgba(255,255,255,0))",
            boxShadow: "0 0 26px 6px rgba(170,210,255,0.75), 0 0 80px 18px rgba(120,170,255,0.4)",
            opacity: interpolate(
              t,
              [T.denoise[0] - 0.15, T.denoise[0] + 0.1, T.denoise[1] - 0.1, T.denoise[1] + 0.15],
              [0, 1, 1, 0],
              clamp,
            ),
          }}
        />
      )}

      <AbsoluteFill style={{ background: "white", opacity: flash, mixBlendMode: "screen" }} />
    </AbsoluteFill>
  );
};
