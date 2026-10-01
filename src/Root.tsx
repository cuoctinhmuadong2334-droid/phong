import { Composition } from "remotion";
import { ChAlphaPromo, CH_ALPHA_DURATION } from "./chalpha/ChAlphaPromo";
import { ChAlphaKeyVisualPromo, CH_ALPHA_KV_DURATION } from "./chalpha/KeyVisualPromo";
import { ChAlphaStoryPromo, CH_ALPHA_STORY_DURATION } from "./chalpha/StoryPromo";
import { ChAlphaStatsPromo, CH_ALPHA_STATS_DURATION } from "./chalpha/StatsPromo";
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
      <Composition
        id="ChAlphaPromo"
        component={ChAlphaPromo}
        durationInFrames={CH_ALPHA_DURATION}
        fps={30}
        width={1080}
        height={1920}
      />
      <Composition
        id="ChAlphaStatsPromo"
        component={ChAlphaStatsPromo}
        durationInFrames={CH_ALPHA_STATS_DURATION}
        fps={30}
        width={1080}
        height={1920}
      />
      <Composition
        id="ChAlphaKeyVisual"
        component={ChAlphaKeyVisualPromo}
        durationInFrames={CH_ALPHA_KV_DURATION}
        fps={30}
        width={1080}
        height={1920}
      />
      <Composition
        id="ChAlphaStory"
        component={ChAlphaStoryPromo}
        durationInFrames={CH_ALPHA_STORY_DURATION}
        fps={30}
        width={1080}
        height={1920}
      />
    </>
  );
};
