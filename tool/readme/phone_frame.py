"""Composite README demo screenshots into an Android phone frame.

Usage: python tool/readme/phone_frame.py OUT_DIR SHOT1 [SHOT2 ...]
Writes OUT_DIR/demo-1.png, demo-2.png, ... in argument order.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SS = 4  # supersampling factor for anti-aliased shapes
BODY = (20, 20, 22, 255)
RIM = (58, 58, 62, 255)
BUTTON = (40, 40, 44, 255)


def frame(shot: Image.Image) -> Image.Image:
    shot = shot.convert("RGB")
    w, h = shot.size
    bezel = round(w * 0.035)
    screen_r = round(w * 0.07)
    body_r = screen_r + bezel
    btn_w = max(3, round(w * 0.008))
    rim = max(2, round(w * 0.004))
    bw, bh = w + 2 * bezel, h + 2 * bezel
    cw = bw + btn_w  # buttons stick out on the right

    s = lambda v: v * SS  # noqa: E731
    big = Image.new("RGBA", (s(cw), s(bh)), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    # Side buttons: volume rocker and power key on the right edge.
    for top, length in ((0.20, 0.11), (0.35, 0.06)):
        y = round(bh * top)
        d.rounded_rectangle(
            (s(bw - btn_w), s(y), s(cw) - 1, s(y + round(bh * length))),
            radius=s(btn_w), fill=BUTTON)
    d.rounded_rectangle((0, 0, s(bw) - 1, s(bh) - 1), radius=s(body_r), fill=RIM)
    d.rounded_rectangle((s(rim), s(rim), s(bw - rim) - 1, s(bh - rim) - 1),
                        radius=s(body_r - rim), fill=BODY)
    out = big.resize((cw, bh), Image.LANCZOS)

    # Screen at native resolution, clipped to rounded corners.
    mask = Image.new("L", (s(w), s(h)), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, s(w) - 1, s(h) - 1),
                                           radius=s(screen_r), fill=255)
    out.paste(shot, (bezel, bezel), mask.resize((w, h), Image.LANCZOS))

    # Punch-hole camera centred in the status bar.
    cam = round(w * 0.032)
    cx, cy = bezel + w / 2, bezel + round(h * 0.024)
    hole = Image.new("RGBA", (s(cam), s(cam)), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hole)
    hd.ellipse((0, 0, s(cam) - 1, s(cam) - 1), fill=(5, 5, 6, 255))
    lens = s(cam) * 0.3
    hd.ellipse((s(cam) / 2 - lens, s(cam) / 2 - lens,
                s(cam) / 2 + lens * 0.2, s(cam) / 2 + lens * 0.2), fill=(28, 32, 44, 255))
    hole = hole.resize((cam, cam), Image.LANCZOS)
    out.alpha_composite(hole, (round(cx - cam / 2), round(cy - cam / 2)))
    return out


def main() -> None:
    out_dir = Path(sys.argv[1])
    out_dir.mkdir(parents=True, exist_ok=True)
    for i, src in enumerate(sys.argv[2:], 1):
        shot = Image.open(src).convert("RGB")
        framed = frame(shot)
        # Screen must keep native pixels: centre pixel unchanged, 1:1 placement.
        w, h = shot.size
        b = round(w * 0.035)
        assert framed.getpixel((b + w // 2, b + h // 2))[:3] == shot.getpixel((w // 2, h // 2))
        framed.save(out_dir / f"demo-{i}.png", optimize=True)


if __name__ == "__main__":
    main()
