"""Generate the moulded-plastic toy pointer SVGs for Tiny Hands.

Usage: python3 gen.py OUTDIR [names...]
"""
import math
import os
import sys

import numpy as np

from sdfart import (Grid, circle, ellipse, capsule, rbox, finger, smin, sunion,
                    path_d, band, inter, mix, shade, fmt)

LX, LY = -0.5, -0.866  # direction towards the light (outward normal facing it)
OUTLINE = 1.0          # outline thickness outside the fill, viewBox units


# --------------------------------------------------------------- palettes
def palette(base, outline=None, warm=0.06):
    base = mix(base, '#EBD9BC', warm)
    return {
        'base': base,
        'light': mix(base, '#F4FFF0', 0.45),
        'hi': mix(base, '#FFFFFF', 0.25),
        'shade': shade(base, 0.70),
        'deep': shade(base, 0.52),
        'rim': mix(base, '#FFFBEA', 0.38),
        'outline': outline or shade(base, 0.46),
    }


# ----------------------------------------------------------------- shapes
def cuff(g):
    # fat rolled cuff: a short cylinder with softly rounded rims
    a = rbox(g, (50, 120.25), 31.5, 16.25, 9.5)
    b = ellipse(g, (50, 120.25), 32.2, 16.75)
    return smin(a, b, 3.0)


def palm_shape(g, cx=53.0, cy=76.0, hx=29.0, hy=24.0):
    upper = rbox(g, (cx, cy), hx, hy, 20)
    wrist = capsule(g, (cx - 2.5, cy + 14), (cx - 2.5, cy + 26), 24.5)
    return smin(upper, wrist, 6)


def hand_pointing(g):
    palm = palm_shape(g)
    bump = capsule(g, (58.5, 53.5), (71, 58), 12.0)
    body = smin(palm, bump, 6)
    index = finger(g, (40.5, 66), (40, 14), 11.0, 8.7, 11.0, k=3.5)
    thumb = finger(g, (40, 86), (11.6, 75), 10.0, 7.9, 9.1, k=3.0)
    body = smin(body, index, 4.5)
    body = smin(body, thumb, 4.0)
    return body


def hand_middle(g):
    palm = rbox(g, (50, 80), 27.5, 31, 17)
    lb = capsule(g, (30, 55), (38, 52), 9.8)
    rb = capsule(g, (62, 52), (71, 56), 10.0)
    body = sunion(6, palm, lb, rb)
    mid = finger(g, (50, 62), (50, 12), 8.6, 7.0, 9.0, k=3.0)
    thumb = finger(g, (38, 88), (12.5, 77), 9.0, 7.2, 8.4, k=3.0)
    body = smin(body, mid, 4.0)
    body = smin(body, thumb, 4.0)
    return body


def hand_peace(g):
    palm = rbox(g, (52, 81), 27, 30, 17)
    rb = capsule(g, (66, 58), (73, 63), 9.5)
    body = smin(palm, rb, 6)
    index = finger(g, (44, 62), (36, 11.5), 8.2, 6.7, 8.5, k=3.0)
    mid = finger(g, (57, 62), (63, 16.5), 8.2, 6.7, 8.5, k=3.0)
    thumb = finger(g, (37, 88), (14, 74), 7.6, 5.9, 7.4, k=2.5)
    vee = smin(index, mid, 9.0)  # moulded web at the bottom of the V
    body = smin(body, vee, 4.5)
    body = smin(body, thumb, 4.0)
    return body


def hand_thumbs(g):
    fist = rbox(g, (48, 80), 24, 26, 18)
    wrist = capsule(g, (50, 96), (50, 106), 24.5)
    body = sunion(6, fist, wrist)
    # curled fingers: fat rolls stacked down the front, scalloping the right edge
    for y, x1, r in ((56.5, 74.5, 9.6), (74.5, 78.5, 9.4), (91.5, 76.5, 9.0)):
        body = smin(body, capsule(g, (50, y), (x1, y + 1.0), r), 2.6)
    thumb = finger(g, (40, 66), (36, 15), 12.8, 10.6, 12.0, k=3.5)
    body = smin(body, thumb, 6.0)
    return body


def hand_rock(g):
    palm = rbox(g, (51, 81), 27.5, 30, 17)
    mb = capsule(g, (46, 56), (60, 56), 10.0)
    body = smin(palm, mb, 6)
    index = finger(g, (36, 62), (34, 11.5), 8.2, 6.7, 8.5, k=3.0)
    pinky = finger(g, (68, 62), (72, 21), 7.4, 6.0, 7.6, k=3.0)
    body = smin(body, index, 6.5)
    body = smin(body, pinky, 6.5)
    return body


def hand_five(g):
    palm = rbox(g, (52, 82), 27.5, 29, 18)
    idx = finger(g, (38, 64), (27.5, 21.5), 7.4, 6.0, 7.4, k=3.0)
    mid = finger(g, (50.5, 60), (50, 10.8), 7.6, 6.2, 7.8, k=3.0)
    ring = finger(g, (62, 64), (71.5, 21.5), 7.3, 5.9, 7.3, k=3.0)
    pinky = finger(g, (71, 74), (88, 42), 6.6, 5.4, 6.6, k=3.0)
    thumb = finger(g, (34, 88), (12, 66), 7.6, 5.9, 7.4, k=2.5)
    fingers = idx
    for f in (mid, ring, pinky):
        fingers = smin(fingers, f, 9.0)  # moulded webs between the fingers
    body = smin(palm, fingers, 4.0)
    body = smin(body, thumb, 4.0)
    return body


def paw(g):
    pad = rbox(g, (50, 66), 33, 40, 30)
    toes = sunion(2.0, circle(g, (22, 31), 9.4), circle(g, (40, 13.6), 10.6),
                  circle(g, (61, 16.0), 10.4), circle(g, (79, 33), 9.4))
    return smin(pad, toes, 5.0)


TOE_BEANS = [((23, 32.6), 4.3, 5.0, -25), ((40.2, 15.8), 5.0, 5.8, -6),
             ((60.6, 18.2), 4.9, 5.7, 6), ((77.8, 34.6), 4.3, 5.0, 25)]


def paw_beans(g):
    main = sunion(5.0, ellipse(g, (50, 72), 15, 10), circle(g, (38.5, 80), 7.2),
                  circle(g, (50, 84.5), 7.6), circle(g, (61.5, 80), 7.2))
    beans = [ellipse(g, c, rx, ry, rot) for c, rx, ry, rot in TOE_BEANS]
    return main, beans


VARIETIES = {
    # name: (shape fn, tip (x, y), palette base, outline override)
    'tiny-hand': (hand_pointing, (40.0, 2.0), '#22B593', None),
    'middle-child': (hand_middle, (50.0, 2.0), '#3F8FBE', None),
    'peace': (hand_peace, (36.0, 2.0), '#A28BD0', None),
    'thumbs-up': (hand_thumbs, (36.0, 2.0), '#F2C64A', '#94701E'),
    'rock-on': (hand_rock, (34.0, 2.0), '#62B36A', None),
    'high-five': (hand_five, (50.0, 2.0), '#F299AC', None),
    'cat-paw': (paw, (40.0, 2.0), '#9DCDE8', None),
}


# ------------------------------------------------------------------ boil
def boil_noise(g, seed, amp, keep_pts):
    if seed == 0:
        return 0.0
    rng = np.random.default_rng(seed)
    n = np.zeros_like(g.X)
    for _ in range(4):
        ang = rng.uniform(0, math.pi)
        f = rng.uniform(0.10, 0.22)
        ph = rng.uniform(0, 2 * math.pi)
        n += np.sin(f * (g.X * math.cos(ang) + g.Y * math.sin(ang)) + ph)
    n = n / 2.0 * amp
    mask = np.ones_like(n)
    for (px, py, r0, r1) in keep_pts:
        d = np.hypot(g.X - px, g.Y - py)
        mask *= np.clip((d - r0) / (r1 - r0), 0, 1)
    return np.clip(n, -amp, amp) * mask


# ---------------------------------------------------------------- render
class SVG:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.defs = []
        self.body = []

    def lin(self, gid, x1, y1, x2, y2, stops, units=None):
        u = ' gradientUnits="userSpaceOnUse"' if units == 'user' else ''
        s = ''.join('<stop offset="%s" stop-color="%s"%s/>' % (
            fmt(o), c, '' if a >= 1 else ' stop-opacity="%s"' % fmt(a)) for o, c, a in stops)
        self.defs.append('<linearGradient id="%s" x1="%s" y1="%s" x2="%s" y2="%s"%s>%s</linearGradient>'
                         % (gid, fmt(x1), fmt(y1), fmt(x2), fmt(y2), u, s))

    def rad(self, gid, cx, cy, r, stops, fx=None, fy=None, units=None):
        u = ' gradientUnits="userSpaceOnUse"' if units == 'user' else ''
        f = '' if fx is None else ' fx="%s" fy="%s"' % (fmt(fx), fmt(fy))
        s = ''.join('<stop offset="%s" stop-color="%s"%s/>' % (
            fmt(o), c, '' if a >= 1 else ' stop-opacity="%s"' % fmt(a)) for o, c, a in stops)
        self.defs.append('<radialGradient id="%s" cx="%s" cy="%s" r="%s"%s%s>%s</radialGradient>'
                         % (gid, fmt(cx), fmt(cy), fmt(r), f, u, s))

    def path(self, d, fill, opacity=1.0):
        if not d:
            return
        op = '' if opacity >= 1 else ' fill-opacity="%s"' % fmt(opacity)
        self.body.append('<path d="%s" fill="%s"%s/>' % (d, fill, op))

    def ellipse(self, cx, cy, rx, ry, fill, opacity=1.0, rot=0.0):
        op = '' if opacity >= 1 else ' fill-opacity="%s"' % fmt(opacity)
        el = '<ellipse cx="0" cy="0" rx="%s" ry="%s" fill="%s"%s/>' % (fmt(rx), fmt(ry), fill, op)
        if rot:
            self.body.append('<g transform="translate(%s %s) rotate(%s)">%s</g>' % (fmt(cx), fmt(cy), fmt(rot), el))
        else:
            self.body.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"%s/>' % (
                fmt(cx), fmt(cy), fmt(rx), fmt(ry), fill, op))

    def text(self):
        return ('<?xml version="1.0" encoding="UTF-8"?>\n'
                '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="%d" height="%d" viewBox="0 0 %d %d">\n'
                '<defs>\n%s\n</defs>\n%s\n</svg>\n' % (self.w, self.h, self.w, self.h,
                                                       '\n'.join(self.defs), '\n'.join(self.body)))


def shade_part(svg, g, S, P, gid, kind, rng, boil):
    """Moulded plastic shading for one merged part with field S."""
    nx, ny = g.normals(S)
    # base fill
    if kind == 'cuff':
        svg.lin(gid, 0, 0, 0, 1, [(0, P['light'], 1), (0.28, P['base'], 1), (0.7, P['shade'], 1), (1, P['deep'], 1)])
    else:
        svg.lin(gid, 0.1, 0.0, 0.75, 1.0, [(0, P['base'], 1), (0.55, P['base'], 1), (1, P['shade'], 1)])
    svg.path(path_d(g, S), 'url(#%s)' % gid)
    # bottom-right occlusion: a dark band hugging the shadow-side edge
    wdark = np.clip(-(nx * LX + ny * LY), 0, 1) ** 1.2
    for wd, op in ((6.5, 0.16), (3.6, 0.18), (1.6, 0.18)):
        svg.path(path_d(g, band(S, -0.3, wd * wdark + 0.3)), P['deep'], op)
    # soft lit volume: shrunk copies pushed toward the light
    K = 9
    for k in range(1, K + 1):
        r = 1.25 * k
        v = 0.7 * r
        sh = g.shift(S, -LX * v, -LY * v)
        svg.path(path_d(g, sh + r), P['light'], 0.055)
    if kind == 'cuff':
        wtop = np.clip(-ny, 0, 1) ** 3
        svg.path(path_d(g, band(S, 0.6, 3.2 * wtop)), P['light'], 0.35)
    # rim / bounce light on the underside, inset from the edge
    wrim = np.clip(nx * 0.25 + ny * 0.97, 0, 1) ** 2.0
    j = rng.uniform(-0.15, 0.15) if boil else 0.0
    svg.path(path_d(g, band(S, 0.9 + j, 1.5 * wrim)), P['rim'], 0.55)
    # specular streak on the lit edge
    dl = nx * LX + ny * LY
    lap = (np.gradient(np.gradient(S, g.h, axis=0), g.h, axis=0)
           + np.gradient(np.gradient(S, g.h, axis=1), g.h, axis=1))
    curv = np.clip((lap - 0.045) / 0.05, 0, 1)
    wsp = np.clip((dl - 0.55) / 0.45, 0, 1) ** 1.3 * curv
    j = rng.uniform(-0.25, 0.25) if boil else 0.0
    svg.path(path_d(g, band(S, 1.7 + j, (2.4 + j) * wsp)), '#FFFFFF', 0.85)


def inside_ok(S_at, cx, cy, rx, ry, rot=0.0, margin=0.8):
    ca, sa = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    for t in np.linspace(0, 2 * math.pi, 48, endpoint=False):
        x = cx + rx * math.cos(t) * ca - ry * math.sin(t) * sa
        y = cy + rx * math.cos(t) * sa + ry * math.sin(t) * ca
        if S_at(x, y) > -margin:
            return False
    return True


def sampler(g, S):
    def at(x, y):
        j = (x - g.x0) / g.h
        i = (y - g.y0) / g.h
        j0, i0 = int(math.floor(j)), int(math.floor(i))
        tj, ti = j - j0, i - i0
        return (S[i0, j0] * (1 - tj) * (1 - ti) + S[i0, j0 + 1] * tj * (1 - ti)
                + S[i0 + 1, j0] * (1 - tj) * ti + S[i0 + 1, j0 + 1] * tj * ti)
    return at


GLINTS = {
    # extra crisp glints and soft glows per variety: (kind, cx, cy, rx, ry, rot)
    'tiny-hand': [('glow', 49, 76, 17, 16, -20), ('glow', 64, 51, 8, 5, -12),
                  ('dot', 34.6, 11.6, 1.9, 3.4, 25), ('dot', 62.0, 47.0, 3.6, 1.35, -18),
                  ('dot', 7.0, 71.6, 1.3, 2.1, 40), ('dot', 33.0, 63, 1.0, 3.2, 12)],
    'middle-child': [('glow', 47, 72, 15, 17, -20), ('glow', 33, 52, 6, 4, -15), ('glow', 66, 52, 6, 4, -10),
                     ('dot', 45.5, 10.5, 1.6, 3.0, 25), ('dot', 30, 46.8, 2.6, 1.1, -20),
                     ('dot', 63, 45.5, 2.8, 1.2, -12), ('dot', 8.6, 74.6, 1.2, 2.0, 40)],
    'peace': [('glow', 48, 74, 15, 16, -20), ('dot', 31.6, 10.0, 1.5, 2.8, 30),
              ('dot', 58.8, 14.6, 1.4, 2.6, 10), ('dot', 67, 52.5, 2.5, 1.1, -25),
              ('dot', 10.8, 71.2, 1.2, 1.8, 40)],
    'thumbs-up': [('glow', 44, 80, 13, 15, -20), ('glow', 66, 53, 8, 4, 0), ('glow', 70, 71, 8, 4, 0),
                  ('dot', 30.0, 12.0, 2.0, 3.6, 22), ('dot', 70, 50.4, 3.6, 1.2, -4),
                  ('dot', 74, 68.2, 3.0, 1.1, -4), ('dot', 72, 85.8, 2.6, 1.0, -4),
                  ('dot', 29.4, 40, 1.2, 4.6, 4)],
    'rock-on': [('glow', 48, 74, 15, 16, -20), ('glow', 52, 52, 8, 4, -5),
                ('dot', 29.6, 10.0, 1.5, 2.8, 25), ('dot', 68.4, 19.3, 1.3, 2.4, 20),
                ('dot', 50, 49.2, 3.0, 1.2, -6)],
    'high-five': [('glow', 50, 80, 15, 15, -20), ('dot', 24.4, 19.4, 1.3, 2.5, 40),
                  ('dot', 46.4, 9.4, 1.4, 2.6, 25), ('dot', 68.2, 18.8, 1.3, 2.4, 15),
                  ('dot', 85.6, 39.4, 1.0, 1.9, 30), ('dot', 9.6, 63.5, 1.1, 1.8, 45)],
    'cat-paw': [('glow', 47, 58, 17, 13, -15), ('dot', 34.6, 8.6, 1.6, 2.8, 40),
                ('dot', 56.6, 11.4, 1.4, 2.4, 30), ('dot', 17.4, 26.8, 1.3, 2.2, 45),
                ('dot', 74.8, 28.4, 1.2, 2.0, 30)],
}
CUFF_GLINTS = [('dot', 27.5, 108.6, 5.8, 1.5, -10), ('dot', 21.4, 119.5, 1.1, 3.6, 0),
               ('glow', 44, 110, 15, 4.8, -3)]


def build(name, seed=0, out=None):
    shape_fn, tip, base, ol = VARIETIES[name]
    P = palette(base, ol)
    g = Grid(-1, -1, 101, 141)
    body = shape_fn(g)
    cf = cuff(g)
    rng = np.random.default_rng(1000 + seed)
    if seed:
        keep = [(tip[0], tip[1] + 1, 7.0, 15.0), (50, 137, 6.0, 14.0)]
        # also hold the left/right extremes so bounds stay put
        S0 = np.minimum(body, cf)
        ins = S0 < OUTLINE
        cols = np.nonzero(ins.any(axis=0))[0]
        for cj in (cols[0], cols[-1]):
            rows = np.nonzero(ins[:, cj])[0]
            keep.append((g.x0 + cj * g.h, g.y0 + rows.mean() * g.h, 4.0, 10.0))
        body = body + boil_noise(g, seed, 0.7, keep)
        cf = cf + boil_noise(g, seed + 50, 0.5, keep)
    svg = SVG(100, 140)
    pre = name.replace('-', '')
    # outline: union dilated by OUTLINE
    svg.path(path_d(g, np.minimum(body, cf), OUTLINE), P['outline'])
    shade_part(svg, g, body, P, pre + 'B', 'body', rng, seed)
    at = sampler(g, body)
    gl = GLINTS[name]
    # soft glows first, then crisp dots
    gi = 0
    for kind, cx, cy, rx, ry, rot in gl:
        if kind != 'glow':
            continue
        if seed:
            cx += rng.uniform(-0.6, 0.6)
            cy += rng.uniform(-0.6, 0.6)
        gid = '%sG%d' % (pre, gi)
        gi += 1
        svg.rad(gid, 0.5, 0.5, 0.5, [(0, P['light'], 0.3), (0.5, P['light'], 0.13), (1, P['light'], 0)])
        if inside_ok(at, cx, cy, rx, ry, rot, 0.5):
            svg.ellipse(cx, cy, rx, ry, 'url(#%s)' % gid, 1.0, rot)
        else:
            print('  glow outside', name, cx, cy)
    if name == 'cat-paw':
        draw_beans(svg, g, P, rng, seed)
    for kind, cx, cy, rx, ry, rot in gl:
        if kind != 'dot':
            continue
        if seed:
            cx += rng.uniform(-0.5, 0.5)
            cy += rng.uniform(-0.5, 0.5)
            rx *= rng.uniform(0.85, 1.12)
            ry *= rng.uniform(0.85, 1.12)
            rot += rng.uniform(-8, 8)
        if inside_ok(at, cx, cy, rx, ry, rot, 0.6):
            svg.ellipse(cx, cy, rx, ry, '#FFFFFF', 0.92, rot)
        else:
            print('  dot outside', name, cx, cy)
    # contact occlusion just above the cuff
    for d, op in ((4.5, 0.12), (2.8, 0.14), (1.4, 0.16)):
        svg.path(path_d(g, inter(-cf, cf - d, body + 0.2)), P['deep'], op)
    shade_part(svg, g, cf, P, pre + 'C', 'cuff', rng, seed)
    atc = sampler(g, cf)
    gi = 0
    for kind, cx, cy, rx, ry, rot in CUFF_GLINTS:
        if seed:
            cx += rng.uniform(-0.5, 0.5)
            cy += rng.uniform(-0.4, 0.4)
            rx *= rng.uniform(0.88, 1.1)
        if kind == 'glow':
            gid = '%sCG%d' % (pre, gi)
            gi += 1
            svg.rad(gid, 0.5, 0.5, 0.5, [(0, P['light'], 0.6), (1, P['light'], 0)])
            if inside_ok(atc, cx, cy, rx, ry, rot, 0.4):
                svg.ellipse(cx, cy, rx, ry, 'url(#%s)' % gid, 1.0, rot)
        else:
            if inside_ok(atc, cx, cy, rx, ry, rot, 0.6):
                svg.ellipse(cx, cy, rx, ry, '#FFFFFF', 0.9, rot)
            else:
                print('  cuff dot outside', cx, cy)
    # hole where the rod goes in
    svg.rad(pre + 'H', 0.5, 0.35, 0.6, [(0, P['deep'], 0.75), (1, P['deep'], 0)])
    svg.ellipse(50, 133.6, 9.5, 2.1, 'url(#%sH)' % pre)
    return svg.text()


def draw_beans(svg, g, P, rng, seed):
    main, beans = paw_beans(g)
    BP = {'base': '#EE9AA6', 'light': '#FFD3D6', 'shade': '#C96F80', 'deep': '#A95467',
          'rim': '#F7B8C0', 'outline': '#B85E70'}
    if seed:
        main = main + boil_noise(g, seed + 7, 0.35, [])
    allb = main
    for b in beans:
        allb = np.minimum(allb, b)
    # soft seat shadow under the beans
    sh = g.shift(allb, -0.75, -1.0)
    svg.path(path_d(g, sh - 0.4), P['deep'], 0.25)
    svg.lin('beanG', 0.2, 0.0, 0.7, 1.0, [(0, BP['light'], 1), (0.45, BP['base'], 1), (1, BP['shade'], 1)])
    svg.path(path_d(g, allb), 'url(#beanG)')
    nx, ny = g.normals(allb)
    wdark = np.clip(-(nx * LX + ny * LY), 0, 1) ** 1.2
    svg.path(path_d(g, band(allb, -0.2, 1.6 * wdark)), BP['deep'], 0.35)
    for k in range(1, 4):
        r = 1.0 * k
        sh = g.shift(allb, -LX * 0.6 * r, -LY * 0.6 * r)
        svg.path(path_d(g, sh + r), BP['light'], 0.18)
    dots = [(43.0, 66.6, 3.6, 1.3, -20)] + [(c[0] - 1.7, c[1] - 2.3, 0.95, 1.6, 30) for c, _, _, _ in TOE_BEANS]
    for cx, cy, rx, ry, rot in dots:
        if seed:
            cx += rng.uniform(-0.35, 0.35)
            cy += rng.uniform(-0.35, 0.35)
        svg.ellipse(cx, cy, rx, ry, '#FFFFFF', 0.9, rot)


def main():
    outdir = sys.argv[1]
    names = sys.argv[2:] or list(VARIETIES)
    for n in names:
        for suf, seed in (('', 0), ('-b', 1), ('-c', 2)):
            txt = build(n, seed)
            p = os.path.join(outdir, n + suf + '.svg')
            with open(p, 'w') as f:
                f.write(txt)
            print(p, len(txt))


if __name__ == '__main__':
    main()
