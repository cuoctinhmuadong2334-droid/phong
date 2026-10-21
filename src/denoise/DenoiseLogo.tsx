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
import { Sparkle } from "../chalpha/Fx";
import { clamp } from "../chalpha/Scenes";
import { Divider } from "./BeforeAfter";
import { LensPhoto, lensFor } from "./LensPhoto";
import { grain, PixelCanvas, specks } from "./NoiseCanvas";

// "Denoise" logo film for a media company:
// a grainy studio photo of a camera lens is cleaned with a before/after wipe, the
// camera pushes into the lens, the lens match-cuts into the "o" of the logo, the other
// letters jump in (each one blurred and noisy), and a denoise beam cleans them.

export const DENOISE_DURATION = 450;

const RATIO = 0.22551; // logo height / width
const LOGO = staticFile("denoise/logo.png");

type Box = { x: number; y: number; w: number; h: number };

// Letter boxes relative to the logo box (from the logo artwork).
const LETTERS = [
  { name: "D", x: 0.0313, y: 0.1338, w: 0.1708, h: 0.7424, at: 222, from: [-3.2, 0], rot: -20 },
  { name: "e1", x: 0.2158, y: 0.3914, w: 0.1253, h: 0.4646, at: 192, from: [0, -2.8], rot: 25 },
  { name: "n", x: 0.3605, y: 0.4015, w: 0.1321, h: 0.4596, at: 182, from: [0, 2.8], rot: -25 },
  { name: "o", x: 0.5108, y: 0.3914, w: 0.1287, h: 0.4798, at: 0, from: [0, 0], rot: 0 },
  { name: "i", x: 0.6589, y: 0.1843, w: 0.0421, h: 0.6768, at: 202, from: [0, -3], rot: 30 },
  { name: "s", x: 0.7181, y: 0.4015, w: 0.1162, h: 0.4596, at: 212, from: [0, 2.8], rot: -30 },
  { name: "e2", x: 0.8457, y: 0.3813, w: 0.1287, h: 0.4949, at: 232, from: [3.2, 0], rot: 20 },
] as const;

// Timeline (frames)
const PHOTO_WIPE = [40, 105] as const;
const PUSH = [118, 158] as const;
const MATCH = 158;
const O_SETTLE = [158, 194] as const;
const DENOISE = [262, 330] as const;
const FINAL = 330;
const PUSH_SCALE = 1.35;

const maskStyle = (src: string): React.CSSProperties => ({
  WebkitMaskImage: `url(${src})`,
  WebkitMaskSize: "100% 100%",
  maskImage: `url(${src})`,
  maskSize: "100% 100%",
});

/** One letter: optional blur and live speckle noise masked to the glyph. */
const Letter: React.FC<{
  name: string;
  box: Box;
  noise: number; // 0 clean .. 1 fully noisy
  style?: React.CSSProperties;
}> = ({ name, box, noise, style }) => {
  const src = staticFile(`denoise/letter-${name}.png`);
  return (
    <div
      style={{
        position: "absolute",
        left: box.x,
        top: box.y,
        width: box.w,
        height: box.h,
        filter: noise > 0.01 ? `blur(${5 * noise}px)` : undefined,
        ...style,
      }}
    >
      <Img src={src} style={{ position: "absolute", width: box.w, height: box.h }} />
      {noise > 0.01 && (
        <div style={{ position: "absolute", inset: 0, ...maskStyle(src) }}>
          <PixelCanvas
            w={Math.max(4, Math.round(box.w / 3))}
            h={Math.max(4, Math.round(box.h / 3))}
            seed={name.length * 13 + name.charCodeAt(0)}
            paint={specks(0.55 * noise)}
            style={{ width: box.w, height: box.h }}
          />
        </div>
      )}
    </div>
  );
};

const BURST = new Array(30).fill(true).map((_, i) => ({
  u: random(`b-u-${i}`),
  v: random(`b-v-${i}`),
  angle: -Math.PI / 2 + (random(`b-a-${i}`) - 0.5) * 2.6,
  dist: 60 + random(`b-d-${i}`) * 140,
  size: 3 + random(`b-s-${i}`) * 4,
}));

/** Noise grains thrown off a letter as it is cleaned. */
const Burst: React.FC<{ box: Box; at: number }> = ({ box, at }) => {
  const frame = useCurrentFrame();
  const t = (frame - at) / 22;
  if (t < 0 || t > 1) return null;
  const e = Easing.out(Easing.cubic)(t);
  return (
    <>
      {BURST.map((p, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            left: box.x + p.u * box.w + Math.cos(p.angle) * p.dist * e,
            top: box.y + p.v * box.h + Math.sin(p.angle) * p.dist * e,
            width: p.size,
            height: p.size,
            background: "white",
            opacity: 1 - t,
            boxShadow: "0 0 6px rgba(160,200,255,0.9)",
          }}
        />
      ))}
    </>
  );
};

export const DenoiseLogo: React.FC = () => {
  const frame = useCurrentFrame();
  const { width, height, fps } = useVideoConfig();

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
  const photoIn = interpolate(frame, [0, 12], [0, 1], clamp);
  const wipe = interpolate(frame, PHOTO_WIPE, [-0.02, 1.02], { ...clamp, easing: Easing.inOut(Easing.cubic) });
  const wipePx = wipe * width;
  const drift = interpolate(frame, [0, PUSH[0]], [1, 1.03], clamp);
  const push = interpolate(frame, PUSH, [1, PUSH_SCALE / 1.03], { ...clamp, easing: Easing.in(Easing.quad) });
  const photoScale = drift * push;
  const pushBlur = interpolate(frame, [PUSH[1] - 16, PUSH[1]], [0, 5], clamp);
  const ringGlow = interpolate(frame, [PUSH[1] - 14, MATCH], [0, 1], clamp);
  const photoOut = interpolate(frame, [MATCH - 2, MATCH + 6], [1, 0], clamp);
  const flash = interpolate(frame, [MATCH - 3, MATCH, MATCH + 7], [0, 0.5, 0], clamp);
  const showPhoto = frame < MATCH + 6;

  // --- Letters ----------------------------------------------------------------------
  const o = LETTERS[3];
  const oBox = letterBox(o);
  const oStartScale = (2 * lens.r * PUSH_SCALE) / oBox.w;
  const settle = interpolate(frame, O_SETTLE, [0, 1], { ...clamp, easing: Easing.out(Easing.exp) });
  const oScale = oStartScale + (1 - oStartScale) * settle;
  const oDx = (lens.cx - (oBox.x + oBox.w / 2)) * (1 - settle);
  const oDy = (lens.cy - (oBox.y + oBox.h / 2)) * (1 - settle);

  const beam = interpolate(frame, DENOISE, [box.x - 80, box.x + box.w + 80], {
    ...clamp,
    easing: Easing.inOut(Easing.quad),
  });
  const cleanOf = (b: Box) => interpolate(beam, [b.x, b.x + b.w], [0, 1], clamp);
  // first frame the beam passes a letter's centre (when its noise is thrown off)
  const burstAt = (b: Box) => {
    for (let f = DENOISE[0]; f <= DENOISE[1]; f++) {
      const x = interpolate(f, DENOISE, [box.x - 80, box.x + box.w + 80], {
        ...clamp,
        easing: Easing.inOut(Easing.quad),
      });
      if (x >= b.x + b.w / 2) return f;
    }
    return DENOISE[1];
  };

  const finalPush = interpolate(frame, [FINAL, FINAL + 70], [1, 1.035], {
    ...clamp,
    easing: Easing.out(Easing.cubic),
  });
  const grainIn = interpolate(frame, [FINAL, FINAL + 30], [0, 1], clamp);
  const shine = interpolate(frame, [350, 395], [-20, 120], { ...clamp, easing: Easing.inOut(Easing.quad) });

  return (
    <AbsoluteFill style={{ backgroundColor: "black", overflow: "hidden" }}>
      {/* soft glow behind the logo once we are in the type world */}
      <AbsoluteFill
        style={{
          background: "radial-gradient(ellipse at 50% 50%, rgba(40,70,160,0.35), rgba(0,0,0,0) 60%)",
          opacity: interpolate(frame, [MATCH, MATCH + 20], [0, 1], clamp),
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
              paint={grain(0.55)}
              style={{ width, height }}
            />
          </AbsoluteFill>
          <Sparkle x={lens.cx - lens.r * 0.12} y={lens.cy - lens.r * 0.4} size={120} at={108} />
          <div
            style={{
              position: "absolute",
              left: lens.cx - lens.r,
              top: lens.cy - lens.r,
              width: lens.r * 2,
              height: lens.r * 2,
              borderRadius: "50%",
              border: `${10 * ringGlow}px solid rgba(255,255,255,${ringGlow})`,
              boxShadow: `0 0 ${60 * ringGlow}px rgba(170,210,255,${ringGlow})`,
            }}
          />
        </AbsoluteFill>
      )}
      {frame >= PHOTO_WIPE[0] - 6 && frame <= PHOTO_WIPE[1] + 6 && (
        <Divider
          x={wipePx}
          top={0}
          height={height}
          opacity={interpolate(
            frame,
            [PHOTO_WIPE[0] - 6, PHOTO_WIPE[0], PHOTO_WIPE[1], PHOTO_WIPE[1] + 6],
            [0, 1, 1, 0],
            clamp,
          )}
        />
      )}

      {frame >= MATCH - 2 && (
        <AbsoluteFill style={{ transformOrigin: "50% 50%", transform: `scale(${finalPush})` }}>
          {LETTERS.map((l) => {
            const b = letterBox(l);
            const clean = cleanOf(b);
            const noise = 1 - clean;
            const pop = 1 + 0.12 * Math.sin(Math.PI * clean);
            if (l.name === "o") {
              return (
                <Letter
                  key={l.name}
                  name={l.name}
                  box={b}
                  noise={noise}
                  style={{
                    opacity: interpolate(frame, [MATCH - 2, MATCH + 4], [0, 1], clamp),
                    transform: `translate(${oDx}px, ${oDy}px) scale(${oScale * pop})`,
                  }}
                />
              );
            }
            const t = spring({ frame: frame - l.at, fps, config: { damping: 10, mass: 0.7 } });
            if (frame < l.at) return null;
            return (
              <Letter
                key={l.name}
                name={l.name}
                box={b}
                noise={noise}
                style={{
                  opacity: interpolate(t, [0, 0.3], [0, 1], clamp),
                  transform: `translate(${(1 - t) * l.from[0] * box.h}px, ${(1 - t) * l.from[1] * box.h}px) rotate(${(1 - t) * l.rot}deg) scale(${(0.4 + 0.6 * t) * pop})`,
                }}
              />
            );
          })}
          {LETTERS.map((l) => (
            <Burst key={l.name} box={letterBox(l)} at={burstAt(letterBox(l))} />
          ))}

          {frame >= FINAL && (
            <>
              <Img
                src={staticFile("denoise/logo-grain.png")}
                style={{
                  position: "absolute",
                  left: box.x,
                  top: box.y,
                  width: box.w,
                  height: box.h,
                  opacity: grainIn * (0.85 + 0.15 * Math.sin(frame / 7)),
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
                  background: `linear-gradient(105deg, rgba(120,170,255,0) ${shine - 10}%, rgba(150,200,255,0.9) ${shine}%, rgba(120,170,255,0) ${shine + 10}%)`,
                }}
              />
              <Sparkle x={box.x + box.w * 0.03} y={box.y + box.h * 0.25} size={70} at={365} />
              <Sparkle x={box.x + box.w * 0.985} y={box.y + box.h * 0.72} size={60} at={382} />
              <Sparkle x={box.x + box.w * 0.68} y={box.y + box.h * 0.1} size={50} at={398} />
            </>
          )}
        </AbsoluteFill>
      )}

      {frame >= DENOISE[0] - 4 && frame <= DENOISE[1] + 4 && (
        <div
          style={{
            position: "absolute",
            left: beam - 3,
            top: box.y - box.h * 1.2,
            width: 6,
            height: box.h * 3.4,
            background:
              "linear-gradient(180deg, rgba(255,255,255,0), white 25%, white 75%, rgba(255,255,255,0))",
            boxShadow: "0 0 30px 8px rgba(170,210,255,0.8), 0 0 90px 20px rgba(120,170,255,0.45)",
            opacity: interpolate(
              frame,
              [DENOISE[0] - 4, DENOISE[0] + 2, DENOISE[1] - 2, DENOISE[1] + 4],
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
