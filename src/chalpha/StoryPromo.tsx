import { AbsoluteFill, Easing, interpolate, Sequence, useCurrentFrame } from "remotion";
import { Background } from "./Background";
import { HealBurst, LightLeak, PainFx, Sparkle, useShake } from "./Fx";
import { Disclaimer, KeyVisualStage, KvCallToAction, KvIngredients } from "./KeyVisualPromo";
import { BenefitsScene, clamp, HookScene } from "./Scenes";

// One continuous ad: the knee-joint story wrapped around the key-visual motion.
// Hook (pain) -> key visual reveal -> how it works -> back to the key visual with
// ingredients and the order button. Each piece of content appears exactly once.

// Screen positions used by the effects and transitions.
const HOOK_JOINT = { x: 540, y: 896 }; // inflamed joint in HookScene
const BENEFIT_JOINT = { x: 540, y: 635 }; // healing joint in BenefitsScene
const KNEE_ON_BOX = "635px 1215px"; // knee artwork on the box at the end of the KV intro

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

type SceneDef = {
  duration: number;
  // Background behind the disclaimer: dark illustrated scene or the key visual's light floor.
  tone: "onDark" | "onLight";
  Component: React.FC<{ duration: number }>;
};

const SCENES: SceneDef[] = [
  { duration: 100, tone: "onDark", Component: Hook },
  { duration: 175, tone: "onLight", Component: KvIntro },
  { duration: 190, tone: "onDark", Component: Benefits },
  { duration: 160, tone: "onLight", Component: KvOutro },
];

type TransitionKind = "flash" | "dive" | "glare";

// TRANSITIONS[i] joins SCENES[i] to SCENES[i + 1].
const TRANSITIONS: { kind: TransitionKind; duration: number }[] = [
  { kind: "flash", duration: 14 }, // hook -> product: light flash with a zoom blur
  { kind: "dive", duration: 18 }, // product -> how it works: dive into the knee on the box
  { kind: "glare", duration: 16 }, // how it works -> ending: glare wipe
];

const OFFSETS = SCENES.map((_, i) =>
  SCENES.slice(0, i).reduce((sum, s, j) => sum + s.duration - TRANSITIONS[j].duration, 0),
);

export const CH_ALPHA_STORY_DURATION =
  OFFSETS[OFFSETS.length - 1] + SCENES[SCENES.length - 1].duration;

const progress = (frame: number, start: number, duration: number) =>
  interpolate(frame, [start, start + duration], [0, 1], clamp);

const enterProgress = (i: number, frame: number) =>
  i === 0 ? 1 : progress(frame, OFFSETS[i], TRANSITIONS[i - 1].duration);

const exitProgress = (i: number, frame: number) =>
  i === SCENES.length - 1
    ? 0
    : progress(frame, OFFSETS[i] + SCENES[i].duration - TRANSITIONS[i].duration, TRANSITIONS[i].duration);

const glareEdge = (p: number) => -15 + 135 * Easing.inOut(Easing.quad)(p);

// How visible an incoming scene is at transition progress p.
const enterVisibility = (kind: TransitionKind, p: number) =>
  kind === "flash"
    ? interpolate(p, [0, 0.45], [0, 1], clamp)
    : kind === "dive"
      ? interpolate(p, [0.3, 0.75], [0, 1], clamp)
      : p;

const enterStyle = (kind: TransitionKind, p: number): React.CSSProperties => {
  if (p >= 1) return {};
  if (kind === "flash") {
    return { opacity: enterVisibility(kind, p), filter: `blur(${10 * (1 - p)}px)` };
  }
  if (kind === "dive") {
    const e = Easing.out(Easing.cubic)(p);
    return {
      opacity: enterVisibility(kind, p),
      transformOrigin: `${BENEFIT_JOINT.x}px ${BENEFIT_JOINT.y}px`,
      transform: `scale(${1.35 - 0.35 * e})`,
      filter: `blur(${12 * (1 - p)}px)`,
    };
  }
  const x = glareEdge(p);
  const mask = `linear-gradient(105deg, black ${x - 15}%, transparent ${x}%)`;
  return { WebkitMaskImage: mask, maskImage: mask };
};

const exitStyle = (kind: TransitionKind, p: number): React.CSSProperties => {
  if (p <= 0) return {};
  if (kind === "flash") {
    const e = Easing.in(Easing.quad)(p);
    return {
      transform: `scale(${1 + 0.25 * e})`,
      filter: `blur(${10 * p}px) brightness(${1 + 0.6 * p})`,
    };
  }
  if (kind === "dive") {
    const e = Easing.in(Easing.cubic)(p);
    return {
      transformOrigin: KNEE_ON_BOX,
      transform: `scale(${1 + 2.2 * e})`,
      filter: `blur(${12 * p}px)`,
    };
  }
  return { transform: `scale(${1 + 0.04 * p})` };
};

// Light that rides on top of each transition.
const TransitionLight: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <>
      {TRANSITIONS.map(({ kind, duration }, i) => {
        const start = OFFSETS[i + 1];
        if (frame < start || frame > start + duration) return null;
        const p = (frame - start) / duration;
        if (kind === "flash") {
          return (
            <AbsoluteFill
              key={i}
              style={{
                background:
                  "radial-gradient(circle at 50% 55%, rgba(255,255,255,0.95), rgba(170,210,255,0.7) 60%, rgba(120,170,255,0.5))",
                opacity: 0.85 * Math.sin(Math.PI * p) ** 2,
              }}
            />
          );
        }
        if (kind === "dive") {
          return (
            <AbsoluteFill
              key={i}
              style={{
                background:
                  "radial-gradient(circle at 50% 40%, rgba(143,211,255,0.6), rgba(143,211,255,0) 70%)",
                opacity: 0.6 * Math.sin(Math.PI * p),
                mixBlendMode: "screen",
              }}
            />
          );
        }
        const x = glareEdge(p);
        return (
          <AbsoluteFill
            key={i}
            style={{
              background: `linear-gradient(105deg, rgba(255,255,255,0) ${x - 22}%, rgba(255,255,255,0.85) ${x - 8}%, rgba(255,255,255,0) ${x + 4}%)`,
              mixBlendMode: "screen",
            }}
          />
        );
      })}
    </>
  );
};

export const ChAlphaStoryPromo: React.FC = () => {
  const frame = useCurrentFrame();

  // How much of the visible picture is a light-floor scene, so the single fixed
  // disclaimer can switch text colour in step with the transitions.
  const light = SCENES.reduce((acc, scene, i) => {
    const active = frame >= OFFSETS[i] && frame < OFFSETS[i] + scene.duration;
    if (!active) return acc;
    const a = i === 0 ? 1 : enterVisibility(TRANSITIONS[i - 1].kind, enterProgress(i, frame));
    return a * (scene.tone === "onLight" ? 1 : 0) + (1 - a) * acc;
  }, 0);

  return (
    <AbsoluteFill style={{ backgroundColor: "black" }}>
      {SCENES.map(({ duration, Component }, i) => {
        const enter = i === 0 ? {} : enterStyle(TRANSITIONS[i - 1].kind, enterProgress(i, frame));
        const exit = i === SCENES.length - 1 ? {} : exitStyle(TRANSITIONS[i].kind, exitProgress(i, frame));
        return (
          <Sequence key={i} from={OFFSETS[i]} durationInFrames={duration}>
            <AbsoluteFill style={enter}>
              <AbsoluteFill style={exit}>
                <Component duration={duration} />
              </AbsoluteFill>
            </AbsoluteFill>
          </Sequence>
        );
      })}
      <TransitionLight />
      <Disclaimer tone="onDark" fadeInAt={15} opacity={1 - light} />
      <Disclaimer tone="onLight" fadeInAt={15} opacity={light} />
    </AbsoluteFill>
  );
};
