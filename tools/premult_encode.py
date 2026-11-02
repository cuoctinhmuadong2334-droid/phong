"""Premultiply a straight-alpha PNG sequence and encode it as ProRes 4444 with alpha.

Why: CapCut reads the alpha of an imported .mov as premultiplied, so a straight-alpha file
shows soft edges (blur, shadow) as fat opaque blobs. Premultiplying the colour fixes that.

usage (from the repo root; needs Pillow and NumPy):
  python3 tools/premult_encode.py SEQ_DIR OUT.mov FPS [premult|straight] [bits_per_mb] [alpha_bits]

SEQ_DIR holds element-000.png ... as written by `remotion render --sequence --image-format=png`.
Remotion's bundled ffmpeg has no rawvideo demuxer, so frames go through temporary PNGs.
"""
import glob
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

seq, out, fps = sys.argv[1], sys.argv[2], sys.argv[3]
mode = sys.argv[4] if len(sys.argv) > 4 else "premult"
bits_per_mb = sys.argv[5] if len(sys.argv) > 5 else "1200"
alpha_bits = sys.argv[6] if len(sys.argv) > 6 else "8"

ffmpeg = ["npx", "remotion", "ffmpeg"]
files = sorted(glob.glob(os.path.join(seq, "element-*.png")))
if not files:
    sys.exit(f"no element-*.png found in {seq}")

tmp = tempfile.mkdtemp(prefix="pm_", dir=os.path.dirname(os.path.abspath(out)))
try:
    for i, f in enumerate(files):
        a = np.asarray(Image.open(f).convert("RGBA")).astype(np.uint16)
        if mode == "premult":
            a[..., :3] = (a[..., :3] * a[..., 3:4] + 127) // 255
        Image.fromarray(a.astype(np.uint8), "RGBA").save(f"{tmp}/f{i:04d}.png", compress_level=1)
    cmd = [
        *ffmpeg, "-y", "-v", "error",
        "-framerate", fps, "-i", f"{tmp}/f%04d.png",
        "-c:v", "prores_ks", "-profile:v", "4444", "-vendor", "apl0",
        "-bits_per_mb", bits_per_mb, "-alpha_bits", alpha_bits,
        "-pix_fmt", "yuva444p10le", out,
    ]
    sys.exit(subprocess.call(cmd))
finally:
    shutil.rmtree(tmp, ignore_errors=True)
