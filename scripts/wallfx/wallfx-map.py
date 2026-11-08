#!/usr/bin/env python3
"""The outline map of a wallpaper, for the Mosaic OS wallpaper transition.

The character is cut out of the image (BiRefNet "general lite") and turned into
a small RGB picture in the image's own proportions, which the shader
(modules/mosaic/wallpapers/shaders/wallfx.frag) reads with the same crop as the
wallpaper:

  R  the signed distance to the silhouette: 0.5 on it, above inside, below
     outside, +-SDF_PX map pixels mapped to 1 and 0. Read with linear filtering,
     a distance field gives a smooth outline at any size: the shader draws the
     line where |distance| is small, one screen pixel soft (no stair steps)
  G  inside: how deep, 0 at the silhouette up to 1 at its deepest point (the
     fill grows inwards); outside: in what order the rest of the picture
     arrives, 0 next to the character up to 1 farthest away, roughened by noise
  B  along the outline: where each point is on the contour, 0 at its top point
     up to 1 at the far side (two pens go round in opposite directions)
 There is no alpha channel on purpose: Qt premultiplies a texture's colours by
 its alpha, which would wipe the map out.

A wallpaper without a clear character (the cut-out takes almost nothing, or
almost everything) gets an empty "<name>.none" instead, and enters with the
plain liquid spread.

  wallfx-map.py IMAGE OUT.png
  wallfx-map.py --warm FOLDER CACHE   every image of FOLDER without a map yet

Runs in its own venv (~/.local/share/mosaic-os/wallfx/venv: onnxruntime, opencv,
pillow; the model is ~/.rembg/models/birefnet-general-lite). The model is run
directly with onnxruntime, without its memory arena and with 2 threads: through
rembg it grew to 7 GB of RAM.
Idea from pocket-dots' wallfx (diegoMalagrida/pocket-dots, GPL-3.0).
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image

MAP_W = 1024         # map width; the height follows the image
MODEL_SIDE = 1024    # the model's input (square)
SDF_PX = 32.0        # how far (map px) the distance field reaches each way
MODEL = os.path.expanduser("~/.rembg/models/birefnet-general-lite/birefnet-general-lite.onnx")
_session = None


def session():
    global _session
    if _session is None:
        import onnxruntime as ort
        opts = ort.SessionOptions()
        opts.enable_cpu_mem_arena = False   # the arena kept every buffer it ever made
        opts.enable_mem_pattern = False
        opts.intra_op_num_threads = 2
        opts.inter_op_num_threads = 1
        _session = ort.InferenceSession(MODEL, opts, providers=["CPUExecutionProvider"])
    return _session


def cutout(img):
    """The character's mask, 0..1, at MAP_W wide."""
    x = np.asarray(img.resize((MODEL_SIDE, MODEL_SIDE), Image.BILINEAR), dtype=np.float32) / 255.0
    x = (x - (0.485, 0.456, 0.406)) / (0.229, 0.224, 0.225)
    x = x.transpose(2, 0, 1)[None].astype(np.float32)
    s = session()
    pred = s.run(None, {s.get_inputs()[0].name: x})[0][0, 0]
    pred = 1.0 / (1.0 + np.exp(-pred))
    pred = (pred - pred.min()) / max(pred.max() - pred.min(), 1e-6)
    h = round(MAP_W * img.height / img.width)
    return cv2.resize(pred.astype(np.float32), (MAP_W, h), interpolation=cv2.INTER_LINEAR)


def main(src, out):
    img = Image.open(src)
    img.draft("RGB", (MODEL_SIDE * 2, MODEL_SIDE * 2))  # JPEGs decode straight at a smaller size
    img = img.convert("RGB")
    soft = cutout(img)
    h, w = soft.shape
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

    # the signed distance: inside positive. Right at the edge the model's own soft
    # value refines it below a pixel, so the outline is smooth, not stepped
    din = cv2.distanceTransform(mask, cv2.DIST_L2, 5)
    dout = cv2.distanceTransform(1 - mask, cv2.DIST_L2, 5)
    sd = np.where(mask > 0, din - 0.5, -(dout - 0.5))
    edge = (din <= 1.5) & (dout <= 1.5) | (np.abs(sd) <= 1.0)
    sd = np.where(edge, (soft - 0.5) * 2.0, sd)
    r = 0.5 + 0.5 * np.clip(sd / SDF_PX, -1, 1)

    # G: inside depth, and outside order (distance to the character plus soft noise)
    depth = din / max(din.max(), 1e-3)
    rng = np.random.default_rng(abs(hash(src)) % (2 ** 32))
    noise = cv2.GaussianBlur(rng.random((h, w)).astype(np.float32), (0, 0), 28)
    noise = (noise - noise.min()) / max(noise.max() - noise.min(), 1e-6)
    order = dout / max(dout.max(), 1e-3) + noise * 0.18
    order = (order - order.min()) / max(order.max() - order.min(), 1e-6)
    g = np.where(mask > 0, depth, order)

    # B: along the outline. Every contour is drawn from its top point by two pens
    # going round in opposite directions; tiny contours (gaps, holes) get none
    line = np.zeros((h, w), np.uint8)
    param = np.zeros((h, w), np.float32)
    contours, _ = cv2.findContours(mask, cv2.RETR_LIST, cv2.CHAIN_APPROX_NONE)
    for c in contours:
        pts = c[:, 0, :]
        if len(pts) < 60:
            continue
        top = int(np.argmin(pts[:, 1]))
        pts = np.roll(pts, -top, axis=0)
        seg = np.linalg.norm(np.diff(pts, axis=0, append=pts[:1]), axis=1)
        s = np.concatenate([[0], np.cumsum(seg)[:-1]])
        total = max(s[-1] + seg[-1], 1)
        t = np.minimum(s, total - s) / (total / 2)
        line[pts[:, 1], pts[:, 0]] = 1
        param[pts[:, 1], pts[:, 0]] = t
    if line.any():
        # every pixel takes the parameter of the nearest contour pixel
        _, lab = cv2.distanceTransformWithLabels(1 - line, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
        ys, xs = np.nonzero(line)
        lut = np.zeros(lab.max() + 1, np.float32)
        lut[lab[ys, xs]] = param[ys, xs]
        b = lut[lab]
    else:
        b = np.zeros((h, w), np.float32)

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
