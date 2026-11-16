import sys
out = sys.argv[1]
secs = [(0.0, 24.0, 0.0, 140.0), (1.5, 22.5, 140.0, 272.0), (3.0, 21.0, 272.0, 400.0)]
D = []
B = []
D.append('<linearGradient id="metal" x1="0" y1="0" x2="1" y2="0">'
         '<stop offset="0" stop-color="#4E4F53"/><stop offset="0.1" stop-color="#8A8B8F"/>'
         '<stop offset="0.24" stop-color="#D8D8D6"/><stop offset="0.34" stop-color="#F4F3EF"/>'
         '<stop offset="0.46" stop-color="#C9C9C7"/><stop offset="0.66" stop-color="#9C9D9F"/>'
         '<stop offset="0.86" stop-color="#727377"/><stop offset="1" stop-color="#46474B"/></linearGradient>')
D.append('<linearGradient id="lip" x1="0" y1="0" x2="1" y2="0">'
         '<stop offset="0" stop-color="#3E3F43"/><stop offset="0.25" stop-color="#B9B9B7"/>'
         '<stop offset="0.36" stop-color="#FFFFFF"/><stop offset="0.5" stop-color="#A9AAAB"/>'
         '<stop offset="1" stop-color="#3A3B3F"/></linearGradient>')
D.append('<linearGradient id="shadeV" x1="0" y1="0" x2="0" y2="1">'
         '<stop offset="0" stop-color="#2E2F33" stop-opacity="0.55"/>'
         '<stop offset="1" stop-color="#2E2F33" stop-opacity="0"/></linearGradient>')
D.append('<radialGradient id="hole" cx="0.5" cy="0.45" r="0.5">'
         '<stop offset="0" stop-color="#1E1F22"/><stop offset="0.7" stop-color="#3A3B3F"/>'
         '<stop offset="1" stop-color="#6B6C70"/></radialGradient>')
for i, (x0, x1, y0, y1) in enumerate(secs):
    w = x1 - x0
    B.append('<rect x="%g" y="%g" width="%g" height="%g" fill="url(#metal)"/>' % (x0, y0, w, y1 - y0 + (0.6 if i < 2 else 0)))
    # bright specular streak and a soft secondary sheen
    B.append('<rect x="%g" y="%g" width="%g" height="%g" rx="%g" fill="#FFFFFF" fill-opacity="0.9"/>'
             % (x0 + w * 0.29, y0 + 3, w * 0.075, y1 - y0 - 6, w * 0.0375))
    B.append('<rect x="%g" y="%g" width="%g" height="%g" fill="#FFFFFF" fill-opacity="0.18"/>'
             % (x0 + w * 0.7, y0 + 2, w * 0.05, y1 - y0 - 4))
    # thin darker edges so it holds on light backgrounds
    B.append('<rect x="%g" y="%g" width="0.9" height="%g" fill="#2F3034" fill-opacity="0.55"/>' % (x0, y0, y1 - y0))
    B.append('<rect x="%g" y="%g" width="0.9" height="%g" fill="#2F3034" fill-opacity="0.55"/>' % (x1 - 0.9, y0, y1 - y0))
    if i > 0:
        # the narrower tube's top is shaded where it slides out of the wider one
        B.append('<rect x="%g" y="%g" width="%g" height="7" fill="url(#shadeV)"/>' % (x0, y0, w))
    if i < 2:
        # rolled lip at the end of each wider section
        B.append('<rect x="%g" y="%g" width="%g" height="5" rx="1.2" fill="url(#lip)"/>' % (x0, y1 - 5, w))
        B.append('<rect x="%g" y="%g" width="%g" height="0.8" fill="#FFFFFF" fill-opacity="0.55"/>' % (x0 + 1, y1 - 4.6, w - 2))
        B.append('<rect x="%g" y="%g" width="%g" height="0.8" fill="#26272A" fill-opacity="0.45"/>' % (x0 + 1, y1 - 0.8, w - 2))
# two little holes near the top, as on the real pointer
for cy in (22.0, 31.0):
    B.append('<ellipse cx="16.2" cy="%g" rx="1.25" ry="1.5" fill="url(#hole)"/>' % cy)
    B.append('<ellipse cx="16.35" cy="%g" rx="1.0" ry="0.35" fill="#FFFFFF" fill-opacity="0.5"/>' % (cy + 1.75))
svg = ('<?xml version="1.0" encoding="UTF-8"?>\n'
       '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="24" height="400" viewBox="0 0 24 400">\n'
       '<defs>\n' + '\n'.join(D) + '\n</defs>\n' + '\n'.join(B) + '\n</svg>\n')
open(out, 'w').write(svg)
