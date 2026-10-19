import {
  AbsoluteFill,
  Audio,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { bodyFont } from "../fonts";
import { Background } from "./Background";
import { Captions } from "./Captions";
import { COLORS, CONTENT } from "./content";
import { HealBurst, LightLeak, Sparkle } from "./Fx";
import { Joint } from "./Joint";
import { KeyVisualStage, KvCallToAction } from "./KeyVisualPromo";
import { PickleballScene } from "./Pickleball";
import { clamp } from "./Scenes";
import { KNEE_ON_BOX } from "./StoryPromo";
import {
  SceneTimeline,
  timelineDuration,
  type TimelineScene,
  type TimelineTransition,
} from "./Transitions";
import { VOICE_FILE } from "./voiceover";

// Motion paced to Tùng's ~15 s read (see voiceover.ts), ending on the order button.
// Scene frames below are local to each scene; comments give the line being read.

const SHIELD_JOINT = { x: 540, y: 765 };
const COLLAGEN_JOINT = { x: 540, y: 687 };
const GLINTS: [x: number, y: number][] = [
  [760, 952],
  [985, 1040],
  [305, 1012],
  [226, 1037],
];

const Heading: React.FC<{ small: string; big: string; at: number; until?: number }> = ({
  small,
  big,
  at,
  until,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = spring({ frame: frame - at, fps, config: { damping: 200 } });
  const out = until === undefined ? 1 : interpolate(frame, [until, until + 8], [1, 0], clamp);
  return (
    <div
      style={{
        position: "absolute",
        top: 150,
        left: 40,
        right: 40,
        textAlign: "center",
        fontFamily: bodyFont,
        color: "white",
        opacity: t * out,
        transform: `translateY(${(1 - t) * 30}px)`,
      }}
    >
      <div style={{ fontSize: 34, fontWeight: 700, letterSpacing: 6, color: COLORS.cartilage }}>
        {small}
      </div>
      <div style={{ fontSize: 64, fontWeight: 800, lineHeight: 1.15, marginTop: 8, whiteSpace: "pre-line" }}>
        {big}
      </div>
    </div>
  );
};

// "Để chủ động bảo vệ sụn khớp và hệ vận động"
const ShieldScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const joint = spring({ frame, fps, config: { damping: 18 } });
  const shield = spring({ frame: frame - 14, fps, config: { damping: 12 } });
  const glow = 0.5 + 0.5 * Math.sin(frame / 7);
  return (
    <AbsoluteFill>
      <Background />
      <Heading small="CHỦ ĐỘNG BẢO VỆ" big={"SỤN KHỚP &\nHỆ VẬN ĐỘNG"} at={4} />
      <div
        style={{
          position: "absolute",
          left: SHIELD_JOINT.x - 340,
          top: SHIELD_JOINT.y - 340,
          width: 680,
          height: 680,
          borderRadius: "50%",
          border: "6px solid rgba(143,211,255,0.9)",
          boxShadow: `0 0 ${40 + 30 * glow}px rgba(143,211,255,0.7), inset 0 0 ${40 + 30 * glow}px rgba(143,211,255,0.45)`,
          opacity: shield,
          transform: `scale(${0.6 + 0.4 * shield})`,
        }}
      />
      <div
        style={{
          position: "absolute",
          left: SHIELD_JOINT.x - 380,
          top: SHIELD_JOINT.y - 380,
          width: 760,
          height: 760,
          borderRadius: "50%",
          border: "3px dashed rgba(255,255,255,0.45)",
          opacity: shield,
          transform: `rotate(${frame * 0.8}deg)`,
        }}
      />
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: 380,
          display: "flex",
          justifyContent: "center",
          opacity: joint,
          transform: `scale(${0.75 + 0.25 * joint})`,
        }}
      >
        <Joint width={560} health={1} inflammation={0} flow={0} />
      </div>
    </AbsoluteFill>
  );
};

// "Với Collagen Peptide FORTIGEL® chuyên biệt cho sụn khớp chuẩn Đức"
const FortigelCard: React.FC<{ at: number }> = ({ at }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = spring({ frame: frame - at, fps, config: { damping: 13 } });
  const shine = interpolate(frame, [at + 8, at + 34], [-30, 130], clamp);
  return (
    <div
      style={{
        position: "absolute",
        top: 560,
        left: 0,
        right: 0,
        display: "flex",
        justifyContent: "center",
        opacity: interpolate(t, [0, 0.4], [0, 1], clamp),
        transform: `scale(${0.8 + 0.2 * t})`,
      }}
    >
      <div
        style={{
          position: "relative",
          overflow: "hidden",
          padding: "26px 56px",
          borderRadius: 36,
          background: "rgba(255,255,255,0.14)",
          border: "1.5px solid rgba(255,255,255,0.4)",
          textAlign: "center",
          fontFamily: bodyFont,
          color: "white",
          textShadow: "0 2px 10px rgba(0,0,0,0.25)",
        }}
      >
        <div style={{ fontSize: 30, fontWeight: 700, letterSpacing: 6 }}>COLLAGEN PEPTIDE</div>
        <div
          style={{
            fontSize: 84,
            fontWeight: 800,
            lineHeight: 1.1,
            textShadow: "0 0 24px rgba(143,211,255,0.8)",
          }}
        >
          {CONTENT.fortigel}
        </div>
        <div style={{ fontSize: 30, fontWeight: 500, marginTop: 6 }}>
          Chuyên biệt cho sụn khớp · Chuẩn Đức
        </div>
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: `linear-gradient(105deg, rgba(255,255,255,0) ${shine - 12}%, rgba(255,255,255,0.45) ${shine}%, rgba(255,255,255,0) ${shine + 12}%)`,
          }}
        />
      </div>
    </div>
  );
};

// "Tùng xin giới thiệu CH-Alpha PLUS" + "Với Collagen Peptide FORTIGEL® ... chuẩn Đức"
const KvIntro: React.FC<{ duration: number }> = ({ duration }) => (
  <KeyVisualStage
    camera="pullback"
    animateTitles
    sweeps={[12]}
    duration={duration}
    badgePulseAt={150}
    fx
  >
    <LightLeak start={60} duration={60} />
    {GLINTS.map(([x, y], i) => (
      <Sparkle key={i} x={x} y={y} size={70} at={90 + i * 18} />
    ))}
    <FortigelCard at={66} />
  </KeyVisualStage>
);

// "sản phẩm giúp kích thích sản sinh collagen type II" + "bôi trơn hệ vận động"
const CollagenScene: React.FC = () => {
  const frame = useCurrentFrame();
  const flow = interpolate(frame, [12, 25, 88, 102], [0, 1, 1, 0], clamp);
  const health = interpolate(frame, [80, 118], [0.45, 1], clamp);
  return (
    <AbsoluteFill>
      <Background />
      <Heading small="KÍCH THÍCH SẢN SINH" big={CONTENT.collagenType} at={12} until={90} />
      <Heading small="GIÚP" big="BÔI TRƠN HỆ VẬN ĐỘNG" at={96} />
      <div style={{ position: "absolute", left: 0, right: 0, top: 330, display: "flex", justifyContent: "center" }}>
        <Joint width={520} health={health} inflammation={0} flow={flow} />
      </div>
      <HealBurst cx={COLLAGEN_JOINT.x} cy={COLLAGEN_JOINT.y} at={[96, 112]} />
    </AbsoluteFill>
  );
};

const KvOutro: React.FC<{ duration: number }> = ({ duration }) => (
  <KeyVisualStage camera="settle" animateTitles={false} sweeps={[24]} duration={duration}>
    <FortigelCard at={-100} />
    <KvCallToAction start={14} fx />
    {GLINTS.slice(0, 3).map(([x, y], i) => (
      <Sparkle key={i} x={x} y={y} size={60} at={20 + i * 22} />
    ))}
  </KeyVisualStage>
);

const SCENES: TimelineScene[] = [
  { duration: 85, tone: "onDark", Component: ShieldScene },
  { duration: 178, tone: "onLight", Component: KvIntro },
  { duration: 136, tone: "onDark", Component: CollagenScene },
  { duration: 125, tone: "onDark", Component: PickleballScene },
  { duration: 90, tone: "onLight", Component: KvOutro },
];

const TRANSITIONS: TimelineTransition[] = [
  { kind: "flash", duration: 14 },
  {
    kind: "dive",
    duration: 18,
    diveFrom: KNEE_ON_BOX,
    diveTo: `${COLLAGEN_JOINT.x}px ${COLLAGEN_JOINT.y}px`,
  },
  { kind: "flash", duration: 14 },
  { kind: "glare", duration: 16 },
];

export const CH_ALPHA_VOICE_DURATION = timelineDuration(SCENES, TRANSITIONS);

export const ChAlphaVoicePromo: React.FC = () => (
  <SceneTimeline scenes={SCENES} transitions={TRANSITIONS}>
    <Captions top={1500} />
    {VOICE_FILE && <Audio src={staticFile(VOICE_FILE)} />}
  </SceneTimeline>
);
