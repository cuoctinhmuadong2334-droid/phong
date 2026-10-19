import { AbsoluteFill, Easing, interpolate, Sequence, useCurrentFrame } from "remotion";
import { Disclaimer } from "./KeyVisualPromo";
import { clamp } from "./Scenes";

// A row of scenes joined by flash / dive / glare transitions, with the mandatory
// disclaimer fixed on screen and re-coloured to suit whichever scene is showing.

export type TimelineScene = {
  duration: number;
  // Background behind the disclaimer: dark illustrated scene or the key visual's light floor.
  tone: "onDark" | "onLight";
  Component: React.FC<{ duration: number }>;
};

export type TransitionKind = "flash" | "dive" | "glare";

export type TimelineTransition = {
  kind: TransitionKind;
  duration: number;
  // dive only: screen point the outgoing scene dives into, and the point the incoming
  // scene settles around (CSS transform-origin values).
  diveFrom?: string;
  diveTo?: string;
};

export const timelineOffsets = (scenes: TimelineScene[], transitions: TimelineTransition[]) =>
  scenes.map((_, i) =>
    scenes.slice(0, i).reduce((sum, s, j) => sum + s.duration - transitions[j].duration, 0),
  );

export const timelineDuration = (scenes: TimelineScene[], transitions: TimelineTransition[]) => {
  const offsets = timelineOffsets(scenes, transitions);
  return offsets[offsets.length - 1] + scenes[scenes.length - 1].duration;
};

const progress = (frame: number, start: number, duration: number) =>
  interpolate(frame, [start, start + duration], [0, 1], clamp);

const glareEdge = (p: number) => -15 + 135 * Easing.inOut(Easing.quad)(p);

// How visible an incoming scene is at transition progress p.
const enterVisibility = (kind: TransitionKind, p: number) =>
  kind === "flash"
    ? interpolate(p, [0, 0.45], [0, 1], clamp)
    : kind === "dive"
      ? interpolate(p, [0.3, 0.75], [0, 1], clamp)
      : p;

const enterStyle = (t: TimelineTransition, p: number): React.CSSProperties => {
  if (p >= 1) return {};
  if (t.kind === "flash") {
    return { opacity: enterVisibility(t.kind, p), filter: `blur(${10 * (1 - p)}px)` };
  }
  if (t.kind === "dive") {
    const e = Easing.out(Easing.cubic)(p);
    return {
      opacity: enterVisibility(t.kind, p),
      transformOrigin: t.diveTo,
      transform: `scale(${1.35 - 0.35 * e})`,
      filter: `blur(${12 * (1 - p)}px)`,
    };
  }
  const x = glareEdge(p);
  const mask = `linear-gradient(105deg, black ${x - 15}%, transparent ${x}%)`;
  return { WebkitMaskImage: mask, maskImage: mask };
};

const exitStyle = (t: TimelineTransition, p: number): React.CSSProperties => {
  if (p <= 0) return {};
  if (t.kind === "flash") {
    const e = Easing.in(Easing.quad)(p);
    return {
      transform: `scale(${1 + 0.25 * e})`,
      filter: `blur(${10 * p}px) brightness(${1 + 0.6 * p})`,
    };
  }
  if (t.kind === "dive") {
    const e = Easing.in(Easing.cubic)(p);
    return {
      transformOrigin: t.diveFrom,
      transform: `scale(${1 + 2.2 * e})`,
      filter: `blur(${12 * p}px)`,
    };
  }
  return { transform: `scale(${1 + 0.04 * p})` };
};

// Light that rides on top of each transition.
const TransitionLight: React.FC<{ transitions: TimelineTransition[]; offsets: number[] }> = ({
  transitions,
  offsets,
}) => {
  const frame = useCurrentFrame();
  return (
    <>
      {transitions.map(({ kind, duration }, i) => {
        const start = offsets[i + 1];
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

/** `children` render above the scenes and transition light, below the disclaimer. */
export const SceneTimeline: React.FC<{
  scenes: TimelineScene[];
  transitions: TimelineTransition[];
  children?: React.ReactNode;
}> = ({ scenes, transitions, children }) => {
  const frame = useCurrentFrame();
  const offsets = timelineOffsets(scenes, transitions);
  const last = scenes.length - 1;

  const enterProgress = (i: number) =>
    i === 0 ? 1 : progress(frame, offsets[i], transitions[i - 1].duration);
  const exitProgress = (i: number) =>
    i === last
      ? 0
      : progress(
          frame,
          offsets[i] + scenes[i].duration - transitions[i].duration,
          transitions[i].duration,
        );

  // How much of the visible picture is a light-floor scene, so the single fixed
  // disclaimer can switch text colour in step with the transitions.
  const light = scenes.reduce((acc, scene, i) => {
    const active = frame >= offsets[i] && frame < offsets[i] + scene.duration;
    if (!active) return acc;
    const a = i === 0 ? 1 : enterVisibility(transitions[i - 1].kind, enterProgress(i));
    return a * (scene.tone === "onLight" ? 1 : 0) + (1 - a) * acc;
  }, 0);

  return (
    <AbsoluteFill style={{ backgroundColor: "black" }}>
      {scenes.map(({ duration, Component }, i) => {
        const enter = i === 0 ? {} : enterStyle(transitions[i - 1], enterProgress(i));
        const exit = i === last ? {} : exitStyle(transitions[i], exitProgress(i));
        return (
          <Sequence key={i} from={offsets[i]} durationInFrames={duration}>
            <AbsoluteFill style={enter}>
              <AbsoluteFill style={exit}>
                <Component duration={duration} />
              </AbsoluteFill>
            </AbsoluteFill>
          </Sequence>
        );
      })}
      <TransitionLight transitions={transitions} offsets={offsets} />
      {children}
      <Disclaimer tone="onDark" fadeInAt={15} opacity={1 - light} />
      <Disclaimer tone="onLight" fadeInAt={15} opacity={light} />
    </AbsoluteFill>
  );
};
