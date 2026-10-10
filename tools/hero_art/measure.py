"""Measure body proportions of hero frames so drift between frames shows up as numbers.

Usage: python3 tools/hero_art/measure.py [--ref assets/hero/raw/hero_side_final.png] [--standing] <frame png>...
"head" is crown-to-collar height in pixels, ears included, and is the unit for every ratio.
Exit code 1 when any frame drifts past tolerance.
Works on transparent frames, green-screen frames, and the flat-background reference.
"""
import sys
import numpy as np
from PIL import Image


def opaque_mask(im):
    a = np.asarray(im.convert("RGBA")).astype(int)
    if (a[..., 3] < 250).any():
        return a, a[..., 3] > 128
    rgb = a[..., :3]
    bg = np.median(np.concatenate([rgb[:4, :4].reshape(-1, 3), rgb[-4:, -4:].reshape(-1, 3)]), axis=0)
    dist = np.abs(rgb - bg).sum(-1)
    return a, dist > 60


def measure(path):
    a, m = opaque_mask(Image.open(path))
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    wisp = (b > r + 30) & (b > 200)  # fox-fire wisps on the old reference
    m = m & ~wisp
    navy = m & (b > r + 25) & (b > g + 5) & (b < 140)
    ys, xs = np.nonzero(m)
    nys, nxs = np.nonzero(navy)
    top, sole = ys.min(), ys.max()
    coat_top, coat_bot = nys.min(), np.percentile(nys, 99)
    coat_l, coat_r = np.percentile(nxs, 1), np.percentile(nxs, 99)
    head_h = coat_top - top
    behind = m.copy()
    behind[:, int(coat_l):] = False
    behind[: coat_top, :] = False
    tys, txs = np.nonzero(behind)
    tail_area = behind.sum()
    return {
        "file": path.split("/")[-1],
        "H": sole - top,
        "head": head_h,
        "coat_h/head": (coat_bot - coat_top) / head_h,
        "coat_w/head": (coat_r - coat_l) / head_h,
        "leg/head": (sole - coat_bot) / head_h,
        "tail_w/head": (txs.max() - txs.min()) / head_h if tail_area else 0,
        "tail_area/head2": tail_area / head_h**2,
    }


KEYS = ["coat_h/head", "coat_w/head", "leg/head", "tail_w/head", "tail_area/head2"]


def report(rows, ref=None, standing=False):
    """Flag drift. Within a strip the head (ears included) and tail must keep their size;
    the reference check uses the tail always and the body ratios only for standing poses."""
    print(f"{'file':22}{'H':>6}{'head':>6}" + "".join(f"{k:>16}" for k in KEYS))
    for row in rows:
        print(f"{row['file']:22}{row['H']:6.0f}{row['head']:6.0f}" + "".join(f"{row[k]:16.2f}" for k in KEYS))
    bad = []
    hmed = float(np.median([row["head"] for row in rows]))
    tmed = float(np.median([row["tail_area/head2"] for row in rows]))
    for row in rows:
        dev = row["head"] / hmed - 1
        if abs(dev) > 0.08:
            bad.append(f"{row['file']}: head {dev:+.0%} vs strip median (scale drift)")
        dev = row["tail_area/head2"] / tmed - 1 if tmed else 0
        if abs(dev) > 0.15:
            bad.append(f"{row['file']}: tail size {dev:+.0%} vs strip median")
    if ref:
        checks = ["tail_area/head2"] + (["coat_h/head", "coat_w/head", "leg/head"] if standing else [])
        for k in checks:
            med = float(np.median([row[k] for row in rows]))
            dev = med / ref[k] - 1
            if abs(dev) > (0.20 if k.startswith("tail") else 0.12):
                bad.append(f"strip {k} {dev:+.0%} vs reference")
    return bad


if __name__ == "__main__":
    args = sys.argv[1:]
    ref = None
    standing = "--standing" in args
    args = [x for x in args if x != "--standing"]
    if args and args[0] == "--ref":
        ref = measure(args[1])
        print("reference:", {k: round(float(v), 2) if not isinstance(v, str) else v for k, v in ref.items()})
        args = args[2:]
    problems = report([measure(p) for p in args], ref, standing)
    print("\n".join(problems) if problems else "OK: no drift over tolerance")
    sys.exit(1 if problems else 0)
