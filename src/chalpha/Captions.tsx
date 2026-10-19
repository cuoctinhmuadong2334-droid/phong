import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { bodyFont } from "../fonts";
import { clamp } from "./Scenes";
import { CUES } from "./voiceover";

const HIGHLIGHT = "#ffd21f";

// Longer (often borrowed) words take a little longer to say.
const weight = (word: string) => (word.replace(/[^\p{L}\p{N}]/gu, "").length > 5 ? 2 : 1);

const keywordMask = (words: string[], keywords: string[]) => {
  const mask = words.map(() => false);
  for (const k of keywords) {
    const kw = k.split(" ");
    for (let i = 0; i + kw.length <= words.length; i++) {
      if (kw.every((w, j) => words[i + j] === w)) kw.forEach((_, j) => (mask[i + j] = true));
    }
  }
  return mask;
};

/** Karaoke-style subtitles: each word lights up as it is read. */
export const Captions: React.FC<{ top?: number }> = ({ top = 1470 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const cue = CUES.find((c) => t >= c.start - 0.1 && t < c.end + 0.15);
  if (!cue) return null;

  const words = cue.text.split(" ");
  const isKey = keywordMask(words, cue.keywords);
  const total = words.reduce((s, w) => s + weight(w), 0);
  const read = interpolate(t, [cue.start, cue.end - 0.1], [0, total], clamp);
  const enter = spring({ frame: frame - Math.round((cue.start - 0.1) * fps), fps, config: { damping: 16 } });
  const exit = interpolate(t, [cue.end, cue.end + 0.15], [1, 0], clamp);

  let acc = 0;
  return (
    <div
      style={{
        position: "absolute",
        top,
        left: 60,
        right: 60,
        display: "flex",
        justifyContent: "center",
        opacity: Math.min(enter, exit),
        transform: `translateY(${(1 - enter) * 30}px) scale(${0.92 + 0.08 * enter})`,
      }}
    >
      <div
        style={{
          maxWidth: 940,
          padding: "18px 30px",
          borderRadius: 28,
          background: "rgba(6,22,66,0.78)",
          border: "1.5px solid rgba(255,255,255,0.18)",
          textAlign: "center",
          fontFamily: bodyFont,
          fontSize: 46,
          fontWeight: 800,
          lineHeight: 1.3,
        }}
      >
        {words.map((w, i) => {
          const from = acc;
          acc += weight(w);
          const lit = interpolate(read, [from, from + 0.6], [0, 1], clamp);
          const color = isKey[i] && lit > 0.5 ? HIGHLIGHT : "white";
          return (
            <span
              key={i}
              style={{
                color,
                opacity: 0.4 + 0.6 * lit,
                display: "inline-block",
                transform: `translateY(${(1 - lit) * 4}px)`,
                marginRight: i < words.length - 1 ? "0.28em" : 0,
              }}
            >
              {w}
            </span>
          );
        })}
      </div>
    </div>
  );
};
