"""Editable demonstration artwork, Store PNGs and a bilingual contact sheet.

Run from the repository root with Python 3 and Pillow. This renderer never
redraws application UI: it places the unmodified Flutter captures into frames.
"""
from pathlib import Path
import base64
import html
import json
import math
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
STORE = ROOT / "marketing/play-store"
FONT = ROOT / "assets/fonts/NotoSans-Regular.ttf"


class Illustration:
    """One source of geometry for antialiased PNG and editable SVG exports."""
    def __init__(self, background):
        self.image = Image.new("RGB", (1800, 1200), background)
        self.draw = ImageDraw.Draw(self.image)
        self.svg = [f'<rect width="900" height="600" fill="{background}"/>']

    def ellipse(self, box, color):
        self.draw.ellipse(tuple(2 * x for x in box), fill=color)
        x0, y0, x1, y1 = box
        self.svg.append(f'<ellipse cx="{(x0+x1)/2}" cy="{(y0+y1)/2}" rx="{(x1-x0)/2}" ry="{(y1-y0)/2}" fill="{color}"/>')

    def rect(self, box, color):
        self.draw.rectangle(tuple(2 * x for x in box), fill=color)
        x0, y0, x1, y1 = box
        self.svg.append(f'<rect x="{x0}" y="{y0}" width="{x1-x0}" height="{y1-y0}" fill="{color}"/>')

    def line(self, points, color, width):
        self.draw.line([(2*x, 2*y) for x, y in points], fill=color, width=2*width, joint="curve")
        for x, y in points:
            self.draw.ellipse((2*x-width, 2*y-width, 2*x+width, 2*y+width), fill=color)
        self.svg.append(f'<polyline points="{" ".join(f"{x},{y}" for x,y in points)}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>')

    def save(self, name):
        output = STORE / "source/demo-images"
        output.mkdir(parents=True, exist_ok=True)
        self.image.resize((900, 600), Image.Resampling.LANCZOS).save(output/f"{name}.png")
        (output/f"{name}.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" width="900" height="600" viewBox="0 0 900 600">\n'+"\n".join(self.svg)+'\n</svg>\n', encoding="utf-8")


def demo_images():
    forest = Illustration("#243e33")
    forest.rect((0, 460, 900, 600), "#66513d")
    forest.line([(130, 550), (195, 290), (290, 45)], "#8eaa77", 11)
    forest.line([(780, 550), (710, 290), (650, 65)], "#b5c291", 11)
    for i in range(7):
        forest.ellipse((60+16*i, 60+60*i, 215+16*i, 130+60*i), "#607f53")
        forest.ellipse((670-12*i, 65+58*i, 830-12*i, 150+58*i), "#718f62")
    forest.rect((375, 260, 520, 510), "#826c50")
    forest.ellipse((345, 250, 560, 345), "#b29976")
    forest.ellipse((375, 450, 520, 540), "#312d26")
    forest.save("terrarium")

    for index in range(3):
        spider = Illustration(["#a6b9a0", "#cfbda0", "#99adac"][index])
        for i in range(14):
            x, y = (i*73+index*31)%900, (i*137)%600
            spider.ellipse((x-80, y-30, x+140, y+60), ["#92a58a", "#b8a787", "#809b95"][index])
        spider.line([(0, 490), (330, 415), (615, 470), (900, 380)], "#8e7861", 62)
        for side in [-1, 1]:
            for i in range(4):
                start=(450+side*44, 300+i*27)
                joint=(450+side*(140+i*7), 160+i*86)
                end=(450+side*(235-i*9), 145+i*107)
                spider.line([start,joint,end], "#493a32", 27)
                spider.line([start,joint], "#d0906b", 10)
                spider.ellipse((joint[0]-17, joint[1]-17, joint[0]+17, joint[1]+17), "#ba7659")
        spider.ellipse((382, 320, 520, 480), "#47382f")
        spider.ellipse((395, 329, 507, 452), "#705141")
        spider.ellipse((382, 245, 520, 355), "#aa7455")
        spider.ellipse((410, 267, 492, 335), "#c99a73")
        for x in [432, 446, 459, 472]:
            spider.ellipse((x, 253, x+8, 261), "#1c241e")
        spider.save(f"luna-{index+1}")

    gecko = Illustration("#d8c69d")
    gecko.line([(20, 485), (300, 445), (570, 480), (875, 405)], "#ae966e", 56)
    gecko.line([(360, 360), (190, 300), (125, 240)], "#ab8850", 55)
    gecko.ellipse((310, 310, 650, 415), "#d7a14f")
    gecko.ellipse((595, 272, 745, 355), "#dfb05f")
    for x, y in [(380,355),(550,359)]:
        gecko.line([(x,y),(x+25,y+76),(x+85,y+79)], "#e6ba6b", 28)
    for i in range(15):
        x, y=337+(i*61)%280, 322+(i*27)%65
        gecko.ellipse((x,y,x+18,y+12), "#5d4b3d")
    gecko.ellipse((665,288,689,313), "#493e30")
    gecko.ellipse((673,292,680,309), "#efe3be")
    gecko.save("milo")


def text_lines(text, font, max_width):
    words = text.split()
    lines = []
    for word in words:
        if lines and font.getlength(lines[-1]+" "+word) <= max_width:
            lines[-1]+=" "+word
        else:
            lines.append(word)
    return lines


def compose():
    config=json.loads((STORE/"source/screenshots.json").read_text(encoding="utf-8"))
    width,height=config["canvas"]["width"],config["canvas"]["height"]
    colors=config["colors"]
    brand=ImageFont.truetype(str(FONT),30)
    title=ImageFont.truetype(str(FONT),58)
    subtitle=ImageFont.truetype(str(FONT),30)
    footer=ImageFont.truetype(str(FONT),23)
    review=[]
    for lang in ["de","en"]:
        output=STORE/"screenshots"/lang
        output.mkdir(parents=True,exist_ok=True)
        svg_dir=STORE/"source/templates"/lang
        svg_dir.mkdir(parents=True,exist_ok=True)
        for shot in config["screenshots"]:
            capture_path=STORE/"source/captures"/lang/(shot["id"]+".png")
            capture=Image.open(capture_path).convert("RGB")
            assert capture.size==(1080,1614), (capture_path,capture.size)
            image=Image.new("RGB",(width,height),colors["background"])
            draw=ImageDraw.Draw(image)
            svg_text=[]
            def label(text,x,y,font,color):
                draw.text((x,y),text,font=font,fill=color,anchor="lt")
                # Noto Sans is the editable template font; SVG's y is a baseline.
                svg_text.append(f'<text x="{x}" y="{y+font.size*0.8}" font-family="Noto Sans, sans-serif" font-size="{font.size}" fill="{color}">{html.escape(text)}</text>')
            label("TerraManager",54,30,brand,colors["muted"])
            lines=text_lines(shot[lang]["title"],title,972)
            assert len(lines)<=2
            for i,line in enumerate(lines): label(line,54,83+i*65,title,colors["text"])
            start=158 if len(lines)==1 else 215
            # All supplied titles fit a single line; fail instead of overlapping UI.
            assert len(lines)==1, (lang,shot["id"])
            label(shot[lang]["subtitle"],54,start,subtitle,colors["muted"])
            image.paste(capture,(0,270))
            demo="Beispieldaten · Standalone" if lang=="de" else "Demo data · Standalone"
            label(demo,54,1887,footer,colors["muted"])
            image.save(output/(shot["id"]+".png"),optimize=True)
            encoded=base64.b64encode(capture_path.read_bytes()).decode()
            svg='<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1080" height="1920" viewBox="0 0 1080 1920">\n'
            svg+=f'<rect width="1080" height="1920" fill="{colors["background"]}"/>\n'
            svg+=f'<image x="0" y="270" width="1080" height="1614" xlink:href="data:image/png;base64,{encoded}"/>\n'
            svg+="\n".join(svg_text)+"\n</svg>\n"
            (svg_dir/(shot["id"]+".svg")).write_text(svg,encoding="utf-8")
            assert len(shot[lang]["alt"])<=140
            review.append(image.resize((270,480),Image.Resampling.LANCZOS))
        (output/"alt-text.json").write_text(json.dumps({s["id"]+".png":s[lang]["alt"] for s in config["screenshots"]},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    sheet=Image.new("RGB",(2160,960),"#073b2b")
    for i,thumb in enumerate(review): sheet.paste(thumb,((i%8)*270,(i//8)*480))
    sheet.save(STORE/"review-contact-sheet.png")
    review_page(config)
    print("16 RGB PNG screenshots and 16 editable SVG templates composed.")


def review_page(config):
    sections=[]
    for language,locale,label in [("de","de-DE","Deutsch"),("en","en-US","English")]:
        fields=[]
        for field,field_label in [("title","Titel / Title"),("short-description","Kurzbeschreibung / Short description"),("full-description","Vollständige Beschreibung / Full description")]:
            value=(STORE/"listing"/locale/(field+".txt")).read_text(encoding="utf-8").strip()
            fields.append(f'<h3>{field_label} <small>{len(value)} Zeichen / characters</small></h3><pre>{html.escape(value)}</pre>')
        images="".join(f'<figure><img loading="lazy" src="screenshots/{language}/{shot["id"]}.png" alt="{html.escape(shot[language]["alt"])}"><figcaption>{html.escape(shot[language]["title"])}</figcaption></figure>' for shot in config["screenshots"])
        sections.append(f'<section id="{language}" lang="{language}"><h2>{label}</h2><div class="review"><article>{"".join(fields)}</article><div class="pictures">{images}</div></div></section>')
    document='''<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>TerraManager — Store review</title><style>
body{margin:0;background:#f3f6f1;color:#17251c;font:16px/1.6 system-ui,sans-serif}header,main{max-width:1500px;margin:auto;padding:28px}header{background:#073b2b;color:white}header a{color:#bedbc9;margin-right:24px}h1{margin:0}h2{font-size:32px}h3{font-size:18px;margin-top:28px}small{font-size:13px;display:block;color:#5a695f}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:inherit;background:white;padding:18px;border-radius:10px}section{padding-bottom:48px;scroll-margin-top:20px}.review{display:grid;grid-template-columns:1fr 1fr;gap:36px}.pictures{display:grid;grid-template-columns:repeat(2,1fr);gap:16px;align-content:start}figure{margin:0}img{display:block;width:100%;height:auto;border-radius:10px}figcaption{font-size:13px;padding:5px}article{min-width:0}@media(max-width:850px){.review{grid-template-columns:1fr}header,main{padding:18px}}
</style><header><h1>TerraManager · Store Presence Refresh</h1>'''
    document+=f'<p>Android {html.escape(config["sourceVersion"])} · Beispieldaten / Demo data · Veröffentlichung durch Release-Verantwortlichen / Release-owner publication</p>'
    document+='<nav><a href="#de">Deutsch</a><a href="#en">English</a></nav></header><main>'+"".join(sections)+'</main></html>'
    (STORE/"review.html").write_text(document,encoding="utf-8")


def validate_listing():
    for locale in ["de-DE","en-US"]:
        for field,limit in [("title",30),("short-description",80),("full-description",4000)]:
            text=(STORE/"listing"/locale/(field+".txt")).read_text(encoding="utf-8").strip()
            # Count UTF-16 code units, as well as Python Unicode code points.
            units=len(text.encode("utf-16-le"))//2
            assert units<=limit,(locale,field,units,limit)
            print(f"{locale} {field}: {units}/{limit}")


if __name__=="__main__":
    validate_listing()
    if "--demo-only" in sys.argv:
        demo_images()
    elif "--validate-only" not in sys.argv:
        compose()
