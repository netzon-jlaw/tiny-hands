"""Generate app-icon.svg: the inked Tiny Hand tapping in front of a vintage sunburst.

Usage: /usr/bin/python3 icon.py tiny-hand.svg OUT.svg     (needs numpy)
"""
import math
import re
import sys

import numpy as np

import sdfart
from sdfart import Grid, capsule, circle, stroke, inter, path_d

hand_svg = open(sys.argv[1]).read()
out = sys.argv[2]
body = re.search(r'<svg[^>]*>\n(.*)\n</svg>', hand_svg, re.S).group(1)
outline_path = re.search(r'<path d="([^"]+)"', body).group(1)
CUFF_X = float(re.search(r'cuff-centre-x ([\d.]+)', hand_svg).group(1))

INK, METAL, SHADE, SHINE = '#1B1410', '#CFC8B6', '#A39B88', '#FFF6DE'
GOLD, RAY, DISC, DROP = '#E8A33C', '#F2C261', '#FBE3A6', '#C47F27'
C, R, N = 512.0, 412.0, 5.0

S, ANG = 4.1, -25.0
CX, CY = 640.0, 764.0
th = math.radians(ANG)


def g2(x, y):
    x, y = (x - CUFF_X) * S, (y - 138) * S
    return (CX + x * math.cos(th) - y * math.sin(th), CY + x * math.sin(th) + y * math.cos(th))


tip = g2(float(re.search(r'tip-x ([\d.]+)', hand_svg).group(1)), 2)
g = Grid(96, 96, 928, 928, h=1.0)
sdfart.XFORM = (1.0, 0.0, 0.0)
squircle = ((np.abs(g.X - C) / R) ** N + (np.abs(g.Y - C) / R) ** N) ** (1 / N) * R - R
# sunburst: 14 rays fanning out from the tap point
ang = np.arctan2(g.Y - tip[1], g.X - tip[0])
dist = np.hypot(g.X - tip[0], g.Y - tip[1])
rays = -np.sin(14 * ang + 0.6) * dist / 14
B = ['<path d="%s" fill="%s"/>' % (path_d(g, squircle, tol=0.3), GOLD),
     '<path d="%s" fill="%s"/>' % (path_d(g, inter(squircle, rays), tol=0.3), RAY),
     '<path d="%s" fill="%s"/>' % (path_d(g, inter(squircle, circle(g, tip, 104)), tol=0.3), DISC)]
# ink "plink" lines around the fingertip
plinks = None
for a_deg, r0, r1 in ((-150, 124, 168), (-117, 122, 160), (-84, 122, 158), (-183, 126, 172), (-51, 124, 166)):
    a = math.radians(a_deg)
    p0 = (tip[0] + r0 * math.cos(a), tip[1] + r0 * math.sin(a))
    p2 = (tip[0] + r1 * math.cos(a), tip[1] + r1 * math.sin(a))
    s = stroke(g, p0, ((p0[0] + p2[0]) / 2, (p0[1] + p2[1]) / 2), p2, 8.0, 3.2)
    plinks = s if plinks is None else np.minimum(plinks, s)
B.append('<path d="%s" fill="%s"/>' % (path_d(g, inter(squircle + 14, plinks), tol=0.3), INK))
# rod from under the cuff to the edge of the tile, cut by the squircle itself
a, b = g2(CUFF_X, 126), g2(CUFF_X, 400)
hw = 9.6 * S
rod = capsule(g, a, b, hw)
nx, ny = math.cos(th), math.sin(th)          # across the rod
side = (g.X - a[0]) * nx + (g.Y - a[1]) * ny  # signed distance across
inner = inter(rod + 2.6 * S, squircle)
B.append('<g transform="translate(16 20)"><path d="%s" fill="%s"/></g>'
         % (path_d(g, inter(rod, squircle + 24), tol=0.3), DROP))
B.append('<path d="%s" fill="%s"/>' % (path_d(g, inter(rod, squircle), tol=0.3), INK))
B.append('<path d="%s" fill="%s"/>' % (path_d(g, inner, tol=0.3), METAL))
B.append('<path d="%s" fill="%s"/>' % (path_d(g, inter(inner, hw * 0.25 - side), tol=0.3), SHADE))
B.append('<path d="%s" fill="%s"/>' % (path_d(g, inter(inner, squircle + 30, np.abs(side + hw * 0.36) - hw * 0.09), tol=0.3), SHINE))
tr = 'translate(%.2f %.2f) rotate(%.1f) scale(%.3f) translate(%.2f -138)' % (CX, CY, ANG, S, -CUFF_X)
B.append('<g transform="translate(16 20)"><g transform="%s"><path d="%s" fill="%s"/></g></g>'
         % (tr, outline_path, DROP))
B.append('<g transform="%s">\n%s\n</g>' % (tr, body))
svg = ('<?xml version="1.0" encoding="UTF-8"?>\n'
       '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="1024" height="1024" viewBox="0 0 1024 1024">\n'
       + '\n'.join(B) + '\n</svg>\n')
open(out, 'w').write(svg)
print('tip', tip)
