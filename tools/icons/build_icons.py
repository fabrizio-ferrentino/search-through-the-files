"""Costruisce le icone pixel-art del finto OS in assets/icons/16 e assets/icons/32.

Base: il set di SerenityOS (BSD-2, vedi serenity/LICENSE), icone 16x16 e 32x32 in stile
Win9x. Quelle che a SerenityOS mancano (Risorse del computer, unita' floppy e CD,
cestino vuoto, cartella col lucchetto, stampante, stop, spegnimento) sono disegnate qui
sotto, a mano, con la STESSA tavolozza (grigio #b5b5b5, luce bianca, ombra #808080,
contorno nero in basso a destra), cosi' la serie resta una.

    python tools/icons/build_icons.py

Il gioco legge solo i PNG in assets/icons/: rilanciare lo script li riscrive tutti.
"""
from pathlib import Path
from PIL import Image

QUI = Path(__file__).resolve().parent
SRC = QUI / "serenity"
OUT = QUI.parent.parent / "assets" / "icons"

# Tavolozza dei disegni a mano: un carattere = un colore.
PAL = {
    ".": (0, 0, 0, 0),
    "k": (0, 0, 0, 255),          # contorno
    "w": (255, 255, 255, 255),    # luce
    "l": (223, 223, 223, 255),    # luce interna
    "g": (181, 181, 181, 255),    # faccia (lo stesso grigio del disco di SerenityOS)
    "D": (128, 128, 128, 255),    # ombra
    "d": (115, 115, 115, 255),    # ombra scura
    "t": (0, 128, 128, 255),      # schermo: il verde acqua del desktop
    "T": (0, 168, 168, 255),      # riflesso sullo schermo
    "n": (0, 0, 128, 255),        # schermo spento: blu notte
    "y": (255, 255, 160, 255),    # luna
    "G": (0, 200, 0, 255),        # LED acceso
    "b": (0, 81, 132, 255),       # blu scuro (il LED del disco di SerenityOS)
    "B": (37, 140, 206, 255),     # azzurro
    "s": (56, 56, 72, 255),       # corpo del dischetto
    "S": (96, 96, 120, 255),      # luce del dischetto
    "Y": (255, 224, 96, 255),     # ottone chiaro (lucchetto)
    "o": (224, 176, 0, 255),      # ottone
    "O": (160, 112, 0, 255),      # ottone scuro
    "r": (200, 0, 0, 255),        # rosso
    "R": (128, 0, 0, 255),        # rosso scuro
    "c": (176, 224, 255, 255),    # riflesso del CD: celeste
    "p": (255, 176, 224, 255),    # riflesso del CD: rosa
    "e": (255, 255, 176, 255),    # riflesso del CD: giallo
    "z": (255, 255, 0, 255),      # giallo pieno (faccina)
}


def griglia(righe: str) -> Image.Image:
    rr = [r for r in righe.strip("\n").split("\n")]
    w = max(len(r) for r in rr)
    im = Image.new("RGBA", (w, len(rr)), (0, 0, 0, 0))
    for y, r in enumerate(rr):
        for x, ch in enumerate(r):
            im.putpixel((x, y), PAL[ch])
    return im


def tela(n: int) -> Image.Image:
    return Image.new("RGBA", (n, n), (0, 0, 0, 0))


def incolla(base: Image.Image, pezzo: Image.Image, x: int, y: int) -> Image.Image:
    base.alpha_composite(pezzo, (x, y))
    return base


def ser(lato: int, nome: str) -> Image.Image:
    return Image.open(SRC / f"{lato}x{lato}" / f"{nome}.png").convert("RGBA")


# ---------------------------------------------------------------- Risorse del computer
# Il monitor sopra la cassa orizzontale, come l'icona del '95. Lo schermo ha il verde
# acqua del desktop; "spento" (per Chiudi sessione) e' blu notte con la luna.
COMPUTER_32 = """
................................
................................
.....wwwwwwwwwwwwwwwwwwwwwk.....
.....wlllllllllllllllllllDk.....
.....wlggggggggggggggggggDk.....
.....wlgDDDDDDDDDDDDDDDDwgDk....
.....wlgDkkkkkkkkkkkkkkDwgDk....
.....wlgDkTTttttttttttkDwgDk....
.....wlgDkTtttttttttttkDwgDk....
.....wlgDktttttttttttttkwgDk....
.....wlgDktttttttttttttkwgDk....
.....wlgDktttttttttttttkwgDk....
.....wlgDktttttttttttttkwgDk....
.....wlgDktttttttttttttkwgDk....
.....wlgDkkkkkkkkkkkkkkkwgDk....
.....wlgwwwwwwwwwwwwwwwwwgDk....
.....wlggggggggggggggggggggDk...
.....wDDDDDDDDDDDDDDDDDDDDDDk...
.....kkkkkkkkkkkkkkkkkkkkkkkk...
............wgggggDk............
...........wggggggggDk..........
..wwwwwwwwwwwwwwwwwwwwwwwwwwwk..
..wllllllllllllllllllllllllllDk.
..wlggggggggggggggggggggggggggDk
..wlgGGgggggggggggkkkkkkkkkgggDk
..wlggggggggggggggwwwwwwwwwgggDk
..wlggggggggggggggggggggggggggDk
..wDDDDDDDDDDDDDDDDDDDDDDDDDDDDk
..kkkkkkkkkkkkkkkkkkkkkkkkkkkkkk
................................
................................
................................
"""

COMPUTER_16 = """
................
..wwwwwwwwwwwk..
..wggggggggggDk.
..wgDkkkkkkkwDk.
..wgkTtttttkwDk.
..wgktttttttwDk.
..wgktttttttwDk.
..wgkwwwwwwwwDk.
..wDDDDDDDDDDDk.
..kkkkkkkkkkkkk.
......wgDk......
.wwwwwwwwwwwwwk.
.wgGgggggkkkkgDk
.wggggggggggggDk
.wDDDDDDDDDDDDDk
.kkkkkkkkkkkkkkk
"""


def computer(lato: int, spento: bool = False) -> Image.Image:
    im = griglia(COMPUTER_32 if lato == 32 else COMPUTER_16)
    if spento:
        # lo schermo diventa blu notte, con una falce di luna
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                if px[x, y] in (PAL["t"], PAL["T"]):
                    px[x, y] = PAL["n"]
        if lato == 32:
            luna = [(16, 7), (17, 7), (15, 8), (16, 8), (14, 9), (15, 9), (14, 10), (15, 10),
                    (14, 11), (15, 11), (15, 12), (16, 12), (16, 13), (17, 13)]
            stelle = [(20, 8), (19, 11), (12, 12)]
        else:
            luna = [(7, 4), (6, 5), (7, 6)]
            stelle = [(10, 5)]
        for p in luna:
            px[p] = PAL["y"]
        for p in stelle:
            px[p] = PAL["w"]
    return im


# ---------------------------------------------------------------- unita' (floppy, CD)
# Come le unita' di Risorse del computer del '95: il cassetto grigio del disco fisso
# di SerenityOS, con sopra quello che ci va dentro (il dischetto, il CD).
def cassetto(lato: int) -> Image.Image:
    """Il corpo dell'unita', preso dal disco fisso di SerenityOS e spinto in fondo."""
    hd = ser(lato, "hard-disk")
    box = hd.getbbox()
    corpo = hd.crop(box)
    im = tela(lato)
    im.alpha_composite(corpo, (box[0], lato - corpo.height - (2 if lato == 32 else 0)))
    return im


FLOPPY_32 = """
kkkkkkkkkkkkkkkkkk..
kSSSkgggggggDDkSSSk.
kSsskglDDgggDDksssSk
kSsskglDDgggDDkssssk
kSsskglDDgggDDkssssk
kSsskgggggggggksssskk
kSssskkkkkkkkksssssk
kSsssssssssssssssssk
kSsswwwwwwwwwwwwwssk
kSsswllllllllllllssk
kSsswlDDDDDDDDDDlssk
kSsswllllllllllllssk
"""

FLOPPY_16 = """
kkkkkkkkk.
kSkgglDkSk
kSkgglDksk
kSskkkkssk
kSwwwwwwsk
kSwDDDDwsk
"""


def floppy(lato: int) -> Image.Image:
    im = tela(lato)
    if lato == 32:
        incolla(im, griglia(FLOPPY_32), 6, 5)
    else:
        incolla(im, griglia(FLOPPY_16), 3, 2)
    # il cassetto sta davanti: il dischetto ci entra dentro
    im.alpha_composite(cassetto(lato))
    if lato == 32:
        # la fessura del floppy sul cassetto
        for x in range(8, 24):
            im.putpixel((x, 24), PAL["k"])
            im.putpixel((x, 25), PAL["w"])
    return im


def disco_cd(r: float, lato_tela: int) -> Image.Image:
    """Un CD visto di sbieco (ellisse) con i riflessi d'arcobaleno e il foro."""
    im = tela(lato_tela)
    px = im.load()
    cx = (lato_tela - 1) / 2.0
    cy = cx
    ry = r * 0.62
    for y in range(lato_tela):
        for x in range(lato_tela):
            dx = (x - cx) / r
            dy = (y - cy) / ry
            d = dx * dx + dy * dy
            if d > 1.0:
                continue
            # bordo: scuro in basso a destra, chiaro in alto a sinistra
            if d > 0.80:
                px[x, y] = PAL["k"] if (dx + dy) > -0.2 else PAL["D"]
                continue
            if d < 0.05:
                px[x, y] = (0, 0, 0, 0)        # il foro
                continue
            if d < 0.16:
                px[x, y] = PAL["D"]            # il mozzo
                continue
            # i riflessi: tre spicchi colorati, il resto argento
            ang = (dx * 1.0 - dy * 0.6)
            if 0.18 < ang < 0.38:
                px[x, y] = PAL["c"]
            elif 0.38 <= ang < 0.52:
                px[x, y] = PAL["p"]
            elif -0.55 < ang < -0.38:
                px[x, y] = PAL["e"]
            else:
                px[x, y] = PAL["l"] if dy < 0 else PAL["g"]
    return im


def cdrom(lato: int) -> Image.Image:
    im = tela(lato)
    if lato == 32:
        cd = disco_cd(12.5, 28)
        im.alpha_composite(cd.crop((0, 0, 28, 20)), (2, 0))
    else:
        cd = disco_cd(6.5, 15)
        im.alpha_composite(cd.crop((0, 0, 15, 10)), (0, 0))
    im.alpha_composite(cassetto(lato))
    if lato == 32:
        for x in range(8, 24):          # la fessura del cassetto del CD, piu' larga
            im.putpixel((x, 24), PAL["k"])
            im.putpixel((x, 25), PAL["w"])
    return im


# ---------------------------------------------------------------- cestino
# Il cestino pieno e' quello di SerenityOS; quello vuoto e' lo stesso cestino senza le
# carte: al posto della carta si vede la bocca (un'ellisse buia col bordo chiaro davanti).
def cestino_vuoto() -> Image.Image:
    im = ser(32, "recycle-bin")
    px = im.load()
    for y in range(0, 14):
        for x in range(32):
            px[x, y] = (0, 0, 0, 0)
    # la bocca: ellisse da x 4..27, y 9..18
    cx, cy, rx, ry = 15.5, 11.0, 11.5, 3.6
    for y in range(6, 16):
        for x in range(3, 29):
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d <= 1.0:
                if d > 0.55:
                    px[x, y] = PAL["w"] if y > cy else PAL["k"]   # bordo: chiaro davanti
                else:
                    px[x, y] = (88, 90, 88, 255) if y < cy + 1 else (110, 112, 110, 255)
    return im


TRASH_FULL_16 = """
................
....kk.kkk......
...kwwkwwwk.....
...kwlwwlwwk....
..kkkkkkkkkkk...
.klgDDDDDDDDdk..
..kkkkkkkkkkk...
...klDDDDDDdk...
...klkDkDkDdk...
...klkDkDkDdk...
...klkDkDkDdk...
...klkDkDkDdk...
...klkDkDkDdk...
...klDDDDDDdk...
....kkkkkkkk....
................
"""


# La faccina di YouAreStupid: quella di SerenityOS e' quadrata, questa e' tonda.
SMILEY_16 = """
................
.....kkkkkk.....
...kkzzzzzzkk...
..kzzzzzzzzzzk..
..kzzkzzzzkzzk..
.kzzzkzzzzkzzok.
.kzzzzzzzzzzzok.
.kzzzzzzzzzzzok.
.kzkzzzzzzzzkok.
.kzzkzzzzzzkzok.
..kzzkkkkkkzok..
..kzzzzzzzzook..
...kkoooooookk..
.....kkkkkk.....
................
................
"""


# ---------------------------------------------------------------- cartella protetta
LUCCHETTO_32 = """
...kkkkkk...
..kDggggDk..
.kgk....kgk.
.kgk....kDk.
.kgk....kDk.
kkkkkkkkkkkk
kYYYYYYYYYYk
kYooooooooOk
kYoookkoooOk
kYoookkoooOk
kYooookoooOk
kYooooooooOk
kOOOOOOOOOOk
kkkkkkkkkkkk
"""

LUCCHETTO_16 = """
..kkk..
.kg.Dk.
.kg.Dk.
kkkkkkk
kYookOk
kYookOk
kOOOOOk
kkkkkkk
"""


def cartella_chiusa(lato: int) -> Image.Image:
    im = ser(lato, "filetype-folder")
    if lato == 32:
        incolla(im, griglia(LUCCHETTO_32), 19, 16)
    else:
        incolla(im, griglia(LUCCHETTO_16), 9, 8)
    return im


# ---------------------------------------------------------------- barra del browser
STOP_16 = """
................
.....kkkkkk.....
...kkrrrrrrkk...
..krrrrrrrrrrk..
..krwwrrrrwwrRk.
.krrwwwrrwwwrRk.
.krrrwwwwwwrrRk.
.krrrrwwwwrrrRk.
.krrrrwwwwrrrRk.
.krrrwwwwwwrrRk.
.krrwwwrrwwwrRk.
..krwwrrrrwwRk..
..kRrrrrrrrRRk..
...kkRRRRRRkk...
.....kkkkkk.....
................
"""

PRINT_16 = """
................
....kkkkkkkk....
....kwwwwwwk....
....kwDDDDwk....
....kwwwwwwk....
..kkkkkkkkkkkk..
.kwwwwwwwwwwwwk.
.kwggggggggGgDk.
.kwggggggggggDk.
.kDDDDDDDDDDDDk.
.kgkkkkkkkkkkgk.
.kkwwwwwwwwwwkk.
...kwDDDDDDwk...
...kwwwwwwwwk...
...kkkkkkkkkk...
................
"""


# ---------------------------------------------------------------- la rete (mappamondo)
def mappamondo_32() -> Image.Image:
    """Il globo del browser di SerenityOS senza la coccinella (il loro marchio): la parte
    coperta si ricopia, specchiata, dalla meta' destra del globo."""
    im = ser(32, "app-browser")
    px = im.load()
    sp = im.transpose(Image.FLIP_LEFT_RIGHT).load()
    for y in range(15, 32):
        for x in range(0, 15):
            px[x, y] = sp[x, y]
    return im


# ---------------------------------------------------------------- l'elenco
# tipo di OSIcon -> (immagine 16, immagine 32). None = quella misura non esiste: OSIcon
# usa l'altra.
def icone() -> dict:
    return {
        "folder": (ser(16, "filetype-folder"), ser(32, "filetype-folder")),
        "folder_open": (ser(16, "filetype-folder-open"), ser(32, "filetype-folder-open")),
        "locked": (cartella_chiusa(16), cartella_chiusa(32)),
        "computer": (computer(16), computer(32)),
        "shutdown": (computer(16, True), computer(32, True)),
        "web": (ser(16, "internet"), mappamondo_32()),
        "file": (ser(16, "filetype-text"), ser(32, "filetype-text")),
        "floppy": (floppy(16), floppy(32)),
        "hdd": (ser(16, "hard-disk"), ser(32, "hard-disk")),
        "cdrom": (cdrom(16), cdrom(32)),
        "exe": (ser(16, "filetype-executable"), ser(32, "filetype-executable")),
        "smiley": (griglia(SMILEY_16), None),
        "image": (ser(16, "filetype-image"), ser(32, "filetype-image")),
        "notepad": (ser(16, "app-text-editor"), ser(32, "app-text-editor")),
        "trash": (ser(16, "trash-can"), cestino_vuoto()),
        "trash_full": (griglia(TRASH_FULL_16), ser(32, "recycle-bin")),
        "back": (ser(16, "go-back"), None),
        "fwd": (ser(16, "go-forward"), None),
        "up": (ser(16, "open-parent-directory"), None),
        "cut": (ser(16, "edit-cut"), None),
        "copy": (ser(16, "edit-copy"), None),
        "paste": (ser(16, "paste"), None),
        "delete": (ser(16, "delete"), None),
        "props": (ser(16, "properties"), None),
        "views": (ser(16, "icon-view"), None),
        "stop": (griglia(STOP_16), None),
        "refresh": (ser(16, "reload"), None),
        "home": (ser(16, "go-home"), None),
        "star": (ser(16, "bookmark-filled"), None),
        "print": (griglia(PRINT_16), None),
        "search": (ser(16, "find"), None),
        "speaker": (ser(16, "audio-volume-medium"), None),
        "speaker_muto": (ser(16, "audio-volume-muted"), None),
    }


def main() -> None:
    for lato in (16, 32):
        (OUT / str(lato)).mkdir(parents=True, exist_ok=True)
    n = 0
    for tipo, coppia in icone().items():
        for lato, im in zip((16, 32), coppia):
            if im is None:
                continue
            assert im.size == (lato, lato), f"{tipo} {lato}: {im.size}"
            im.save(OUT / str(lato) / f"{tipo}.png")
            n += 1
    print(f"scritte {n} icone in {OUT}")


if __name__ == "__main__":
    main()
