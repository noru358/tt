"""Draw pose-guide mannequins with the locked proportions of hero_side_final.png.

Codex gets these strips together with the final design so every frame of an animation
starts from the same skeleton: same head size, limb lengths, tail size and ground line.
Near limbs are light, far limbs dark, so leg alternation is unambiguous.

Usage: python3 tools/hero_art/mannequin.py [out_dir]
Writes <motion>_pose.png strips (512px square cells, white background, no text) and
proportion_sheet.png (reference beside the mannequin with landmark lines, for review only).
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

CELL = 512
H = 340  # crown (ear tip) to sole, as in HERO_FRAMES_PLAN
GROUND = 440
GAP = 96

# Landmarks measured on assets/hero/raw/hero_side_final.png, in units of total height,
# x relative to the coat centre (positive = facing direction), y down from the ear tip.
P = {
    "skull_c": (0.057, 0.32), "skull_r": 0.125,
    "nose": (0.23, 0.37), "chin": (0.095, 0.41),
    "ear_tip": (-0.08, 0.008), "ear_front": (0.05, 0.23), "ear_back": (-0.057, 0.34),
    "far_ear_tip": (-0.01, 0.0), "ear_bulge_back": (-0.15, 0.2), "ear_bulge_front": (0.05, 0.14),
    "collar": 0.43, "shoulder": (-0.027, 0.51), "far_shoulder": (0.02, 0.50), "upper_arm": 0.11, "forearm": 0.105,
    "waist": 0.55, "coat_bottom": 0.80, "chest_w": 0.17, "hem_w": 0.24,
    "hip": (0.0, 0.70), "thigh": 0.15, "shin": 0.12, "foot": 0.14,
    "tail_root": (-0.08, 0.66), "tail_c": (-0.217, 0.74), "tail_r": (0.135, 0.19),
    "fan": 0.2,
}

NEAR, FAR, BODY, HEAD, TAIL = (226, 220, 210), (110, 114, 124), (160, 164, 176), (205, 200, 190), (185, 180, 172)
LINE = (30, 30, 34)
EAR_IN = (238, 214, 206)
FAN = (40, 40, 44)


def rot(v, deg):
    a = math.radians(deg)
    return (v[0] * math.cos(a) - v[1] * math.sin(a), v[0] * math.sin(a) + v[1] * math.cos(a))


def limb_points(root, a1, l1, a2, l2):
    """Angles in degrees from straight down, positive swings forward (to the right)."""
    j = (root[0] + math.sin(math.radians(a1)) * l1, root[1] + math.cos(math.radians(a1)) * l1)
    e = (j[0] + math.sin(math.radians(a2)) * l2, j[1] + math.cos(math.radians(a2)) * l2)
    return j, e


def capsule(d, pts, w, fill):
    for width, col in ((w + 6, LINE), (w, fill)):
        d.line(pts, fill=col, width=int(width), joint="curve")
        for p in pts:
            r = width / 2
            d.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=col)


def silhouette(im, draw, fill, line=5):
    """Fill the union of the shapes drawn by draw(ImageDraw on a mask) with one outer outline."""
    from PIL import ImageFilter
    mask = Image.new("L", im.size, 0)
    draw(ImageDraw.Draw(mask))
    edge = mask.filter(ImageFilter.MaxFilter(2 * line + 1))
    im.paste(LINE, (0, 0), edge)
    im.paste(fill, (0, 0), mask)


def poly(d, pts, fill):
    d.polygon(pts, fill=fill, outline=LINE, width=4)


def draw_pose(pose):
    """pose: lean (deg, + = forward), bob (units of H, + = up), legs/arms per side, tail swing."""
    im = Image.new("RGB", (CELL, CELL), (255, 255, 255))
    d = ImageDraw.Draw(im)
    cx = CELL / 2
    lean, bob = pose.get("lean", 0), pose.get("bob", 0)

    def leg(side):
        th, sh = pose[side + "_leg"]
        hip = (P["hip"][0] * H, P["hip"][1] * H)
        k, a = limb_points(hip, th, P["thigh"] * H, sh, P["shin"] * H)
        toe_angle = sh + 90 + pose.get(side + "_foot", 0)
        t = (a[0] + math.sin(math.radians(toe_angle)) * P["foot"] * H * 0.8,
             a[1] + math.cos(math.radians(toe_angle)) * P["foot"] * H * 0.8)
        return hip, k, a, t

    legs = {s: leg(s) for s in ("far", "near")}
    lowest = max(max(p[1] for p in legs[s]) for s in legs) + 12
    oy = GROUND - lowest - bob * H

    def T(p, upper=False):
        x, y = p
        if upper:  # upper body leans around the hip
            hx, hy = P["hip"][0] * H, P["hip"][1] * H
            x, y = rot((x - hx, y - hy), lean)
            x, y = x + hx, y + hy
        return (cx + x, oy + y)

    def U(key):
        x, y = P[key]
        return T((x * H, y * H), upper=True)

    def arm(side):
        sa, ea = pose[side + "_arm"]
        key = "far_shoulder" if side == "far" else "shoulder"
        s = (P[key][0] * H, P[key][1] * H)
        e, w = limb_points(s, sa, P["upper_arm"] * H, sa + ea, P["forearm"] * H)
        return [T(s, True), T(e, True), T(w, True)], sa + ea

    # far arm and far leg
    pts, _ = arm("far")
    capsule(d, pts, 0.055 * H, FAR)
    capsule(d, [T(p) for p in legs["far"]], 0.07 * H, FAR)

    # tail, rotated around its root by tail swing
    tr = (P["tail_root"][0] * H, P["tail_root"][1] * H)
    tc = rot(((P["tail_c"][0] - P["tail_root"][0]) * H, (P["tail_c"][1] - P["tail_root"][1]) * H), pose.get("tail", 0))
    c = T((tr[0] + tc[0], tr[1] + tc[1]), True)
    rx, ry = P["tail_r"][0] * H, P["tail_r"][1] * H
    tail = Image.new("RGBA", (CELL, CELL))
    td = ImageDraw.Draw(tail)
    td.ellipse((c[0] - rx, c[1] - ry, c[0] + rx, c[1] + ry), fill=TAIL + (255,), outline=LINE, width=4)
    tail = tail.rotate(-(pose.get("tail", 0) + lean) * 0.6 - 25, center=c, resample=Image.BICUBIC)
    im.paste(tail, (0, 0), tail)
    d = ImageDraw.Draw(im)

    # near leg
    capsule(d, [T(p) for p in legs["near"]], 0.075 * H, NEAR)

    # coat: chest to hem, flared skirt
    cw, hw = P["chest_w"] * H / 2, P["hem_w"] * H / 2
    col, wa, hem = P["collar"] * H, P["waist"] * H, P["coat_bottom"] * H
    coat = [(-cw, col), (cw, col), (cw * 1.05, wa), (hw, hem), (-hw, hem), (-cw * 1.1, wa)]
    poly(d, [T(p, True) for p in coat], BODY)
    d.line([T((-cw * 1.1, wa), True), T((cw * 1.05, wa), True)], fill=LINE, width=8)  # sash line

    # Head, snout and near ear are one silhouette so no inner outline reads as an extra ear.
    # The far ear is the same leaf, smaller, a little forward and dark, behind the head.
    sc, sr = U("skull_c"), P["skull_r"] * H

    def ear_pt(key, shift=(0.0, 0.0), scale=1.0):  # ears tilt back around their base by pose["ear"]
        b = P["ear_back"]
        v = rot((P[key][0] - b[0], P[key][1] - b[1]), -pose.get("ear", 0))
        return T(((b[0] + v[0] * scale + shift[0]) * H, (b[1] + v[1] * scale + shift[1]) * H), True)

    leaf = ["ear_front", "ear_bulge_front", "ear_tip", "ear_bulge_back", "ear_back"]
    far = [ear_pt(k, (0.09, 0.0), 0.9) for k in leaf]
    silhouette(im, lambda m: m.polygon(far, fill=255), FAR)

    def head(m):
        m.ellipse((sc[0] - sr * 1.1, sc[1] - sr, sc[0] + sr * 1.1, sc[1] + sr), fill=255)
        m.polygon([(sc[0], sc[1] - sr * 0.55), U("nose"), U("chin"), (sc[0], sc[1] + sr * 0.8)], fill=255)
        m.polygon([ear_pt(k) for k in leaf], fill=255)

    silhouette(im, head, HEAD)
    d = ImageDraw.Draw(im)
    d.polygon([ear_pt("ear_front", scale=1.0)] + [ear_pt(k, (0.0, 0.03), 0.75) for k in ("ear_bulge_front", "ear_tip", "ear_bulge_back")], fill=EAR_IN)
    n = U("nose")
    d.ellipse((n[0] - 7, n[1] - 6, n[0] + 5, n[1] + 6), fill=LINE)
    d.ellipse((sc[0] + sr * 0.35, sc[1] - 8, sc[0] + sr * 0.55, sc[1] + 8), fill=LINE)

    # near arm with closed fan
    pts, _ = arm("near")
    capsule(d, pts, 0.06 * H, NEAR)
    fa = pose.get("fan", 0)  # absolute angle from straight down; negative points backward
    w = pts[-1]
    fe = (w[0] + math.sin(math.radians(fa)) * P["fan"] * H, w[1] + math.cos(math.radians(fa)) * P["fan"] * H)
    d.line([w, fe], fill=FAN, width=12)
    return im


def strip(poses):
    out = Image.new("RGB", (len(poses) * CELL + (len(poses) - 1) * GAP, CELL), (255, 255, 255))
    for i, p in enumerate(poses):
        out.paste(draw_pose(p), (i * (CELL + GAP), 0))
    return out


IDLE = dict(lean=0, near_leg=(8, 0), far_leg=(-8, 0), near_arm=(-8, 25), far_arm=(-12, 30), fan=-5, tail=0)

# Run: contact, passing, flight, then the same with legs swapped. Arms swing against the legs.
RUN_STEP = [
    dict(near_leg=(32, 15), far_leg=(-28, -70), near_arm=(-55, 35), far_arm=(30, 60), tail=10, ear=12, bob=0.0),
    dict(near_leg=(0, -10), far_leg=(35, -40), near_arm=(0, 60), far_arm=(-5, 55), tail=0, ear=14, bob=0.02),
    dict(near_leg=(-38, -55), far_leg=(45, 5), near_arm=(35, 60), far_arm=(-55, 35), tail=-10, ear=16, bob=0.05),
]


def swap(p):
    q = dict(p)
    q["near_leg"], q["far_leg"] = p["far_leg"], p["near_leg"]
    q["near_arm"], q["far_arm"] = p["far_arm"], p["near_arm"]
    return q


RUN = [dict(lean=10, fan=-70, **p) for p in RUN_STEP] + [dict(lean=10, fan=-70, **swap(p)) for p in RUN_STEP]

MOTIONS = {"idle": [IDLE] * 4, "run": RUN}

def proportion_sheet(ref_path, out_path):
    """Reference and idle mannequin side by side at the same height, with landmark lines."""
    ref = Image.open(ref_path).convert("RGB")
    top, sole = 30, 1340  # ear tip and sole rows on hero_side_final.png
    k = H / (sole - top)
    ref = ref.resize((round(ref.width * k), round(ref.height * k)), Image.LANCZOS)
    sheet = Image.new("RGB", (ref.width + CELL, CELL), (255, 255, 255))
    sheet.paste(ref, (0, GROUND - round(sole * k)))
    sheet.paste(draw_pose(IDLE), (ref.width, 0))
    d = ImageDraw.Draw(sheet)
    top_y = GROUND - H
    for frac in (0.0, P["collar"], P["waist"], P["coat_bottom"], 1.0):
        y = top_y + frac * H
        d.line([(0, y), (sheet.width, y)], fill=(220, 40, 40), width=2)
    sheet.save(out_path)


if __name__ == "__main__":
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/plan/hero_refs/poses")
    out.mkdir(parents=True, exist_ok=True)
    for name, poses in MOTIONS.items():
        strip(poses).save(out / f"{name}_pose.png")
        print(out / f"{name}_pose.png")
    proportion_sheet("assets/hero/raw/hero_side_final.png", out / "proportion_sheet.png")
    print(out / "proportion_sheet.png")
