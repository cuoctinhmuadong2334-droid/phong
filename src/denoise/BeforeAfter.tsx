/** Vertical before/after divider with a drag knob. */
export const Divider: React.FC<{ x: number; top: number; height: number; opacity: number }> = ({
  x,
  top,
  height,
  opacity,
}) => (
  <div style={{ position: "absolute", left: x - 2, top, width: 4, height, opacity }}>
    <div
      style={{
        position: "absolute",
        inset: 0,
        background:
          "linear-gradient(180deg, rgba(255,255,255,0), white 15%, white 85%, rgba(255,255,255,0))",
        boxShadow: "0 0 18px rgba(255,255,255,0.9), 0 0 50px rgba(160,200,255,0.6)",
      }}
    />
    <div
      style={{
        position: "absolute",
        left: -26,
        top: height / 2 - 28,
        width: 56,
        height: 56,
        borderRadius: "50%",
        border: "3px solid white",
        background: "rgba(0,0,0,0.55)",
        boxShadow: "0 0 20px rgba(255,255,255,0.6)",
      }}
    >
      <svg width="50" height="50" viewBox="0 0 24 24" style={{ position: "absolute", left: 0, top: 0 }}>
        <path d="M9 7 L4 12 L9 17 M15 7 L20 12 L15 17" fill="none" stroke="white" strokeWidth="2.2" />
      </svg>
    </div>
  </div>
);
