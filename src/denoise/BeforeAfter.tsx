/** Vertical before/after divider: a thin line of light. */
export const Divider: React.FC<{ x: number; top: number; height: number; opacity: number }> = ({
  x,
  top,
  height,
  opacity,
}) => (
  <div
    style={{
      position: "absolute",
      left: x - 1.5,
      top,
      width: 3,
      height,
      opacity,
      background:
        "linear-gradient(180deg, rgba(255,255,255,0), white 15%, white 85%, rgba(255,255,255,0))",
      boxShadow: "0 0 16px rgba(255,255,255,0.8), 0 0 60px rgba(160,200,255,0.5)",
    }}
  />
);
