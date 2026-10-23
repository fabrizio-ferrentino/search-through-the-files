"""Generatore dei file multimediali SEGNAPOSTO delle pagine web (strumento di scrittura,
NON fa parte del gioco; Godot ignora i .py).

Disegna GIF d'epoca (animate e no) in web/img/ e compone melodie MIDI originali in
web/audio/, con la sola libreria standard: un piccolo scrittore GIF89a (LZW) e uno
scrittore di Standard MIDI File. Ogni file e' un segnaposto: si sostituisce con uno
vero tenendo lo stesso nome.

Regole: nelle immagini NIENTE PAROLE (le pagine sono in due lingue, un'immagine no):
solo pittogrammi e cifre; niente marchi veri; melodie inventate, mai motivi esistenti.

    python tools/web/media.py            # rigenera tutto
    python tools/web/media.py busta      # solo i file il cui nome contiene "busta"
"""
import math, os, random, struct, sys

QUI = os.path.dirname(os.path.abspath(__file__))
IMG = os.path.join(QUI, "..", "..", "web", "img")
AUDIO = os.path.join(QUI, "..", "..", "web", "audio")


# ============================================================
# GIF
# ============================================================

def _lzw(indici, min_size):
    """Compressione LZW a lunghezza variabile come la vuole il formato GIF."""
    clear = 1 << min_size
    eoi = clear + 1
    out = bytearray()
    acc = 0
    nbit = 0

    def scrivi(codice, taglia):
        nonlocal acc, nbit
        acc |= codice << nbit
        nbit += taglia
        while nbit >= 8:
            out.append(acc & 0xFF)
            acc >>= 8
            nbit -= 8

    def nuovo_diz():
        return {bytes([i]): i for i in range(clear)}

    taglia = min_size + 1
    diz = nuovo_diz()
    prossimo = eoi + 1
    scrivi(clear, taglia)
    w = bytes([indici[0]])
    for k in indici[1:]:
        wk = w + bytes([k])
        if wk in diz:
            w = wk
            continue
        scrivi(diz[w], taglia)
        if prossimo < 4096:
            diz[wk] = prossimo
            prossimo += 1
            if prossimo > (1 << taglia) and taglia < 12:
                taglia += 1
        else:
            scrivi(clear, taglia)
            diz = nuovo_diz()
            prossimo = eoi + 1
            taglia = min_size + 1
        w = bytes([k])
    scrivi(diz[w], taglia)
    scrivi(eoi, taglia)
    if nbit > 0:
        out.append(acc & 0xFF)
    return bytes(out)


def scrivi_gif(nome, fotogrammi, palette, ritardo=10, trasparente=None, ritardi=None):
    """fotogrammi: liste di righe di indici nella palette (tutti della stessa misura).
    ritardo in centesimi di secondo; trasparente = indice trasparente o None."""
    h = len(fotogrammi[0])
    w = len(fotogrammi[0][0])
    pal = list(palette)
    bit = 1
    while (1 << bit) < len(pal):
        bit += 1
    pal += [(0, 0, 0)] * ((1 << bit) - len(pal))
    dati = bytearray(b"GIF89a")
    dati += struct.pack("<HHBBB", w, h, 0x80 | (bit - 1), 0, 0)
    for r, g, b in pal:
        dati += bytes([r, g, b])
    if len(fotogrammi) > 1:
        # NETSCAPE2.0: ripeti per sempre
        dati += b"\x21\xFF\x0BNETSCAPE2.0\x03\x01\x00\x00\x00"
    for n, f in enumerate(fotogrammi):
        rit = ritardi[n] if ritardi else ritardo
        gp = 0x08  # smaltimento 2: si torna al fondo (le animazioni con trasparenza)
        if trasparente is not None:
            gp |= 1
        dati += struct.pack("<BBBBHBB", 0x21, 0xF9, 4, gp, rit,
                            trasparente if trasparente is not None else 0, 0)
        dati += struct.pack("<BHHHHB", 0x2C, 0, 0, w, h, 0)
        min_size = max(2, bit)
        dati += bytes([min_size])
        compressi = _lzw([c for riga in f for c in riga], min_size)
        for i in range(0, len(compressi), 255):
            pezzo = compressi[i:i + 255]
            dati += bytes([len(pezzo)]) + pezzo
        dati += b"\x00"
    dati += b"\x3B"
    os.makedirs(IMG, exist_ok=True)
    with open(os.path.join(IMG, nome), "wb") as fh:
        fh.write(dati)
    print("img  ", nome, "%dx%d" % (w, h), len(fotogrammi), "fotogrammi")


class Tela:
    """Una tela di indici di palette, con le primitive che servono ai pittogrammi."""

    def __init__(self, w, h, fondo=0):
        self.w, self.h = w, h
        self.p = [[fondo] * w for _ in range(h)]

    def px(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[y][x] = c

    def rett(self, x, y, w, h, c):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.px(xx, yy, c)

    def cerchio(self, cx, cy, r, c, pieno=True):
        for yy in range(int(cy - r - 1), int(cy + r + 2)):
            for xx in range(int(cx - r - 1), int(cx + r + 2)):
                d = math.hypot(xx - cx, yy - cy)
                if (pieno and d <= r) or (not pieno and abs(d - r) < 0.6):
                    self.px(xx, yy, c)

    def linea(self, x0, y0, x1, y1, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / n
            self.px(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, c)

    def poligono(self, punti, c):
        ys = [p[1] for p in punti]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            xs = []
            for i in range(len(punti)):
                (x0, y0), (x1, y1) = punti[i], punti[(i + 1) % len(punti)]
                if (y0 <= y < y1) or (y1 <= y < y0):
                    xs.append(x0 + (y - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for a, b in zip(xs[::2], xs[1::2]):
                for x in range(int(math.ceil(a)), int(b) + 1):
                    self.px(x, y, c)

    def testo(self, x, y, s, c, scala=1):
        """Solo cifre e pochi simboli (font 3x5): nelle immagini non ci vanno parole."""
        for ch in s:
            g = _FONT.get(ch)
            if g is None:
                x += 4 * scala
                continue
            for ry, riga in enumerate(g):
                for rx, bit in enumerate(riga):
                    if bit == "#":
                        self.rett(x + rx * scala, y + ry * scala, scala, scala, c)
            x += 4 * scala

    def copia(self):
        t = Tela(self.w, self.h)
        t.p = [r[:] for r in self.p]
        return t


_FONT = {
    "0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["###", "..#", "###", "#..", "###"], "3": ["###", "..#", ".##", "..#", "###"],
    "4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "###", "..#", "###"],
    "6": ["###", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "###"],
    "x": ["...", "#.#", ".#.", "#.#", "..."], "K": ["#.#", "#.#", "##.", "#.#", "#.#"],
    "!": [".#.", ".#.", ".#.", "...", ".#."], "+": ["...", ".#.", "###", ".#.", "..."],
}


def _ruota(x, y, cx, cy, a):
    s, c = math.sin(a), math.cos(a)
    return cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c


# ---------------- i disegni ----------------

def cantiere():
    """Il cartello "lavori in corso": il rombo giallo con l'omino che scava, a strisce
    che scorrono sotto."""
    pal = [(255, 0, 255), (0, 0, 0), (255, 204, 0), (255, 255, 255), (200, 120, 0)]
    fs = []
    for f in range(4):
        t = Tela(64, 52, 0)
        t.poligono([(32, 1), (62, 30), (32, 59), (2, 30)], 1)
        t.poligono([(32, 4), (59, 30), (32, 56), (5, 30)], 2)
        # l'omino con la pala
        t.cerchio(28, 16, 3, 1)
        t.linea(28, 19, 27, 30, 1)
        t.linea(27, 30, 22, 38, 1)
        t.linea(27, 30, 31, 38, 1)
        t.linea(28, 22, 36, 26 + (f % 2) * 2, 1)
        t.linea(36, 26 + (f % 2) * 2, 40, 36, 1)
        t.rett(38, 36 - (f % 2), 6, 2, 4)
        # strisce in basso
        for x in range(64):
            for y in range(44, 52):
                t.px(x, y, 1 if ((x + y + f * 4) // 6) % 2 == 0 else 2)
        fs.append(t.p)
    scrivi_gif("cantiere.gif", fs, pal, ritardo=25, trasparente=0)


def busta():
    """La busta della posta che gira su se stessa (il "scrivimi" di ogni pagina)."""
    pal = [(255, 0, 255), (0, 0, 0), (255, 255, 255), (200, 200, 220), (220, 0, 0)]
    fs = []
    for f in range(12):
        t = Tela(40, 28, 0)
        k = math.cos(f / 12 * math.tau)
        mezza = max(1, abs(k) * 17)
        x0, x1 = 20 - mezza, 20 + mezza
        t.rett(x0, 4, x1 - x0, 20, 2 if k >= 0 else 3)
        t.linea(x0, 4, x1, 4, 1)
        t.linea(x0, 23, x1, 23, 1)
        t.linea(x0, 4, x0, 23, 1)
        t.linea(x1, 4, x1, 23, 1)
        if k >= 0:
            t.linea(x0, 4, 20, 15, 1)
            t.linea(x1, 4, 20, 15, 1)
            if mezza > 8:
                t.rett(x1 - 6 * abs(k), 6, 4 * abs(k) + 1, 4, 4)
        fs.append(t.p)
    scrivi_gif("busta.gif", fs, pal, ritardo=8, trasparente=0)


def globo():
    """Il mappamondo che gira: Internet, per chi lo disegnava nel 1998."""
    pal = [(255, 0, 255), (0, 40, 140), (40, 110, 230), (40, 170, 60), (0, 0, 0), (255, 255, 255)]
    terre = [(0.3, 0.2, 0.25), (1.6, -0.3, 0.35), (2.9, 0.35, 0.3), (4.2, -0.1, 0.4), (5.3, 0.4, 0.2)]
    fs = []
    for f in range(16):
        t = Tela(36, 36, 0)
        t.cerchio(18, 18, 16, 2)
        for y in range(36):
            for x in range(36):
                dx, dy = (x - 18) / 16, (y - 18) / 16
                if dx * dx + dy * dy > 1:
                    continue
                lat = math.asin(dy)
                lon = math.asin(max(-1, min(1, dx / max(0.01, math.cos(lat))))) + f / 16 * math.tau
                for lo, la, r in terre:
                    dl = (lon - lo + math.pi) % math.tau - math.pi
                    if dl * dl + (lat - la) ** 2 < r * r:
                        t.px(x, y, 3)
                if dx < -0.55 and (dx * dx + dy * dy) > 0.5:
                    t.px(x, y, 1 if t.p[y][x] == 2 else t.p[y][x])
        t.cerchio(18, 18, 16, 4, pieno=False)
        t.px(12, 10, 5)
        t.px(13, 10, 5)
        fs.append(t.p)
    scrivi_gif("globo.gif", fs, pal, ritardo=10, trasparente=0)


def nuovo():
    """La stellina che lampeggia accanto alle novita' (senza la scritta: e' un'immagine)."""
    pal = [(255, 0, 255), (255, 0, 0), (255, 230, 0), (255, 255, 255)]
    fs = []
    for f in range(4):
        t = Tela(28, 28, 0)
        r1, r2 = (13, 6) if f % 2 == 0 else (11, 5)
        pt = []
        for i in range(24):
            r = r1 if i % 2 == 0 else r2
            a = i / 24 * math.tau + f * 0.13
            pt.append((14 + r * math.cos(a), 14 + r * math.sin(a)))
        t.poligono(pt, 1 if f % 2 == 0 else 2)
        t.cerchio(14, 14, 4, 2 if f % 2 == 0 else 3)
        t.testo(12, 12, "!", 1)
        fs.append(t.p)
    scrivi_gif("nuovo.gif", fs, pal, ritardo=30, trasparente=0)


def smile():
    """La faccina gialla che salta."""
    pal = [(255, 0, 255), (0, 0, 0), (255, 220, 0), (255, 255, 255)]
    fs = []
    for f in range(8):
        t = Tela(28, 30, 0)
        y = 15 - abs(math.sin(f / 8 * math.pi)) * 3
        t.cerchio(14, y, 11, 2)
        t.cerchio(14, y, 11, 1, pieno=False)
        t.rett(10, y - 5, 2, 3, 1)
        t.rett(17, y - 5, 2, 3, 1)
        for i in range(9):
            a = math.pi * (0.15 + 0.7 * i / 8)
            t.px(14 - 6 * math.cos(a), y + 2 + 4 * math.sin(a), 1)
        fs.append(t.p)
    scrivi_gif("smile.gif", fs, pal, ritardo=9, trasparente=0)


def fiamme(nome="fiamme.gif", w=480):
    """La barra di fiamme che separa i paragrafi (il <hr> dei siti piu' "tosti")."""
    pal = [(255, 0, 255), (120, 0, 0), (220, 30, 0), (255, 120, 0), (255, 220, 40), (255, 255, 200)]
    h = 18
    rng = random.Random(7)
    fase = [rng.random() * math.tau for _ in range(w)]
    fs = []
    for f in range(6):
        t = Tela(w, h, 0)
        for x in range(w):
            alt = 6 + 5 * (math.sin(x * 0.35 + fase[x] * 0.3 + f * 1.1) * 0.5 + 0.5) \
                + 4 * (math.sin(x * 0.11 - f * 0.7) * 0.5 + 0.5)
            for y in range(h):
                d = h - y
                if d <= alt:
                    k = d / alt
                    c = 5 if k < 0.15 else 4 if k < 0.4 else 3 if k < 0.7 else 2 if k < 0.9 else 1
                    t.px(x, y, c)
        fs.append(t.p)
    scrivi_gif(nome, fs, pal, ritardo=10, trasparente=0)


def arcobaleno(w=480):
    """Il righello arcobaleno, immobile."""
    pal = [(255, 0, 0), (255, 140, 0), (255, 230, 0), (0, 200, 0), (0, 120, 255), (90, 0, 200), (200, 0, 200)]
    t = Tela(w, 6, 0)
    for x in range(w):
        for y in range(6):
            t.px(x, y, int(x / w * 7 + y * 0.15) % 7)
    scrivi_gif("arcobaleno.gif", [t.p], pal)


def contatore(numero, nome):
    """Il contatore delle visite: cifre verdi su nero, come un display a sette segmenti."""
    pal = [(0, 0, 0), (0, 230, 0), (0, 60, 0), (90, 90, 90)]
    s = "%06d" % numero
    t = Tela(len(s) * 12 + 2, 18, 0)
    for i, ch in enumerate(s):
        x = 2 + i * 12
        t.rett(x - 1, 1, 11, 16, 0)
        t.testo(x + 1, 3, "8", 2, scala=2)
        t.testo(x + 1, 3, ch, 1, scala=2)
        t.linea(x + 10, 0, x + 10, 17, 3)
    scrivi_gif(nome, [t.p], pal)


def bottone(nome, disegno, fondo, scritta=""):
    """Un bottoncino 88x31 (il "badge" d'epoca) con un pittogramma e al piu' delle cifre."""
    pal = [fondo, (255, 255, 255), (64, 64, 64), (0, 0, 0), (255, 220, 0), (0, 160, 255), (200, 0, 0)]
    fs = []
    for f in range(2 if disegno == "modem" else 1):
        t = Tela(88, 31, 0)
        t.linea(0, 0, 87, 0, 1)
        t.linea(0, 0, 0, 30, 1)
        t.linea(87, 0, 87, 30, 2)
        t.linea(0, 30, 87, 30, 2)
        if disegno == "monitor":
            t.rett(6, 5, 24, 17, 2)
            t.rett(8, 7, 20, 13, 5)
            t.rett(14, 22, 8, 3, 2)
            t.rett(10, 25, 16, 2, 2)
        elif disegno == "modem":
            t.rett(5, 11, 28, 10, 2)
            t.rett(7, 13, 24, 6, 3)
            for i in range(4):
                t.rett(9 + i * 5, 15, 2, 2, 4 if (i + f) % 2 else 6)
        elif disegno == "dischetto":
            t.rett(7, 5, 21, 21, 3)
            t.rett(11, 5, 13, 8, 1)
            t.rett(20, 6, 3, 6, 3)
            t.rett(10, 16, 15, 10, 1)
        if scritta:
            scala = 2 if len(scritta) * 8 <= 52 else 1
            t.testo(85 - len(scritta) * 4 * scala, 16 - 5 * scala // 2, scritta, 1, scala=scala)
        fs.append(t.p)
    scrivi_gif(nome, fs, pal, ritardo=50)


def floppy():
    """Il dischetto con la freccia che scende: "scarica"."""
    pal = [(255, 0, 255), (0, 0, 0), (40, 40, 160), (220, 220, 220), (0, 200, 0)]
    fs = []
    for f in range(6):
        t = Tela(32, 40, 0)
        t.rett(4, 12, 24, 24, 2)
        t.rett(9, 12, 14, 9, 3)
        t.rett(18, 13, 3, 6, 2)
        t.rett(8, 26, 16, 10, 3)
        y = 0 + f * 2
        t.rett(13, y, 6, 6, 4)
        t.poligono([(9, y + 6), (23, y + 6), (16, y + 12)], 4)
        fs.append(t.p)
    scrivi_gif("floppy.gif", fs, pal, ritardo=12, trasparente=0)


def ingranaggio():
    """La rotella che gira (le pagine "tecniche")."""
    pal = [(255, 0, 255), (90, 90, 100), (170, 170, 180), (0, 0, 0)]
    fs = []
    for f in range(8):
        t = Tela(32, 32, 0)
        a0 = f / 8 * (math.tau / 8)
        pt = []
        for i in range(32):
            r = 14 if (i // 2) % 2 == 0 else 10
            a = a0 + i / 32 * math.tau
            pt.append((16 + r * math.cos(a), 16 + r * math.sin(a)))
        t.poligono(pt, 2)
        t.cerchio(16, 16, 5, 0)
        t.cerchio(16, 16, 5, 1, pieno=False)
        fs.append(t.p)
    scrivi_gif("ingranaggio.gif", fs, pal, ritardo=10, trasparente=0)


def pallone():
    """Il pallone che rimbalza (il fan club)."""
    pal = [(255, 0, 255), (0, 0, 0), (255, 255, 255), (60, 60, 60)]
    fs = []
    for f in range(10):
        t = Tela(30, 34, 0)
        y = 6 + abs(math.cos(f / 10 * math.pi)) * 0 + (1 - abs(math.sin(f / 10 * math.pi))) * 16
        t.cerchio(15, y + 8, 8, 2)
        t.cerchio(15, y + 8, 8, 1, pieno=False)
        a = f * 0.6
        for k in range(5):
            x, yy = _ruota(15 + 5, y + 8, 15, y + 8, a + k * math.tau / 5)
            t.cerchio(x, yy, 1.6, 1)
        t.cerchio(15, y + 8, 2.2, 1)
        t.rett(9, 32, 12, 1, 3)
        fs.append(t.p)
    scrivi_gif("pallone.gif", fs, pal, ritardo=7, trasparente=0)


def pentola():
    """La pentola col vapore (la cucina della nonna)."""
    pal = [(255, 0, 255), (0, 0, 0), (180, 40, 30), (230, 230, 230), (120, 20, 15)]
    fs = []
    for f in range(6):
        t = Tela(48, 44, 0)
        t.rett(8, 22, 32, 18, 2)
        t.rett(6, 20, 36, 4, 4)
        t.rett(2, 26, 6, 3, 4)
        t.rett(40, 26, 6, 3, 4)
        t.rett(20, 17, 8, 3, 4)
        for k in range(3):
            for i in range(12):
                y = 16 - i
                x = 14 + k * 10 + 2 * math.sin(i * 0.6 + f * 1.0 + k)
                if (i + f) % 6 < 4:
                    t.px(x, y, 3)
        fs.append(t.p)
    scrivi_gif("pentola.gif", fs, pal, ritardo=15, trasparente=0)


def fiore():
    """Un fiorellino per gli angoli delle ricette."""
    pal = [(255, 0, 255), (220, 60, 120), (255, 220, 0), (40, 140, 40)]
    t = Tela(24, 30, 0)
    t.rett(11, 14, 2, 15, 3)
    t.poligono([(12, 22), (5, 18), (7, 24)], 3)
    for k in range(6):
        a = k / 6 * math.tau
        t.cerchio(12 + 5 * math.cos(a), 9 + 5 * math.sin(a), 3.5, 1)
    t.cerchio(12, 9, 3, 2)
    scrivi_gif("fiore.gif", [t.p], pal, trasparente=0)


def stemma():
    """Lo stemma del comune: uno scudo con il lago e una torre (immobile)."""
    pal = [(255, 0, 255), (0, 0, 0), (30, 90, 40), (255, 255, 255), (40, 90, 200), (200, 170, 40)]
    t = Tela(48, 56, 0)
    scudo = [(2, 2), (46, 2), (46, 30), (24, 54), (2, 30)]
    t.poligono(scudo, 2)
    t.poligono([(5, 5), (43, 5), (43, 29), (24, 50), (5, 29)], 3)
    t.rett(18, 10, 12, 18, 1)
    t.rett(19, 11, 10, 17, 5)
    for i in range(3):
        t.rett(18 + i * 5, 7, 3, 3, 1)
    for y in range(30, 48):
        for x in range(5, 44):
            if t.p[y][x] == 3 and (y // 3) % 2 == 0:
                t.p[y][x] = 4
    for i in range(len(scudo)):
        x0, y0 = scudo[i]
        x1, y1 = scudo[(i + 1) % len(scudo)]
        t.linea(x0, y0, x1, y1, 1)
    scrivi_gif("stemma.gif", [t.p], pal, trasparente=0)


def zodiaco():
    """La ruota dello zodiaco che gira lenta con la luna al centro (la pagina d'ingresso
    dell'oroscopo). Solo segni grafici, niente nomi."""
    pal = [(255, 0, 255), (20, 10, 50), (255, 210, 90), (180, 150, 255), (255, 255, 230), (90, 60, 160)]
    fs = []
    for f in range(24):
        t = Tela(160, 160, 0)
        t.cerchio(80, 80, 76, 1)
        t.cerchio(80, 80, 76, 2, pieno=False)
        t.cerchio(80, 80, 56, 2, pieno=False)
        a0 = f / 24 * (math.tau / 12)
        for k in range(12):
            a = a0 + k / 12 * math.tau
            x0, y0 = 80 + 56 * math.cos(a), 80 + 56 * math.sin(a)
            x1, y1 = 80 + 76 * math.cos(a), 80 + 76 * math.sin(a)
            t.linea(x0, y0, x1, y1, 2)
            am = a + math.tau / 24
            cx, cy = 80 + 66 * math.cos(am), 80 + 66 * math.sin(am)
            # dodici pittogrammi astratti, diversi fra loro
            if k % 3 == 0:
                t.cerchio(cx, cy, 4, 3, pieno=False)
            elif k % 3 == 1:
                t.poligono([(cx, cy - 5), (cx + 5, cy + 4), (cx - 5, cy + 4)], 3)
            else:
                t.rett(cx - 3, cy - 3, 7, 7, 3)
            t.px(cx, cy, 4)
        # la luna: falce che cambia piano
        t.cerchio(80, 80, 30, 4)
        t.cerchio(80 + 12 + 6 * math.sin(f / 24 * math.tau), 74, 27, 1)
        for k in range(30):
            rng = random.Random(k)
            x, y = rng.randint(20, 140), rng.randint(20, 140)
            if math.hypot(x - 80, y - 80) < 54 and math.hypot(x - 80, y - 80) > 34 and (k + f) % 5:
                t.px(x, y, 4)
        fs.append(t.p)
    scrivi_gif("zodiaco.gif", fs, pal, ritardo=12, trasparente=0)


# ---------------- sfondi a mosaico ----------------

def stelle():
    """Cielo notturno a mosaico con le stelle che brillano (animato)."""
    pal = [(5, 5, 30), (255, 255, 255), (150, 150, 200), (60, 60, 110)]
    rng = random.Random(3)
    punti = [(rng.randrange(64), rng.randrange(64), rng.randrange(4)) for _ in range(22)]
    fs = []
    for f in range(4):
        t = Tela(64, 64, 0)
        for x, y, fase in punti:
            c = 1 if (fase + f) % 4 == 0 else 2 if (fase + f) % 4 == 1 else 3
            t.px(x, y, c)
            if c == 1:
                t.px(x + 1, y, 3)
                t.px(x - 1, y, 3)
                t.px(x, y + 1, 3)
                t.px(x, y - 1, 3)
        fs.append(t.p)
    scrivi_gif("stelle.gif", fs, pal, ritardo=40)


def griglia():
    """La griglia al neon su nero (i siti "cyber" dei ragazzi). Spenta apposta: sotto il
    testo una griglia accesa si legge male (proprietario, 23/10/2026)."""
    pal = [(0, 0, 20), (0, 18, 32), (0, 40, 58)]
    t = Tela(40, 40, 0)
    for i in range(40):
        t.px(i, 0, 2)
        t.px(0, i, 2)
        t.px(i, 20, 1)
        t.px(20, i, 1)
    scrivi_gif("griglia.gif", [t.p], pal)


def quadretti():
    """La tovaglia a quadretti bianchi e rossi."""
    pal = [(255, 255, 255), (240, 170, 170), (220, 90, 90)]
    t = Tela(32, 32, 0)
    for y in range(32):
        for x in range(32):
            a, b = (x // 8) % 2, (y // 8) % 2
            t.px(x, y, 2 if a and b else 1 if a or b else 0)
    scrivi_gif("quadretti.gif", [t.p], pal)


def pergamena():
    """Carta vecchia, macchiettata."""
    pal = [(244, 232, 200), (236, 222, 186), (228, 212, 172), (250, 242, 216)]
    rng = random.Random(11)
    t = Tela(64, 64, 0)
    for y in range(64):
        for x in range(64):
            v = math.sin(x * 0.2) + math.sin(y * 0.17 + x * 0.05) + rng.random() * 1.2
            t.px(x, y, 3 if v > 1.6 else 0 if v > 0.4 else 1 if v > -0.6 else 2)
    scrivi_gif("pergamena.gif", [t.p], pal)


def metallo():
    """Metallo spazzolato (i portali "tecnici")."""
    pal = [(150, 152, 158), (160, 162, 168), (140, 142, 148), (170, 172, 178)]
    rng = random.Random(5)
    t = Tela(64, 64, 0)
    for y in range(64):
        base = rng.randrange(4)
        for x in range(64):
            t.px(x, y, base if rng.random() < 0.85 else rng.randrange(4))
    scrivi_gif("metallo.gif", [t.p], pal)


# ============================================================
# MIDI
# ============================================================

def _varlen(v):
    b = [v & 0x7F]
    v >>= 7
    while v:
        b.insert(0, 0x80 | (v & 0x7F))
        v >>= 7
    return bytes(b)


def scrivi_mid(nome, bpm, tracce, tpq=96):
    """tracce: liste di (canale, programma, [(inizio_in_quarti, durata, nota, vel), ...])."""
    blocchi = []
    for n, (can, prog, note) in enumerate(tracce):
        ev = []
        if n == 0:
            ev.append((0, 0, b"\xFF\x51\x03" + struct.pack(">I", int(60000000 / bpm))[1:]))
        if can != 9:
            ev.append((0, 1, bytes([0xC0 | can, prog])))
        for ini, dur, nota, vel in note:
            t0 = int(round(ini * tpq))
            t1 = int(round((ini + dur) * tpq))
            ev.append((t0, 3, bytes([0x90 | can, nota, vel])))
            ev.append((t1, 2, bytes([0x80 | can, nota, 0])))
        ev.sort(key=lambda e: (e[0], e[1]))
        dati = bytearray()
        prima = 0
        for t, _o, msg in ev:
            dati += _varlen(t - prima) + msg
            prima = t
        dati += b"\x00\xFF\x2F\x00"
        blocchi.append(b"MTrk" + struct.pack(">I", len(dati)) + bytes(dati))
    testa = b"MThd" + struct.pack(">IHHH", 6, 1, len(blocchi), tpq)
    os.makedirs(AUDIO, exist_ok=True)
    with open(os.path.join(AUDIO, nome), "wb") as fh:
        fh.write(testa + b"".join(blocchi))
    print("audio", nome, bpm, "bpm,", sum(len(t[2]) for t in tracce), "note")


def _accordi(seq, ottava, durata, ripeti=1, vel=70, arpeggio=False):
    """seq = [(fondamentale MIDI relativa a C, "M"/"m"), ...], una per battuta."""
    note = []
    t = 0.0
    for _r in range(ripeti):
        for fond, modo in seq:
            terza = 4 if modo == "M" else 3
            voci = [fond, fond + terza, fond + 7]
            if arpeggio:
                passi = int(durata / 0.5)
                for i in range(passi):
                    note.append((t + i * 0.5, 0.45, 12 * ottava + voci[i % 3], vel))
            else:
                for v in voci:
                    note.append((t, durata * 0.95, 12 * ottava + v, vel))
            t += durata
    return note


def _melodia(gradi, ottava, inizio=0.0, vel=96):
    """gradi = [(nota relativa a C, durata in quarti)], None = pausa."""
    note, t = [], inizio
    for g, d in gradi:
        if g is not None:
            note.append((t, d * 0.9, 12 * ottava + g, vel))
        t += d
    return note


def _batteria(battute, schema, tempi=4):
    """schema: {nota GM: [posizioni in quarti dentro la battuta]}"""
    note = []
    for b in range(battute):
        for nota, pos in schema.items():
            for p in pos:
                note.append((b * tempi + p, 0.1, nota, 100 if nota in (35, 36) else 80))
    return note


def jack():
    """Il motivetto pop del sito di jack99: allegro, in loop, con la batteria."""
    giro = [(0, "M"), (9, "m"), (5, "M"), (7, "M")] * 2
    mel = [(7, .5), (7, .5), (9, .5), (7, .5), (12, 1), (11, 1),
           (9, .5), (9, .5), (11, .5), (9, .5), (7, 2),
           (5, .5), (5, .5), (7, .5), (9, .5), (12, 1), (9, 1),
           (7, .5), (5, .5), (4, .5), (2, .5), (4, 2)] * 2
    basso = []
    for b, (f, _m) in enumerate(giro):
        for k in range(4):
            basso.append((b * 4 + k, 0.8, 36 + f, 90))
    scrivi_mid("jack.mid", 126, [
        (0, 80, _melodia(mel, 6)),                       # lead quadra
        (1, 33, basso),                                  # basso
        (2, 4, _accordi(giro, 5, 4, vel=45, arpeggio=True)),
        (9, 0, _batteria(8, {36: [0, 2], 38: [1, 3], 42: [0, .5, 1, 1.5, 2, 2.5, 3, 3.5]})),
    ])


def inno():
    """L'inno da stadio del fan club: marcia in Si bemolle, ottoni e grancassa."""
    giro = [(10, "M"), (3, "M"), (5, "M"), (10, "M"), (3, "M"), (10, "M"), (5, "M"), (10, "M")]
    mel = [(10, 1), (14, .5), (15, .5), (17, 1.5), (14, .5),
           (15, 1), (19, 1), (17, 2),
           (17, 1), (15, .5), (14, .5), (12, 1.5), (14, .5),
           (15, 1), (14, 1), (12, 2),
           (10, 1), (14, .5), (15, .5), (17, 1.5), (19, .5),
           (20, 1), (19, 1), (17, 2),
           (15, 1), (17, .5), (15, .5), (14, 1), (12, 1),
           (10, 3), (None, 1)]
    scrivi_mid("inno.mid", 112, [
        (0, 61, _melodia(mel, 5)),                       # ottoni
        (1, 57, _accordi(giro, 4, 4, vel=60)),
        (2, 58, [(b * 4 + k, 0.9, (36 + f) if f < 6 else (24 + f), 90)
                 for b, (f, _m) in enumerate(giro) for k in (0, 2)]),
        (9, 0, _batteria(8, {36: [0, 2], 38: [1, 3], 49: [0]})),
    ])


def valzer():
    """Il valzerino della cucina della nonna: fisarmonica in tre quarti."""
    giro = [(0, "M"), (7, "M"), (7, "M"), (0, "M"), (5, "M"), (0, "M"), (7, "M"), (0, "M")]
    mel = [(4, 1), (7, 1), (12, 1), (11, 2), (7, 1), (5, 1), (7, 1), (11, 1), (12, 3),
           (9, 1), (12, 1), (17, 1), (16, 2), (12, 1), (14, 1), (11, 1), (7, 1), (12, 3)]
    acc = []
    for b, (f, m) in enumerate(giro):
        acc.append((b * 3, 0.9, 36 + f, 80))
        for k in (1, 2):
            for v in (0, 4, 7):
                acc.append((b * 3 + k, 0.6, (48 + f + v) if f < 7 else (36 + f + v), 50))
    scrivi_mid("valzer.mid", 150, [
        (0, 21, _melodia(mel, 6, vel=90)),                # fisarmonica
        (1, 21, acc),
    ])


def notte():
    """La musica d'atmosfera dell'oroscopo: un tappeto lento e qualche campanella."""
    giro = [(9, "m"), (5, "M"), (0, "M"), (7, "M")]
    campane = []
    rng = random.Random(9)
    scala = [0, 2, 4, 7, 9, 12, 14, 16]
    for b in range(8):
        for k in range(2):
            campane.append((b * 4 + k * 2 + rng.choice([0, .5, 1]), 1.5, 72 + rng.choice(scala), 60))
    scrivi_mid("notte.mid", 70, [
        (0, 89, _accordi(giro, 4, 4, ripeti=2, vel=55)),  # pad
        (1, 11, campane),                                 # vibrafono
        (2, 89, [(b * 4, 3.8, 33 + f, 60) for b, (f, _m) in enumerate(giro * 2)]),
    ])


TUTTI = [cantiere, busta, globo, nuovo, smile, fiamme, arcobaleno, floppy, ingranaggio,
         pallone, pentola, fiore, stemma, zodiaco, stelle, griglia, quadretti, pergamena,
         metallo,
         lambda: contatore(4217, "contatore_jack.gif"),
         lambda: contatore(18342, "contatore_grifoni.gif"),
         lambda: contatore(951, "contatore_stelle.gif"),
         lambda: bottone("bottone_monitor.gif", "monitor", (0, 0, 128), "800x600"),
         lambda: bottone("bottone_modem.gif", "modem", (0, 90, 0), "56K"),
         lambda: bottone("bottone_dischetto.gif", "dischetto", (110, 0, 0), "144"),
         jack, inno, valzer, notte]

if __name__ == "__main__":
    filtro = sys.argv[1] if len(sys.argv) > 1 else ""
    for fn in TUTTI:
        nome = getattr(fn, "__name__", "")
        if filtro and filtro not in nome and nome != "<lambda>":
            continue
        fn()
