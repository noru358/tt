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


def crack(sec, seed, cutoff=3000, gain=0.6):
    return shaped(highpass(noise(sec, seed), cutoff), env(int(RATE * sec), 0.001, 6), gain)


def whoosh(sec, seed, c0, c1, gain=0.5, attack=0.3):
    n = int(RATE * sec)
    e = env(n, sec * attack, 2)
    return shaped(lowpass(highpass(noise(sec, seed), 200), c0, c1), e, gain * 3)


def chime(sec, freqs, gain=0.3, decay=3):
    tracks = []
    for j, f in enumerate(freqs):
        tracks.append(shaped(sweep(sec, f, f), env(int(RATE * sec), 0.002, decay), gain / (1 + 0.4 * j)))
    return mix(*tracks)


def arpeggio(notes, step, sec, shape='tri', gain=0.25):
    tracks = [offset(shaped(sweep(sec, f, f, shape), env(int(RATE * sec), 0.004, 2), gain), i * step) for i, f in enumerate(notes)]
    return mix(*tracks)


SOUNDS = {
    # Golem
    'golem_step': lambda: thud(0.42, 75, 32, 1, gain=0.9, grit=0.6),
    'golem_slam': lambda: mix(thud(0.7, 90, 28, 2, gain=1.0, grit=0.9, grit_cut=1500), crack(0.18, 3, 2500, 0.5)),
    'golem_stomp': lambda: mix(thud(0.9, 70, 24, 4, gain=1.0, grit=1.0, grit_cut=700), offset(shaped(lowpass(noise(0.8, 5), 300), env(int(RATE * 0.8), 0.05, 2), 0.8), 0.05)),
    'golem_windup': lambda: shaped(lowpass(noise(0.45, 6), 250, 900), env(int(RATE * 0.45), 0.3, 1.5), 1.6),
    'golem_sweep': lambda: whoosh(0.5, 7, 300, 1400, gain=0.6, attack=0.45),
    'golem_kneel': lambda: mix(shaped(lowpass(noise(0.9, 8), 1200, 200), env(int(RATE * 0.9), 0.01, 1.5), 0.7), offset(crack(0.12, 9, 2000, 0.4), 0.05), offset(crack(0.1, 10, 2500, 0.3), 0.22)),
    'golem_land': lambda: thud(1.0, 65, 20, 11, gain=1.0, grit=1.0, grit_cut=600),
    'golem_die': lambda: mix(thud(1.6, 55, 18, 12, gain=1.0, grit=1.2, grit_cut=800), *[offset(crack(0.15, 13 + i, 1800 + 300 * i, 0.35), 0.12 * i) for i in range(6)]),
    'golem_shake': lambda: shaped(lowpass(noise(0.4, 20), 500), [abs(math.sin(i / RATE * 2 * math.pi * 14)) * e for i, e in enumerate(env(int(RATE * 0.4), 0.01, 1))], 1.4),
    'rock_pop': lambda: mix(shaped(sweep(0.12, 300, 120), env(int(RATE * 0.12), 0.002, 3), 0.4), crack(0.08, 21, 1500, 0.3)),
    'rock_hit': lambda: mix(thud(0.4, 140, 50, 22, gain=0.8, grit=0.8, grit_cut=2500), crack(0.2, 23, 2000, 0.6)),
    # Player hits on the golem
    'weak_hit': lambda: mix(chime(0.5, [1320, 1980, 2640], 0.35), crack(0.12, 24, 4000, 0.5), thud(0.2, 220, 90, 25, gain=0.4, grit=0.3)),
    'body_hit': lambda: mix(thud(0.18, 160, 80, 26, gain=0.5, grit=0.7, grit_cut=1800), crack(0.06, 27, 2500, 0.25)),
    'swing': lambda: whoosh(0.14, 28, 1500, 4000, gain=0.25, attack=0.3),
    # Player
    'jump': lambda: shaped(sweep(0.1, 260, 520, 'tri'), env(int(RATE * 0.1), 0.003, 2), 0.25),
    'wall_jump': lambda: mix(shaped(sweep(0.11, 330, 660, 'tri'), env(int(RATE * 0.11), 0.003, 2), 0.25), crack(0.04, 29, 1500, 0.2)),
    'dash': lambda: whoosh(0.2, 30, 2500, 700, gain=0.35, attack=0.1),
    'dodge': lambda: mix(chime(0.35, [1760, 2637], 0.22, decay=2), whoosh(0.15, 31, 4000, 1500, gain=0.15, attack=0.1)),
    'grab': lambda: mix(shaped(sweep(0.18, 900, 1800, 'tri'), env(int(RATE * 0.18), 0.002, 3), 0.25), crack(0.03, 32, 3000, 0.4)),
    'launch': lambda: mix(shaped(sweep(0.22, 180, 700), env(int(RATE * 0.22), 0.002, 2), 0.35), whoosh(0.3, 33, 3500, 900, gain=0.35, attack=0.05)),
    'hurt': lambda: mix(shaped(sweep(0.28, 520, 160, 'square'), env(int(RATE * 0.28), 0.002, 1.5), 0.16), crack(0.08, 34, 1200, 0.35)),
    'death': lambda: mix(shaped(sweep(0.6, 440, 70, 'square'), env(int(RATE * 0.6), 0.002, 1.2), 0.14), crack(0.1, 35, 1000, 0.3)),
    'checkpoint': lambda: arpeggio([784, 1175], 0.07, 0.3, gain=0.22),
    'goal': lambda: arpeggio([523, 659, 784, 1047], 0.08, 0.35, gain=0.22),
    'win': lambda: mix(arpeggio([392, 523, 659, 784, 1047], 0.11, 0.6, gain=0.22), offset(chime(1.0, [1047, 1568], 0.18, decay=2), 0.55)),
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
