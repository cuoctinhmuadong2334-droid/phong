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
import { clamp } from "../chalpha/Scenes";
import { bodyFont, phuduFont } from "../fonts";

// "MẮC LỖI, trả giao bóng rất mạnh" on a flat chroma-key green, for CapCut.
// Only flat colours and hard mask reveals: no glow, shadow, blur or opacity fades, so
// the edges stay clean when the green is keyed out. Timings are in seconds.

export const ERROR_TEXT_FPS = 60;
export const ERROR_TEXT_SECONDS = 7.2;

const GREEN = "#00ff00";
const RED = "#e10600";
const WHITE = "#ffffff";

const RED_TEXT = "MẮC LỖI,";
const RED_WEIGHT = 800; // Phudu weight of the red headline
const WHITE_TEXT = "trả giao bóng rất mạnh";
const TEXT_WIDTH = 940; // both lines are fitted to this width
const STRIKE_OVERSHOOT = 24; // red line sticks out this far past the white text
const STRIKE_Y = 0.5; // vertical position of the strike inside the white line box (0..1)
const LINE_HEIGHT = 1.2;
const BLUR_PX = 8; // blur of the white words once the red line has gone through them

const EASE_OUT = Easing.bezier(0.16, 1, 0.3, 1);
const EASE_IN = Easing.bezier(0.55, 0, 1, 0.45);
const EASE_IN_OUT = Easing.bezier(0.65, 0, 0.35, 1);

const rise = (t: number, start: number, duration: number, curve = EASE_OUT) =>
  interpolate(t, [start, start + duration], [0, 1], { ...clamp, easing: curve });

// Red letters, white words, strike line, exit (seconds).
// "MẮC LỖI," stays alone for ~3 s before "trả giao bóng rất mạnh" comes in.
const T = {
  redIn: 0.2,
  redLetterStagger: 0.035,
  whiteIn: 3.2,
  whiteWordStagger: 0.09,
  strike: [4.15, 0.35],
  hit: 4.5,
  strikeOut: [6.35, 0.25],
  whiteOut: 6.45,
  redOut: 6.55,
} as const;

/** Both lines are measured once the font is really loaded, then fitted to TEXT_WIDTH. */
const useFittedSizes = () => {
  const [handle] = useState(() => delayRender("fit text"));
  const [sizes, setSizes] = useState<{ red: number; white: number } | null>(null);
  useEffect(() => {
    document.fonts
      .load(`800 100px "${bodyFont}"`, WHITE_TEXT)
      .then(() => document.fonts.load(`${RED_WEIGHT} 100px "${phuduFont}"`, RED_TEXT))
      .then(() => document.fonts.ready)
      .then(() => {
        const fit = (text: string, fontFamily: string, fontWeight: number, letterSpacing: string) =>
          fitText({ text, withinWidth: TEXT_WIDTH, fontFamily, fontWeight, letterSpacing }).fontSize;
        setSizes({
          red: fit(RED_TEXT, phuduFont, RED_WEIGHT, "0.02em"),
          white: fit(WHITE_TEXT, bodyFont, 800, "0em"),
        });
        continueRender(handle);
      });
  }, [handle]);
  return sizes;
};

/** Clips whatever slides in or out; padded so the stacked Vietnamese accents are not cut. */
const Mask: React.FC<{ size: number; children: React.ReactNode }> = ({ size, children }) => (
  <div
    style={{
      overflow: "hidden",
      padding: `${size * 0.5}px 60px ${size * 0.35}px`,
      margin: `${-size * 0.5}px -60px ${-size * 0.35}px`,
    }}
  >
    {children}
  </div>
);

const slide = (inProgress: number, outProgress: number, blur = 0): React.CSSProperties => ({
  display: "inline-block",
  transform: `translateY(${(1 - inProgress + outProgress) * 1.7}em)`,
  filter: blur > 0.05 ? `blur(${blur}px)` : undefined,
});

export const ErrorReturnText: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const sizes = useFittedSizes();
  const words = WHITE_TEXT.split(" ");

  // x position and width of every white word, so the blur can follow the red line
  const geo = useMemo(() => {
    if (!sizes) return null;
    const m = (text: string) =>
      measureText({ text, fontFamily: bodyFont, fontSize: sizes.white, fontWeight: 800 }).width;
    const space = m("a a") - m("aa");
    return {
      total: m(WHITE_TEXT),
      lefts: words.map((_, i) => (i === 0 ? 0 : m(words.slice(0, i).join(" ")) + space)),
      widths: words.map((w) => m(w)),
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sizes]);

  if (!sizes || !geo) return <AbsoluteFill style={{ backgroundColor: GREEN }} />;

  const redChars = Array.from(RED_TEXT);

  // whole block: slow push-in while holding, plus a small "hit" when the red line lands
  const drift = 1 + 0.03 * rise(t, 0.85, T.strikeOut[0] - 0.85, (x) => x);
  const hit = t < T.hit ? 1 : 1 + 0.04 * (1 - EASE_OUT(rise(t, T.hit, 0.3, (x) => x)));
  const settle = 1 + 0.08 * (1 - rise(t, T.redIn, 0.9));

  // red strike drawn left -> right, retracted to the right on exit (crisp clip, no scaling)
  const draw = rise(t, T.strike[0], T.strike[1], EASE_IN_OUT);
  const retract = rise(t, T.strikeOut[0], T.strikeOut[1], EASE_IN_OUT);
  const strikeThickness = Math.round(sizes.white * 0.15);
  // front of the red line, measured from the left edge of the white text
  const head = -STRIKE_OVERSHOOT + draw * (geo.total + 2 * STRIKE_OVERSHOOT);
  const blurOf = (i: number) =>
    BLUR_PX *
    EASE_IN_OUT(interpolate(head, [geo.lefts[i], geo.lefts[i] + geo.widths[i]], [0, 1], clamp));

  return (
    <AbsoluteFill
      style={{
        backgroundColor: GREEN,
        alignItems: "center",
        justifyContent: "center",
        fontFamily: bodyFont,
        fontWeight: 800,
      }}
    >
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: sizes.red * 0.16,
          transform: `scale(${drift})`,
        }}
      >
        <div style={{ transform: `scale(${hit * settle})` }}>
          <Mask size={sizes.red}>
            <div
              style={{
                fontFamily: phuduFont,
                fontWeight: RED_WEIGHT,
                fontSize: sizes.red,
                lineHeight: LINE_HEIGHT,
                letterSpacing: "0.02em",
                color: RED,
                whiteSpace: "pre",
              }}
            >
              {redChars.map((ch, i) =>
                ch === " " ? (
                  <span key={i} style={{ display: "inline-block", width: "0.3em" }} />
                ) : (
                  <span
                    key={i}
                    style={slide(
                      rise(t, T.redIn + i * T.redLetterStagger, 0.55),
                      rise(t, T.redOut + (redChars.length - 1 - i) * 0.02, 0.3, EASE_IN),
                    )}
                  >
                    {ch}
                  </span>
                ),
              )}
            </div>
          </Mask>
        </div>

        <div style={{ position: "relative" }}>
          <Mask size={sizes.white}>
            <div
              style={{
                fontSize: sizes.white,
                lineHeight: LINE_HEIGHT,
                color: WHITE,
                whiteSpace: "pre",
              }}
            >
              {words.map((w, i) => (
                <span key={i}>
                  <span
                    style={slide(
                      rise(t, T.whiteIn + i * T.whiteWordStagger, 0.55),
                      rise(t, T.whiteOut + (words.length - 1 - i) * 0.04, 0.3, EASE_IN),
                      blurOf(i),
                    )}
                  >
                    {w}
                  </span>
                  {i < words.length - 1 ? " " : ""}
                </span>
              ))}
            </div>
          </Mask>
          {draw > 0 && retract < 1 && (
            <div
              style={{
                position: "absolute",
                left: -STRIKE_OVERSHOOT,
                right: -STRIKE_OVERSHOOT,
                top: `calc(${STRIKE_Y * 100}% - ${strikeThickness / 2}px)`,
                height: strikeThickness,
                background: RED,
                clipPath: `inset(0 ${(1 - draw) * 100}% 0 ${retract * 100}%)`,
              }}
            />
          )}
        </div>
      </div>
    </AbsoluteFill>
  );
};
