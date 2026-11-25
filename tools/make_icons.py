"""从 1024 源图生成 Android 全套图标（含自适应图标）。

源图：白底 + 等距立方体。做法：
  1. 把接近纯白的像素抠成透明，得到"只有盒子"的图；
  2. 裁掉四周空白，按内容自适应缩放；
  3. 传统图标（mipmap-*）：白底 + 盒子占 82%，兼容 Android 7 及以下；
  4. 自适应图标（mipmap-anydpi-v26）：前景透明、盒子占 66% 安全区，
     背景用纯白色资源，交给启动器自己裁形状（圆/方/水滴都行）。
"""
import os
from PIL import Image, ImageDraw

SRC = r"E:\workbuddymade\haut-app-品牌方案\Flutter风_折面盒子_1024.png"
RES = r"E:\workbuddymade\haut-app\android\app\src\main\res"

# mdpi 为基准倍数
LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
WHITE = (255, 255, 255, 255)


def cutout(path):
    img = Image.open(path).convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r >= 244 and g >= 244 and b >= 244:
                px[x, y] = (r, g, b, 0)
    return img.crop(img.getbbox())


def on_canvas(cube, size, ratio, background=None, circle=False):
    canvas = Image.new("RGBA", (size, size), background or (0, 0, 0, 0))
    inner = int(round(size * ratio))
    c = cube.copy()
    c.thumbnail((inner, inner), Image.LANCZOS)
    canvas.alpha_composite(c, ((size - c.width) // 2, (size - c.height) // 2))
    if circle and background is not None:
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
        out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        out.paste(canvas, (0, 0), mask)
        return out
    return canvas


def main():
    cube = cutout(SRC)
    print("盒子裁切后尺寸:", cube.size)

    for density, size in LEGACY.items():
        folder = os.path.join(RES, f"mipmap-{density}")
        os.makedirs(folder, exist_ok=True)
        icon = on_canvas(cube, size, 0.82, background=WHITE)
        icon.save(os.path.join(folder, "ic_launcher.png"))
        rnd = on_canvas(cube, size, 0.82, background=WHITE, circle=True)
        rnd.save(os.path.join(folder, "ic_launcher_round.png"))
        print(f"  mipmap-{density}: {size}px")

    for density, size in ADAPTIVE.items():
        folder = os.path.join(RES, f"mipmap-{density}")
        fg = on_canvas(cube, size, 0.62)
        fg.save(os.path.join(folder, "ic_launcher_foreground.png"))
        print(f"  mipmap-{density} 前景: {size}px")


if __name__ == "__main__":
    main()
