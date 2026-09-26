import { Composition } from "remotion";
import { HelloWorld } from "./HelloWorld";
import { JerseyShowcase, SHOWCASE_DURATION } from "./jersey/JerseyShowcase";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="HelloWorld"
        component={HelloWorld}
        durationInFrames={150}
        fps={30}
        width={1920}
        height={1080}
        defaultProps={{
          title: "Luật của Phong",
          subtitle: "Made with Remotion",
        }}
      />
      <Composition
        id="JerseyShowcase"
        component={JerseyShowcase}
        durationInFrames={SHOWCASE_DURATION}
        fps={30}
        width={1080}
        height={1080}
      />
    </>
  );
};
