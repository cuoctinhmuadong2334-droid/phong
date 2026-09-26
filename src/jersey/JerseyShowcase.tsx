import { AbsoluteFill, interpolate, Sequence, useCurrentFrame } from "remotion";
import { Background } from "./Background";
import { JerseyScene } from "./JerseyScene";
import { KivixWordmark } from "./Logos";
import { VARIANTS } from "./types";

export const SCENE_DURATION = 150;
export const CROSSFADE = 15;
export const SHOWCASE_DURATION =
  VARIANTS.length * SCENE_DURATION - (VARIANTS.length - 1) * CROSSFADE;

export const JerseyShowcase: React.FC = () => {
  const frame = useCurrentFrame();
  const fadeOut = interpolate(
    frame,
    [SHOWCASE_DURATION - CROSSFADE, SHOWCASE_DURATION],
    [1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

  return (
    <AbsoluteFill style={{ backgroundColor: "black" }}>
      <AbsoluteFill style={{ opacity: fadeOut }}>
        <Background />
        <div style={{ position: "absolute", left: 50, top: 40 }}>
          <KivixWordmark height={44} />
        </div>
        {VARIANTS.map((variant, i) => {
          const from = i * (SCENE_DURATION - CROSSFADE);
          const isLast = i === VARIANTS.length - 1;
          const opacity = interpolate(
            frame - from,
            [0, CROSSFADE, SCENE_DURATION - CROSSFADE, SCENE_DURATION],
            [i === 0 ? 1 : 0, 1, 1, isLast ? 1 : 0],
            { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
          );
          return (
            <Sequence key={variant.name} from={from} durationInFrames={SCENE_DURATION}>
              <AbsoluteFill style={{ opacity }}>
                <JerseyScene variant={variant} index={i} />
              </AbsoluteFill>
            </Sequence>
          );
        })}
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
