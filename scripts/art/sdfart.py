"""Tiny SDF -> SVG toolkit for moulded-plastic toy hands.

Shapes are signed distance fields sampled on a grid (numpy). Regions are
extracted with marching squares and written as plain SVG paths. Only the
NSImage-safe subset is emitted: path, ellipse, g, linear/radialGradient.
"""
import math
import numpy as np

H = 0.25  # grid step in viewBox units


class Grid:
    def __init__(self, x0, y0, x1, y1, h=H):
        self.h = h
        self.x0, self.y0 = x0, y0
        self.nx = int(round((x1 - x0) / h)) + 1
        self.ny = int(round((y1 - y0) / h)) + 1
        xs = x0 + np.arange(self.nx) * h
        ys = y0 + np.arange(self.ny) * h
        self.X, self.Y = np.meshgrid(xs, ys)

    def shift(self, F, dx, dy, fill=50.0):
        """Return G with G(p) = F(p + (dx, dy)), dx/dy rounded to grid steps."""
        ix = int(round(dx / self.h))
        iy = int(round(dy / self.h))
        G = np.full_like(F, fill)
        ny, nx = F.shape
        ys_src = slice(max(iy, 0), ny + min(iy, 0))
        ys_dst = slice(max(-iy, 0), ny + min(-iy, 0))
        xs_src = slice(max(ix, 0), nx + min(ix, 0))
        xs_dst = slice(max(-ix, 0), nx + min(-ix, 0))
        G[ys_dst, xs_dst] = F[ys_src, xs_src]
        return G

    def normals(self, F):
        gy, gx = np.gradient(F, self.h)
        n = np.sqrt(gx * gx + gy * gy) + 1e-9
        return gx / n, gy / n


# ---------------------------------------------------------------- primitives
def circle(g, c, r):
    return np.hypot(g.X - c[0], g.Y - c[1]) - r


def ellipse(g, c, rx, ry, rot=0.0):
    ca, sa = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    px = (g.X - c[0]) * ca + (g.Y - c[1]) * sa
    py = -(g.X - c[0]) * sa + (g.Y - c[1]) * ca
    k = np.hypot(px / rx, py / ry)
    return (k - 1.0) * min(rx, ry)


def round_cone(g, a, b, r1, r2):
    """Inigo Quilez round cone: sphere r1 at a, sphere r2 at b."""
    ax, ay = a
    bx, by = b
    px, py = g.X - ax, g.Y - ay
    vx, vy = bx - ax, by - ay
    l2 = vx * vx + vy * vy
    rr = r1 - r2
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    yv = px * vx + py * vy
    z = yv - l2
    xx = (px * l2 - vx * yv) ** 2 + (py * l2 - vy * yv) ** 2
    y2 = yv * yv * l2
    z2 = z * z * l2
    k = np.sign(rr) * rr * rr * xx
    out = np.empty_like(px)
    m1 = np.sign(z) * a2 * z2 > k
    m2 = (~m1) & (np.sign(yv) * a2 * y2 < k)
    m3 = ~(m1 | m2)
    out[m1] = np.sqrt(xx[m1] + z2[m1]) * il2 - r2
    out[m2] = np.sqrt(xx[m2] + y2[m2]) * il2 - r1
    out[m3] = (np.sqrt(xx[m3] * a2 * il2) + yv[m3] * rr) * il2 - r1
    return out


def capsule(g, a, b, r):
    return round_cone(g, a, b, r, r + 1e-6)


def rbox(g, c, hx, hy, r):
    qx = np.abs(g.X - c[0]) - hx + r
    qy = np.abs(g.Y - c[1]) - hy + r
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def sunion(k, *fs):
    out = fs[0]
    for f in fs[1:]:
        out = smin(out, f, k)
    return out


def finger(g, base, tip, r_base, r_neck, r_tip, k=3.0):
    """Toy finger: round cone from base to a neck point, plus a fat tip bulb."""
    bx, by = base
    tx, ty = tip
    L = math.hypot(tx - bx, ty - by)
    ux, uy = (tx - bx) / L, (ty - by) / L
    neck = (tx - ux * r_tip * 1.05, ty - uy * r_tip * 1.05)
    shaft = round_cone(g, base, neck, r_base, r_neck)
    return smin(shaft, circle(g, tip, r_tip), k)


# ---------------------------------------------------------- marching squares
def contours(g, F, level=0.0):
    """Closed loops of {F < level}, oriented so the inside is on the left
    in y-down coordinates (i.e. counter-clockwise on screen)."""
    F = F - level
    # pad so every loop closes
    P = np.full((F.shape[0] + 2, F.shape[1] + 2), 1.0)
    P[1:-1, 1:-1] = F
    x0 = g.x0 - g.h
    y0 = g.y0 - g.h
    h = g.h
    inside = P < 0
    a = inside[:-1, :-1]
    b = inside[:-1, 1:]
    c = inside[1:, 1:]
    d = inside[1:, :-1]
    case = a * 8 + b * 4 + c * 2 + d * 1
    ii, jj = np.nonzero((case > 0) & (case < 15))

    def pt(edge):
        kind, i, j = edge
        if kind == 'h':  # edge from (i,j) to (i,j+1)
            fa, fb = P[i, j], P[i, j + 1]
            t = fa / (fa - fb)
            return (x0 + (j + t) * h, y0 + i * h)
        else:  # 'v' edge from (i,j) to (i+1,j)
            fa, fb = P[i, j], P[i + 1, j]
            t = fa / (fa - fb)
            return (x0 + j * h, y0 + (i + t) * h)

    # edges of cell (i,j): T=('h',i,j) R=('v',i,j+1) B=('h',i+1,j) L=('v',i,j)
    # segments go from entry edge to exit edge with inside on the left (y down)
    table = {
        1: [('L', 'B')], 2: [('B', 'R')], 3: [('L', 'R')], 4: [('R', 'T')],
        6: [('B', 'T')], 7: [('L', 'T')], 8: [('T', 'L')], 9: [('T', 'B')],
        11: [('T', 'R')], 12: [('R', 'L')], 13: [('R', 'B')], 14: [('B', 'L')],
    }
    nxt = {}
    for i, j in zip(ii.tolist(), jj.tolist()):
        cs = int(case[i, j])
        E = {'T': ('h', i, j), 'R': ('v', i, j + 1), 'B': ('h', i + 1, j), 'L': ('v', i, j)}
        if cs in (5, 10):
            centre = (P[i, j] + P[i, j + 1] + P[i + 1, j] + P[i + 1, j + 1]) / 4 < 0
            if cs == 5:  # b and d inside
                segs = [('R', 'T'), ('L', 'B')] if not centre else [('L', 'T'), ('R', 'B')]
            else:  # a and c inside
                segs = [('T', 'L'), ('B', 'R')] if not centre else [('T', 'R'), ('B', 'L')]
        else:
            segs = table[cs]
        for s, e in segs:
            nxt[E[s]] = E[e]
    loops = []
    seen = set()
    for start in list(nxt.keys()):
        if start in seen:
            continue
        loop = []
        e = start
        while e not in seen:
            seen.add(e)
            loop.append(pt(e))
            e = nxt.get(e)
            if e is None:
                break
        if len(loop) > 3:
            loops.append(loop)
    return loops


def _rdp(pts, tol):
    if len(pts) < 3:
        return pts
    ax, ay = pts[0]
    bx, by = pts[-1]
    dx, dy = bx - ax, by - ay
    L = math.hypot(dx, dy) or 1e-9
    dmax, idx = 0.0, 0
    for k in range(1, len(pts) - 1):
        px, py = pts[k]
        d = abs((px - ax) * dy - (py - ay) * dx) / L
        if d > dmax:
            dmax, idx = d, k
    if dmax > tol:
        left = _rdp(pts[:idx + 1], tol)
        right = _rdp(pts[idx:], tol)
        return left[:-1] + right
    return [pts[0], pts[-1]]


def simplify(loop, tol=0.035):
    # split at topmost point so it is always kept exactly
    k = min(range(len(loop)), key=lambda i: (loop[i][1], loop[i][0]))
    loop = loop[k:] + loop[:k]
    n = len(loop)
    m = n // 2
    a = _rdp(loop[:m + 1], tol)
    b = _rdp(loop[m:] + [loop[0]], tol)
    return a[:-1] + b[:-1]


def fmt(v):
    s = ('%.2f' % v).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


def path_d(g, F, level=0.0, min_area=0.6, tol=0.035):
    out = []
    for loop in contours(g, F, level):
        # shoelace area to drop specks
        area = 0.0
        for k in range(len(loop)):
            x1, y1 = loop[k]
            x2, y2 = loop[(k + 1) % len(loop)]
            area += x1 * y2 - x2 * y1
        if abs(area) / 2 < min_area:
            continue
        pts = simplify(loop, tol)
        out.append('M' + ' '.join('%s %s' % (fmt(x), fmt(y)) for x, y in pts) + 'Z')
    return ''.join(out)


def band(F, inset, width_field):
    """Region with -(inset+width) < F < -inset; empty where width <= 0."""
    return np.maximum(F + inset, -(F + inset + width_field))


def inter(*fs):
    out = fs[0]
    for f in fs[1:]:
        out = np.maximum(out, f)
    return out


# ------------------------------------------------------------------ colour
def hx(c):
    c = c.lstrip('#')
    return tuple(int(c[i:i + 2], 16) / 255 for i in (0, 2, 4))


def tohex(rgb):
    return '#%02X%02X%02X' % tuple(max(0, min(255, int(round(v * 255)))) for v in rgb)


def mix(a, b, t):
    a, b = hx(a), hx(b)
    return tohex(tuple(a[i] * (1 - t) + b[i] * t for i in range(3)))


def shade(c, f):
    import colorsys
    r, g_, b = hx(c)
    h, l, s = colorsys.rgb_to_hls(r, g_, b)
    return tohex(colorsys.hls_to_rgb(h, max(0, min(1, l * f)), s))
