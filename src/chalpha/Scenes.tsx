import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { bodyFont } from "../fonts";
import { COLORS, CONTENT } from "./content";
import { Joint } from "./Joint";
import { Product } from "./Product";

export const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

export const useEnter = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (delay: number, damping = 14) =>
    spring({ frame: frame - delay, fps, config: { damping } });
};

export const centered: React.CSSProperties = {
  position: "absolute",
  left: 0,
  right: 0,
  display: "flex",
  flexDirection: "column",
  alignItems: "center",
  textAlign: "center",
  fontFamily: bodyFont,
  color: "white",
};

export const HookScene: React.FC = () => {
  const enter = useEnter();
  const lines = CONTENT.hookTitle.split("\n");
  const joint = enter(0, 20);
  const sub = enter(40, 200);
  return (
    <AbsoluteFill>
      <div style={{ ...centered, top: 170 }}>
        {lines.map((line, i) => {
          const t = enter(6 + i * 10, 200);
          return (
            <div
              key={line}
              style={{
                fontSize: 78,
                fontWeight: 800,
                lineHeight: 1.2,
                opacity: t,
                transform: `translateY(${interpolate(t, [0, 1], [50, 0])}px)`,
              }}
            >
              {line}
            </div>
          );
        })}
      </div>
      <div
        style={{
          ...centered,
          top: 470,
          transform: `scale(${interpolate(joint, [0, 1], [0.7, 1])})`,
          opacity: joint,
        }}
      >
        <Joint width={620} health={0.1} inflammation={1} flow={0} />
      </div>
      <div
        style={{
          ...centered,
          top: 1340,
          fontSize: 44,
          fontWeight: 500,
          color: COLORS.cartilage,
          opacity: sub,
        }}
      >
        {CONTENT.hookSubtitle}
      </div>
    </AbsoluteFill>
  );
};

export const RevealScene: React.FC = () => {
  const enter = useEnter();
  const [line1, line2] = CONTENT.tagline.split("\n");
  const title = enter(4, 200);
  const highlight = enter(16, 12);
  const product = enter(10, 13);
  return (
    <AbsoluteFill>
      <div style={{ ...centered, top: 190, gap: 18 }}>
        <div
          style={{
            fontSize: 64,
            fontWeight: 700,
            opacity: title,
            transform: `translateY(${interpolate(title, [0, 1], [40, 0])}px)`,
          }}
        >
          {line1}
        </div>
        <div
          style={{
            fontSize: 84,
            fontWeight: 800,
            background: COLORS.red,
            padding: "6px 36px",
            borderRadius: 20,
            transform: `scale(${highlight})`,
            boxShadow: "0 16px 40px rgba(0,0,0,0.35)",
          }}
        >
          {line2}
        </div>
      </div>
      <div
        style={{
          ...centered,
          top: 520,
          transform: `scale(${interpolate(product, [0, 1], [0.5, 1])}) rotate(${interpolate(product, [0, 1], [-8, 0])}deg)`,
          opacity: interpolate(product, [0, 0.3], [0, 1], clamp),
        }}
      >
        <Product width={940} />
      </div>
      <div
        style={{
          position: "absolute",
          top: 1390,
          left: 40,
          right: 40,
          display: "flex",
          flexWrap: "wrap",
          justifyContent: "center",
          gap: 18,
        }}
      >
        {CONTENT.ingredients.map((item, i) => {
          const t = enter(36 + i * 7, 200);
          return (
            <div
              key={item}
              style={{
                fontFamily: bodyFont,
                fontSize: 32,
                fontWeight: 700,
                color: COLORS.blueDark,
                background: "white",
                borderRadius: 999,
                padding: "12px 28px",
                opacity: t,
                transform: `translateY(${interpolate(t, [0, 1], [30, 0])}px)`,
              }}
            >
              + {item}
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};

export const BenefitCard: React.FC<{
  text: string;
  index: number;
  enter: number;
  check: number;
}> = ({ text, index, enter, check }) => (
  <div
    style={{
      display: "flex",
      alignItems: "center",
      gap: 30,
      background: "white",
      borderRadius: 32,
      padding: "30px 36px",
      minHeight: 110,
      boxShadow: "0 20px 40px rgba(0,0,0,0.3)",
      opacity: interpolate(enter, [0, 0.4], [0, 1], clamp),
      transform: `translateX(${interpolate(enter, [0, 1], [700, 0])}px)`,
    }}
  >
    <div
      style={{
        flexShrink: 0,
        width: 96,
        height: 96,
        borderRadius: "50%",
        background: index === 2 ? COLORS.red : COLORS.blue,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        transform: `scale(${check})`,
      }}
    >
      <svg width="52" height="52" viewBox="0 0 24 24">
        <path
          d="M4 12.5 L9.5 18 L20 6"
          fill="none"
          stroke="white"
          strokeWidth="3.2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </div>
    <div
      style={{
        fontFamily: bodyFont,
        fontSize: 44,
        fontWeight: 700,
        lineHeight: 1.3,
        color: COLORS.blueDark,
      }}
    >
      {text}
    </div>
  </div>
);

const CARD_DELAYS = [20, 70, 120];

export const BenefitsScene: React.FC = () => {
  const frame = useCurrentFrame();
  const enter = useEnter();
  const header = enter(0, 200);
  const flow = interpolate(frame, [20, 40, 120, 150], [0, 1, 1, 0], clamp);
  const health = interpolate(frame, [60, 140], [0.1, 1], clamp);
  const inflammation = interpolate(frame, [120, 160], [1, 0], clamp);

  return (
    <AbsoluteFill>
      <div
        style={{
          ...centered,
          top: 150,
          fontSize: 66,
          fontWeight: 800,
          opacity: header,
        }}
      >
        {CONTENT.productName}
      </div>
      <div style={{ ...centered, top: 260 }}>
        <Joint width={470} health={health} inflammation={inflammation} flow={flow} />
      </div>
      <div
        style={{
          position: "absolute",
          top: 930,
          left: 60,
          right: 60,
          display: "flex",
          flexDirection: "column",
          gap: 26,
        }}
      >
        {CONTENT.benefits.map((benefit, i) => {
          const t = enter(CARD_DELAYS[i], 15);
          const check = enter(CARD_DELAYS[i] + 12, 10);
          return (
            <BenefitCard key={benefit} text={benefit} index={i} enter={t} check={check} />
          );
        })}
      </div>
    </AbsoluteFill>
  );
};

export const CtaScene: React.FC = () => {
  const frame = useCurrentFrame();
  const enter = useEnter();
  const product = enter(0, 14);
  const name = enter(12, 200);
  const button = enter(24, 10);
  const pulse = 1 + Math.max(0, Math.sin((frame - 30) / 6)) * 0.05;
  return (
    <AbsoluteFill>
      <div
        style={{
          ...centered,
          top: 230,
          transform: `scale(${interpolate(product, [0, 1], [0.8, 1])})`,
          opacity: product,
        }}
      >
        <Product width={960} sweepEvery={50} />
      </div>
      <div
        style={{
          ...centered,
          top: 1110,
          opacity: name,
          transform: `translateY(${interpolate(name, [0, 1], [40, 0])}px)`,
        }}
      >
        <div style={{ fontSize: 88, fontWeight: 800 }}>{CONTENT.productName}</div>
        <div style={{ fontSize: 40, fontWeight: 500, color: COLORS.cartilage, marginTop: 8 }}>
          {CONTENT.pack}
        </div>
      </div>
      <div style={{ ...centered, top: 1330 }}>
        <div
          style={{
            fontSize: 58,
            fontWeight: 800,
            background: COLORS.red,
            borderRadius: 999,
            padding: "26px 80px",
            boxShadow: "0 0 0 8px rgba(255,255,255,0.25), 0 20px 50px rgba(0,0,0,0.4)",
            transform: `scale(${button * pulse})`,
          }}
        >
          {CONTENT.cta}
        </div>
      </div>
    </AbsoluteFill>
  );
};
