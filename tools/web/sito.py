"""Generatore dei siti (strumento di scrittura, NON fa parte del gioco; Godot ignora i .py).

Un sito = un modulo che chiama genera(id, skin, pagine):
  skin(lang, page, titolo) -> (testa_html, coda_html, attributi_body)
  pagine = { "index": {"en": (titolo, corpo), "it": (titolo, corpo)}, ... }
Scrive web/pages/<lang>/<id>/<page>.html e stampa i controlli.
"""
import io, os, re, sys

# la cartella delle pagine, calcolata da dove sta questo file (tools/web/ -> radice del progetto)
RADICE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "web", "pages") + os.sep
PORTALE = {"en": "http://www.webnet.com", "it": "http://www.webnet.it"}

_tag = re.compile(r"<[^>]*>")
_spazi = re.compile(r"\s+")
_chiave = re.compile(r"\b\d-[A-Z0-9]{4}\b")
_href = re.compile(r'href\s*=\s*"([^"]*)"')
# i moduli ci sono (dal 24/10/2026) ma restano nel sito: action vuota, una pagina del sito o
# uno script del suo server (risponde l'errore 500), mai un altro sito
_ctrl = re.compile(r'(?i)<form\b[^>]*\baction\s*=\s*"((?:https?:|www\.|mailto:)[^"]*)"')
_anno = re.compile(r"\b\d{1,2}/(?:\d{1,2}/)?((?:19|20)\d{2})\b|&copy;\s*((?:19|20)\d{2})")
_rel = re.compile(r"(?i)\b(today|yesterday|oggi|ieri)\b,?\s*(at|alle|ore)?\s*\d{1,2}[:.]\d{2}")


def visibile(html):
    m = re.search(r"(?is)<body[^>]*>(.*)</body>", html)
    t = m.group(1) if m else html
    t = re.sub(r"(?s)<!--.*?-->", "", t)
    t = _tag.sub(" ", t)
    for e in ["&nbsp;", "&middot;", "&raquo;", "&laquo;", "&mdash;", "&copy;", "&amp;", "&quot;"]:
        t = t.replace(e, " ")
    return _spazi.sub(" ", t).strip()


# SNELLIMENTO (20/11/2026, proprietario: il sorgente era un muro, la chiave introvabile).
# Va a capo prima di ogni tag di BLOCCO attaccato al tag precedente ("...</td><td>" ->
# "...</td>\n<td>"), come chi scriveva l'HTML a mano: una riga per riga di tabella, per
# paragrafo, per voce di elenco. Solo FRA DUE TAG di blocco, e solo dove il tag di prima
# chiude un blocco (o apre una tabella/un elenco): li' la pagina e' gia' a inizio riga e
# l'a capo del sorgente non diventa uno spazio. Fra un testo e un tag, o prima di
# </center>, lo spazio si vedrebbe (sposta di mezzo carattere una riga centrata). Mai
# dentro <pre> e <textarea>, dove gli a capo si vedono. Lo prova tests/bb_dump.gd: il
# BBCode di ogni pagina resta identico.
_blocco = re.compile(
    r"(?i)(<(?:/(?:table|tr|td|th|ul|ol|li|p|h[1-6]|div|center|form|blockquote|title|head"
    r"|address|dl|dt|dd)|(?:table|tr|ul|ol|html|head|body|br|hr))\b[^<>]*>)"
    r"(?=<(?:/(?:table|tr|ul|ol|body|html|head)|(?:table|tr|td|th|p|li|h[1-6]|hr|ul|ol|form"
    r"|center|div|blockquote|dl|dt|dd|address|pre|textarea|body|head|title))\b)")
_intoccabile = re.compile(r"(?is)<(pre|textarea)\b.*?</\1\s*>")


def snellisci(html):
    pezzi, fine = [], 0
    for m in _intoccabile.finditer(html):
        pezzi.append(_blocco.sub("\\1\n", html[fine:m.start()]))
        pezzi.append(m.group(0))
        fine = m.end()
    pezzi.append(_blocco.sub("\\1\n", html[fine:]))
    return "".join(pezzi)


def genera(sid, skin, pagine, morti=()):
    errori = []
    for lang in ("en", "it"):
        cartella = RADICE + lang + "/" + sid
        if os.path.isdir(cartella):
            for f in os.listdir(cartella):
                if f.endswith(".html"):
                    os.remove(os.path.join(cartella, f))
        os.makedirs(cartella, exist_ok=True)
        totale = 0
        for nome, lingue in pagine.items():
            titolo, corpo = lingue[lang]
            testa, coda, body = skin(lang, nome, titolo)
            html = "<html>\n<head><title>%s</title></head>\n<body %s>\n%s\n%s\n%s\n</body>\n</html>\n" % (
                titolo, body, testa.strip("\n"), corpo.strip("\n"), coda.strip("\n"))
            html = snellisci(html)
            io.open(cartella + "/" + nome + ".html", "w", encoding="utf-8", newline="\n").write(html)
            totale += len(visibile(html))
            for m in _chiave.finditer(html):
                errori.append("%s/%s chiave finta '%s'" % (lang, nome, m.group()))
            for m in _ctrl.finditer(html):
                errori.append("%s/%s modulo fuori dal sito: action=%s" % (lang, nome, m.group(1)))
            for m in _rel.finditer(visibile(html)):
                errori.append("%s/%s data relativa '%s'" % (lang, nome, m.group()))
            for m in _anno.finditer(html):
                y = int(m.group(1) or m.group(2))
                if y > 1999:
                    errori.append("%s/%s anno %d" % (lang, nome, y))
            for h in _href.findall(html):
                if h.startswith("http://"):
                    nudo = h[7:].rstrip("/").lower()
                    if h != PORTALE[lang] and nudo not in morti:
                        errori.append("%s/%s link esterno %s" % (lang, nome, h))
                elif h.endswith(".html"):
                    if h[:-5] not in pagine and h[:-5] not in morti:
                        errori.append("%s/%s link a pagina inesistente %s" % (lang, nome, h))
                else:
                    errori.append("%s/%s href strano %s" % (lang, nome, h))
        print("%s/%s: %d pagine, %d caratteri" % (lang, sid, len(pagine), totale))
        if totale < 2000:   # come CatalogoSiti.COMPLETO_TESTO
            errori.append("%s/%s troppo corto (%d)" % (lang, sid, totale))
    for e in errori:
        print("  ERRORE " + e)
    if not errori:
        print("  ok")


def controlla(sid, morti=()):
    """Controlla le pagine GIA' scritte di un sito (dopo una modifica a mano), senza riscriverle:
    gli stessi controlli di genera(). Uso: python -c "import sito; sito.controlla('news')"."""
    errori = []
    for lang in ("en", "it"):
        cartella = RADICE + lang + "/" + sid
        pagine = sorted(f[:-5] for f in os.listdir(cartella) if f.endswith(".html"))
        totale = 0
        for nome in pagine:
            html = io.open(cartella + "/" + nome + ".html", encoding="utf-8").read()
            totale += len(visibile(html))
            for m in _chiave.finditer(html):
                errori.append("%s/%s chiave finta '%s'" % (lang, nome, m.group()))
            for m in _ctrl.finditer(html):
                errori.append("%s/%s modulo fuori dal sito: action=%s" % (lang, nome, m.group(1)))
            for m in _rel.finditer(visibile(html)):
                errori.append("%s/%s data relativa '%s'" % (lang, nome, m.group()))
            for m in _anno.finditer(html):
                if int(m.group(1) or m.group(2)) > 1999:
                    errori.append("%s/%s anno %s" % (lang, nome, m.group()))
            for h in _href.findall(html):
                if h.startswith("http://"):
                    if h != PORTALE[lang] and h[7:].rstrip("/").lower() not in morti:
                        errori.append("%s/%s link esterno %s" % (lang, nome, h))
                elif h.endswith(".html") and h[:-5] not in pagine and h[:-5] not in morti:
                    errori.append("%s/%s link a pagina inesistente %s" % (lang, nome, h))
        print("%s/%s: %d pagine, %d caratteri" % (lang, sid, len(pagine), totale))
    for e in errori:
        print("  ERRORE " + e)
    if not errori:
        print("  ok")


# python tools/web/sito.py snellisci  -> applica snellisci() a TUTTE le pagine esistenti
if __name__ == "__main__" and sys.argv[1:] == ["snellisci"]:
    cambiate = 0
    for cartella, _, nomi in os.walk(RADICE):
        for f in nomi:
            if f.endswith(".html"):
                percorso = os.path.join(cartella, f)
                prima = io.open(percorso, encoding="utf-8", newline="").read()
                dopo = snellisci(prima)
                if dopo != prima:
                    io.open(percorso, "w", encoding="utf-8", newline="").write(dopo)
                    cambiate += 1
    print("snellite %d pagine" % cambiate)
