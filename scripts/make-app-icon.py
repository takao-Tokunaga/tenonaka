#!/usr/bin/env python3
"""アプリアイコンを生成する。

紙の地に朱色の手を置き、その手のひらの中に脈の線を通す。
アプリの名前(手のなか)と機構(生きた手・脈)をそのまま絵にしたもの。

脈は鋭い一拍だけに絞っている。T波まで入れると手のひらの中で潰れて読めない。

  python3 scripts/make-app-icon.py

出力: ios/Tenonaka/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024x1024)
"""

from __future__ import annotations

import math
import pathlib
import random

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT = (
    pathlib.Path(__file__).resolve().parent.parent
    / "ios/Tenonaka/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
)

# アプリ内の配色と揃える (Theme/PaperTheme.swift)
PAPER = (243, 236, 221)
PAPER_DARK = (237, 229, 212)
SHADE = (200, 186, 163)
INK = (43, 37, 32)
SEAL = (140, 55, 52)
SEAL_DEEP = (117, 43, 41)


def paper_ground(image: Image.Image) -> None:
    """生成りの紙。わずかに斜めの陰をつける"""
    draw = ImageDraw.Draw(image)
    for y in range(SIZE):
        # 上が明るく下が沈む
        t = y / SIZE
        color = tuple(
            round(PAPER[i] + (PAPER_DARK[i] - PAPER[i]) * t) for i in range(3)
        )
        draw.line([(0, y), (SIZE, y)], fill=color)


def paper_grain(image: Image.Image) -> None:
    """紙の粒子。単色だと画面に見えるので荒れを入れる"""
    rng = random.Random(0x5EED)
    grain = Image.new("L", (SIZE // 2, SIZE // 2))
    grain.putdata([rng.randint(112, 143) for _ in range(grain.width * grain.height)])
    grain = grain.resize((SIZE, SIZE), Image.BILINEAR).filter(
        ImageFilter.GaussianBlur(0.4)
    )
    noise = Image.new("RGB", (SIZE, SIZE), (128, 128, 128))
    noise.putalpha(grain.point(lambda v: abs(v - 128) * 2))
    image.paste(
        Image.blend(image, Image.composite(noise.convert("RGB"), image, grain), 0.10)
    )


def pulse_path(cx: float, cy: float, half_width: float, scale: float):
    """脈波の形。
    立ち上がりの鋭さが心拍らしさを決めるので、頂点を明示した折れ線で作る。
    手のひらに収めるので、余分な波は入れず一拍だけにする。
    """
    corners = [
        (0.00, 0.00),
        (0.34, 0.00),
        (0.40, -0.18),  # 立ち上がる前の小さな落ち込み
        (0.50, 1.00),  # 鋭い頂点
        (0.60, -0.34),  # 深い谷
        (0.67, 0.00),
        (1.00, 0.00),
    ]

    def to_xy(t: float, h: float) -> tuple[float, float]:
        return (cx - half_width + half_width * 2 * t, cy - h * scale)

    points: list[tuple[float, float]] = []
    for index in range(len(corners) - 1):
        t0, h0 = corners[index]
        t1, h1 = corners[index + 1]
        steps = 40
        for step in range(steps):
            k = step / steps
            points.append(to_xy(t0 + (t1 - t0) * k, h0 + (h1 - h0) * k))
    points.append(to_xy(*corners[-1]))
    return points


def stroke(
    draw: ImageDraw.ImageDraw, points, width: float, color, smooth: bool = False
) -> None:
    """円を密に並べて線を引く。
    折れ線をそのまま描くと角の継ぎ目が段になって出るので、
    等幅・丸端の線を確実に得るためにこうしている。

    smooth は輪郭に段を出したくない太い線に使う(間隔を詰める)。
    """
    radius = width / 2
    step = max(radius * (0.06 if smooth else 0.35), 1.0)

    def dot(x: float, y: float) -> None:
        draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=color)

    previous = points[0]
    dot(*previous)
    for current in points[1:]:
        dx, dy = current[0] - previous[0], current[1] - previous[1]
        distance = math.hypot(dx, dy)
        count = max(int(distance / step), 1)
        for i in range(1, count + 1):
            dot(previous[0] + dx * i / count, previous[1] + dy * i / count)
        previous = current


def hand_mask(scale: float) -> Image.Image:
    """手のひらを正面から見た形。
    実物に似せるより、小さいサイズで手だと分かる輪郭を優先している。
    指と親指は太い線(丸端)として引き、手のひらと合成する。
    """
    canvas = round(SIZE * scale)
    mask = Image.new("L", (canvas, canvas), 0)
    draw = ImageDraw.Draw(mask)

    def px(value: float) -> float:
        return value * canvas

    # 手のひら
    draw.rounded_rectangle(
        [px(0.275), px(0.455), px(0.725), px(0.830)],
        radius=px(0.105),
        fill=255,
    )

    # 指4本。長さを少しずつ変えて手に見せる。
    # まっすぐなので角丸矩形で描く(円を並べると輪郭に段が出る)
    finger_half = px(0.049)
    finger_bottom = px(0.620)
    for center, top in (
        (0.329, 0.290),  # 人差し指
        (0.443, 0.243),  # 中指
        (0.557, 0.272),  # 薬指
        (0.671, 0.352),  # 小指
    ):
        draw.rounded_rectangle(
            [px(center) - finger_half, px(top), px(center) + finger_half, finger_bottom],
            radius=finger_half,
            fill=255,
        )

    # 親指。手のひらの左下から斜めに出すので、こちらは線で引く
    stroke(
        draw,
        [(px(0.325), px(0.735)), (px(0.185), px(0.560))],
        px(0.108),
        255,
        smooth=True,
    )

    return mask


# 手を傾ける角度。正面を向いていると「止まれ」の記号に見えるので少し崩す
TILT_DEGREES = 14.0
# 傾けると重心が動くので、画面の中央に戻す量(canvas 比)
TILT_OFFSET = (0.028, -0.030)


def draw_hand(image: Image.Image) -> None:
    """朱色の手を置き、手のひらの中に脈を抜く"""
    # 拡大して描いてから縮小し、輪郭を滑らかにする
    factor = 4
    mask = hand_mask(factor)
    canvas = mask.size[0]

    hand = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    hand.paste(Image.new("RGB", (canvas, canvas), SEAL), (0, 0), mask)
    hand.putalpha(mask)

    # 脈の線。手のひらの中に紙の色で抜く
    draw = ImageDraw.Draw(hand)
    palm_cx = canvas * 0.500
    palm_cy = canvas * 0.722
    points = pulse_path(palm_cx, palm_cy, canvas * 0.152, canvas * 0.082)
    stroke(draw, points, canvas * 0.032, PAPER + (255,), smooth=True)

    # 脈ごと傾ける。手のひらの中の線も一緒に回るので、関係が崩れない。
    # 回すと重心がずれて角に寄るので、同時に平行移動で戻す
    shift = (canvas * TILT_OFFSET[0], canvas * TILT_OFFSET[1])
    hand = hand.rotate(
        TILT_DEGREES,
        resample=Image.BICUBIC,
        center=(palm_cx, palm_cy),
        translate=shift,
    )
    mask = mask.rotate(
        TILT_DEGREES,
        resample=Image.BICUBIC,
        center=(palm_cx, palm_cy),
        translate=shift,
    )

    small = hand.resize((SIZE, SIZE), Image.LANCZOS)

    # 紙に落ちる影
    shadow_mask = mask.resize((SIZE, SIZE), Image.LANCZOS)
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow.paste(Image.new("RGB", (SIZE, SIZE), SHADE), (0, 0), shadow_mask)
    shadow.putalpha(shadow_mask.point(lambda v: v * 100 // 255))
    shadow = shadow.filter(ImageFilter.GaussianBlur(SIZE * 0.016))

    image.paste(shadow, (0, round(SIZE * 0.012)), shadow)
    image.paste(small, (0, 0), small)


def main() -> None:
    image = Image.new("RGB", (SIZE, SIZE), PAPER)
    paper_ground(image)
    paper_grain(image)
    draw_hand(image)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    # iOS のアイコンは透過も角丸も持たせない(システムが丸める)
    image.convert("RGB").save(OUT, "PNG")
    print(f"書き出しました: {OUT} ({SIZE}x{SIZE})")


if __name__ == "__main__":
    main()
