"""Synthesise the sound effects for the "MẮC LỖI, trả giao bóng rất mạnh" text motion.

Everything is generated from noise and sine waves (no samples, no downloads), timed to the
animation in src/captext/ErrorReturnText.tsx. Writes a 48 kHz stereo 16-bit WAV.

usage (needs NumPy):  python3 tools/make_sfx.py [out.wav]      default: public/sfx/error-return.wav
"""
import os
import sys
import wave

import numpy as np

SR = 48000
TOTAL = 7.2  # seconds, same as ERROR_TEXT_SECONDS
rng = np.random.default_rng(7)  # fixed seed: the file is identical on every run


def t_axis(duration):
    return np.arange(int(duration * SR)) / SR


def env_attack_decay(n, attack, power=2.0):
    """0 -> 1 over `attack` of the length, then a decay back to 0."""
    x = np.linspace(0, 1, n)
    up = np.clip(x / max(attack, 1e-6), 0, 1) ** power
    down = np.clip((1 - x) / max(1 - attack, 1e-6), 0, 1) ** power
    return np.minimum(up, down)


def sweep_noise(duration, f0, f1, bw_oct, env, pan0=0.0, pan1=0.0):
    """Band-limited noise whose centre frequency glides f0 -> f1 (log scale), panned -1..1."""
    n = int(duration * SR)
    frame, hop = 1024, 256
    win = np.hanning(frame)
    out = np.zeros((2, n + frame))
    freqs = np.fft.rfftfreq(frame, 1 / SR)[1:]
    for ch in range(2):
        noise = rng.standard_normal(n + frame)
        acc = np.zeros(n + frame)
        norm = np.zeros(n + frame)
        for start in range(0, n, hop):
            k = start / n
            fc = f0 * (f1 / f0) ** k
            gain = np.exp(-0.5 * (np.log2(freqs / fc) / bw_oct) ** 2)
            spec = np.fft.rfft(noise[start:start + frame] * win)
            spec[1:] *= gain
            spec[0] = 0
            seg = np.fft.irfft(spec, frame) * win
            acc[start:start + frame] += seg
            norm[start:start + frame] += win ** 2
        out[ch] = acc / np.maximum(norm, 1e-6)
    out = out[:, :n]
    out /= np.sqrt(np.mean(out ** 2)) + 1e-9  # unit RMS, so `gain` in place() sets loudness
    out *= env[None, :n]
    pan = np.linspace(pan0, pan1, n)
    left = np.sqrt((1 - pan) / 2)
    right = np.sqrt((1 + pan) / 2)
    out[0] *= left
    out[1] *= right
    return out


def impact(f_start, f_end, decay, click=0.5, crack=0.0, length=0.9):
    """Sub drop (pitch glides down) plus a short noise thump and an optional bright crack."""
    t = t_axis(length)
    freq = f_end + (f_start - f_end) * np.exp(-t * 14)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    body = np.sin(phase) * np.exp(-t / decay)
    thump = rng.standard_normal(len(t)) * np.exp(-t / 0.035)
    thump = np.convolve(thump, np.ones(24) / 24, mode="same") * click  # low-passed
    sig = body + thump
    if crack > 0:
        c = rng.standard_normal(len(t)) * np.exp(-t / 0.018)
        c = c - np.convolve(c, np.ones(6) / 6, mode="same")  # high-passed
        sig += c * crack
    sig *= np.clip(t / 0.002, 0, 1)  # avoid a click at the first sample
    return np.stack([sig, sig])


def place(mix, clip, at, gain=1.0):
    i = int(at * SR)
    n = min(clip.shape[1], mix.shape[1] - i)
    if n > 0:
        mix[:, i:i + n] += clip[:, :n] * gain


def build():
    mix = np.zeros((2, int(TOTAL * SR)))

    # 0.20 s: "MẮC LỖI," rises letter by letter -> rising whoosh, then a heavy impact
    d = 0.46
    n = int(d * SR)
    place(mix, sweep_noise(d, 250, 3800, 1.1, env_attack_decay(n, 0.82, 1.6)), 0.08, 0.30)
    place(mix, impact(130, 42, 0.30, click=0.9, crack=0.25), 0.50, 1.0)

    # 3.20 s: the five white words slide in, one light swish each, drifting left -> right
    for i in range(5):
        d = 0.24
        n = int(d * SR)
        pan = -0.6 + 1.2 * i / 4
        place(mix, sweep_noise(d, 1400, 5200, 0.7, env_attack_decay(n, 0.35, 1.8), pan, pan),
              3.18 + i * 0.09, 0.20)

    # 4.15 - 4.50 s: the red line is drawn left -> right -> sharp slash, then a hit
    d = 0.40
    n = int(d * SR)
    place(mix, sweep_noise(d, 900, 9500, 0.55, env_attack_decay(n, 0.88, 1.4), -0.9, 0.9), 4.10, 0.30)
    place(mix, impact(95, 52, 0.18, click=0.8, crack=0.55, length=0.6), 4.50, 0.95)
    d = 0.35
    n = int(d * SR)
    place(mix, sweep_noise(d, 5200, 2200, 0.9, env_attack_decay(n, 0.05, 2.2)), 4.50, 0.11)

    # 6.35 s: the red line retracts, then the text drops out -> two descending whooshes
    d = 0.26
    n = int(d * SR)
    place(mix, sweep_noise(d, 7000, 1500, 0.6, env_attack_decay(n, 0.5, 1.5), 0.8, -0.8), 6.33, 0.16)
    d = 0.58
    n = int(d * SR)
    place(mix, sweep_noise(d, 2800, 220, 1.1, env_attack_decay(n, 0.38, 1.5)), 6.42, 0.26)

    # tidy up: soft-limit stray noise peaks, remove DC, short fades, peak at -2 dBFS
    mix = np.tanh(mix * 0.9)
    mix -= mix.mean(axis=1, keepdims=True)
    fade = int(0.01 * SR)
    mix[:, :fade] *= np.linspace(0, 1, fade)
    mix[:, -fade:] *= np.linspace(1, 0, fade)
    mix *= 10 ** (-2 / 20) / (np.max(np.abs(mix)) + 1e-9)
    return mix


def write_wav(path, mix):
    pcm = np.clip(mix.T * 32767, -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "public/sfx/error-return.wav"
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    mix = build()
    write_wav(out, mix)
    print(f"wrote {out}: {mix.shape[1] / SR:.2f} s, peak {20 * np.log10(np.max(np.abs(mix))):.1f} dBFS")
