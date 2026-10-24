from PIL import Image, ImageDraw, ImageFont
import os

base = r"C:\Users\wanga\Documents\deepseek-harness\default-workspace\PhyLab\design"
W, H = 1000, 2020
canvas = Image.new("RGB", (W, H), (245, 245, 247))
d = ImageDraw.Draw(canvas)

font_path = r"C:\Windows\Fonts\msyh.ttc"
font_bold = r"C:\Windows\Fonts\msyhbd.ttc"

def font(size, bold=False):
    try:
        return ImageFont.truetype(font_bold if bold else font_path, size)
    except Exception:
        return ImageFont.load_default()

d.text((50, 42), "PhyLab / 鸿蒙物理实验室", font=font(34, True), fill=(29, 29, 31))
d.text((50, 92), "HarmonyOS 7 · API 26 · 完全离线的传感器实验室", font=font(17), fill=(110, 110, 115))
d.text((W - 50, 52), "LIGHT UI · DESIGN PREVIEW", font=font(13, True), fill=(0, 113, 227), anchor="ra")

labels = [
    ("01  物理实验室", "实时加速度、实验库与本地记录"),
    ("02  传感器", "18 类传感器与可用性状态"),
    ("03  记录", "四通道记录、历史会话、CSV 导出"),
    ("04  实验运行时", "自由落体：失重、冲击与高度估算"),
]
positions = [(50, 176), (560, 176), (50, 1106), (560, 1106)]
files = ["screen-home.png", "screen-sensors.png", "screen-records.png", "screen-experiment.png"]

for (title, sub), (x, y), fn in zip(labels, positions, files):
    d.text((x, y - 46), title, font=font(17, True), fill=(29, 29, 31))
    d.text((x, y - 23), sub, font=font(11), fill=(110, 110, 115))
    im = Image.open(os.path.join(base, fn)).convert("RGB").resize((390, 844), Image.Resampling.LANCZOS)
    # soft shadow
    shadow = Image.new("RGBA", (410, 864), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([8, 12, 402, 856], radius=30, fill=(0, 0, 0, 22))
    shadow = shadow.filter(ImageFilter.GaussianBlur(10)) if False else shadow
    canvas.paste(Image.new("RGB", (410, 864), (245, 245, 247)), (x - 10, y - 10))
    d.rounded_rectangle([x - 5, y - 5, x + 395, y + 849], radius=28,
                        fill=(255, 255, 255), outline=(229, 229, 234), width=1)
    canvas.paste(im, (x, y))

d.text((50, 1962),
       "注：本图为依据 ArkUI 页面制作的 UI 设计预览，用于展示视觉与交互结构，不是 HarmonyOS 真机截图。",
       font=font(12), fill=(134, 134, 139))

canvas.save(os.path.join(base, "phylab-ui-preview.png"), quality=95)
print("saved", os.path.getsize(os.path.join(base, "phylab-ui-preview.png")))
