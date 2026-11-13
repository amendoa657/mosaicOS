#!/usr/bin/env python3
# Mosaic OS: gera os três papéis de parede da casa, em 4K, com as cores da
# mosaic-ui (o fundo #211e26 e os blocos azul, rosa, pêssego e verde).
#   mosaic-tesselas.png   uma faixa de tesselas em degradê que se desfaz em
#                         peças soltas, algumas teclas levantadas, o campo de
#                         pontos atrás e um brilho atravessando
#   mosaic-paisagem.png   pixel art 480×270 ampliada 8×: céu pontilhado (Bayer),
#                         sol em faixas, montanhas em camadas e estrelas
#   mosaic-aurora.png    feito para a área de trabalho: escuro, aurora em blocos
#                         verde/violeta/magenta no meio, cantos apagados
# Uso: gerar-mosaic.py [pasta]   (padrão ~/Imagens/Wallpapers)
# A semente é fixa, então o resultado é sempre o mesmo.
import sys
from pathlib import Path

import numpy as np
from PIL import Image

W, H = 3840, 2160
rng = np.random.default_rng(22)

def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)

BASE = hexrgb("#16131b")
DOT = hexrgb("#3a3545")
AZUL, ROSA, PESSEGO, VERDE = map(hexrgb, ["#b5c5f9", "#e9b9d3", "#ffb77c", "#86d7ac"])
AZUL_FUNDO, AMEIXA = hexrgb("#354571"), hexrgb("#5f3c51")

def ramp(stops, t):
    """Degradê entre várias cores; t em 0..1 (array)."""
    t = np.clip(t, 0, 1) * (len(stops) - 1)
    i = np.minimum(t.astype(int), len(stops) - 2)
    f = (t - i)[..., None]
    s = np.array(stops)
    return s[i] * (1 - f) + s[i + 1] * f

def grain(img, amount):
    n = rng.normal(0, amount, img.shape[:2])[..., None]
    return img + n

def save(img, path):
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(path, optimize=True)
    print(path)

# ── TESSELAS ────────────────────────────────────────────────────────────────

def tesselas():
    img = np.empty((H, W, 3)); img[:] = BASE
    # um halo bem leve atrás da faixa, para não ficar chapado
    yy, xx = np.mgrid[0:H, 0:W]
    halo = np.exp(-(((xx - W * 0.62) / (W * 0.55)) ** 2 + ((yy - H * 0.45) / (H * 0.6)) ** 2))
    img += (AZUL_FUNDO - BASE) * 0.35 * halo[..., None]

    # o campo de pontos da mosaic-ui
    step = 48
    for y in range(step // 2, H, step):
        for x in range(step // 2, W, step):
            img[y - 2:y + 2, x - 2:x + 2] = img[y - 2:y + 2, x - 2:x + 2] * 0.4 + DOT * 0.6

    cell, gap = 96, 10
    cols, rows = W // cell + 2, H // cell + 2
    stops = [AZUL_FUNDO, AZUL, ROSA, PESSEGO]
    keys = []
    for r in range(rows):
        for c in range(cols):
            cx, cy = (c + 0.5) * cell, (r + 0.5) * cell
            # a faixa: uma curva suave que atravessa a tela na diagonal
            u = cx / W
            center = H * (0.78 - 0.55 * u + 0.08 * np.sin(u * 5.5))
            d = (cy - center) / (H * 0.30)
            presence = 1 - abs(d)
            # a borda se desfaz: quanto mais longe do centro, menos peças
            if presence < 0 or rng.random() > presence ** 0.6 * 1.25:
                # algumas peças soltas, bem longe da faixa
                if rng.random() < 0.012:
                    pass
                else:
                    continue
            t = np.clip(u * 0.9 + (d + 1) * 0.12 + rng.normal(0, 0.035), 0, 1)
            col = ramp(stops, np.array(t))
            # variação de tom por peça, como tesselas de verdade
            col = col * (0.88 + rng.random() * 0.2)
            if rng.random() < 0.035:
                col = VERDE * (0.9 + rng.random() * 0.1)
            lift = rng.random() < 0.07 and presence > 0.3
            keys.append((c, r, col, lift, presence))

    # as levantadas por último, para a parede e a sombra ficarem por cima das vizinhas
    keys.sort(key=lambda k: k[3])
    for c, r, col, lift, presence in keys:
        x0, y0 = c * cell + gap // 2, r * cell + gap // 2
        s = cell - gap
        if lift:
            # a tecla levantada: uma "parede" mais escura embaixo e uma sombra
            depth = 16
            y0 -= depth
            img[y0 + depth + 10:y0 + s + depth + 10, x0 + 8:x0 + s + 8] *= 0.5
            img[y0 + depth:y0 + s + depth, x0:x0 + s] = col * 0.5
            img[y0:y0 + s, x0:x0 + s] = np.minimum(col * 1.08, 255)
            img[y0:y0 + 4, x0:x0 + s] = np.minimum(col * 1.15, 255)
        else:
            img[y0:y0 + s, x0:x0 + s] = col
            # a junta escura embaixo de cada peça dá um pouco de relevo
            img[y0 + s - 5:y0 + s, x0:x0 + s] = col * 0.78

    # o brilho atravessando, quantizado em blocos para seguir o grid
    by, bx = yy // cell, xx // cell
    band = np.exp(-(((bx * 1.0 - by * 1.6) - 18) / 3.2) ** 2)
    img = img * (1 + 0.14 * band[..., None])

    return grain(img, 3.2)

# ── PAISAGEM EM PIXEL ───────────────────────────────────────────────────────

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16 - 0.5

def paisagem():
    w, h = 480, 270
    yy, xx = np.mgrid[0:h, 0:w]
    dither = BAYER[yy % 4, xx % 4]

    # o céu em poucas faixas, pontilhado entre elas (como num console antigo)
    sky_stops = [hexrgb("#120f1c"), hexrgb("#1f2547"), AZUL_FUNDO, AMEIXA, hexrgb("#b9798f"), ROSA, PESSEGO]
    levels = len(sky_stops) - 1
    t = (yy / (h * 0.66)) ** 1.15
    q = np.clip(np.floor(t * levels + dither * 0.9 + 0.5), 0, levels) / levels
    img = ramp(sky_stops, q)

    # as estrelas, só na parte escura
    for _ in range(140):
        x, y = rng.integers(0, w), rng.integers(0, int(h * 0.38))
        b = 0.5 + rng.random() * 0.5
        img[y, x] = img[y, x] * (1 - b) + hexrgb("#e6e0ec") * b
        if rng.random() < 0.08 and 0 < x < w - 1 and 0 < y < h - 1:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                img[y + dy, x + dx] = img[y + dy, x + dx] * 0.6 + hexrgb("#e6e0ec") * 0.4

    # o sol: um disco em faixas, cortado por linhas horizontais embaixo
    sx, sy, sr = w * 0.64, h * 0.58, 58
    dist = np.hypot(xx - sx, (yy - sy) * 1.0)
    sun_t = np.clip((yy - (sy - sr)) / (2 * sr), 0, 1)
    sun_q = np.floor(sun_t * 4 + dither * 0.8 + 0.5) / 4
    sun = ramp([hexrgb("#fff1d6"), PESSEGO, hexrgb("#ff8f6b"), hexrgb("#e0607e")], sun_q)
    cut = (yy > sy) & (((yy - int(sy)) // 3) % 3 == 0) & (yy - sy > (sy + sr - yy) * 0.25)
    inside = (dist < sr) & ~cut
    img[inside] = sun[inside]
    # um halo pontilhado em volta
    glow = (dist >= sr) & (dist < sr + 22)
    g = 1 - (dist - sr) / 22
    mix = (g * 0.5 + dither * 0.35 > 0.32) & glow
    img[mix] = img[mix] * 0.6 + PESSEGO * 0.4

    # as montanhas: quatro camadas, cada uma mais perto e mais escura
    def ridge(base, amp, freqs, seed):
        r = np.random.default_rng(seed)
        x = np.arange(w)
        y = np.full(w, base, float)
        for f, a in freqs:
            y += a * amp * np.sin(x / w * np.pi * 2 * f + r.random() * 6.28)
        # degraus de 2 px dão o ar de pixel art feita à mão
        return (np.round(y / 2) * 2).astype(int)

    layers = [
        (h * 0.62, 18, [(1.3, 1), (3.1, 0.45), (7, 0.15)], 1, hexrgb("#7a5a86"), hexrgb("#9c7aa0")),
        (h * 0.70, 20, [(1.7, 1), (4.3, 0.4), (9, 0.12)], 2, hexrgb("#4d3f6e"), hexrgb("#6b5a8c")),
        (h * 0.79, 16, [(2.2, 1), (5.5, 0.35), (12, 0.1)], 3, hexrgb("#2b2848"), hexrgb("#3d3a63")),
        (h * 0.90, 10, [(1.1, 1), (6, 0.3), (15, 0.12)], 4, hexrgb("#16131f"), hexrgb("#211e30")),
    ]
    for base, amp, freqs, seed, dark, lit in layers:
        top = ridge(base, amp, freqs, seed)
        below = yy >= top[None, :]
        img[below] = dark
        # a encosta virada para o sol pega luz: os primeiros pixels, pontilhados
        edge = below & (yy < top[None, :] + 6) & (xx < sx + 40)
        lit_mask = edge & (dither + (top[None, :] + 6 - yy) / 6 * 0.6 > 0.25)
        img[lit_mask] = lit
        # névoa entre as camadas: um tom pontilhado logo acima de cada crista
        mist = (yy < top[None, :]) & (yy >= top[None, :] - 5) & (dither > 0.2)
        img[mist] = img[mist] * 0.85 + ROSA * 0.15

    # o lago na frente: espelha o céu escurecido e o sol em traços que estreitam
    lake_top = int(h * 0.94)
    for y in range(lake_top, h):
        k = (y - lake_top) / (h - lake_top)
        img[y, :] = ramp([hexrgb("#2b2848"), hexrgb("#16131f")], np.full(w, k))
        img[y, :][dither[y] > 0.3] *= 1.12
        if (y - lake_top) % 2 == 0:
            span = int(sr * (1 - k * 0.7))
            for x in range(int(sx - span), int(sx + span)):
                if ((x // 3 + y) % 4) != 0 and rng.random() < 0.8 - k * 0.4:
                    img[y, x] = img[y, x] * 0.35 + PESSEGO * 0.65
    img[lake_top, :] = img[lake_top, :] * 0.6 + ROSA * 0.4

    # amplia 8× sem suavizar: cada pixel vira um bloco 8×8
    big = np.repeat(np.repeat(img, 8, axis=0), 8, axis=1)
    # uma junta finíssima entre os blocos, o "mosaico" visto de perto
    by, bx = np.mgrid[0:H, 0:W]
    seam = ((by % 8) == 7) | ((bx % 8) == 7)
    big[seam] *= 0.94
    return grain(big, 1.8)

# ── NOTURNO ─────────────────────────────────────────────────────────────────
# Feito para a área de trabalho do Mosaic: os widgets são cartões quase pretos
# nos cantos e o desk já desenha o campo de pontos por cima. Então: um fundo
# escuro, uma aurora em blocos de 24 px de baixo contraste no meio (verde do
# gráfico do GitHub à esquerda, magenta do visualizador à direita, violeta
# entre eles) e os cantos apagados, onde ficam os cartões. Funciona recortado
# no meio para a tela vertical.

def noturno():
    blk = 24
    w, h = W // blk, H // blk
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / w, yy / h
    dither = BAYER[yy % 4, xx % 4]

    def blob(cx, cy, rx, ry):
        return np.exp(-(((u - cx) / rx) ** 2 + ((v - cy) / ry) ** 2))

    # a aurora: faixas inclinadas que ondulam, mais fortes embaixo do meio
    wave = 0.5 + 0.5 * np.sin(u * 7.0 + np.sin(u * 3.1) * 1.4 - v * 4.0)
    verde = blob(0.30, 0.78, 0.30, 0.40) * (0.55 + 0.45 * wave)
    magenta = blob(0.74, 0.70, 0.28, 0.38) * (0.55 + 0.45 * (1 - wave))
    violeta = blob(0.52, 0.40, 0.34, 0.36)

    cores = {
        "verde": hexrgb("#2fbf71"),
        "magenta": hexrgb("#d9467f"),
        "violeta": hexrgb("#6b4fd8"),
    }
    base = ramp([hexrgb("#141220"), hexrgb("#0d0c13")], v)
    # cantos apagados, onde ficam os cartões
    vin = np.clip(1 - (np.abs(u - 0.5) * 1.6) ** 2.2 - (np.abs(v - 0.55) * 1.5) ** 2.6, 0, 1)

    luz = np.zeros((h, w, 3))
    for k, m in (("verde", verde), ("magenta", magenta), ("violeta", violeta * 0.7)):
        luz += cores[k] * m[..., None]
    forca = (verde + magenta + violeta * 0.7) * vin
    # quantiza a força em 6 degraus com Bayer: blocos chapados, nada de degradê liso
    niveis = 6
    q = np.clip(np.floor(forca * niveis * 1.1 + dither * 0.95 + 0.5), 0, niveis) / niveis
    tom = luz / np.maximum(verde + magenta + violeta * 0.7, 1e-3)[..., None]
    img = base + (tom - base) * (q * 0.34)[..., None]

    big = np.repeat(np.repeat(img, blk, axis=0), blk, axis=1)
    by, bx = np.mgrid[0:H, 0:W]
    seam = ((by % blk) >= blk - 2) | ((bx % blk) >= blk - 2)
    big[seam] *= 0.82
    return grain(big, 2.2)

if __name__ == "__main__":
    out = Path(sys.argv[1] if len(sys.argv) > 1 else Path.home() / "Imagens/Wallpapers")
    out.mkdir(parents=True, exist_ok=True)
    save(tesselas(), out / "mosaic-tesselas.png")
    save(paisagem(), out / "mosaic-paisagem.png")
    save(noturno(), out / "mosaic-aurora.png")
