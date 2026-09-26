import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

type Props = {
  title: string;
  subtitle: string;
};

export const HelloWorld: React.FC<Props> = ({ title, subtitle }) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  const titleScale = spring({ frame, fps, config: { damping: 200 } });
  const subtitleOpacity = interpolate(frame, [30, 60], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const fadeOut = interpolate(
    frame,
    [durationInFrames - 20, durationInFrames],
    [1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

  return (
    <AbsoluteFill
      style={{
        backgroundColor: "#0f172a",
        justifyContent: "center",
        alignItems: "center",
        fontFamily: "Arial, Helvetica, sans-serif",
        opacity: fadeOut,
      }}
    >
      <h1
        style={{
          color: "white",
          fontSize: 140,
          margin: 0,
          transform: `scale(${titleScale})`,
        }}
      >
        {title}
      </h1>
      <p style={{ color: "#38bdf8", fontSize: 56, opacity: subtitleOpacity }}>
        {subtitle}
      </p>
    </AbsoluteFill>
  );
};
