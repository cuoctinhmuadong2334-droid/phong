import { AbsoluteFill, interpolate, Sequence, useCurrentFrame } from "remotion";
import { bodyFont } from "../fonts";
import { Background } from "./Background";
import { CONTENT } from "./content";
import { BenefitsScene, CtaScene, HookScene, RevealScene } from "./Scenes";

const FADE = 10;

const SCENES = [
  { from: 0, duration: 100, Component: HookScene },
  { from: 90, duration: 110, Component: RevealScene },
  { from: 190, duration: 190, Component: BenefitsScene },
  { from: 370, duration: 90, Component: CtaScene },
];

export const CH_ALPHA_DURATION = 460;

export const ChAlphaPromo: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill>
      <Background />
      {SCENES.map(({ from, duration, Component }, i) => {
        const opacity = interpolate(
          frame - from,
          [0, FADE, duration - FADE, duration],
          [i === 0 ? 1 : 0, 1, 1, i === SCENES.length - 1 ? 1 : 0],
          { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
        );
        return (
          <Sequence key={i} from={from} durationInFrames={duration}>
            <AbsoluteFill style={{ opacity }}>
              <Component />
            </AbsoluteFill>
          </Sequence>
        );
      })}
      <div
        style={{
          position: "absolute",
          top: 1650,
          left: 90,
          right: 90,
          textAlign: "center",
          fontFamily: bodyFont,
          fontSize: 26,
          fontWeight: 500,
          lineHeight: 1.4,
          color: "rgba(255,255,255,0.75)",
        }}
      >
        {CONTENT.disclaimer}
      </div>
    </AbsoluteFill>
  );
};
