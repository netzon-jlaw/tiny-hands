import math, re, sys
hand_svg = open(sys.argv[1]).read()
out = sys.argv[2]
defs = re.search(r'<defs>\n(.*?)\n</defs>', hand_svg, re.S).group(1)
body = re.search(r'</defs>\n(.*)\n</svg>', hand_svg, re.S).group(1)
outline_path = re.search(r'<path d="([^"]+)"', body).group(1)

N, LO, HI = 5.0, 100.0, 924.0
C, R = 512.0, 412.0
def sq(t):
    c, s = math.cos(t), math.sin(t)
    return (C + R * math.copysign(abs(c) ** (2 / N), c), C + R * math.copysign(abs(s) ** (2 / N), s))
def inside(x, y):
    return (abs(x - C) / R) ** N + (abs(y - C) / R) ** N <= 1.0
pts = [sq(2 * math.pi * k / 240) for k in range(240)]
squ = 'M' + ' '.join('%.2f %.2f' % p for p in pts) + 'Z'

S, ANG = 4.1, -25.0
CX, CY = 622.0, 722.0
NOBG = len(sys.argv) > 3
th = math.radians(ANG)
def g2(x, y):
    x, y = (x - 50) * S, (y - 138) * S
    return (CX + x * math.cos(th) - y * math.sin(th), CY + x * math.sin(th) + y * math.cos(th))
tip = g2(40, 2)
# rod: centreline from local (50,132) downward, cut exactly at the squircle edge
d = (-math.sin(th), math.cos(th))           # local +y after rotation
n = (math.cos(th), math.sin(th))            # local +x after rotation
hw = 8.0 * S
start = g2(50, 130)
def exit_point(off):
    ox, oy = start[0] + n[0] * off, start[1] + n[1] * off
    lo, hi = 0.0, 900.0
    for _ in range(60):
        mid = (lo + hi) / 2
        if inside(ox + d[0] * mid, oy + d[1] * mid):
            lo = mid
        else:
            hi = mid
    lo -= 2.5
    return (ox, oy), (ox + d[0] * lo, oy + d[1] * lo)
(a0, a1), (b0, b1) = exit_point(-hw), exit_point(hw)
# sample the squircle between the two exit points so the cut follows the curve
rod = 'M%.2f %.2f L%.2f %.2f ' % (a0[0], a0[1], a1[0], a1[1])
steps = 12
for k in range(1, steps):
    off = -hw + 2 * hw * k / steps
    _, p = exit_point(off)
    rod += 'L%.2f %.2f ' % p
rod += 'L%.2f %.2f L%.2f %.2f Z' % (b1[0], b1[1], b0[0], b0[1])
gx1, gy1 = start[0] - n[0] * hw, start[1] - n[1] * hw
gx2, gy2 = start[0] + n[0] * hw, start[1] + n[1] * hw
streak_off = -hw * 0.42
s0 = (start[0] + n[0] * streak_off, start[1] + n[1] * streak_off)
_, s1 = exit_point(streak_off)
s1 = (s1[0] - d[0] * 6, s1[1] - d[1] * 6)

D = [defs,
     '<linearGradient id="bgG" x1="0" y1="0" x2="0.35" y2="1"><stop offset="0" stop-color="#F8B35A"/>'
     '<stop offset="0.55" stop-color="#EE8A3A"/><stop offset="1" stop-color="#DB6A2C"/></linearGradient>',
     '<radialGradient id="bgGlow" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#FFE9B8" stop-opacity="0.75"/>'
     '<stop offset="0.5" stop-color="#FFD58F" stop-opacity="0.3"/><stop offset="1" stop-color="#FFD58F" stop-opacity="0"/></radialGradient>',
     '<linearGradient id="rodG" x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" gradientUnits="userSpaceOnUse">'
     '<stop offset="0" stop-color="#4E4F53"/><stop offset="0.12" stop-color="#8E8F93"/><stop offset="0.28" stop-color="#E2E2DF"/>'
     '<stop offset="0.4" stop-color="#C8C8C6"/><stop offset="0.7" stop-color="#97989B"/><stop offset="1" stop-color="#46474B"/></linearGradient>'
     % (gx1, gy1, gx2, gy2)]
B = ['<path d="%s" fill="url(#bgG)"/>' % squ,
     '<ellipse cx="%.1f" cy="%.1f" rx="122" ry="122" fill="url(#bgGlow)"/>' % tip]
for r, w, op in ((58, 14, 0.75), (104, 11, 0.5), (150, 8, 0.28)):
    B.append('<ellipse cx="%.1f" cy="%.1f" rx="%d" ry="%d" fill="none" stroke="#FFF3DA" stroke-width="%d" stroke-opacity="%.2f"/>'
             % (tip[0], tip[1], r, int(r * 0.82), w, op))
B.append('<path d="%s" fill="#9C4518" fill-opacity="0.28"/>' % rod.replace('M', 'M', 1))
B.append('<path d="%s" fill="url(#rodG)" stroke="#3E3F43" stroke-width="3" stroke-opacity="0.6"/>' % rod)
B.append('<path d="M%.2f %.2f L%.2f %.2f" stroke="#FFFFFF" stroke-width="7" stroke-linecap="round" stroke-opacity="0.9"/>'
         % (s0[0], s0[1], s1[0], s1[1]))
tr = 'translate(%.2f %.2f) rotate(%.1f) scale(%.3f) translate(-50 -138)' % (CX, CY, ANG, S)
B.append('<g transform="translate(16 20)"><g transform="%s"><path d="%s" fill="#9C4518" fill-opacity="0.3"/></g></g>' % (tr, outline_path))
B.append('<g transform="%s">\n%s\n</g>' % (tr, body))
if NOBG:
    B = [b for b in B if 'bgG' not in b and 'FFF3DA' not in b and 'fill-opacity="0.3"' not in b and 'fill-opacity="0.28"' not in b]
svg = ('<?xml version="1.0" encoding="UTF-8"?>\n'
       '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="1024" height="1024" viewBox="0 0 1024 1024">\n'
       '<defs>\n' + '\n'.join(D) + '\n</defs>\n' + '\n'.join(B) + '\n</svg>\n')
open(out, 'w').write(svg)
print('tip', tip, 'rod exit', a1, b1)
