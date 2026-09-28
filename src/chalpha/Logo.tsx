import { Img, staticFile } from "remotion";

const RATIO = 528 / 1517;

// Official logo (blue/red on transparent) presented on a white card so it
// stays legible on the blue video backgrounds.
export const Logo: React.FC<{ width: number; style?: React.CSSProperties }> = ({
  width,
  style,
}) => (
  <div
    style={{
      background: "white",
      borderRadius: 28,
      padding: "20px 30px",
      boxShadow: "0 20px 50px rgba(0,0,0,0.3)",
      ...style,
    }}
  >
    <Img
      src={staticFile("chalpha/logo.png")}
      style={{ display: "block", width, height: width * RATIO }}
    />
  </div>
);
