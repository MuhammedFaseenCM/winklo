#!/usr/bin/env python3
"""Generate Winklo preset avatar mascot-blob PNGs (512x512)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 512
OUT_DIR = Path(__file__).resolve().parents[1] / "tools" / "static-assets" / "avatars"

SLATE = (30, 41, 59, 255)  # ZipColors.wall-ish
INK = (15, 23, 42, 255)  # ZipColors.ink

PRESETS = [
    ("preset_01", (255, 107, 44), "smile"),  # ember
    ("preset_02", (56, 189, 248), "wink"),  # sky
    ("preset_03", (167, 139, 250), "shy"),  # lavender
    ("preset_04", (45, 212, 191), "cheeky"),  # mint
    ("preset_05", (251, 191, 36), "sleepy"),  # gold
    ("preset_06", (251, 113, 133), "surprise"),  # rose
]


def disc(
    draw: ImageDraw.ImageDraw,
    cx: int,
    cy: int,
    r: int,
    fill: tuple[int, int, int, int],
) -> None:
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)


def eye(draw: ImageDraw.ImageDraw, x: int, y: int, r: int = 18) -> None:
    disc(draw, x, y, r, INK)


def closed_eye(draw: ImageDraw.ImageDraw, x: int, y: int, w: int = 36) -> None:
    draw.rounded_rectangle((x - w // 2, y - 4, x + w // 2, y + 4), radius=4, fill=INK)


def smile_mouth(draw: ImageDraw.ImageDraw, cx: int, cy: int) -> None:
    box = (cx - 55, cy - 20, cx + 55, cy + 55)
    draw.arc(box, start=20, end=160, fill=INK, width=10)


def shy_mouth(draw: ImageDraw.ImageDraw, cx: int, cy: int) -> None:
    # Small soft smile (shy, not sad)
    box = (cx - 35, cy - 10, cx + 35, cy + 40)
    draw.arc(box, start=30, end=150, fill=INK, width=8)


def flat_mouth(draw: ImageDraw.ImageDraw, cx: int, cy: int) -> None:
    draw.rounded_rectangle((cx - 40, cy - 5, cx + 40, cy + 5), radius=4, fill=INK)


def draw_face(
    draw: ImageDraw.ImageDraw,
    kind: str,
    cx: int,
    cy: int,
    blob_r: int,
    fill: tuple[int, int, int, int],
) -> None:
    eye_y = cy - int(blob_r * 0.12)
    left_x = cx - int(blob_r * 0.28)
    right_x = cx + int(blob_r * 0.28)
    mouth_y = cy + int(blob_r * 0.28)

    if kind == "smile":
        eye(draw, left_x, eye_y)
        eye(draw, right_x, eye_y)
        smile_mouth(draw, cx, mouth_y)
    elif kind == "wink":
        eye(draw, left_x, eye_y)
        closed_eye(draw, right_x, eye_y)
        flat_mouth(draw, cx, mouth_y)
    elif kind == "shy":
        eye(draw, left_x, eye_y, r=14)
        eye(draw, right_x, eye_y, r=14)
        shy_mouth(draw, cx, mouth_y)
    elif kind == "cheeky":
        eye(draw, left_x, eye_y)
        eye(draw, right_x, eye_y)
        smile_mouth(draw, cx, mouth_y + 5)
    elif kind == "sleepy":
        closed_eye(draw, left_x, eye_y)
        closed_eye(draw, right_x, eye_y)
        smile_mouth(draw, cx, mouth_y)
    elif kind == "surprise":
        eye(draw, left_x, eye_y, r=20)
        eye(draw, right_x, eye_y, r=20)
        disc(draw, cx, mouth_y, 26, INK)
        disc(draw, cx, mouth_y, 12, fill)
    else:
        raise ValueError(kind)


def render(_preset_id: str, rgb: tuple[int, int, int], kind: str) -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), SLATE)
    draw = ImageDraw.Draw(img)
    cx = cy = SIZE // 2
    fill = (*rgb, 255)
    blob_r = 170
    body_cy = cy + 8

    # Mint cheeky: ears peek from behind the body
    if kind == "cheeky":
        disc(draw, cx - 120, cy - 130, 48, fill)
        disc(draw, cx + 120, cy - 130, 48, fill)

    if kind in ("shy", "sleepy"):
        draw.ellipse(
            (
                cx - blob_r - 10,
                body_cy - blob_r + 25,
                cx + blob_r + 10,
                body_cy + blob_r - 10,
            ),
            fill=fill,
        )
    elif kind == "wink":
        draw.ellipse(
            (
                cx - blob_r + 5,
                body_cy - blob_r + 5,
                cx + blob_r - 5,
                body_cy + blob_r - 5,
            ),
            fill=fill,
        )
    else:
        disc(draw, cx, body_cy, blob_r, fill)

    draw_face(draw, kind, cx, body_cy, blob_r, fill)
    return img.convert("RGB")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for preset_id, rgb, kind in PRESETS:
        path = OUT_DIR / f"{preset_id}.png"
        render(preset_id, rgb, kind).save(path, format="PNG", optimize=True)
        print(f"wrote {path} ({path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
