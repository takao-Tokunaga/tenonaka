#!/usr/bin/env python3
"""アプリアイコンを生成する。

紙の地に、栓のされた瓶を一本立て、その中に巻かれた手紙を沈める。
宛先の無いまま流された手紙、というこのアプリの姿をそのまま絵にしたもの。

瓶の輪郭はアプリ内(Views/Bottle.swift の BottleShape)と同じ比率で描く。
アイコンと画面の中の瓶が違う形だと、同じ海の話に見えない。

巻かれた紙には朱の印を一つだけ置く。脈で封をするという機構の印で、
アプリ内の朱印(SealSheet)と同じ役目を持たせている。

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

# アプリ内の配色と揃える (Theme/PaperTheme.swift, Views/Bottle.swift)
PAPER = (243, 236, 221)
PAPER_DARK = (237, 229, 212)
SHADE = (200, 186, 163)
SEAL = (140, 55, 52)
GLASS = (146, 175, 169)
GLASS_DEEP = (118, 150, 145)
GLASS_LINE = (86, 112, 109)
CORK = (189, 150, 102)
CORK_DEEP = (145, 110, 70)

# 瓶の置き方。まっすぐ立てると標本のようになるので少し傾ける
TILT_DEGREES = 9.0
# 瓶の丈(アイコンの一辺に対する割合)。輪郭の比は 1 : 1.78
BOTTLE_HEIGHT = 0.74


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


# MARK: - 曲線


def cubic(p0, p1, p2, p3, steps: int = 56):
    """三次ベジェを折れ線に落とす。PIL は曲線を引けないので自分で刻む"""
    points = []
    for index in range(steps + 1):
        t = index / steps
        u = 1 - t
        points.append(
            (
                u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
                u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1],
            )
        )
    return points


def quad(p0, p1, p2, steps: int = 36):
    """二次ベジェを折れ線に落とす"""
    points = []
    for index in range(steps + 1):
        t = index / steps
        u = 1 - t
        points.append(
            (
                u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
                u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1],
            )
        )
    return points


def bottle_outline(width: float, height: float, origin=(0.0, 0.0)):
    """瓶の輪郭。Views/Bottle.swift の BottleShape と同じ比率"""

    def point(fx: float, fy: float):
        return (origin[0] + width * fx, origin[1] + height * fy)

    points = [point(0.393, 0.004), point(0.607, 0.004), point(0.607, 0.040)]
    points.append(point(0.580, 0.056))
    # 首
    points.append(point(0.580, 0.270))
    # 肩(右)
    points += cubic(
        point(0.580, 0.270), point(0.596, 0.355), point(0.795, 0.365), point(0.795, 0.455)
    )
    # 胴(右)
    points.append(point(0.795, 0.930))
    points += quad(point(0.795, 0.930), point(0.795, 0.982), point(0.695, 0.996))
    # 底
    points.append(point(0.305, 0.996))
    points += quad(point(0.305, 0.996), point(0.205, 0.982), point(0.205, 0.930))
    # 胴(左)
    points.append(point(0.205, 0.455))
    # 肩(左)
    points += cubic(
        point(0.205, 0.455), point(0.205, 0.365), point(0.404, 0.355), point(0.420, 0.270)
    )
    # 首
    points.append(point(0.420, 0.056))
    points.append(point(0.393, 0.040))
    return points


# MARK: - 中身


def rotated_layer(size, radius: float, fill, angle: float):
    """角丸の板を描いて回す。巻いた紙と栓に使う"""
    layer = Image.new("RGBA", (round(size[0]), round(size[1])), (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        [0, 0, layer.width - 1, layer.height - 1], radius=radius, fill=fill
    )
    return layer.rotate(angle, resample=Image.BICUBIC, expand=True)


def paste_centered(base: Image.Image, layer: Image.Image, center) -> None:
    base.alpha_composite(
        layer,
        (round(center[0] - layer.width / 2), round(center[1] - layer.height / 2)),
    )


def draw_scroll(bottle: Image.Image, width: float, height: float) -> None:
    """巻かれた便り。胴の中に斜めに沈める。

    太く短いと札に見えるので、筒として細長く取り、両端に口を描いて
    紙が巻かれていることを示す。中ほどを朱の紐で結ぶ。
    紐は「封」の印で、アプリ内の朱印と同じ役目を持たせている。
    """
    thickness = width * 0.22
    length = width * 0.78
    angle = 22.0

    # まっすぐな向きで組み立ててから、まとめて一度だけ回す。
    # 部品ごとに回すと継ぎ目がずれる
    roll = Image.new("RGBA", (round(thickness), round(length)), (0, 0, 0, 0))
    draw = ImageDraw.Draw(roll)
    draw.rounded_rectangle(
        [0, 0, roll.width - 1, roll.height - 1],
        radius=thickness * 0.16,
        fill=PAPER + (255,),
    )

    # 筒の両端。中が空いている口
    cap_height = thickness * 0.34
    inset = thickness * 0.07
    draw.ellipse(
        [inset, -cap_height / 2, roll.width - inset, cap_height / 2],
        fill=SHADE + (215,),
    )
    draw.ellipse(
        [inset, roll.height - cap_height / 2, roll.width - inset, roll.height + cap_height / 2],
        fill=SHADE + (170,),
    )

    # 巻き終わりの縁。紙が重なっている線
    seam_x = roll.width * 0.68
    draw.line(
        [(seam_x, cap_height * 0.6), (seam_x, roll.height - cap_height * 0.6)],
        fill=SHADE + (190,),
        width=max(round(thickness * 0.05), 2),
    )

    # 朱の紐。巻いた紙を結んでいる
    tie_height = length * 0.085
    tie_top = (roll.height - tie_height) / 2
    draw.rectangle(
        [-thickness * 0.04, tie_top, roll.width + thickness * 0.04, tie_top + tie_height],
        fill=SEAL + (255,),
    )

    paste_centered(
        bottle,
        roll.rotate(angle, resample=Image.BICUBIC, expand=True),
        (width * 0.500, height * 0.715),
    )


def draw_cork(bottle: Image.Image, width: float, height: float) -> None:
    """栓。首の口に差し込む"""
    layer = Image.new("RGBA", (round(width), round(height * 0.12)), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cork_width = width * 0.185
    cork_height = height * 0.052
    left = (layer.width - cork_width) / 2
    for y in range(round(cork_height)):
        t = y / max(cork_height - 1, 1)
        color = tuple(round(CORK[i] + (CORK_DEEP[i] - CORK[i]) * t) for i in range(3))
        draw.line([(left, y), (left + cork_width, y)], fill=color + (255,))
    # 角を落とす
    rounded = Image.new("L", layer.size, 0)
    ImageDraw.Draw(rounded).rounded_rectangle(
        [left, 0, left + cork_width, cork_height],
        radius=cork_width * 0.16,
        fill=255,
    )
    layer.putalpha(rounded)
    bottle.alpha_composite(layer, (0, round(height * 0.012)))


def draw_bottle(image: Image.Image) -> None:
    """瓶を一本立て、栓をして、中に手紙を沈める"""
    # 拡大して描いてから縮小し、輪郭を滑らかにする
    factor = 4
    canvas = SIZE * factor
    height = canvas * BOTTLE_HEIGHT
    width = height / 1.78

    bottle = Image.new("RGBA", (round(width), round(height)), (0, 0, 0, 0))
    outline = bottle_outline(width, height)

    # 硝子。上を明るく下を沈めて厚みを出す
    glass = Image.new("RGBA", bottle.size, (0, 0, 0, 0))
    gradient = ImageDraw.Draw(glass)
    for y in range(round(height)):
        t = y / height
        color = tuple(round(GLASS[i] + (GLASS_DEEP[i] - GLASS[i]) * t) for i in range(3))
        gradient.line([(0, y), (width, y)], fill=color + (232,))
    shape = Image.new("L", bottle.size, 0)
    ImageDraw.Draw(shape).polygon(outline, fill=255)
    glass.putalpha(shape.point(lambda v: v * 232 // 255))
    bottle.alpha_composite(glass)

    draw_scroll(bottle, width, height)
    draw_cork(bottle, width, height)

    # 硝子の照り。中身の上に置いて「ガラス越し」に見せる
    shine = rotated_layer(
        (width * 0.035, height * 0.20), radius=width * 0.02,
        fill=(255, 255, 255, 96), angle=0.0
    )
    paste_centered(bottle, shine, (width * 0.315, height * 0.600))

    # 輪郭。中身を描いた後に引いて、瓶が手前にあることを示す
    stroke(
        ImageDraw.Draw(bottle),
        outline + [outline[0]],
        width * 0.020,
        GLASS_LINE + (215,),
        smooth=True,
    )

    bottle = bottle.rotate(-TILT_DEGREES, resample=Image.BICUBIC, expand=True)
    scaled = bottle.resize(
        (round(bottle.width / factor), round(bottle.height / factor)), Image.LANCZOS
    )

    # 紙に落ちる影
    shadow = Image.new("RGBA", scaled.size, (0, 0, 0, 0))
    shadow.paste(Image.new("RGB", scaled.size, SHADE), (0, 0), scaled.getchannel("A"))
    shadow.putalpha(scaled.getchannel("A").point(lambda v: v * 95 // 255))
    shadow = shadow.filter(ImageFilter.GaussianBlur(SIZE * 0.014))

    left = round((SIZE - scaled.width) / 2)
    top = round((SIZE - scaled.height) / 2)
    image.paste(shadow, (left, top + round(SIZE * 0.013)), shadow)
    image.paste(scaled, (left, top), scaled)


def main() -> None:
    image = Image.new("RGB", (SIZE, SIZE), PAPER)
    paper_ground(image)
    paper_grain(image)
    draw_bottle(image)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    # iOS のアイコンは透過も角丸も持たせない(システムが丸める)
    image.convert("RGB").save(OUT, "PNG")
    print(f"書き出しました: {OUT} ({SIZE}x{SIZE})")


if __name__ == "__main__":
    main()
