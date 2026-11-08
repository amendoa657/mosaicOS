#!/usr/bin/env python3
"""The outline map of a wallpaper, for the Mosaic OS wallpaper transition.

The character is cut out of the image (BiRefNet "general lite", through rembg)
and turned into a small RGB picture in the image's own proportions, which the
shader (modules/mosaic/wallpapers/shaders/wallfx.frag) reads with the same crop
as the wallpaper:

  R  inside, 0.5 at the silhouette up to 1 at its deepest point (the fill grows
     inwards from the outline); outside, 0 up to 0.45 right next to the outline
     (the line just outside the silhouette; the shader draws the inner half
     from the depth itself)
  G  outside: in what order the rest of the picture arrives, 0 next to the
     character up to 1 farthest away, roughened by noise so the front is not
     a perfect copy of the silhouette
  B  along the outline: where each point is on the contour, 0 at its top point
     up to 1 at the far side (two pens go round in opposite directions)
 There is no alpha channel on purpose: Qt premultiplies a texture's colours by
 its alpha, which would wipe out everything away from the line.

A wallpaper without a clear character (the cut-out takes almost nothing, or
almost everything) gets an empty "<name>.none" instead, and enters with the
plain liquid spread.

  wallfx-map.py IMAGE OUT.png
  wallfx-map.py --warm FOLDER CACHE   every image of FOLDER without a map yet

Runs in its own venv (~/.local/share/mosaic-os/wallfx/venv: rembg, onnxruntime,
opencv). Idea from pocket-dots' wallfx (diegoMalagrida/pocket-dots, GPL-3.0).
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image

MAP_W = 640          # map width; the height follows the image
MODEL_SIDE = 1024    # the image is shrunk to this before the cut-out
LINE_PX = 3.0        # how far (map px) the line fades out
_session = None


def cutout(img):
    """The character's mask, 0..1, at the image's size (shrunk)."""
    global _session
    from rembg import new_session, remove
    if _session is None:
        _session = new_session("birefnet-general-lite", providers=["CPUExecutionProvider"])
    small = img.copy()
    small.thumbnail((MODEL_SIDE, MODEL_SIDE))
    mask = remove(small, session=_session, only_mask=True)
    return np.asarray(mask.convert("L"), dtype=np.float32) / 255.0


def main(src, out):
    img = Image.open(src).convert("RGB")
    soft = cutout(img)
    h = round(MAP_W * img.height / img.width)
    soft = cv2.resize(soft, (MAP_W, h), interpolation=cv2.INTER_AREA)
    mask = (soft > 0.5).astype(np.uint8)

    # specks out: only pieces that take at least 1% of the biggest one
    n, labels, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    if n > 1:
        biggest = stats[1:, cv2.CC_STAT_AREA].max()
        keep = np.zeros(n, np.uint8)
        keep[1:] = stats[1:, cv2.CC_STAT_AREA] >= biggest * 0.01
        mask = keep[labels]

    # a character takes part of the picture: not a crumb, not the whole poster,
    # and the model has to be sure about it
    area = mask.mean()
    sure = soft[mask > 0].mean() if mask.any() else 0
    if area < 0.004 or area > 0.6 or sure < 0.8:
        open(os.path.splitext(out)[0] + ".none", "w").close()
        return 1

    # R: inside depth, 0.5 at the edge up to 1 deep inside
    inside = cv2.distanceTransform(mask, cv2.DIST_L2, 5)
    r_inside = 0.5 + 0.5 * inside / max(inside.max(), 1e-3)

    # G: outside order, the distance to the character plus soft noise
    outside = cv2.distanceTransform(1 - mask, cv2.DIST_L2, 5)
    rng = np.random.default_rng(abs(hash(src)) % (2 ** 32))
    noise = cv2.GaussianBlur(rng.random((h, MAP_W)).astype(np.float32), (0, 0), 18)
    noise = (noise - noise.min()) / max(noise.max() - noise.min(), 1e-6)
    g = outside / max(outside.max(), 1e-3) + noise * 0.18
    g = (g - g.min()) / max(g.max() - g.min(), 1e-6)
    g[mask > 0] = 0

    # B and A: the outline. Every contour is drawn from its top point by two pens
    # going round in opposite directions; contours along the picture's border are
    # not an outline, and tiny ones (gaps, holes) get no line
    line = np.zeros((h, MAP_W), np.uint8)
    param = np.zeros((h, MAP_W), np.float32)
    contours, _ = cv2.findContours(mask, cv2.RETR_LIST, cv2.CHAIN_APPROX_NONE)
    for c in contours:
        pts = c[:, 0, :]
        if len(pts) < 40:
            continue
        top = int(np.argmin(pts[:, 1]))
        pts = np.roll(pts, -top, axis=0)
        seg = np.linalg.norm(np.diff(pts, axis=0, append=pts[:1]), axis=1)
        s = np.concatenate([[0], np.cumsum(seg)[:-1]])
        total = max(s[-1] + seg[-1], 1)
        t = np.minimum(s, total - s) / (total / 2)
        for (x, y), tv in zip(pts, t):
            if x <= 1 or y <= 1 or x >= MAP_W - 2 or y >= h - 2:
                continue
            line[y, x] = 1
            param[y, x] = tv
    # spread each contour pixel's parameter to the pixels around it (nearest one)
    dist, lab = cv2.distanceTransformWithLabels(1 - line, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
    ys, xs = np.nonzero(line)
    lut = np.zeros(lab.max() + 1, np.float32)
    lut[lab[ys, xs]] = param[ys, xs]
    b = lut[lab]
    a = np.clip(1 - dist / LINE_PX, 0, 1)
    r = np.where(mask > 0, r_inside, 0.45 * a)

    rgb = np.dstack([r, g, b])
    Image.fromarray((rgb * 255).round().astype(np.uint8), "RGB").save(out)
    return 0


def warm(folder, cache):
    """Every image of the folder that has no map yet, one after another, with the
    model loaded once. A map is <cache>/<file name>.png (or .none)."""
    os.makedirs(cache, exist_ok=True)
    exts = (".jpg", ".jpeg", ".png", ".webp")
    for name in sorted(os.listdir(folder)):
        if not name.lower().endswith(exts):
            continue
        out = os.path.join(cache, name + ".png")
        if os.path.exists(out) or os.path.exists(os.path.join(cache, name + ".none")):
            continue
        try:
            main(os.path.join(folder, name), out)
        except Exception as e:  # a broken image must not stop the rest
            print(f"{name}: {e}", file=sys.stderr)
            open(os.path.join(cache, name + ".none"), "w").close()
    return 0


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "--warm":
        sys.exit(warm(sys.argv[2], sys.argv[3]))
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1], sys.argv[2]))
