"""Synthesize the toy sound effects as 16-bit mono WAVs. Standard library only.
Every sound is generated here (no samples), so the files are free to use and change.
Usage: python3 assets/sfx/make_sfx.py   (writes next to this script)
"""
import math, pathlib, random, struct, wave

RATE = 44100
OUT = pathlib.Path(__file__).resolve().parent


def silence(sec):
    return [0.0] * int(RATE * sec)


def mix(*tracks):
    out = [0.0] * max(len(t) for t in tracks)
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def offset(track, sec):
    return silence(sec) + track


def env(n, attack, decay_power=1.0, hold=0.0):
    """Fast attack, optional hold, then a decay curve to zero over the rest."""
    a = max(1, int(RATE * attack))
    h = int(RATE * hold)
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        elif i < a + h:
            out.append(1.0)
        else:
            x = (i - a - h) / max(1, n - a - h)
            out.append((1 - x) ** decay_power)
    return out


def sweep(sec, f0, f1, shape='sine', curve=1.0):
    n = int(RATE * sec)
    out, phase = [], 0.0
    for i in range(n):
        x = (i / n) ** curve
        f = f0 + (f1 - f0) * x
        phase += 2 * math.pi * f / RATE
        if shape == 'sine':
            out.append(math.sin(phase))
        elif shape == 'square':
            out.append(1.0 if math.sin(phase) >= 0 else -1.0)
        elif shape == 'tri':
            out.append(2 / math.pi * math.asin(math.sin(phase)))
    return out


def noise(sec, seed):
    rng = random.Random(seed)
    return [rng.uniform(-1, 1) for _ in range(int(RATE * sec))]


def lowpass(track, cutoff_start, cutoff_end=None):
    cutoff_end = cutoff_start if cutoff_end is None else cutoff_end
    out, y, n = [], 0.0, len(track)
    for i, v in enumerate(track):
        c = cutoff_start + (cutoff_end - cutoff_start) * i / max(1, n)
        k = 1 - math.exp(-2 * math.pi * c / RATE)
        y += k * (v - y)
        out.append(y)
    return out


def highpass(track, cutoff):
    low = lowpass(track, cutoff)
    return [a - b for a, b in zip(track, low)]


def shaped(track, envelope, gain=1.0):
    return [v * e * gain for v, e in zip(track, envelope)]


def thud(sec, f0, f1, seed, gain=1.0, grit=0.5, grit_cut=900):
    """Heavy body: falling sine plus low-passed noise for dirt and stone."""
    body = shaped(sweep(sec, f0, f1, curve=0.5), env(int(RATE * sec), 0.004, 2.5), gain)
    dirt = shaped(lowpass(noise(sec, seed), grit_cut, 150), env(int(RATE * sec), 0.002, 4), gain * grit)
    return mix(body, dirt)


def whoosh(sec, seed, c0, c1, gain=0.5, attack=0.3):
    n = int(RATE * sec)
    e = env(n, sec * attack, 2)
    return shaped(lowpass(highpass(noise(sec, seed), 200), c0, c1), e, gain * 3)


def band(track, lo, hi):
    return lowpass(highpass(track, lo), hi)


def grains(sec, count, seed, lo=300, hi=2500, gain=0.4, grain=0.012):
    """Debris: many tiny noise clicks scattered over time, falling off. Gravel, not a ring."""
    rng = random.Random(seed)
    out = silence(sec)
    for _ in range(count):
        at = int(RATE * sec * rng.random() ** 1.8)
        g = band(noise(grain * rng.uniform(0.5, 1.5), rng.random()), lo, hi)
        g = shaped(g, env(len(g), 0.0005, 3), gain * rng.uniform(0.3, 1.0) * (1 - at / len(out)))
        for i, v in enumerate(g):
            if at + i < len(out):
                out[at + i] += v
    return out


def punch(sec, f0, f1, seed, gain=1.0, cut=1800):
    """Muffled impact on a body: short low thump plus a lowpassed slap of noise, no ring."""
    n = int(RATE * sec)
    body = shaped(sweep(sec, f0, f1, curve=0.4), env(n, 0.002, 3), gain)
    slap = shaped(lowpass(noise(sec, seed), cut, 300), env(n, 0.001, 6), gain * 0.9)
    return mix(body, slap)


def swell(sec, freqs, gain=0.2, attack=0.35):
    """Soft pad: sines with a slow attack and gentle tail, for rewards (no beeps)."""
    n = int(RATE * sec)
    e = env(n, sec * attack, 1.6)
    tracks = [shaped(sweep(sec, f, f * 1.003), e, gain / (1 + 0.5 * j)) for j, f in enumerate(freqs)]
    return lowpass(mix(*tracks), 2500)


SOUNDS = {
    # Golem: stone and earth, all noise and low thumps.
    'golem_step': lambda: mix(thud(0.42, 75, 32, 1, gain=0.9, grit=0.6), grains(0.35, 14, 101, 200, 1500, 0.25)),
    'golem_slam': lambda: mix(thud(0.7, 90, 28, 2, gain=1.0, grit=0.9, grit_cut=1500), grains(0.6, 40, 102, 250, 2200, 0.5)),
    'golem_stomp': lambda: mix(thud(0.9, 70, 24, 4, gain=1.0, grit=1.0, grit_cut=700), offset(shaped(lowpass(noise(0.8, 5), 300), env(int(RATE * 0.8), 0.05, 2), 0.8), 0.05), grains(0.7, 30, 103, 200, 1500, 0.4)),
    'golem_windup': lambda: mix(shaped(lowpass(noise(0.45, 6), 250, 900), env(int(RATE * 0.45), 0.3, 1.5), 1.6), grains(0.45, 12, 104, 300, 1800, 0.15)),
    'golem_sweep': lambda: whoosh(0.5, 7, 300, 1400, gain=0.6, attack=0.45),
    'golem_kneel': lambda: mix(shaped(lowpass(noise(0.9, 8), 1200, 200), env(int(RATE * 0.9), 0.01, 1.5), 0.7), grains(0.9, 60, 105, 250, 2000, 0.45)),
    'golem_land': lambda: mix(thud(1.0, 65, 20, 11, gain=1.0, grit=1.0, grit_cut=600), grains(0.8, 40, 106, 200, 1600, 0.4)),
    'golem_die': lambda: mix(thud(1.6, 55, 18, 12, gain=1.0, grit=1.2, grit_cut=800), grains(1.6, 140, 107, 200, 2200, 0.5), offset(thud(0.6, 60, 25, 108, gain=0.7), 0.5)),
    'golem_shake': lambda: shaped(lowpass(noise(0.4, 20), 500), [abs(math.sin(i / RATE * 2 * math.pi * 14)) * e for i, e in enumerate(env(int(RATE * 0.4), 0.01, 1))], 1.4),
    'rock_pop': lambda: mix(punch(0.12, 140, 70, 21, gain=0.5, cut=1200), grains(0.2, 10, 109, 300, 1800, 0.3)),
    'rock_hit': lambda: mix(thud(0.4, 120, 45, 22, gain=0.9, grit=0.9, grit_cut=1600), grains(0.45, 35, 110, 250, 2200, 0.55)),
    # Player hits on stone: dull crunch, never a ring.
    'weak_hit': lambda: mix(punch(0.3, 170, 60, 24, gain=0.9, cut=2200), grains(0.35, 45, 111, 400, 3500, 0.5), offset(thud(0.3, 90, 40, 112, gain=0.5, grit=0.4), 0.02)),
    'body_hit': lambda: mix(punch(0.16, 150, 80, 26, gain=0.6, cut=1200), grains(0.15, 10, 113, 250, 1400, 0.25)),
    'swing': lambda: whoosh(0.14, 28, 1500, 4000, gain=0.25, attack=0.3),
    # Player movement: air and footing.
    'jump': lambda: shaped(band(noise(0.09, 40), 300, 1600), env(int(RATE * 0.09), 0.004, 3), 0.5),
    'wall_jump': lambda: mix(shaped(band(noise(0.1, 41), 300, 1600), env(int(RATE * 0.1), 0.004, 3), 0.5), grains(0.08, 6, 114, 400, 2500, 0.25)),
    'dash': lambda: whoosh(0.2, 30, 2500, 700, gain=0.35, attack=0.1),
    'dodge': lambda: mix(whoosh(0.22, 31, 5000, 1200, gain=0.4, attack=0.08), offset(whoosh(0.12, 42, 3000, 900, gain=0.2, attack=0.1), 0.06)),
    'grab': lambda: mix(punch(0.1, 110, 60, 32, gain=0.5, cut=900), grains(0.06, 5, 115, 300, 1800, 0.2)),
    'launch': lambda: mix(punch(0.15, 90, 45, 33, gain=0.6, cut=900), whoosh(0.32, 43, 3500, 900, gain=0.45, attack=0.05)),
    'hurt': lambda: mix(punch(0.22, 130, 55, 34, gain=1.0, cut=1600), grains(0.1, 6, 116, 300, 1500, 0.2)),
    'death': lambda: mix(punch(0.35, 110, 40, 35, gain=1.0, cut=1300), offset(whoosh(0.5, 44, 1200, 250, gain=0.35, attack=0.2), 0.08)),
    # Rewards: soft swells instead of beeps.
    'checkpoint': lambda: swell(0.6, [220, 330], gain=0.25, attack=0.25),
    'goal': lambda: mix(swell(0.9, [196, 294, 392], gain=0.25, attack=0.3), whoosh(0.6, 45, 600, 3000, gain=0.15, attack=0.6)),
    'win': lambda: mix(swell(2.2, [131, 196, 262, 330], gain=0.28, attack=0.3), thud(0.8, 60, 30, 117, gain=0.4, grit=0.3)),
}


def write(name, track):
    peak = max(1e-6, max(abs(v) for v in track))
    scale = min(1.0, 0.9 / peak)
    fade = int(RATE * 0.005)
    data = bytearray()
    for i, v in enumerate(track):
        if i >= len(track) - fade:
            v *= (len(track) - i) / fade
        data += struct.pack('<h', int(max(-1, min(1, v * scale)) * 32767))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(bytes(data))


if __name__ == '__main__':
    for name, make in SOUNDS.items():
        write(name, make())
    print(len(SOUNDS), 'sounds written to', OUT)
