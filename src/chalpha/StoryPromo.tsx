import { AbsoluteFill } from "remotion";
import { Background } from "./Background";
import { HealBurst, LightLeak, PainFx, Sparkle, useShake } from "./Fx";
import { KeyVisualStage, KvCallToAction, KvIngredients } from "./KeyVisualPromo";
import { BenefitsScene, HookScene } from "./Scenes";
import {
  SceneTimeline,
  timelineDuration,
  type TimelineScene,
  type TimelineTransition,
} from "./Transitions";

// One continuous ad: the knee-joint story wrapped around the key-visual motion.
// Hook (pain) -> key visual reveal -> how it works -> back to the key visual with
// ingredients and the order button. Each piece of content appears exactly once.

// Screen positions used by the effects and transitions.
// KNEE_ON_BOX is the knee artwork on the box at the end of the KV intro (push 1.035).
const HOOK_JOINT = { x: 540, y: 896 }; // inflamed joint in HookScene
const BENEFIT_JOINT = { x: 540, y: 635 }; // healing joint in BenefitsScene
export const KNEE_ON_BOX = "635px 1215px";

const PAIN_BEATS = [20, 48, 76];

const Hook: React.FC = () => {
  const shake = useShake(PAIN_BEATS);
  return (
    <AbsoluteFill>
      <Background />
      <AbsoluteFill style={{ transform: shake }}>
        <HookScene />
        <PainFx cx={HOOK_JOINT.x} cy={HOOK_JOINT.y} beats={PAIN_BEATS} />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

// Glints on the box corners and the ampoule cap (poster coordinates).
const GLINTS: [x: number, y: number][] = [
  [760, 952],
  [985, 1040],
  [305, 1012],
  [226, 1037],
];

const KvIntro: React.FC<{ duration: number }> = ({ duration }) => (
  <KeyVisualStage camera="pullback" animateTitles sweeps={[12]} duration={duration} fx>
    <LightLeak start={60} duration={60} />
    {GLINTS.map(([x, y], i) => (
      <Sparkle key={i} x={x} y={y} size={70} at={80 + i * 20} />
    ))}
  </KeyVisualStage>
);

const Benefits: React.FC = () => (
  <AbsoluteFill>
    <Background />
    <BenefitsScene />
    <HealBurst cx={BENEFIT_JOINT.x} cy={BENEFIT_JOINT.y} at={[26, 76, 126]} />
  </AbsoluteFill>
);

const KvOutro: React.FC<{ duration: number }> = ({ duration }) => (
  <KeyVisualStage camera="settle" animateTitles={false} sweeps={[30, 110]} duration={duration}>
    <KvIngredients start={14} />
    <KvCallToAction start={50} fx />
    {GLINTS.slice(0, 3).map(([x, y], i) => (
      <Sparkle key={i} x={x} y={y} size={60} at={40 + i * 45} />
    ))}
  </KeyVisualStage>
);

const SCENES: TimelineScene[] = [
  { duration: 100, tone: "onDark", Component: Hook },
  { duration: 175, tone: "onLight", Component: KvIntro },
  { duration: 190, tone: "onDark", Component: Benefits },
  { duration: 160, tone: "onLight", Component: KvOutro },
];

// TRANSITIONS[i] joins SCENES[i] to SCENES[i + 1].
const TRANSITIONS: TimelineTransition[] = [
  { kind: "flash", duration: 14 }, // hook -> product: light flash with a zoom blur
  {
    // product -> how it works: dive into the knee on the box
    kind: "dive",
    duration: 18,
    diveFrom: KNEE_ON_BOX,
    diveTo: `${BENEFIT_JOINT.x}px ${BENEFIT_JOINT.y}px`,
  },
  { kind: "glare", duration: 16 }, // how it works -> ending: glare wipe
];

export const CH_ALPHA_STORY_DURATION = timelineDuration(SCENES, TRANSITIONS);

export const ChAlphaStoryPromo: React.FC = () => (
  <SceneTimeline scenes={SCENES} transitions={TRANSITIONS} />
);
