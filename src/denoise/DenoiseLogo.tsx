import { useEffect, useState } from "react";
import {
  AbsoluteFill,
  continueRender,
  delayRender,
  Easing,
  Img,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Sparkle } from "../chalpha/Fx";
import { clamp } from "../chalpha/Scenes";
import { Divider } from "./BeforeAfter";
import { PixelCanvas, screenStatic, specks } from "./NoiseCanvas";
import { Particles, type Box } from "./Particles";

// "Denoise" logo reveal: TV static is swept clean, stray grains fly into the letters,
// a before/after divider wipes the remaining speckle off, and the clean logo holds.
// Works for any frame size; the logo is centred and sized to the shorter side.

export const DENOISE_DURATION = 450;

const RATIO = 0.22551; // logo height / width
const LOGO = staticFile("denoise/logo.png");

// Timeline (frames)
const SWEEP = [60, 150] as const;
const GATHER = { start: 150, duration: 95 };
const WIPE = [250, 325] as const;
const FINAL = 325;

const usePoints = () => {
  const [handle] = useState(() => delayRender("denoise points"));
  const [points, setPoints] = useState<[number, number][] | null>(null);
  useEffect(() => {
    fetch(staticFile("denoise/points.json"))
      .then((r) => r.json())
      .then((j: { points: [number, number][] }) => {
        setPoints(j.points);
        continueRender(handle);
      });
  }, [handle]);
  return points;
};

const inset = (box: Box, left: number, right: number) =>
  `inset(-60% ${Math.max(0, right)}px -60% ${Math.max(0, left)}px)`;

/** The logo with live speckle noise inside the letters. */
const NoisyLogo: React.FC<{ box: Box; density: number; style?: React.CSSProperties }> = ({
  box,
  density,
  style,
}) => {
  const frame = useCurrentFrame();
  const jx = Math.sin(frame * 2.3) * 1.5;
  return (
    <div
      style={{
        position: "absolute",
        left: box.x,
        top: box.y,
        width: box.w,
        height: box.h,
        WebkitMaskImage: `url(${LOGO})`,
        WebkitMaskSize: "100% 100%",
        maskImage: `url(${LOGO})`,
        maskSize: "100% 100%",
        background: "white",
        transform: `translateX(${jx}px)`,
        ...style,
      }}
    >
      <PixelCanvas
        w={Math.round(box.w / 3)}
        h={Math.round(box.h / 3)}
        seed={3}
        paint={specks(density)}
        style={{ width: box.w, height: box.h }}
      />
    </div>
  );
};

const LogoImg: React.FC<{ box: Box; src: string; style?: React.CSSProperties }> = ({
  box,
  src,
  style,
}) => (
  <Img
    src={staticFile(src)}
    style={{
      position: "absolute",
      left: box.x,
      top: box.y,
      width: box.w,
      height: box.h,
      ...style,
    }}
  />
);

export const DenoiseLogo: React.FC = () => {
  const frame = useCurrentFrame();
  const { width, height } = useVideoConfig();
  const points = usePoints();

  const logoW = width >= height ? 1100 : 900;
  const box: Box = { x: (width - logoW) / 2, y: (height - logoW * RATIO) / 2, w: logoW, h: logoW * RATIO };

  // 1) static, swept clean left -> right
  const sweep = interpolate(frame, SWEEP, [-0.08, 1.1], { ...clamp, easing: Easing.inOut(Easing.quad) });
  const sweepPx = sweep * width;
  const residual = interpolate(frame, [SWEEP[1], WIPE[0]], [0.06, 0], clamp);
  const power = interpolate(frame, [0, 3, 5, 8], [0, 1, 0.4, 1], clamp);
  const fade = 0.12;
  const amountAt = (x: number) =>
    power *
    (x < sweep - fade ? residual : x < sweep ? residual + ((1 - residual) * (x - (sweep - fade))) / fade : 1);
  const band = ((frame * 0.013) % 1.3) - 0.15;

  // 2) speckle inside the letters eases off while grains gather
  const density = interpolate(frame, [GATHER.start, GATHER.start + GATHER.duration], [0.55, 0.38], clamp);

  // 3) before/after divider sweeps right -> left, cleaning the logo
  const wipe = interpolate(frame, WIPE, [1.04, -0.04], { ...clamp, easing: Easing.inOut(Easing.cubic) });
  const dividerPx = box.x + box.w * wipe;
  const dividerOpacity = interpolate(frame, [WIPE[0] - 6, WIPE[0] + 2, WIPE[1] - 2, WIPE[1] + 6], [0, 1, 1, 0], clamp);

  // 4) final hold
  const final = frame >= FINAL;
  const push = interpolate(frame, [FINAL, FINAL + 65], [1, 1.04], { ...clamp, easing: Easing.out(Easing.cubic) });
  const shine = interpolate(frame, [345, 390], [-20, 120], { ...clamp, easing: Easing.inOut(Easing.quad) });
  const grainDrift = Math.sin(frame / 18) * 2;
  const grainGlow = 0.85 + 0.15 * Math.sin(frame / 7);

  const inSweep = frame < SWEEP[1] + 4;
  const beforeWipe = frame < WIPE[0];

  return (
    <AbsoluteFill style={{ backgroundColor: "black", overflow: "hidden" }}>
      {frame < WIPE[1] && (
        <PixelCanvas
          w={Math.round(width / 2)}
          h={Math.round(height / 2)}
          seed={1}
          paint={screenStatic(amountAt, band)}
          style={{ width, height }}
        />
      )}

      <AbsoluteFill style={{ transformOrigin: "50% 50%", transform: `scale(${push})` }}>
        {/* logo hidden in the static, still uncleaned (right of the sweep) */}
        {inSweep && (
          <NoisyLogo
            box={box}
            density={0.55}
            style={{
              opacity: 0.22 * power,
              mixBlendMode: "screen",
              clipPath: inset(box, sweepPx - box.x, 0),
            }}
          />
        )}

        {/* noisy logo: revealed by the sweep, then wiped by the divider */}
        {!final && frame >= SWEEP[0] && (
          <NoisyLogo
            box={box}
            density={density}
            style={{
              clipPath: beforeWipe
                ? inset(box, 0, box.x + box.w - sweepPx)
                : inset(box, 0, box.x + box.w - dividerPx),
            }}
          />
        )}

        {/* clean logo to the right of the divider */}
        {!final && !beforeWipe && (
          <LogoImg box={box} src="denoise/logo.png" style={{ clipPath: inset(box, dividerPx - box.x, 0) }} />
        )}

        {final && (
          <>
            <LogoImg
              box={box}
              src="denoise/logo-core.png"
              style={{ filter: "drop-shadow(0 0 18px rgba(255,255,255,0.25))" }}
            />
            <LogoImg
              box={box}
              src="denoise/logo-grain.png"
              style={{ opacity: grainGlow, transform: `translateX(${grainDrift}px)` }}
            />
            <div
              style={{
                position: "absolute",
                left: box.x,
                top: box.y,
                width: box.w,
                height: box.h,
                WebkitMaskImage: `url(${LOGO})`,
                WebkitMaskSize: "100% 100%",
                maskImage: `url(${LOGO})`,
                maskSize: "100% 100%",
                background: `linear-gradient(105deg, rgba(120,170,255,0) ${shine - 10}%, rgba(150,200,255,0.9) ${shine}%, rgba(120,170,255,0) ${shine + 10}%)`,
              }}
            />
            <Sparkle x={box.x + box.w * 0.03} y={box.y + box.h * 0.25} size={70} at={360} />
            <Sparkle x={box.x + box.w * 0.985} y={box.y + box.h * 0.72} size={60} at={378} />
            <Sparkle x={box.x + box.w * 0.62} y={box.y + box.h * 0.08} size={50} at={396} />
          </>
        )}
      </AbsoluteFill>

      {points && <Particles points={points} box={box} start={GATHER.start} duration={GATHER.duration} />}

      {inSweep && frame >= SWEEP[0] && (
        <div
          style={{
            position: "absolute",
            left: sweepPx - 3,
            top: 0,
            width: 6,
            height,
            background: "white",
            boxShadow: "0 0 30px 8px rgba(170,210,255,0.8), 0 0 90px 20px rgba(120,170,255,0.45)",
          }}
        />
      )}

      {!final && !beforeWipe && <Divider x={dividerPx} box={box} opacity={dividerOpacity} />}
    </AbsoluteFill>
  );
};
