import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Badge } from "./Badge";
import { bodyFont, titleFont } from "../fonts";
import { Shirt } from "./Shirt";
import type { JerseyVariant } from "./types";

export const JerseyScene: React.FC<{ variant: JerseyVariant; index: number }> = ({
  variant,
  index,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = (delay: number, damping = 14) =>
    spring({ frame: frame - delay, fps, config: { damping } });

  const front = enter(4);
  const back = enter(14);
  const title = enter(28, 200);
  const label = enter(42, 200);
  const badge = enter(52, 10);
  const float = Math.sin(frame / 18) * 6;

  return (
    <AbsoluteFill>
      <div
        style={{
          position: "absolute",
          left: 520,
          top: 140,
          transform: `translate(${interpolate(back, [0, 1], [700, 0])}px, ${-float}px)`,
        }}
      >
        <Shirt id={`back-${index}`} variant={variant} side="back" width={480} />
      </div>
      <div
        style={{
          position: "absolute",
          left: 50,
          top: 165,
          transform: `translate(${interpolate(front, [0, 1], [-750, 0])}px, ${float}px)`,
        }}
      >
        <Shirt id={`front-${index}`} variant={variant} side="front" width={540} />
      </div>

      <div
        style={{
          position: "absolute",
          left: 50,
          top: 800,
          color: "white",
          fontFamily: titleFont,
          opacity: title,
          transform: `translateY(${interpolate(title, [0, 1], [60, 0])}px)`,
        }}
      >
        <div style={{ fontSize: 66, fontWeight: 700, lineHeight: 1 }}>
          COMPETITION JERSEY
        </div>
        <div style={{ fontSize: 38, fontWeight: 500, lineHeight: 1.3 }}>
          WORLD CUP PICKLEBALL 2026
        </div>
      </div>

      <div
        style={{
          position: "absolute",
          right: 70,
          top: 600,
          transform: `scale(${badge}) rotate(${interpolate(badge, [0, 1], [-25, 0])}deg)`,
        }}
      >
        <Badge width={140} />
      </div>

      <div
        style={{
          position: "absolute",
          right: 50,
          top: 840,
          display: "flex",
          flexDirection: "column",
          alignItems: "flex-end",
          gap: 14,
          opacity: label,
          transform: `translateX(${interpolate(label, [0, 1], [80, 0])}px)`,
        }}
      >
        <div
          style={{
            color: "white",
            fontFamily: titleFont,
            fontWeight: 700,
            fontSize: 46,
            lineHeight: 1,
          }}
        >
          {variant.name}
        </div>
        <div
          style={{
            background: "white",
            color: "#111",
            fontFamily: bodyFont,
            fontWeight: 500,
            fontSize: 26,
            padding: "8px 36px",
            borderRadius: 8,
          }}
        >
          {variant.colorLabel}
        </div>
      </div>
    </AbsoluteFill>
  );
};
