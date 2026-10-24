from PIL import Image, ImageDraw
import math, os

proj = r"C:\Users\wanga\Documents\deepseek-harness\default-workspace\PhyLab"

def make_icon(size: int, bg: bool = True) -> Image.Image:
    S = size * 4
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if bg:
        d.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.225), fill=(255, 255, 255, 255))
        tint = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        td = ImageDraw.Draw(tint)
        for i in range(70, 0, -1):
            rad = int(S * 0.60 * i / 70)
            alpha = int(10 * (1 - i / 70))
            td.ellipse([S // 2 - rad, S - rad // 2, S // 2 + rad, S + rad // 2],
                       fill=(0, 113, 227, alpha))
        img = Image.alpha_composite(img, tint)
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.225),
                            outline=(229, 229, 234, 255), width=max(2, S // 220))
        for i in range(1, 4):
            y = int(S * (0.25 + i * 0.14))
            d.line([int(S * 0.14), y, int(S * 0.86), y], fill=(242, 242, 245, 255),
                   width=max(2, S // 260))
    pts = []
    for i in range(0, 241):
        t = i / 240
        x = S * 0.13 + t * S * 0.74
        y = S * 0.52 - math.sin(t * math.pi * 6.4) * S * 0.15
        pts.append((x, y))
    split = 170
    d.line(pts[:split], fill=(29, 29, 31, 255), width=max(6, S // 46), joint="curve")
    d.line(pts[split - 1:], fill=(0, 113, 227, 255), width=max(6, S // 46), joint="curve")
    cx, cy = pts[-1]
    rr = S * 0.032
    d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(0, 113, 227, 255))
    return img.resize((size, size), Image.LANCZOS)

for size in (512, 1024):
    name = "app_icon.png" if size == 512 else "app_icon_1024.png"
    make_icon(size).save(os.path.join(proj, "AppScope", "resources", "base", "media", name))
make_icon(512).save(os.path.join(proj, "entry", "src", "main", "resources", "base", "media", "app_icon.png"))
make_icon(512).save(os.path.join(proj, "entry", "src", "main", "resources", "base", "media", "startIcon.png"))
make_icon(512, bg=False).save(os.path.join(proj, "design", "phylab-mark.png"))
print("light icons generated")
