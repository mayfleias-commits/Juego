#!/usr/bin/env python3
"""Sintetiza todos los sonidos del juego (originales, CC0). Salida: assets/audio/*.wav (mono, 22050 Hz, 16 bits)."""
import numpy as np, wave, os
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1234)

def save(name, x, loop=False):
    x = np.asarray(x, dtype=np.float64)
    if loop:
        # fundido cruzado para que el bucle no haga clic
        n = int(0.25 * SR)
        x[:n] = x[:n] * np.linspace(0, 1, n) + x[-n:] * np.linspace(1, 0, n)
        x = x[:-n]
    m = np.max(np.abs(x)) or 1.0
    x = x / m * 0.9
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())

def t(sec):
    return np.arange(int(sec * SR)) / SR

def lowpass(x, a):
    y = np.zeros_like(x); acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc); y[i] = acc
    return y

def env(n, a=0.01, r=0.3):
    e = np.ones(n); na = max(1, int(a * SR)); nr = max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na); e[-nr:] = np.linspace(1, 0, nr)
    return e

# Viento: ruido filtrado con ráfagas lentas (bucle de 12 s)
tt = t(12.25)
noise = rng.standard_normal(len(tt))
gust = 0.55 + 0.45 * np.sin(2 * np.pi * tt / 12.25 * 2) * np.sin(2 * np.pi * tt / 12.25 * 3 + 1)
w1 = lowpass(noise, 0.035) * gust
w2 = lowpass(noise, 0.12) * 0.35 * (0.5 + 0.5 * np.sin(2 * np.pi * tt / 12.25 * 5))
save("viento", w1 + w2, loop=True)

# Zumbido del generador (bucle 4 s): graves + armónicos + traqueteo
tt = t(4.25)
hum = 0.6 * np.sin(2 * np.pi * 55 * tt) + 0.3 * np.sin(2 * np.pi * 110 * tt) + 0.12 * np.sin(2 * np.pi * 165 * tt)
rumble = lowpass(rng.standard_normal(len(tt)), 0.02) * 0.6
pulse = 0.5 + 0.5 * np.sin(2 * np.pi * 2.0 * tt) ** 8
save("generador", (hum + rumble) * (0.8 + 0.2 * pulse), loop=True)

# Clic de interfaz
tt = t(0.06)
save("clic", np.sin(2 * np.pi * 1800 * tt) * np.exp(-tt * 90) + 0.3 * rng.standard_normal(len(tt)) * np.exp(-tt * 200))

# Obra terminada: martillazos + campanita
x = np.zeros(int(0.9 * SR))
for k, st in enumerate([0.0, 0.18, 0.36]):
    s = int(st * SR); n = int(0.12 * SR)
    seg = t(0.12)
    x[s:s + n] += (np.sin(2 * np.pi * 320 * seg) + 0.5 * rng.standard_normal(n)) * np.exp(-seg * 40)
seg = t(0.4); s = int(0.5 * SR)
x[s:s + len(seg)] += 0.6 * (np.sin(2 * np.pi * 880 * seg) + 0.4 * np.sin(2 * np.pi * 1320 * seg)) * np.exp(-seg * 7)
save("obra", x)

# Sirena de oleada (bocina de vapor grave)
tt = t(2.6)
f = 140 + 30 * np.minimum(tt / 0.4, 1)
ph = 2 * np.pi * np.cumsum(f) / SR
horn = np.sign(np.sin(ph)) * 0.4 + np.sin(ph) * 0.6 + 0.3 * np.sin(2 * ph)
save("oleada", lowpass(horn, 0.25) * env(len(tt), 0.15, 0.8))

# Campana de muerte (grave, inarmónica)
tt = t(3.0)
bell = sum(a * np.sin(2 * np.pi * fr * tt) * np.exp(-tt * d) for fr, a, d in [(196, 1, 1.2), (392.5, .5, 1.6), (523, .35, 2.2), (659, .2, 2.8), (987, .1, 3.5)])
save("campana", bell)

# Notificación de evento (dos tonos)
x = np.concatenate([np.sin(2 * np.pi * 660 * t(0.12)) * np.exp(-t(0.12) * 10), np.sin(2 * np.pi * 990 * t(0.25)) * np.exp(-t(0.25) * 8)])
save("evento", x)

# Investigación lista (arpegio)
x = np.concatenate([np.sin(2 * np.pi * f0 * t(0.14)) * np.exp(-t(0.14) * 6) for f0 in [523, 659, 784, 1046]])
save("investigacion", x)

# Ley promulgada (golpe de sello + acorde)
tt = t(0.8)
thump = lowpass(rng.standard_normal(len(tt)), 0.15) * np.exp(-tt * 30)
chord = sum(np.sin(2 * np.pi * fr * tt) for fr in [220, 277.2, 329.6]) * np.exp(-tt * 3) * 0.4
save("ley", thump + chord)

# Música ambiente: pad lento en menor (bucle de ~64 s)
dur = 64.25
tt = t(dur)
music = np.zeros(len(tt))
chords = [[110, 130.8, 164.8], [98, 123.5, 146.8], [87.3, 110, 130.8], [82.4, 103.8, 123.5]]
seg = dur / 4
for i, ch in enumerate(chords * 1):
    s = int(i * seg * SR); n = int(seg * SR)
    tl = np.arange(n) / SR
    e = np.minimum(1, tl / 4.0) * np.minimum(1, (seg - tl) / 4.0)
    for fr in ch:
        for det in (0.998, 1.0, 1.003):
            music[s:s + n] += np.sin(2 * np.pi * fr * det * tl) * e * 0.18
            music[s:s + n] += np.sin(2 * np.pi * fr * 2 * det * tl) * e * 0.05
# melodía rara y espaciada (campanitas)
notes = [440, 523, 494, 392, 440, 587, 523, 494]
for k, f0 in enumerate(notes):
    s = int((4 + k * 7.5) * SR); seg2 = t(3.0)
    if s + len(seg2) < len(music):
        music[s:s + len(seg2)] += 0.18 * np.sin(2 * np.pi * f0 * seg2) * np.exp(-seg2 * 1.4)
music += lowpass(rng.standard_normal(len(tt)), 0.01) * 0.25
save("musica", music, loop=True)
print("audio:", sorted(os.listdir(OUT)))
