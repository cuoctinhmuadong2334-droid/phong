import type { Box } from "./Particles";

/** Vertical divider used for the before/after wipe across the logo. */
export const Divider: React.FC<{ x: number; box: Box; opacity: number }> = ({ x, box, opacity }) => {
  const top = box.y - box.h * 0.9;
  const height = box.h * 2.8;
  return (
    <div style={{ position: "absolute", left: x - 2, top, width: 4, height, opacity }}>
      <div
        style={{
          position: "absolute",
          inset: 0,
          background:
            "linear-gradient(180deg, rgba(255,255,255,0), white 25%, white 75%, rgba(255,255,255,0))",
          boxShadow: "0 0 18px rgba(255,255,255,0.9), 0 0 50px rgba(160,200,255,0.6)",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: -20,
          top: height / 2 - 22,
          width: 44,
          height: 44,
          borderRadius: "50%",
          border: "3px solid white",
          background: "rgba(0,0,0,0.6)",
          boxShadow: "0 0 20px rgba(255,255,255,0.6)",
        }}
      >
        <svg width="38" height="38" viewBox="0 0 24 24" style={{ position: "absolute", left: 0, top: 0 }}>
          <path d="M9 7 L4 12 L9 17 M15 7 L20 12 L15 17" fill="none" stroke="white" strokeWidth="2.2" />
        </svg>
      </div>
    </div>
  );
};
