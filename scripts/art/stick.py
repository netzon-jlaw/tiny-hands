"""Generate stick.svg: the telescoping rod, inked and flat-painted to match the hands.

Usage: python3 stick.py OUT.svg
"""
import sys

INK, METAL, SHADE, SHINE = '#1B1410', '#CFC8B6', '#A39B88', '#FFF6DE'
LINE = 1.6           # ink weight, matched to the hands' outline at the size the app draws the rod
RING = 1.8           # how far a ferrule ring puffs out past its tube
secs = [(5.2, 18.8, 0.0, 140.0), (6.3, 17.7, 140.0, 272.0), (7.4, 16.6, 272.0, 400.0)]
B = []


def rect(x, y, w, h, fill, rx=0.0):
    r = ' rx="%g"' % rx if rx else ''
    B.append('<rect x="%g" y="%g" width="%g" height="%g"%s fill="%s"/>' % (x, y, w, h, r, fill))


# narrowest section first, so each wider tube overlaps the one sliding out of it
for i in (2, 1, 0):
    x0, x1, y0, y1 = secs[i]
    w = x1 - x0
    top = y0 - (10 if i else 0)
    rect(x0, top, w, y1 - top, INK)
    fx, fw = x0 + LINE, w - 2 * LINE
    rect(fx, top, fw, y1 - top, METAL)
    rect(fx + fw * 0.64, top, fw * 0.36, y1 - top, SHADE)                     # one flat shadow tone
    rect(fx + fw * 0.15, y0 + 8, fw * 0.15, y1 - y0 - 22, SHINE, fw * 0.075)   # one long shine
    if i < 2:
        # a puffy ring where the next tube slides out
        rx0, rw, rh = x0 - RING, w + 2 * RING, 11.0
        rect(rx0, y1 - rh, rw, rh, INK, rh / 2)
        rect(rx0 + LINE, y1 - rh + LINE, rw - 2 * LINE, rh - 2 * LINE, METAL, rh / 2 - LINE)
svg = ('<?xml version="1.0" encoding="UTF-8"?>\n'
       '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="24" height="400" viewBox="0 0 24 400">\n'
       + '\n'.join(B) + '\n</svg>\n')
open(sys.argv[1], 'w').write(svg)
