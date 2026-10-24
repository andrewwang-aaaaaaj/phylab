from PIL import Image, ImageDraw, ImageFont
import os
base = r"C:\Users\wanga\Documents\deepseek-harness\default-workspace\PhyLab\design"
W,H = 1000, 2020
canvas = Image.new("RGB",(W,H),(5,12,22))
d = ImageDraw.Draw(canvas)
for y in range(0,H,40):
    d.line([(0,y),(W,y)], fill=(8,20,34), width=1)
for x in range(0,W,40):
    d.line([(x,0),(x,H)], fill=(8,20,34), width=1)
font_path = r"C:\Windows\Fonts\msyh.ttc"
font_bold = r"C:\Windows\Fonts\msyhbd.ttc"
def font(size,bold=False):
    try: return ImageFont.truetype(font_bold if bold else font_path, size)
    except: return ImageFont.load_default()
d.text((50,42),"PhyLab / 鸿蒙物理实验室", font=font(34,True), fill=(232,245,255))
d.text((50,92),"HarmonyOS 7 · API 26 · 完全离线的传感器实验室", font=font(17), fill=(155,178,200))
d.text((W-50,52),"UI DESIGN PREVIEW", font=font(14,True), fill=(34,211,238), anchor="ra")
labels = [("01  实验首页","实时加速度、实验库与快捷入口"),("02  传感器图谱","18 类传感器与可用性状态"),("03  记录与导出","四通道记录、历史会话、CSV"),("04  实验运行时","自由落体：失重、冲击与高度估算")]
positions=[(50,170),(560,170),(50,1100),(560,1100)]
files=["screen-home.png","screen-sensors.png","screen-records.png","screen-experiment.png"]
for (title,sub),(x,y),fn in zip(labels,positions,files):
    d.text((x,y-44),title,font=font(17,True),fill=(232,245,255))
    d.text((x,y-21),sub,font=font(11),fill=(108,130,152))
    im=Image.open(os.path.join(base,fn)).convert("RGB").resize((390,844),Image.Resampling.LANCZOS)
    d.rounded_rectangle([x-5,y-5,x+395,y+849], radius=28, fill=(14,27,46), outline=(30,53,80), width=1)
    canvas.paste(im,(x,y))
d.text((50,1962),"注：本图为依据 ArkUI 页面制作的 UI 设计预览，用于展示视觉与交互结构，不是 HarmonyOS 真机截图。", font=font(12), fill=(108,130,152))
canvas.save(os.path.join(base,"phylab-ui-preview.png"), quality=95)
print("saved", os.path.getsize(os.path.join(base,"phylab-ui-preview.png")))
