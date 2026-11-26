"""Le immagini delle pagine web prese da FONTI VERE (strumento di scrittura, non fa parte del
gioco). Gli originali stanno in tools/web/fonti/ (scaricati una volta, cosi' rigenerare non
chiede la rete); qui si adattano ai siti e si scrivono in web/img/ con i crediti in
web/img/CREDITI.md. Solo licenze libere e verificate: pubblico dominio o CC0.

Le GIF di media.py sembravano troppo moderne (proprietario, 26/11/2026): dove esiste una GIF
d'epoca con licenza pulita si usa quella; le altre restano disegnate da media.py.

    python tools/web/fonti.py

Serve Pillow (pip install pillow).
"""
import os
from PIL import Image, ImageEnhance, ImageOps, ImageSequence

QUI = os.path.dirname(os.path.abspath(__file__))
FONTI = os.path.join(QUI, "fonti")
IMG = os.path.join(QUI, "..", "..", "web", "img")

APACHE = ("Kevin Hughes (icone di NCSA Mosaic, 1993-95), distribuite con Apache httpd",
          "Pubblico dominio (docs/icons/README di Apache httpd)",
          "https://svn.apache.org/repos/asf/httpd/httpd/trunk/docs/icons/")


def copia(src, dst):
    with open(os.path.join(FONTI, src), "rb") as a, open(os.path.join(IMG, dst), "wb") as b:
        b.write(a.read())


def lampeggia(src, dst):
    """Icona ferma -> due fotogrammi, il secondo piu' chiaro: il "NEW!" che lampeggia."""
    im = Image.open(os.path.join(FONTI, src)).convert("RGBA")
    chiaro = im.copy()
    px = chiaro.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (min(255, r + 90), min(255, g + 90), min(255, b + 90), a)
    _salva_gif([im, chiaro], dst, 40)


def striscia_fuoco(src, dst):
    """Le punte del fuoco (righe 48-66, senza il bordo bianco dell'originale), ripetute a
    specchio fino a 480 px: la barra di fiamme che separa i paragrafi."""
    fs = []
    for f in ImageSequence.Iterator(Image.open(os.path.join(FONTI, src))):
        pezzo = f.convert("RGB").crop((2, 48, 98, 66))
        st = Image.new("RGB", (480, 18))
        for i in range(5):
            st.paste(ImageOps.mirror(pezzo) if i % 2 else pezzo, (i * 96, 0))
        fs.append(st.quantize(64, dither=Image.Dither.FLOYDSTEINBERG))
    fs[0].save(os.path.join(IMG, dst), save_all=True, append_images=fs[1:], duration=40, loop=0)


def foto(w, h, bordo=0.0):
    """Una foto vera resa "da sito del '98": ritagliata a riempire w x h, colori un po'
    spenti (scanner e monitor dell'epoca) e JPEG molto compresso (si pagava a minuti).
    bordo = quota da togliere su ogni lato prima (la cornice nera di una diapositiva)."""
    def fai(src, dst):
        im = Image.open(os.path.join(FONTI, "foto", src)).convert("RGB")
        if bordo:
            dx, dy = int(im.width * bordo), int(im.height * bordo)
            im = im.crop((dx, dy, im.width - dx, im.height - dy))
        im = ImageOps.fit(im, (w, h), Image.Resampling.LANCZOS)
        im = ImageEnhance.Color(im).enhance(0.8)
        im = ImageEnhance.Contrast(im).enhance(1.08)
        im.save(os.path.join(IMG, dst), "JPEG", quality=32, subsampling=2)
    fai.__name__ = "foto %dx%d" % (w, h)
    return fai


def _salva_gif(fotogrammi, dst, durata):
    # trasparenza GIF: un indice riservato, i pixel con alfa 0 ci finiscono dentro
    pal = [f.convert("RGB").quantize(255) for f in fotogrammi]
    out = []
    for f, q in zip(fotogrammi, pal):
        q = q.copy()
        q.putpalette(q.getpalette()[:255 * 3] + [255, 0, 255])
        dati = q.load()
        alfa = f.getchannel("A").load()
        for y in range(f.height):
            for x in range(f.width):
                if alfa[x, y] == 0:
                    dati[x, y] = 255
        out.append(q)
    out[0].save(os.path.join(IMG, dst), save_all=True, append_images=out[1:], duration=durata,
                loop=0, transparency=255, disposal=2)


# file in web/img -> (cosa fa, originale, descrizione, autore, licenza, pagina della fonte)
VOCI = [
    ("globo.gif", copia, "Globe_rotating.gif", "mappamondo che gira",
     "kkck (utente di Wikimedia Commons)", "Pubblico dominio",
     "https://commons.wikimedia.org/wiki/File:Globe_rotating.gif"),
    ("busta.gif", copia, "E-mail_oiseau.gif", "uccellino che porta una lettera (\"scrivimi\")",
     "Mouh2jijel (Wikipedia in arabo)", "Pubblico dominio",
     "https://commons.wikimedia.org/wiki/File:E-mail_oiseau.gif"),
    ("fiamme.gif", striscia_fuoco, "Fire-animation.gif", "barra di fiamme (ritaglio ripetuto)",
     "Nevit (utente di Wikimedia Commons)", "Pubblico dominio",
     "https://commons.wikimedia.org/wiki/File:Fire-animation.gif"),
    ("nuovo.gif", lampeggia, "apache_burst.gif", "stella \"nuovo\" (burst.gif), fatta lampeggiare") + APACHE,
    ("vecchio_pc.gif", copia, "apache_comp.blue.gif", "computer (comp.blue.gif)") + APACHE,
    # le FOTO: originali in fonti/foto/ (miniature da 320 px di Commons)
    ("foto_villaggio_mare.jpg", foto(200, 150, 0.06), "Mediterranean_coast__00.jpg",
     "villaggio sulla baia (viaggi)", "Matson Collection (Library of Congress)", "Pubblico dominio",
     "https://commons.wikimedia.org/wiki/File:Along_the_Mediterranean_coast,_southward._Caesarea,_village_and_bay._Acts_10-1,_23-33_LOC_matpc.23002.jpg"),
    ("foto_spiaggia.jpg", foto(200, 150), "beach_00.jpg", "spiaggia con ombrelloni (viaggi)",
     "Jebulon", "CC0",
     "https://commons.wikimedia.org/wiki/File:Parasols,_Evening,_Beach,_Rincon_de_la_Victoria,_Andalusia,_Spain.jpg"),
    ("foto_lago_monti.jpg", foto(200, 150), "mountain_lake_alps_00.jpg", "lago di montagna (viaggi)",
     "autore sconosciuto", "CC0", "https://commons.wikimedia.org/wiki/File:Mountain_lake_in_Alps.jpg"),
    ("foto_cane.jpg", foto(120, 90), "dog_portrait_mixed_b_00.jpg", "pastore tedesco (animali)",
     "Jen Wong Hui Xian", "CC0", "https://commons.wikimedia.org/wiki/File:BobbyWonderful.jpg"),
    ("foto_gatto.jpg", foto(120, 90), "cat_tabby_kitten_00.jpg", "gatto tigrato (animali)",
     "W.carter", "CC0", "https://commons.wikimedia.org/wiki/File:Young_tabby_cat_keeping_watch.jpg"),
    ("foto_cucciolo.jpg", foto(120, 90), "puppy_02.jpg", "cucciolo bianco (animali)",
     "autore non indicato", "CC0", "https://commons.wikimedia.org/wiki/File:Puppy_filtered.jpg"),
    ("foto_torta_mele.jpg", foto(160, 120), "apple_pie_00.jpg", "torta di mele (ricette)",
     "W.carter", "CC0", "https://commons.wikimedia.org/wiki/File:Apple_cake_with_vanilla_ice_cream_2.jpg"),
    ("foto_lasagna.jpg", foto(160, 120), "lasagna_dish_00.jpg", "lasagna (ricette)",
     "Olos88", "Pubblico dominio", "https://commons.wikimedia.org/wiki/File:Lasagna_by_Olos88.JPG"),
    ("foto_spaghetti.jpg", foto(160, 120), "spaghetti_01.jpg", "piatto di spaghetti (ricette)",
     "Chado07", "CC0", "https://commons.wikimedia.org/wiki/File:Plat_de_Spaghetti_blanc.jpg"),
    ("foto_municipio.jpg", foto(200, 150), "town_hall_Italy_00.jpg", "municipio (comune)",
     "Fabio Carassio", "CC0",
     "https://commons.wikimedia.org/wiki/File:Municipio_del_Comune_di_Scopa,_Italia.jpg"),
]


def crediti():
    righe = ["# Crediti delle immagini web prese da fonti esterne",
             "",
             "Generato da `tools/web/fonti.py` (non modificare a mano). Gli originali stanno in",
             "`tools/web/fonti/`. Le altre immagini di questa cartella sono disegnate da",
             "`tools/web/media.py`.",
             "",
             "| File | Cosa | Originale | Autore | Licenza | Fonte |",
             "|---|---|---|---|---|---|"]
    for dst, _fn, src, cosa, autore, lic, url in VOCI:
        righe.append("| `%s` | %s | `%s` | %s | %s | %s |" % (dst, cosa, src, autore, lic, url))
    with open(os.path.join(IMG, "CREDITI.md"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(righe) + "\n")


if __name__ == "__main__":
    for dst, fn, src, *_ in VOCI:
        fn(src, dst)
        print("img  ", dst, "<-", src)
    crediti()
