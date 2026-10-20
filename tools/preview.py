#!/usr/bin/env python3
"""Render a test terminal snapshot, including actual 2x3 mosaic character data."""
from pathlib import Path
import json, sys
from PIL import Image, ImageDraw, ImageFont

PALETTE = ['f0f0f0','f2b233','e57fd8','99b2f2','dede6c','7fcc19','f2b2cc','4c4c4c',
           '999999','4c99b2','b266e5','3366cc','7f664c','57a64e','cc4c4c','111111']

def render(source, destination):
    snapshot=json.loads(Path(source).read_text())
    cell_w,cell_h=12,18
    canvas=Image.new('RGB',(snapshot['width']*cell_w,snapshot['height']*cell_h))
    draw=ImageDraw.Draw(canvas)
    font=ImageFont.truetype('DejaVuSansMono.ttf',14)
    for y,line in enumerate(snapshot['lines']):
        for x,char in enumerate(line['text']):
            fg='#'+PALETTE[int(line['fg'][x],16)]; bg='#'+PALETTE[int(line['bg'][x],16)]
            left,top=x*cell_w,y*cell_h
            draw.rectangle((left,top,left+cell_w-1,top+cell_h-1),fill=bg)
            if 128<=ord(char)<160:
                bits=ord(char)-128
                for pixel in range(5):
                    if bits & (1<<pixel):
                        px,py=left+(pixel%2)*6,top+(pixel//2)*6
                        draw.rectangle((px,py,px+5,py+5),fill=fg)
            elif char!=' ':
                draw.text((left+1,top-1),char,font=font,fill=fg)
    Path(destination).parent.mkdir(parents=True,exist_ok=True)
    canvas.save(destination)

if __name__=='__main__':
    if len(sys.argv)!=3: raise SystemExit('Usage: preview.py snapshot.json output.png')
    render(sys.argv[1],sys.argv[2])
