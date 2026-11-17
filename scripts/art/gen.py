"""Generate the ink-and-paint pointer SVGs for Tiny Hands.

The toy hand, drawn the way a 1930s rubber-hose cartoon would draw it. Each hand is
one continuous outline: club-tipped fingers that bow and flow into a round hand,
stubs for the folded fingers, a pinch at the wrist and a soft rolled cuff. One even
warm-black line, flat cel paint, nothing else.

Every hand is a right hand seen from above with the palm down, the way the toy looks
when it taps a screen: we see the back of the hand. A folded finger shows as a short
stub (knuckle to first joint) with its tip hidden underneath, so the only inner lines
are the seams between neighbouring fingers. No finger pads or palm creases can show.

The hands are modelled with depth, so the same drawing can be turned about its long
axis. Besides the three line-boil frames, each hand gets eight "roll" frames (the hand
turned 11, 22, 33 and 44 degrees each way), which the app shows when the pointer is
flicked sideways.

Usage: /usr/bin/python3 gen.py OUTDIR [names...]     (needs numpy)
"""
import math
import os
import sys

import numpy as np

import sdfart
from sdfart import (Grid, circle, ellipse, capsule, limb, brush, smin, sunion, rbox,
                    path_d, contours, inter, mix, redist, closing)

INK = '#1B1410'      # same ink as the app's tap effects
CLAW = '#F6ECD2'     # cat claws
T0, TA = 2.05, 0.35  # ink weight outside the paint: base, plus a little extra on the lower right
SHX, SHY = 0.55, 0.835
LINE = 1.12          # radius of an inner brush line: the same weight as the outline
DART = 0.95          # radius of a dart line: a touch lighter
TOP, BOTTOM = 2.0, 138.0   # where the inked art must start and end in the viewBox
MARGIN = 1.5               # the boil frames need this much room at the sides
ROUND = 3.6                # every inside corner of the outline is opened up to at least this radius
ROLL_STEP = 11.0           # degrees between roll frames
ROLL_MAX = 4               # roll frames each way


def paint(base):
    # aged cel paint: every colour pulled toward a warm cream
    return mix(base, '#E9D7B2', 0.22)


# ------------------------------------------------------------- the third dimension
# Drawing units: x right, y down, z toward the camera (up off the back of the hand).
# A roll turns the hand about a vertical axis through the fingertip, so the tip never
# moves. Positive roll carries the top of the hand to the right.
class View:
    def __init__(self, degrees, axis_x):
        self.t = math.radians(degrees)
        self.c, self.s = math.cos(self.t), math.sin(self.t)
        self.ax = axis_x

    def x(self, x, z=0.0):
        return self.ax + (x - self.ax) * self.c + z * self.s

    def p(self, pt, z=0.0):
        return (self.x(pt[0], z), pt[1])

    def width(self, rx, rz):
        """Half-width of something rx wide and rz deep, seen turned."""
        return math.hypot(rx * self.c, rz * self.s)

    def faces(self, phi):
        """Is the surface point at angle phi round a vertical cylinder (0 = top) turned toward us?"""
        return math.cos(phi + self.t) > 0.0


V = View(0.0, 50.0)


def ball(g, c, rx, ry, rz, z=0.0, rot=0.0):
    return ellipse(g, V.p(c, z), V.width(rx, rz), ry, rot)


def knob(g, c, r, z=0.0):
    return circle(g, V.p(c, z), r)


def digit(g, base, ctrl, tip, r, root=0.88, z=(0.0, 0.0, 0.0)):
    """A cartoon finger: a sausage that bows along base-ctrl-tip and swells a little toward a round tip of radius r."""
    return limb(g, V.p(base, z[0]), V.p(ctrl, z[1]), V.p(tip, z[2]), lambda t: r * (root + (1 - root) * t ** 0.8))


# ----------------------------------------------------------------- shapes
WRIST_R = 15.0
CUFF_R = 24.0


class Part:
    """Something drawn in front of the hand's main shape with its own ink line: a raised
    finger, a folded finger's stub, a toe. Its line fades out toward `root` (fully gone
    within r0, full weight beyond r1), so the part grows out of the hand there, and what is
    left of the line is the seam between it and its neighbour. Parts are painted far to
    near, so when the hand turns the nearer finger overlaps the next with one clean line."""
    def __init__(self, sdf, root, r0, r1, x):
        self.sdf, self.root, self.r0, self.r1, self.x = sdf, root, r0, r1, x


def cuff(g):
    # a narrow rolled cuff, like the band on a 1930s cartoon glove: a little fuller on one side
    return smin(ball(g, (49.7, 126.6), 25.4, 10.7, 22.0), rbox(g, V.p((50.3, 126.3)), V.width(24.2, 21.0), 9.9, 9.8), 3.0)


def darts(cx, y0, y1, spread=6.6):
    """The three short lines on the back of a cartoon glove: mid-back, clear of the outline,
    running from the knuckles toward the wrist and fanning a little."""
    out = []
    for i in (-1, 0, 1):
        ym = (y0 + y1) / 2
        out.append([(cx + i * spread * 1.12, y0 + abs(i) * 1.2), (cx + i * spread * 1.0, ym), (cx + i * spread * 0.86, y1 - abs(i) * 0.6)])
    return out


def finger(g, base, ctrl, tip, r, root=0.88, reach=1.0):
    """A raised finger as a Part: its sides run on into the hand as seams, fading toward its root."""
    sdf = digit(g, base, ctrl, tip, r, root)
    return Part(sdf, V.p(base), r * 1.15 * reach, r * 1.5 * reach, base[0])


def stub(g, c, r, toward, reach=1.0):
    """A folded finger seen from the back: a round stub. `toward` is the middle of the hand;
    the stub's line fades out in that direction."""
    d = math.hypot(toward[0] - c[0], toward[1] - c[1])
    root = (c[0] + (toward[0] - c[0]) / d * r * 0.95, c[1] + (toward[1] - c[1]) / d * r * 0.95)
    return Part(knob(g, c, r), V.p(root), r * 1.2 * reach, r * 1.5 * reach, c[0])


def build_hand(g, palm, parts, extra=(), k=6.0, crotch=6.0, bump_k=3.0):
    """One continuous silhouette: fingers flow into the hand, folded fingers bump the outline,
    the wrist pinches in and the cuff swells out below it. As the hand turns and fingers
    close up, the webbing between them is let go, so they overlap instead of fusing."""
    crotch = crotch * V.c ** 3
    limbs = [p.sdf for p in parts if not getattr(p, 'is_stub', False)] + list(extra)
    stubs = [p.sdf for p in parts if getattr(p, 'is_stub', False)]
    body = smin(palm, sunion(crotch, *limbs), k) if limbs else palm
    if stubs:
        body = smin(body, sunion(0, *stubs), bump_k)
    neck = capsule(g, V.p((50, 100)), V.p((50, 122)), WRIST_R)
    return smin(smin(body, neck, 7.0), cuff(g), 1.5)


def cuff_lines():
    """The seam where the wrist goes into the cuff: the same arc in every drawing, from one
    wrist pinch to the other. And a short crease tick on each side of the roll; the ticks
    travel round the cuff as the hand turns, and one goes out of sight."""
    cx = V.x(50)
    seam = [(cx + dx, 115.6 + 4.6 * (1 - (dx / 18.0) ** 2)) for dx in (-18, -12, -6, 0, 6, 12, 18)]
    out = [(seam, 0.0, LINE)]
    for a in (-60, 60):
        phi = math.radians(a)
        if math.cos(phi + V.t) < 0.22:
            continue
        x = V.x(50 + CUFF_R * math.sin(phi), CUFF_R * math.cos(phi))
        lean = math.sin(phi + V.t)
        out.append(([(x + lean * 2.6, 124.0), (x + lean * 0.9, 126.2), (x - lean * 0.6, 128.6)], -0.3, DART))
    return out


def tucked_thumb(g):
    """A thumb folded under the fist. It lies below the hand, so from above only the part
    that sticks out past the left edge shows, as a lobe; turn the hand left and it slides
    out of sight underneath."""
    return limb(g, V.p((31, 96), -5), V.p((25.5, 89), -5), V.p((28, 79), -5), lambda t: 9.2 - 1.8 * t)


OUT_THUMB_Z = (-2.0, -3.0, -4.0)   # a thumb held out sits a little lower than the back of the hand


def mark_stubs(*parts):
    for p in parts:
        p.is_stub = True
    return list(parts)


def hand_pointing(g):
    palm = ball(g, (53, 85), 26, 26, 14)
    index = finger(g, (44, 70), (38.5, 44), (42, 19), 10.0)
    thumb = digit(g, (37, 83), (25.5, 81), (15, 70.5), 9.2, z=OUT_THUMB_Z)
    # The two folded fingers root on the same knuckle row as the index, so their stubs sit
    # side by side to its right, stepping down.
    stubs = mark_stubs(stub(g, (61.5, 62.5), 9.6, (55, 82)), stub(g, (74, 69.5), 8.6, (60, 84)))
    parts = [index] + stubs
    return {'base': build_hand(g, palm, parts, extra=[thumb], crotch=10.0, bump_k=4.0),
            'palm': (53, 26, 14), 'parts': parts, 'darts': darts(56, 82, 95)}


def hand_middle(g):
    palm = ball(g, (50, 86), 26, 26, 14)
    mid = finger(g, (50, 70), (53.5, 44), (50, 18.5), 9.2)
    # one folded finger on each side of the raised one
    stubs = mark_stubs(stub(g, (36.5, 63.5), 9.2, (46, 82)), stub(g, (64, 65), 9.4, (54, 82)))
    parts = [stubs[0], mid, stubs[1]]
    return {'base': build_hand(g, palm, parts), 'under': tucked_thumb(g),
            'palm': (50, 26, 14), 'parts': parts, 'darts': darts(52, 82, 95)}


def hand_peace(g):
    palm = ball(g, (51, 86), 25.5, 26, 14)
    index = finger(g, (45, 72), (34.5, 49), (31, 21.5), 8.8)
    mid = finger(g, (58, 72), (68.8, 51), (70.5, 25.5), 8.8)
    stubs = mark_stubs(stub(g, (70.5, 74), 10.0, (56, 86)))
    parts = [index, mid] + stubs
    return {'base': build_hand(g, palm, parts, crotch=7.0), 'under': tucked_thumb(g),
            'palm': (51, 25.5, 14), 'parts': parts, 'darts': darts(52.5, 83, 96)}


def hand_thumbs(g):
    palm = ball(g, (53, 86), 25, 26, 14)
    # The thumb roots low on the side of the hand, as thumbs do, and stands up leaning out:
    # shorter and fatter than a finger. The three folded fingers root on the knuckle row
    # across the top, so their stubs sit in a row to its right, stepping down, exactly as on
    # the pointing hand.
    thumb = finger(g, (38, 88), (28.5, 69), (22, 45), 12.6, root=0.74, reach=0.9)
    stubs = mark_stubs(stub(g, (48, 61.5), 8.6, (52, 82)), stub(g, (60.5, 63.5), 8.4, (56, 82)),
                       stub(g, (71.5, 69.5), 7.6, (60, 84)))
    parts = [thumb] + stubs
    return {'base': build_hand(g, palm, parts, crotch=8.0, bump_k=4.0),
            'palm': (53, 25, 14), 'parts': parts, 'darts': darts(55, 83, 96)}


def hand_rock(g):
    palm = ball(g, (51, 86), 26, 26, 14)
    index = finger(g, (39, 72), (29.5, 49), (31.5, 21), 8.6)
    pinky = finger(g, (65, 74), (74.5, 54), (73, 31.5), 7.6)
    # one folded finger between the two raised ones: a single stub
    stubs = mark_stubs(stub(g, (52.2, 63.5), 9.2, (52, 82)))
    parts = [index] + stubs + [pinky]
    return {'base': build_hand(g, palm, parts, crotch=4.0), 'under': tucked_thumb(g),
            'palm': (51, 26, 14), 'parts': parts, 'darts': darts(53, 83, 96)}


def hand_five(g):
    # a cartoon hand: three fat fingers and a thumb
    palm = ball(g, (52, 87), 26, 25, 14)
    index = finger(g, (38, 73), (26, 55), (23.5, 33.5), 8.8)
    mid = finger(g, (52, 70), (57, 44.5), (52.5, 19.5), 9.2)
    ring = finger(g, (67, 75), (80.5, 58), (83, 38.5), 8.5)
    thumb = digit(g, (36, 86), (24.5, 84.5), (13.5, 73.5), 8.6, z=OUT_THUMB_Z)
    parts = [index, mid, ring]
    return {'base': build_hand(g, palm, parts, extra=[thumb], crotch=7.0),
            'palm': (52, 26, 14), 'parts': parts, 'darts': darts(53.5, 83, 96)}


def paw(g):
    # the top of a cat's paw: a fat mitt with four toes, and a fat hooked claw on each
    cheeks = smin(ball(g, (50, 82), 33, 26, 22), ball(g, (50, 62), 29, 20, 19), 10.0)
    toes = [((24.5, 54.5), 10.6, 12.6, -32), ((39.6, 37.5), 11.4, 14.6, -10),
            ((60.4, 40.4), 11.2, 14.2, 10), ((75.5, 56), 10.6, 12.4, 32)]
    parts, claws = [], []
    for c, rx, ry, rot in toes:
        p = Part(ellipse(g, V.p(c), rx, ry, rot), V.p((c[0] * 0.55 + 22.5, c[1] + ry * 1.05)), rx * 0.6, rx * 1.9, c[0])
        parts.append(p)
        # the claw points forward out of the middle of its toe; the outer pair splay only a little
        a = math.radians(max(-20.0, min(20.0, rot)))
        ux, uy = math.sin(a), -math.cos(a)
        top = (c[0] + math.sin(math.radians(rot)) * ry * 0.9, c[1] - math.cos(math.radians(rot)) * ry * 0.9)
        hook = -1.0 if c[0] < 50 else 1.0
        root = (top[0] - ux * 2.5, top[1] - uy * 2.5)
        mid = (top[0] + ux * 3.4 + hook * 0.3, top[1] + uy * 3.4)
        tip = (top[0] + ux * 7.4 + hook * 1.9, top[1] + uy * 7.4 + 0.6)
        # the claws stay level with the roll axis, so the tallest claw's tip (the hotspot) never moves
        claws.append(limb(g, V.p(root), V.p(mid), V.p(tip), lambda t: 3.9 - 2.9 * t ** 1.3))
    return {'base': build_hand(g, cheeks, parts, k=5.0, crotch=0.0),
            'round': 3.0, 'palm': (50, 33, 22), 'parts': parts,
            'under': sunion(0, *claws), 'under_paint': CLAW, 'under_min': -1e9,
            'darts': darts(50, 78, 91, 7.4)}


# name: (shape fn, fingertip (x, y) in drawing units, paint colour)
VARIETIES = {
    'tiny-hand': (hand_pointing, (42.0, 9.0), '#2BBF9F'),
    'middle-child': (hand_middle, (50.0, 9.3), '#4490C2'),
    'peace': (hand_peace, (31.0, 12.7), '#A489D2'),
    'thumbs-up': (hand_thumbs, (22.0, 32.4), '#F2C03C'),
    'rock-on': (hand_rock, (31.5, 12.4), '#63B25F'),
    'high-five': (hand_five, (52.5, 10.3), '#EE889E'),
    'cat-paw': (paw, (34.0, 16.6), '#95C6E6'),
}


# ------------------------------------------------------------------ boil
def noise(g, seed, amp, keep_pts=(), lo=0.10, hi=0.22):
    rng = np.random.default_rng(seed)
    n = np.zeros_like(g.X)
    for _ in range(4):
        ang = rng.uniform(0, math.pi)
        f = rng.uniform(lo, hi)
        ph = rng.uniform(0, 2 * math.pi)
        n += np.sin(f * (g.X * math.cos(ang) + g.Y * math.sin(ang)) + ph)
    n = np.clip(n / 2.0 * amp, -amp, amp)
    for (px, py, r0, r1) in keep_pts:
        n = n * np.clip((np.hypot(g.X - px, g.Y - py) - r0) / (r1 - r0), 0, 1)
    return n


# ---------------------------------------------------------------- render
class SVG:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.body = []

    def path(self, d, fill):
        if d:
            self.body.append('<path d="%s" fill="%s"/>' % (d, fill))

    def text(self):
        return ('<?xml version="1.0" encoding="UTF-8"?>\n'
                '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="%d" height="%d" viewBox="0 0 %d %d">\n'
                '%s\n</svg>\n' % (self.w, self.h, self.w, self.h, '\n'.join(self.body)))


def ink_weight(g, S, wobble):
    """A brush line: a touch heavier on the lower right, with a slow wobble."""
    nx, ny = g.normals(S)
    return T0 + TA * np.clip(nx * SHX + ny * SHY, 0, 1) ** 1.4 + wobble


FIT = {}
TIPX = {}


def build(name, seed=0, roll=0):
    """One frame: seed picks the line-boil variant, roll the turn (in steps of ROLL_STEP degrees)."""
    global V
    shape_fn, tip, colour = VARIETIES[name]
    base_paint = paint(colour)
    V = View(roll * ROLL_STEP, tip[0])
    g = Grid(-6, -6, 106, 146)
    hand = shape_fn(g)
    base = hand['base']
    under = hand.get('under')
    parts = hand.get('parts', [])
    rng = np.random.default_rng(1000 + seed)
    # points the boil must leave alone: the fingertip and the cuff bottom
    keep = [(tip[0], tip[1], 12.0, 22.0), (50, 137, 8.0, 16.0)]
    if seed:
        wob = noise(g, seed, 0.3, keep)
        base = base + wob
        if under is not None:
            under = under + wob
        for p in parts:
            p.sdf = p.sdf + wob
    # webbing and rounding are let go as the fingers close up, so they overlap rather than fuse
    whole = closing(g, base, hand.get('round', ROUND) * (0.4 + 0.6 * V.c ** 2))
    wobble = noise(g, 300 + seed, 0.14 if seed else 0.08, keep, 0.05, 0.12)
    weight = ink_weight(g, whole, wobble)
    ink = whole - weight
    if under is not None:
        under = redist(g, under)
        # A tucked thumb only counts if enough of it shows. A strip thinner than the ink line
        # would just make the outline look heavy there, so it is left out. (Claws always stay.)
        showing = np.minimum(-under, ink)
        if showing.max() < hand.get('under_min', 1.3):
            under = None
        else:
            ink = np.minimum(ink, under - T0)
    # close any hairline gap left where two outlines run side by side
    ink = closing(g, ink, 0.9)
    if seed == 0 and roll == 0:
        pts = [p for loop in contours(g, ink) for p in loop]
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        k = (BOTTOM - TOP) / (max(ys) - min(ys))
        ox = 50 - 50 * k
        # keep the cuff on x = 50 unless a thumb would leave the viewBox; then slide the art over
        ox += max(0.0, MARGIN - (k * min(xs) + ox)) - max(0.0, (k * max(xs) + ox) - (100 - MARGIN))
        if k * (max(xs) - min(xs)) > 100 - 2 * MARGIN:
            raise SystemExit('%s is %.1f units wide at full height: too wide for the viewBox' % (name, k * (max(xs) - min(xs))))
        FIT[name] = (k, ox, TOP - k * min(ys))
        TIPX[name] = k * xs[ys.index(min(ys))] + ox
    sdfart.XFORM = FIT[name]

    def jit(v, a):
        return v + (rng.uniform(-a, a) if seed else 0.0)

    svg = SVG(100, 140)
    svg.body.append('<!-- tip-x %s cuff-centre-x %s -->' % (sdfart.fmt(TIPX[name]), sdfart.fmt(V.x(50) * FIT[name][0] + FIT[name][1])))
    svg.path(path_d(g, ink), INK)
    if under is not None:
        # things that lie under the hand (a tucked thumb, claws): painted first, then the hand's own line over them
        svg.path(path_d(g, under), hand.get('under_paint', base_paint))
        svg.path(path_d(g, whole - weight), INK)
    svg.path(path_d(g, whole), base_paint)

    # Fingers, stubs and toes, far to near. Turning right brings the left side nearer.
    order = sorted(parts, key=lambda p: -p.x if V.s >= 0 else p.x)
    for i, p in enumerate(order):
        d = np.hypot(g.X - p.root[0], g.Y - p.root[1])
        fade = np.clip((d - p.r0) / (p.r1 - p.r0), 0, 1) ** 0.7
        # the part's line stays inside the hand's own outline, and sinks under the paint where it fades
        ring = inter(p.sdf - ink_weight(g, p.sdf, wobble) * fade + 1.4 * (1 - fade), ink)
        # Only the band of line that will still show once this part and the nearer ones are
        # painted is drawn (with a little tucked under the paint). A nearer part can cover most
        # of a line and leave its faded tail stranded; such a scrap is dropped, not drawn.
        band = inter(ring, -(p.sdf + 0.9))
        for q in order[i + 1:]:
            # ...and where a nearer part's own line runs alongside, only that one is drawn
            band = inter(band, 2.2 - q.sdf)
        svg.path(path_d(g, band, min_area=20.0), INK)
        svg.path(path_d(g, inter(p.sdf, whole)), base_paint)

    lines = None
    pcx, prx, prz = hand['palm']
    marks = []
    for pts in hand.get('darts', []):
        # A dart is given on the flat drawing: lift it onto the rounded back of the hand, turn it
        # with the view, and let it bow toward the turn the way a line on a curved surface does.
        (xa, ya), (xb, yb), (xc, yc) = pts
        out = []
        for i in range(7):
            # resample the dart as one smooth arc, lifted onto the back of the hand and bowed with the turn
            t = i / 6.0
            x = (1 - t) ** 2 * xa + 2 * t * (1 - t) * (2 * xb - (xa + xc) / 2) + t * t * xc
            y = ya + (yc - ya) * t
            u = max(-0.97, min(0.97, (x - pcx) / prx))
            out.append((V.x(x, prz * math.sqrt(1 - u * u)) + 1.5 * V.s * math.sin(math.pi * t), y))
        # A dart keeps clear of the outline. As it nears the edge it shortens, then it is left out.
        depth = min(-whole[int(round((y - g.y0) / g.h)), int(round((x - g.x0) / g.h))] for x, y in out)
        keep_len = max(0.0, min(1.0, (depth - 2.6) / 2.6))
        if keep_len > 0.15:
            cut = int(round((1 - keep_len) * 2.0))
            marks.append((out[cut:len(out) - cut], -0.3, DART))
    for pts, taper, weight_ in marks + cuff_lines():
        last = (jit(pts[-1][0], 0.4), jit(pts[-1][1], 0.4)) if taper != 0 else pts[-1]
        pts = [pts[0]] + [(jit(x, 0.3), jit(y, 0.3)) for x, y in pts[1:-1]] + [last]
        if taper < 0:
            s = brush(g, pts, jit(weight_, 0.06), -taper, weight_ * 0.62, lead=-taper)
        else:
            s = brush(g, pts, jit(weight_, 0.06), taper)
        lines = s if lines is None else np.minimum(lines, s)
    # lines run a little way under the outline so there is no seam where they meet it
    svg.path(path_d(g, inter(lines, whole - 1.0)), INK)
    return svg.text()


def roll_suffix(roll):
    return '' if roll == 0 else '-r%s%d' % ('p' if roll > 0 else 'm', abs(roll))


def main():
    outdir = sys.argv[1]
    names = sys.argv[2:] or list(VARIETIES)
    for n in names:
        frames = [('', 0, 0), ('-b', 1, 0), ('-c', 2, 0)]
        frames += [(roll_suffix(r), 0, r) for r in range(-ROLL_MAX, ROLL_MAX + 1) if r]
        for suf, seed, roll in frames:
            txt = build(n, seed, roll)
            p = os.path.join(outdir, n + suf + '.svg')
            with open(p, 'w') as f:
                f.write(txt)
            print(p, len(txt))


if __name__ == '__main__':
    main()
