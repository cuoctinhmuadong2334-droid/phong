import { techFont } from "./fonts";

// Simplified wordmark stand-ins drawn as shapes/text (not the official logos).

export const WingMark: React.FC<{ size: number; color?: string }> = ({
  size,
  color = "white",
}) => (
  <svg width={size} height={size * 0.6} viewBox="0 0 100 60">
    <path d="M0 4 L38 4 L50 40 L62 4 L100 4 L58 56 L42 56 Z" fill={color} />
    <path d="M20 4 L44 44 L50 34 Z" fill="rgba(0,0,0,0.25)" />
  </svg>
);

export const KivixWordmark: React.FC<{ height: number; color?: string }> = ({
  height,
  color = "white",
}) => (
  <div style={{ display: "flex", alignItems: "center", gap: height * 0.2 }}>
    <WingMark size={height * 1.4} color={color} />
    <span
      style={{
        fontFamily: techFont,
        fontWeight: 700,
        fontSize: height,
        color,
        letterSpacing: height * 0.08,
        lineHeight: 1,
      }}
    >
      KIVIX
    </span>
  </div>
);

export const TriangleMark: React.FC<{ size: number; color?: string }> = ({
  size,
  color = "white",
}) => (
  <svg width={size} height={size} viewBox="0 0 100 100">
    <path d="M50 5 L95 90 L70 90 L50 50 L30 90 L5 90 Z" fill={color} />
    <path d="M50 50 L62 72 L38 72 Z" fill={color} />
  </svg>
);

export const DiamondMark: React.FC<{ size: number; color?: string }> = ({
  size,
  color = "white",
}) => (
  <svg width={size} height={size * 0.8} viewBox="0 0 100 80">
    <path
      d="M20 5 L80 5 L98 28 L50 78 L2 28 Z M2 28 L98 28 M35 5 L28 28 L50 78 L72 28 L65 5"
      fill="none"
      stroke={color}
      strokeWidth={5}
      strokeLinejoin="round"
    />
  </svg>
);
