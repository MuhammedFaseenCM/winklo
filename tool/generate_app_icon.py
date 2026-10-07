#!/usr/bin/env python3
"""Render the Winklo "W" path mark as crisp launcher / splash / store icons.

The mark is described with signed distance fields (SDFs) in a 1024-unit
design space, so it renders sharp at any size. Outputs:

  assets/branding/app_icon_adaptive.png   1024, full-bleed (adaptive fg)
  assets/branding/app_icon.png            1024, rounded tile (legacy + ZipMark)
  assets/branding/splash_logo.png          512, rounded tile
  fastlane/.../images/icon.png             512, rounded tile (Play listing)

After running, regenerate the Android resources:
  dart run flutter_launcher_icons && dart run flutter_native_splash:create
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
RENDER = 2048  # master resolution; downsampled for every output
S = RENDER / 1024  # pixels per design unit

INK = np.array([15, 23, 42], np.float32)  # ZipColors.ink / #0F172A
TILE_RADIUS = 230  # rounded-tile corner radius (design units)

# Body gradient stops (design-space y -> RGB), sampled from the old icon.
GRADIENT = [
    (290, (252, 114, 24)),
    (500, (250, 104, 52)),
    (740, (253, 84, 96)),
]

# Path nodes (design units). Symmetric about x = 512.
TL, TM, TR = (278, 338), (512, 338), (746, 338)
LM, C, RM = (313, 512), (512, 504), (711, 512)
BL, BR = (394, 690), (630, 690)
ARM = 34  # half stroke width


def grid() -> tuple[np.ndarray, np.ndarray]:
    t = (np.arange(RENDER, dtype=np.float32) + 0.5) / S
    return np.meshgrid(t, t)


X, Y = grid()


def circle(c, r):
    return np.hypot(X - c[0], Y - c[1]) - r


def capsule(a, b, r):
    ax, ay = a
    bx, by = b
    px, py = X - ax, Y - ay
    dx, dy = bx - ax, by - ay
    h = np.clip((px * dx + py * dy) / (dx * dx + dy * dy), 0, 1)
    return np.hypot(px - dx * h, py - dy * h) - r


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b + (a - b) * h - k * h * (1 - h)


def union(fields, k):
    out = fields[0]
    for f in fields[1:]:
        out = smin(out, f, k)
    return out


def coverage(d):
    """Analytic anti-aliasing: d is in design units."""
    return np.clip(0.5 - d * S, 0, 1)


def normals(d):
    gy, gx = np.gradient(d)
    n = np.hypot(gx, gy) + 1e-6
    return gx / n, gy / n


def puzzle_piece(node, r, knob=None, knob_r=17):
    """Node disc, optionally with a jigsaw knob attached by a short neck."""
    d = circle(node, r)
    if knob is not None:
        neck = capsule(node, knob, 8)
        d = union([d, neck, circle(knob, knob_r)], 5)
    return d


def body_sdf():
    parts = [
        capsule(TL, BL, ARM),
        capsule(BL, C, ARM),
        capsule(C, BR, ARM),
        capsule(BR, TR, ARM),
        capsule(C, TM, 28),  # pinched neck under the top node
        circle(TL, 50),
        circle(TR, 50),
        circle(TM, 52),
        circle(LM, 52),
        circle(RM, 52),
        circle(C, 60),
        capsule((512, 448), (462, 508), 36),  # neck flares into round shoulders
        capsule((512, 448), (562, 508), 36),
        circle(BL, 53),
        circle(BR, 53),
    ]
    return union(parts, 16)


def pieces_sdf():
    pieces = [
        puzzle_piece(TM, 52, knob=(512, 416)),
        puzzle_piece(LM, 52, knob=(346, 578)),
        puzzle_piece(RM, 52, knob=(678, 578)),
        puzzle_piece(BL, 53, knob=(431, 619), knob_r=16),
        puzzle_piece(C, 52),
        puzzle_piece(BR, 53),
    ]
    return np.minimum.reduce(pieces)


def base_color():
    ys = [g[0] for g in GRADIENT]
    rgb = np.stack(
        [np.interp(Y, ys, [g[1][i] for g in GRADIENT]) for i in range(3)],
        axis=-1,
    ).astype(np.float32)
    # Burnt outer tips on the top-left / top-right caps, as in the original.
    dist = np.hypot(X - 512, Y - 540)
    tip = np.clip((dist - 240) / 120, 0, 1)[..., None]
    rgb *= 1 - tip * np.array([0.14, 0.38, 0.45], np.float32)
    return rgb


def shade(rgb, body, pieces):
    up = (0.0, -1.0)  # light comes from above

    # Pillowy bevel on the whole path.
    nx, ny = normals(body)
    rim = np.clip(1 + body / 16, 0, 1) ** 1.5
    rgb *= (1 + 0.38 * rim * (nx * up[0] + ny * up[1]))[..., None]

    # Slight dome on each puzzle piece.
    px, py = normals(pieces)
    dome = np.clip(1 + pieces / 10, 0, 1) ** 1.3 * (pieces < 0)
    rgb *= (1 + 0.28 * dome * (px * up[0] + py * up[1]))[..., None]

    # Engraved groove + light lip just outside it (catches the top light).
    groove = np.clip(1 - (np.abs(pieces + 0.6) - 1.9) * S, 0, 1)
    rgb *= (1 - 0.50 * groove)[..., None]
    lip = np.clip(1 - np.abs(pieces - 3.4) * S / 1.2, 0, 1) * np.clip(-py, 0, 1)
    rgb += (lip * 26)[..., None]
    return np.clip(rgb, 0, 255)


def background():
    rgb = np.broadcast_to(INK, (RENDER, RENDER, 3)).copy()
    glow = np.clip(1 - np.hypot(X - 512, Y - 500) / 430, 0, 1) ** 2
    rgb += glow[..., None] * np.array([5, 5, 7], np.float32)
    return rgb


def drop_shadow(alpha):
    img = Image.fromarray((alpha * 255).astype(np.uint8))
    img = img.filter(ImageFilter.GaussianBlur(16 * S))
    a = np.asarray(img, np.float32) / 255
    shift = int(14 * S)
    a = np.roll(a, shift, axis=0)
    a[:shift] = 0
    return a * 0.55


def tile_mask(radius):
    qx = np.clip(np.abs(X - 512) - (512 - radius), 0, None)
    qy = np.clip(np.abs(Y - 512) - (512 - radius), 0, None)
    return coverage(np.hypot(qx, qy) - radius)


def render() -> tuple[np.ndarray, np.ndarray]:
    body = body_sdf()
    pieces = pieces_sdf()
    alpha = coverage(body)

    rgb = background()
    rgb *= (1 - drop_shadow(alpha))[..., None]
    mark = shade(base_color(), body, pieces)
    rgb = rgb * (1 - alpha[..., None]) + mark * alpha[..., None]
    return rgb, tile_mask(TILE_RADIUS)


def save(rgb, alpha, size, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if alpha is None:
        img = Image.fromarray(rgb.round().astype(np.uint8))
    else:
        rgba = np.dstack([rgb, alpha * 255]).round().astype(np.uint8)
        img = Image.fromarray(rgba)
    img.resize((size, size), Image.LANCZOS).save(path, optimize=True)
    print(f"wrote {path.relative_to(ROOT) if path.is_relative_to(ROOT) else path}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, help="write to this dir instead of the repo")
    args = parser.parse_args()

    rgb, tile = render()
    targets = {
        "assets/branding/app_icon_adaptive.png": (1024, False),
        "assets/branding/app_icon.png": (1024, True),
        "assets/branding/splash_logo.png": (512, True),
        "fastlane/metadata/android/en-US/images/icon.png": (512, True),
    }
    for rel, (size, rounded) in targets.items():
        dest = (args.out / Path(rel).name) if args.out else ROOT / rel
        if args.out and "fastlane" in rel:
            dest = args.out / "play_icon.png"
        save(rgb, tile if rounded else None, size, dest)


if __name__ == "__main__":
    main()
