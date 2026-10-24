from PIL import Image, ImageDraw, ImageFilter
import math, os
proj = r"C:\Users\wanga\Documents\deepseek-harness\default-workspace\PhyLab"
def make_icon(size, bg=True):
    S=size*4
    img=Image.new('RGBA',(S,S),(0,0,0,0))
    d=ImageDraw.Draw(img)
    if bg:
        r=int(S*0.22)
        d.rounded_rectangle([0,0,S-1,S-1], radius=r, fill=(8,16,30,255))
        # subtle radial glow
        glow=Image.new('RGBA',(S,S),(0,0,0,0)); gd=ImageDraw.Draw(glow)
        for i in range(40,0,-1):
            rad=int(S*0.55*i/40)
            a=int(22*(1-i/40))
            gd.ellipse([S//2-rad,S//2-rad,S//2+rad,S//2+rad], fill=(34,211,238,a))
        img=Image.alpha_composite(img,glow); d=ImageDraw.Draw(img)
    # grid
    for i in range(1,5):
        y=int(S*0.2+i*S*0.15)
        d.line([S*0.10,y,S*0.90,y], fill=(40,60,90,110), width=max(1,S//400))
    # waveform
    pts=[]
    for i in range(0,241):
        t=i/240
        x=S*0.10+t*S*0.80
        env=math.exp(-((t-0.5)**2)/0.045)
        y=S*0.52 - math.sin(t*math.pi*9)*S*0.19*env
        pts.append((x,y))
    d.line(pts, fill=(34,211,238,255), width=max(3,S//80), joint='curve')
    # glow under wave
    layer=Image.new('RGBA',(S,S),(0,0,0,0)); ld=ImageDraw.Draw(layer)
    ld.line(pts, fill=(34,211,238,120), width=max(10,S//20), joint='curve')
    layer=layer.filter(ImageFilter.GaussianBlur(S//90))
    img=Image.alpha_composite(img,layer); d=ImageDraw.Draw(img); d.line(pts, fill=(103,232,249,255), width=max(3,S//90), joint='curve')
    # dot
    cx,cy=S*0.80,S*0.30; rr=S*0.045
    d.ellipse([cx-rr,cy-rr,cx+rr,cy+rr], fill=(163,230,53,255))
    return img.resize((size,size), Image.LANCZOS)
for size in [512,1024]:
    make_icon(size).save(os.path.join(proj,'AppScope','resources','base','media','app_icon.png' if size==512 else 'app_icon_1024.png'))
make_icon(512).save(os.path.join(proj,'entry','src','main','resources','base','media','app_icon.png'))
make_icon(512).save(os.path.join(proj,'entry','src','main','resources','base','media','startIcon.png'))
# showcase mark without bg
mark=make_icon(512, bg=False).resize((512,512), Image.LANCZOS)
mark.save(os.path.join(proj,'design','phylab-mark.png'))
print('icons generated')
