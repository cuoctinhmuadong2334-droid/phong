import { AbsoluteFill, Easing, interpolate, Sequence, useCurrentFrame } from "remotion";
import { Background } from "./Background";
import { Disclaimer, KeyVisualStage, KvCallToAction, KvIngredients } from "./KeyVisualPromo";
import { BenefitsScene, clamp, HookScene } from "./Scenes";

// One continuous ad: the knee-joint story wrapped around the key-visual motion.
// Hook (pain) -> key visual reveal -> how it works -> back to the key visual with
// ingredients and the order button. Each piece of content appears exactly once.

const TRANSITION = 12;

type SceneDef = {
  duration: number;
  // Background behind the disclaimer: dark illustrated scene or the key visual's light floor.
  tone: "onDark" | "onLight";
  Component: React.FC<{ duration: number }>;
};

const SCENES: SceneDef[] = [
  {
    duration: 100,
    tone: "onDark",
    Component: () => (
      <>
        <Background />
        <HookScene />
      </>
    ),
  },
  {
    duration: 175,
    tone: "onLight",
    Component: ({ duration }) => (
      <KeyVisualStage camera="pullback" animateTitles sweeps={[12]} duration={duration} />
    ),
  },
  {
    duration: 190,
    tone: "onDark",
    Component: () => (
      <>
        <Background />
        <BenefitsScene />
      </>
    ),
  },
  {
    duration: 160,
    tone: "onLight",
    Component: ({ duration }) => (
      <KeyVisualStage camera="settle" animateTitles={false} sweeps={[30, 110]} duration={duration}>
        <KvIngredients start={14} />
        <KvCallToAction start={50} />
      </KeyVisualStage>
    ),
  },
];

const OFFSETS = SCENES.map((_, i) =>
  SCENES.slice(0, i).reduce((sum, s) => sum + s.duration - TRANSITION, 0),
);

export const CH_ALPHA_STORY_DURATION =
  OFFSETS[OFFSETS.length - 1] + SCENES[SCENES.length - 1].duration;

const fadeInOf = (i: number, frame: number) =>
  i === 0 ? 1 : interpolate(frame - OFFSETS[i], [0, TRANSITION], [0, 1], clamp);

export const ChAlphaStoryPromo: React.FC = () => {
  const frame = useCurrentFrame();

  // How much of the visible picture is a light-floor scene, so the single fixed
  // disclaimer can switch text colour in step with the cross-fades.
  const light = SCENES.reduce((acc, scene, i) => {
    const active = frame >= OFFSETS[i] && frame < OFFSETS[i] + scene.duration;
    if (!active) return acc;
    const a = fadeInOf(i, frame);
    return a * (scene.tone === "onLight" ? 1 : 0) + (1 - a) * acc;
  }, 0);

  return (
    <AbsoluteFill style={{ backgroundColor: "black" }}>
      {SCENES.map(({ duration, Component }, i) => {
        // The incoming scene fades in on top; the outgoing one pushes forward underneath.
        const exitZoom =
          i === SCENES.length - 1
            ? 1
            : interpolate(frame - OFFSETS[i], [duration - TRANSITION, duration], [1, 1.08], {
                ...clamp,
                easing: Easing.in(Easing.quad),
              });
        return (
          <Sequence key={i} from={OFFSETS[i]} durationInFrames={duration}>
            <AbsoluteFill
              style={{ opacity: fadeInOf(i, frame), transform: `scale(${exitZoom})` }}
            >
              <Component duration={duration} />
            </AbsoluteFill>
          </Sequence>
        );
      })}
      <Disclaimer tone="onDark" fadeInAt={15} opacity={1 - light} />
      <Disclaimer tone="onLight" fadeInAt={15} opacity={light} />
    </AbsoluteFill>
  );
};
