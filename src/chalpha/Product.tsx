import { Img, interpolate, staticFile, useCurrentFrame } from "remotion";

export const BOX_IMAGE = {
  src: staticFile("chalpha/product.png"),
  ratio: 530 / 807,
};
export const AMPOULE_IMAGE = {
  src: staticFile("chalpha/ampoule.png"),
  ratio: 1206 / 692,
};

// Cut-out product photo with a glossy light sweep that repeats every `sweepEvery` frames.
export const Product: React.FC<{
  width: number;
  sweepEvery?: number;
  image?: { src: string; ratio: number };
  glow?: boolean;
}> = ({ width, sweepEvery = 70, image = BOX_IMAGE, glow = false }) => {
  const { src: SRC, ratio: RATIO } = image;
  const frame = useCurrentFrame();
  const p = interpolate(frame % sweepEvery, [0, sweepEvery * 0.6], [-20, 120], {
    extrapolateRight: "clamp",
  });
  return (
    <div style={{ position: "relative", width, height: width * RATIO }}>
      {glow && (
        <div
          style={{
            position: "absolute",
            inset: "-10%",
            background:
              "radial-gradient(circle, rgba(255,255,255,0.45) 0%, rgba(255,255,255,0) 60%)",
          }}
        />
      )}
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
