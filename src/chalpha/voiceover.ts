// Narration for the ChAlphaVoice motion. Times are in seconds from the start of the video.
// They are estimates for a ~15 s read; once the recording arrives, put it in
// public/chalpha/voice/, set VOICE_FILE and update the times to match the audio.

export const VOICE_FILE: string | null = null; // e.g. "chalpha/voice/tung.mp3"

export type Cue = {
  text: string;
  start: number;
  end: number;
  // Phrases (exact words from `text`) shown in the highlight colour.
  keywords: string[];
};

export const CUES: Cue[] = [
  {
    text: "Để chủ động bảo vệ sụn khớp và hệ vận động,",
    start: 0.1,
    end: 2.5,
    keywords: ["sụn khớp", "hệ vận động,"],
  },
  { text: "Tùng xin giới thiệu CH-Alpha PLUS", start: 2.6, end: 4.4, keywords: ["CH-Alpha PLUS"] },
  {
    text: "Với Collagen Peptide FORTIGEL® chuyên biệt cho sụn khớp chuẩn Đức,",
    start: 4.5,
    end: 8.0,
    keywords: ["Collagen Peptide FORTIGEL®", "chuẩn Đức,"],
  },
  {
    text: "sản phẩm giúp kích thích sản sinh collagen type II,",
    start: 8.1,
    end: 10.8,
    keywords: ["collagen type II,"],
  },
  { text: "bôi trơn hệ vận động", start: 10.85, end: 11.9, keywords: ["bôi trơn"] },
  {
    text: "để anh em thoải mái di chuyển, vung vợt",
    start: 12.0,
    end: 13.8,
    keywords: ["vung vợt"],
  },
  { text: "mà không lo mài mòn sụn.", start: 13.85, end: 15.0, keywords: ["không lo mài mòn sụn."] },
];
