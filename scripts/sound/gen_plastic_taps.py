"""Synthesise original "plastic toy hand" tap sounds (modal synthesis, no samples).

  python3 gen_plastic_taps.py OUT_DIR [--seed N]

Writes tap-01..10.wav, poke-01..10.wav, thwack-01..05.wav (44.1 kHz, mono, 16-bit).

Model (targets come from tapstats.py on reference clips of a small plastic hand on a
stick tapping screens):
  * body   : damped sinusoidal modes of a light hollow plastic shell + rod. Plastic has
             high internal damping (loss factor eta ~0.03-0.05) so every mode dies in a few
             tens of ms and high modes die fastest: tau_i = 1 / (pi * f_i * eta).
             Glass/metal have eta ~0.001, which is why the old sounds rang.
  * contact: the modes are driven by a half-sine force pulse of 0.2-0.55 ms (hard vinyl
             fingertip), which also rolls off the top end naturally.
  * click  : a 4-8 ms burst of noise, high-passed and shaped with broad bumps near
             2.4 / 4.6 / 6.6 kHz - the dry "tik" of hard plastic on glass.
  * grit   : a little band-passed noise (300 Hz-2 kHz, tau ~6 ms) so it reads as a
             hollow knock rather than a pure chime.
  * level  : tanh soft-clip of the mix (drive 3-3.5) so the click spike doesn't set the
             peak on its own, then -3 dBFS peak normalisation, 70 Hz high-pass (no DC),
             25 ms raised-cosine fade-out.
  * bounce : optional second contact 9-20 ms later at -12..-16 dB (seen in ~20% of
             reference taps), and for thwack a short rattle of 2-4 micro-contacts.
"""
import math, os, sys, wave
import numpy as np

SR = 44100
TAU_MIN = 0.012


# ---------------------------------------------------------------- filters
def biquad(x, b, a):
    b0, b1, b2 = b; a0, a1, a2 = a
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for n in range(len(x)):
        xn = x[n]
        yn = b0 * xn + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        y[n] = yn
        x2, x1, y2, y1 = x1, xn, y1, yn
    return y


def rbj(kind, f0, q=0.707, gain_db=0.0):
    w = 2 * math.pi * f0 / SR; c = math.cos(w); s = math.sin(w); al = s / (2 * q)
    A = 10 ** (gain_db / 40)
    if kind == 'hp':
        return (((1 + c) / 2, -(1 + c), (1 + c) / 2), (1 + al, -2 * c, 1 - al))
    if kind == 'lp':
        return (((1 - c) / 2, 1 - c, (1 - c) / 2), (1 + al, -2 * c, 1 - al))
    if kind == 'bp':
        return ((al, 0, -al), (1 + al, -2 * c, 1 - al))
    if kind == 'peak':
        return ((1 + al * A, -2 * c, 1 - al * A), (1 + al / A, -2 * c, 1 - al / A))
    raise ValueError(kind)


def filt(x, *specs):
    for sp in specs:
        x = biquad(x, *rbj(*sp))
    return x


# ---------------------------------------------------------------- components
def half_sine(dur_s):
    n = max(2, int(dur_s * SR))
    p = np.sin(np.pi * np.arange(n) / (n - 1))
    return p / p.sum()


def modal_body(n, modes, eta, rng, eta_floor_tau=None):
    """modes: list of (freq, amp). eta: loss factor. Returns impulse response."""
    t = np.arange(n) / SR
    y = np.zeros(n)
    for f, a in modes:
        tau = max(1.0 / (math.pi * f * eta), TAU_MIN)  # upper modes keep a few ms of 'tock'
        if eta_floor_tau is not None:
            tau = min(tau, eta_floor_tau)
        ph = rng.uniform(0, 2 * math.pi) * 0.25  # mostly sine-phase start (no step)
        y += a * np.exp(-t / tau) * np.sin(2 * math.pi * f * t + ph)
    return y


def noise_burst(n, tau, rng, rise=0.0002):
    t = np.arange(n) / SR
    env = np.exp(-t / tau) * (1 - np.exp(-t / rise))
    return rng.standard_normal(n) * env


def click(n, rng, tau, bright):
    """Hard-plastic contact click. bright in [0,1] tilts energy toward 4-7 kHz."""
    x = noise_burst(n, tau, rng)
    x = filt(x, ('hp', 1100, 0.7), ('hp', 1100, 0.7),
             ('peak', 2400, 1.4, 5.0), ('peak', 4600, 1.6, 2.0 + 4 * bright),
             ('peak', 6600, 1.8, 1.0 + 4 * bright), ('lp', 9000 + 3000 * bright, 0.7))
    return x


def grit(n, rng, tau, centre):
    x = noise_burst(n, tau, rng, rise=0.0004)
    return filt(x, ('bp', centre, 0.7), ('hp', 280, 0.7))


# ---------------------------------------------------------------- presets
# Base mode table for the hollow plastic hand + rod (Hz, relative amplitude).
# Frequencies follow the reference's recurring per-tap peaks:
#   ~200, 300-350, 420-490, 590-700, 800-900, ~1080, 1550-1680 Hz, plus a weak 2.4 kHz.
BASE_MODES = [(205, 0.80), (335, 0.70), (462, 0.85), (648, 0.65), (842, 0.60),
              (1085, 0.60), (1630, 0.62), (2440, 0.30), (3350, 0.12)]

SETS = {
    #            n  len_s  pitch-range    eta range      contact(ms)   click lvl  click tau(ms) bright   grit  low-mode gain  bounce prob  rattle
    'tap':    dict(count=10, length=0.110, pitch=(0.98, 1.10), eta=(0.040, 0.052), tc=(0.22, 0.32),
                   click=(2.6, 3.2), ctau=(0.6, 1.0), bright=(0.45, 0.9), grit=0.75, low=1.1,
                   bounce=0.3, rattle=0, tau_cap=0.024, drive=3.0),
    'poke':   dict(count=10, length=0.140, pitch=(0.86, 0.95), eta=(0.034, 0.044), tc=(0.30, 0.42),
                   click=(2.0, 2.6), ctau=(0.8, 1.2), bright=(0.3, 0.7), grit=0.7, low=1.2,
                   bounce=0.3, rattle=0, tau_cap=0.026, drive=3.0),
    'thwack': dict(count=5, length=0.230, pitch=(0.76, 0.84), eta=(0.028, 0.036), tc=(0.40, 0.55),
                   click=(2.0, 2.5), ctau=(1.0, 1.5), bright=(0.5, 0.9), grit=0.75, low=1.3,
                   bounce=0.0, rattle=(2, 4), tau_cap=0.032, drive=3.5),
}


def render(name, idx, p, rng):
    n = int(p['length'] * SR)
    pitch = rng.uniform(*p['pitch'])
    eta = rng.uniform(*p['eta'])
    modes = []
    for k, (f, a) in enumerate(BASE_MODES):
        f = f * pitch * (1 + rng.uniform(-0.055, 0.055))   # per-mode +-3-6% detune
        a = a * rng.uniform(0.75, 1.25)
        if k == 0:
            a *= p['low']
        if k == 1:
            a *= (0.5 + 0.5 * p['low'])
        modes.append((f, a))
    body = modal_body(n, modes, eta, rng, eta_floor_tau=p['tau_cap'])
    body = np.convolve(body, half_sine(rng.uniform(*p['tc']) / 1000))[:n]
    body /= np.max(np.abs(body)) + 1e-12

    cl = click(n, rng, rng.uniform(*p['ctau']) / 1000, rng.uniform(*p['bright']))
    cl /= np.max(np.abs(cl)) + 1e-12
    gr = grit(n, rng, rng.uniform(0.004, 0.008), rng.uniform(1200, 2000) * pitch)
    gr /= np.max(np.abs(gr)) + 1e-12

    clv = rng.uniform(*p['click'])
    y = body + clv * cl + p['grit'] * gr
    tags = []

    # second contact (small bounce of the hand)
    if rng.uniform() < p['bounce']:
        d = int(rng.uniform(0.009, 0.020) * SR)
        g = 10 ** (rng.uniform(-13, -9) / 20)
        b2 = click(n - d, rng, 0.0006, 0.6)
        b2 /= np.max(np.abs(b2)) + 1e-12
        y[d:] += g * (clv * b2 + 0.8 * body[: n - d])
        tags.append(f'bounce@{d / SR * 1000:.0f}ms')
    # rattle: hand wobbling on the stick after a hard smack
    if p['rattle']:
        k = rng.integers(p['rattle'][0], p['rattle'][1] + 1)
        tpos = 0.014
        g_db = -10
        for _ in range(k):
            tpos += rng.uniform(0.010, 0.020)
            d = int(tpos * SR)
            g = 10 ** ((g_db + rng.uniform(-2, 2)) / 20)
            r = click(n - d, rng, 0.0005, 0.5)
            r /= np.max(np.abs(r)) + 1e-12
            hi = modal_body(n - d, [(f, a) for f, a in modes[3:]], eta * 1.4, rng, p['tau_cap'])
            hi /= np.max(np.abs(hi)) + 1e-12
            y[d:] += g * (clv * 0.5 * r + 0.2 * hi)
            tags.append(f'rattle@{tpos * 1000:.0f}ms')
            g_db -= rng.uniform(3, 5)

    # Soft-clip the first-millisecond spike so the body, not a 3-sample click, sets the
    # level (crest factor ~24 dB -> ~17 dB; keeps loudness close to the old set).
    y = y / np.max(np.abs(y))
    y = np.tanh(p['drive'] * y) / math.tanh(p['drive'])
    # DC / sub-rumble removal, fade-out, normalise to -3 dBFS
    y = filt(y, ('hp', 70, 0.7))
    y -= y.mean()
    fo = int(0.025 * SR)
    y[-fo:] *= 0.5 * (1 + np.cos(np.linspace(0, np.pi, fo)))
    y[:16] *= np.linspace(0, 1, 16)
    y *= 10 ** (-3 / 20) / np.max(np.abs(y))
    return y, dict(pitch=round(pitch, 3), eta=round(eta, 4), modes=[round(f) for f, _ in modes], extra=tags)


def write_wav(path, y):
    d = np.clip(np.round(y * 32767 + np.random.default_rng(0).uniform(-0.5, 0.5, len(y))), -32768, 32767)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(d.astype('<i2').tobytes())


def main():
    out = sys.argv[1]
    seed = int(sys.argv[sys.argv.index('--seed') + 1]) if '--seed' in sys.argv else 7
    os.makedirs(out, exist_ok=True)
    rng = np.random.default_rng(seed)
    for name, p in SETS.items():
        for i in range(1, p['count'] + 1):
            y, info = render(name, i, p, rng)
            fn = os.path.join(out, f'{name}-{i:02d}.wav')
            write_wav(fn, y)
            print(fn.split('/')[-1], info)


if __name__ == '__main__':
    main()
