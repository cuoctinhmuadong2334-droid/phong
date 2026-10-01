import { Img, staticFile } from "remotion";

const LOGO_RATIO = 528 / 1517;
const BADGE_RATIO = 342 / 446;

// White version of the official logo, for the blue video backgrounds.
export const Logo: React.FC<{ width: number }> = ({ width }) => (
  <Img
    src={staticFile("chalpha/logo-white.png")}
    style={{ display: "block", width, height: width * LOGO_RATIO }}
  />
);

export const MadeInGermany: React.FC<{ width: number }> = ({ width }) => (
  <Img
    src={staticFile("chalpha/made-in-germany.png")}
    style={{ display: "block", width, height: width * BADGE_RATIO }}
  />
);
