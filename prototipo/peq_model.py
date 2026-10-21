"""Modelo (Python) do gerador de coeficientes PEQ da Airoha, validado contra o emulador."""
import cmath
import math
import random
import sys

sys.path.insert(0, r"H:\moondrop-port\prototipo")

HEADROOM = 1.19


def rbj(fs, f, g, q):
    A = math.sqrt(10 ** (g / 20))
    w = 2 * math.pi * f / fs
    al = math.sin(w) / (2 * q)
    c = math.cos(w)
    a0 = 1 + al / A
    return ((1 + al * A) / a0, -2 * c / a0, (1 - al * A) / a0, -2 * c / a0, (1 - al / A) / a0)


def total_peak(fs, coefs):
    """max |H_total| na grade de 1 Hz de 0 a fs/2 (exclusive)."""
    peak = 0.0
    n = int(fs / 2)
    for k in range(n):
        w = 2 * math.pi * k / fs
        z1 = cmath.exp(-1j * w)
        z2 = z1 * z1
        h = 1.0 + 0j
        for (b0, b1, b2, a1, a2) in coefs:
            h *= (b0 + b1 * z1 + b2 * z2) / (1 + a1 * z1 + a2 * z2)
        peak = max(peak, abs(h))
    return peak


def to_i32(x, shift_bits):
    """x * 2^shift_bits + 0.5 -> int (truncando como C), saturando em int32."""
    v = x * (1 << shift_bits) + 0.5
    v = max(-2147483648.0, min(2147483647.0, v))
    return int(v)  # trunc toward zero


def q24(x, frac_bits):
    """Arredonda x*2^frac_bits (meio para cima) e satura em 24 bits com sinal."""
    v = math.floor(x * (1 << frac_bits) + 0.5)
    return max(-(1 << 23), min((1 << 23) - 1, v))


def model(fs, bands, mode_round="trunc"):
    # ordena: maior pico de banda (boost) primeiro; empate pela ordem original
    idx = sorted(range(len(bands)), key=lambda i: (-bands[i][1], i))
    coefs = [rbj(fs, *bands[i]) for i in idx]
    peak = max(1.0, total_peak(fs, coefs))
    x6 = peak * 0.25 if peak >= 4.0 else 1.0
    b0, b1, b2, a1, a2 = coefs[0]
    maxc = max(abs(b0), abs(b1) * 0.5, abs(b2))
    S = x6 * maxc * HEADROOM
    blocks = [[2 * b0 / S, b1 / S, 2 * b2 / S, a1, 2 * a2]]
    prod = 1.0
    for (c0, c1, c2, ca1, ca2) in coefs[1:]:
        blocks.append([2.0, c1 / c0, 2 * c2 / c0, ca1, 2 * ca2])
        prod *= c0
    M = S * prod / peak
    return blocks, M, peak


def quantize(blocks, M, q_shift=22):
    out = [len(blocks)]
    for b in blocks:
        for v in b:
            q = (q24(v, 22) << 8) & 0xFFFFFFFF
            out += [(q >> 16) & 0xFFFF, q & 0xFFFF]
    m = (q24(M, 18) << 8) & 0xFFFFFFFF
    out += [(m >> 16) & 0xFFFF, m & 0xFFFF]
    return out


def compare(emu, fs, bands):
    n, s = emu.compute(fs, bands)
    blocks, M, peak = model(fs, bands)
    mine = quantize(blocks, M)
    theirs = [x & 0xFFFF for x in s]
    return mine, theirs, peak


def blob_response(shorts, fs, npts=2000):
    """Resposta |H| (dB) do bloco quantizado, no dominio de tempo discreto, incluindo o ganho master."""
    def i32(h, l):
        v = ((h & 0xFFFF) << 16) | (l & 0xFFFF)
        return v - (1 << 32) if v & 0x80000000 else v
    n = shorts[0]
    blocks = [[i32(shorts[1 + 10 * k + 2 * j], shorts[2 + 10 * k + 2 * j]) / 2**30 for j in range(5)] for k in range(n)]
    M = i32(shorts[-2], shorts[-1]) / 2**26
    out = []
    for i in range(npts):
        f = 20 * (fs / 2 / 20) ** (i / (npts - 1))
        w = 2 * math.pi * f / fs
        z1 = cmath.exp(-1j * w); z2 = z1 * z1
        h = complex(M)
        for (v1, v2, v3, v4, v5) in blocks:
            h *= (v1 / 2 + v2 * z1 + v3 / 2 * z2) / (1 + v4 * z1 + v5 / 2 * z2)
        out.append(20 * math.log10(max(abs(h), 1e-12)))
    return out


if __name__ == "__main__":
    from peq_emu import PeqEmu

    emu = PeqEmu()
    random.seed(7)
    bad = 0
    total = 0
    exact = 0
    equiv = 0
    for trial in range(120):
        fs = random.choice([44100.0, 48000.0, 88200.0, 96000.0])
        n = random.choice([1, 2, 3, 5, 8, 10])
        bands = []
        for _ in range(n):
            bands.append((random.choice([31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]),
                          round(random.uniform(-9, 9), 1), round(random.uniform(0.4, 4), 2)))
        mine, theirs, peak = compare(emu, fs, bands)
        total += 1
        if mine == theirs:
            exact += 1
            continue
        ra = blob_response(mine, fs)
        rb = blob_response(theirs, fs)
        dev = max(abs(a - b) for a, b in zip(ra, rb))
        if dev < 0.01:
            equiv += 1
        else:
            bad += 1
            print(f"RUIM fs={fs} n={n} desvio={dev:.4f} dB bands={bands}")
    print(f"\nbit-a-bit: {exact}/{total}   equivalentes (<0,01 dB): {equiv}   ruins: {bad}")
