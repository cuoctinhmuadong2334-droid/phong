import { Img, interpolate, staticFile, useCurrentFrame } from "remotion";

const SRC = staticFile("chalpha/product.png");
const RATIO = 760 / 854;

// Product photo with a glossy light sweep that repeats every `sweepEvery` frames.
export const Product: React.FC<{ width: number; sweepEvery?: number }> = ({
  width,
  sweepEvery = 70,
}) => {
  const frame = useCurrentFrame();
  const p = interpolate(frame % sweepEvery, [0, sweepEvery * 0.6], [-20, 120], {
    extrapolateRight: "clamp",
  });
  return (
    <div style={{ position: "relative", width, height: width * RATIO }}>
      <div
        style={{
          position: "absolute",
          inset: "-10%",
          background:
            "radial-gradient(circle, rgba(255,255,255,0.45) 0%, rgba(255,255,255,0) 60%)",
        }}
      />
      <Img
        src={SRC}
        style={{
          position: "absolute",
          left: 0,
          top: 0,
          width: "100%",
          filter: "drop-shadow(0 40px 50px rgba(0,0,0,0.45))",
        }}
      />
      <div
        style={{
          position: "absolute",
          inset: 0,
          WebkitMaskImage: `url(${SRC})`,
          WebkitMaskSize: "100% 100%",
          background: `linear-gradient(110deg, rgba(255,255,255,0) ${p - 12}%, rgba(255,255,255,0.75) ${p}%, rgba(255,255,255,0) ${p + 12}%)`,
        }}
      />
    </div>
  );
};
