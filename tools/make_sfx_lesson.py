"""Synthesise the sound effects for the "Bài tập / TRẢ GIAO BÓNG" title.

Every moment is read from src/captext/lessonTimeline.json (the same file the animation uses),
so the sounds land exactly when letters drop and the ball touches down. Reuses the synthesis
helpers of tools/make_sfx.py. Writes a 48 kHz stereo 16-bit WAV.

usage (needs NumPy):  python3 tools/make_sfx_lesson.py [out.wav]    default: public/sfx/lesson-title.wav
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sfx import SR, env_attack_decay, impact, place, sweep_noise, t_axis, write_wav  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
TL = json.load(open(os.path.join(HERE, "..", "src", "captext", "lessonTimeline.json"), encoding="utf-8"))
TOTAL = TL["seconds"]

PENTATONIC = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]  # semitones, so the drops sound like a tune


def pan(clip, p):
    """Constant-power pan, p in -1 (left) .. 1 (right)."""
    return clip * np.array([[np.sqrt((1 - p) / 2)], [np.sqrt((1 + p) / 2)]])


def bell(freq, decay=0.45, length=1.0):
    t = t_axis(length)
    sig = (np.sin(2 * np.pi * freq * t) + 0.45 * np.sin(2 * np.pi * freq * 2.76 * t)) * np.exp(-t / decay)
    sig *= np.clip(t / 0.002, 0, 1)
    return np.stack([sig, sig])


def blop(freq, gain_len=0.25):
    """Round 'bụp': a short sine that glides down a fifth."""
    return impact(freq * 1.5, freq, 0.07, click=0.22, length=gain_len)


def build():
    mix = np.zeros((2, int(TOTAL * SR)))

    # tape label slaps on, then the handwriting scribbles in
    place(mix, impact(260, 110, 0.09, click=0.7, length=0.4), TL["tapeIn"] + 0.04, 0.5)
    d = 0.22
    place(mix, sweep_noise(d, 500, 3200, 0.9, env_attack_decay(int(d * SR), 0.6, 1.6), -0.5, -0.2), TL["tapeIn"], 0.16)
    w0, w1 = TL["write"]
    d = w1 - w0
    n = int(d * SR)
    scribble = env_attack_decay(n, 0.15, 0.6) * (0.55 + 0.45 * np.sin(2 * np.pi * 17 * t_axis(d)[:n]))
    place(mix, sweep_noise(d, 3500, 6500, 0.5, scribble, -0.4, 0.2), w0, 0.14)
    place(mix, bell(2400, 0.12, 0.3), 0.34, 0.12)
    place(mix, sweep_noise(0.22, 2000, 6500, 0.7, env_attack_decay(int(0.22 * SR), 0.5, 1.6), -0.2, 0.3), w1 - 0.02, 0.12)

    # "TRẢ GIAO" letters drop and squash; "BÓNG" letters jump up from below
    L1, L2 = TL["line1"], TL["line2"]
    d = 0.5
    place(mix, sweep_noise(d, 4200, 700, 1.0, env_attack_decay(int(d * SR), 0.3, 1.5)), L1["start"] - 0.02, 0.13)
    k = 0
    for i, ch in enumerate(L1["text"]):
        if ch == " ":
            continue
        f = 330 * 2 ** (PENTATONIC[k] / 12)
        place(mix, pan(blop(f), -0.45 + 0.9 * i / max(len(L1["text"]) - 1, 1)),
              L1["start"] + i * L1["stagger"] + L1["fall"], 0.34)
        k += 1
    d = 0.4
    place(mix, sweep_noise(d, 400, 3200, 1.0, env_attack_decay(int(d * SR), 0.7, 1.6)), L2["start"] - 0.02, 0.12)
    for j, ch in enumerate(L2["text"]):
        f = 330 * 2 ** (PENTATONIC[k] / 12)
        place(mix, pan(blop(f), -0.35 + 0.5 * j / max(len(L2["text"]) - 1, 1)),
              L2["start"] + j * L2["stagger"] + L2["rise"], 0.3)
        k += 1

    # the pickleball: whoosh on the way in, a 'póc' and a low thump at every touchdown
    segs = TL["ball"]["segments"]
    fall = segs[0]
    d = fall["t1"] - fall["t0"]
    place(mix, sweep_noise(d, 3600, 500, 1.0, env_attack_decay(int(d * SR), 0.85, 1.5), 0.55, 0.55), fall["t0"], 0.26)
    for s in segs:
        h = 170 if s["kind"] == "fall" else s["H"]
        g = 0.34 + 0.66 * min(h, 170) / 170
        if s["x1"] > 380:  # the ball has already left the frame on the right: keep it quiet
            g *= 0.4
        pos = 0.55 + 0.45 * min(1.0, s["x1"] / 1000)
        pop = impact(1250, 520, 0.028, click=0.15, crack=0.8, length=0.2)
        thump = impact(170, 90, 0.05, click=0.5, length=0.25)
        place(mix, pan(pop, pos), s["t1"], 0.62 * g)
        place(mix, pan(thump, pos), s["t1"], 0.3 * g)

    # sparkles glint on the finished title
    for s, f in zip(TL["sparkles"], (2349, 3136, 3951)):
        place(mix, pan(bell(f), 0.0), s, 0.1)

    # exit: letters drop away, tape slides off
    ex = TL["exit"]
    d = 0.65
    place(mix, sweep_noise(d, 3200, 250, 1.1, env_attack_decay(int(d * SR), 0.35, 1.5)), ex["letters"] - 0.03, 0.3)
    d = 0.4
    place(mix, sweep_noise(d, 6000, 1200, 0.6, env_attack_decay(int(d * SR), 0.5, 1.5), -0.3, -0.9), ex["tape"], 0.16)

    # tidy up: soft-limit stray peaks, remove DC, short fades, peak at -2 dBFS
    mix = np.tanh(mix * 0.9)
    mix -= mix.mean(axis=1, keepdims=True)
    fade = int(0.01 * SR)
    mix[:, :fade] *= np.linspace(0, 1, fade)
    mix[:, -fade:] *= np.linspace(1, 0, fade)
    mix *= 10 ** (-2 / 20) / (np.max(np.abs(mix)) + 1e-9)
    return mix


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "public", "sfx", "lesson-title.wav")
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    mix = build()
    write_wav(out, mix)
    print(f"wrote {out}: {mix.shape[1] / SR:.2f} s, peak {20 * np.log10(np.max(np.abs(mix))):.1f} dBFS")
