import { useEffect, useState } from "react";
import {
  AbsoluteFill,
  continueRender,
  delayRender,
  Easing,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { fitText } from "@remotion/layout-utils";
import { clamp } from "../chalpha/Scenes";
import { bodyFont } from "../fonts";

// "MẮC LỖI, trả giao bóng rất mạnh" on a flat chroma-key green, for CapCut.
// Only flat colours and hard mask reveals: no glow, shadow, blur or opacity fades, so
// the edges stay clean when the green is keyed out. Timings are in seconds.

export const ERROR_TEXT_FPS = 60;
export const ERROR_TEXT_SECONDS = 4.5;

const GREEN = "#00ff00";
const RED = "#e10600";
const WHITE = "#ffffff";

const RED_TEXT = "MẮC LỖI,";
const WHITE_TEXT = "trả giao bóng rất mạnh";
const TEXT_WIDTH = 940; // both lines are fitted to this width
const STRIKE_OVERSHOOT = 24; // red line sticks out this far past the white text
const STRIKE_Y = 0.5; // vertical position of the strike inside the white line box (0..1)
const LINE_HEIGHT = 1.2;

const EASE_OUT = Easing.bezier(0.16, 1, 0.3, 1);
const EASE_IN = Easing.bezier(0.55, 0, 1, 0.45);
const EASE_IN_OUT = Easing.bezier(0.65, 0, 0.35, 1);

const rise = (t: number, start: number, duration: number, curve = EASE_OUT) =>
  interpolate(t, [start, start + duration], [0, 1], { ...clamp, easing: curve });

// Red letters, white words, strike line, exit (seconds)
const T = {
  redIn: 0.2,
  redLetterStagger: 0.035,
  whiteIn: 0.75,
  whiteWordStagger: 0.09,
  strike: [1.7, 0.35],
  hit: 2.05,
  strikeOut: [3.9, 0.25],
  whiteOut: 4.0,
  redOut: 4.1,
} as const;

/** Both lines are measured once the font is really loaded, then fitted to TEXT_WIDTH. */
const useFittedSizes = () => {
  const [handle] = useState(() => delayRender("fit text"));
  const [sizes, setSizes] = useState<{ red: number; white: number } | null>(null);
  useEffect(() => {
    document.fonts
      .load(`800 100px "${bodyFont}"`, RED_TEXT + WHITE_TEXT)
      .then(() => document.fonts.ready)
      .then(() => {
        const fit = (text: string, letterSpacing: string) =>
          fitText({
            text,
            withinWidth: TEXT_WIDTH,
            fontFamily: bodyFont,
            fontWeight: 800,
            letterSpacing,
          }).fontSize;
        setSizes({ red: fit(RED_TEXT, "0.02em"), white: fit(WHITE_TEXT, "0em") });
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
      padding: `${size * 0.3}px 0 ${size * 0.18}px`,
      margin: `${-size * 0.3}px 0 ${-size * 0.18}px`,
    }}
  >
    {children}
  </div>
);

const slide = (inProgress: number, outProgress: number): React.CSSProperties => ({
  display: "inline-block",
  transform: `translateY(${(1 - inProgress + outProgress) * 1.7}em)`,
});

export const ErrorReturnText: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const sizes = useFittedSizes();
  if (!sizes) return <AbsoluteFill style={{ backgroundColor: GREEN }} />;

  const redChars = Array.from(RED_TEXT);
  const words = WHITE_TEXT.split(" ");

  // whole block: slow push-in while holding, plus a small "hit" when the red line lands
  const drift = 1 + 0.02 * rise(t, T.hit, 1.85, (x) => x);
  const hit = t < T.hit ? 1 : 1 + 0.04 * (1 - EASE_OUT(rise(t, T.hit, 0.3, (x) => x)));
  const settle = 1 + 0.08 * (1 - rise(t, T.redIn, 0.9));

  // red strike drawn left -> right, retracted to the right on exit (crisp clip, no scaling)
  const draw = rise(t, T.strike[0], T.strike[1], EASE_IN_OUT);
  const retract = rise(t, T.strikeOut[0], T.strikeOut[1], EASE_IN_OUT);
  const strikeThickness = Math.round(sizes.white * 0.15);

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
