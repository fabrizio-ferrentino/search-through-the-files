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
_href = re.compile(r'(?i)href\s*=\s*"([^"]*)"')   # anche HREF= delle pagine scritte a mano
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


# DIALETTI (20/11/2026, proprietario: "manca ancora qualcosa per sembrare dei siti autentici
# di fine anni 90"). Nel '99 il sorgente diceva CHI aveva fatto la pagina e con che cosa:
#   mano      scritta a mano nel Blocco note: tag e attributi in MAIUSCOLO, valori semplici
#             senza virgolette (<TABLE BORDER=0 WIDTH=600>), commenti di chi la scriveva;
#   editor    fatta con un editor da ufficio (il FrontPage dell'epoca; qui "Hydrophone
#             HomePage", della stessa ditta del sistema): la riga GENERATOR, i segnaposto
#             <!--hpbot ...--> e la zona modificabile del modello;
#   composer  fatta con l'editor del browser (qui "WebNet Composer"): la riga GENERATOR;
#   bacheca   generata dal programma del forum (qui "Corkboard"): GENERATOR e commenti suoi.
# Marche INVENTATE, come il browser e il sistema. Commenti in inglese in ogni lingua, come
# quelli che nascondono la chiave (WebRuntime._COMMENT): cosi' <!-- --> non e' piu' un
# indizio, e nel sorgente bisogna leggere. A schermo non cambia niente: i commenti si
# tolgono prima di disegnare, un commento a inizio riga si porta il suo a capo (spazi in
# piu' fra due blocchi non contano) e gli attributi si leggono senza badare a maiuscole
# e virgolette. Lo prova tests/bb_dump.gd (BBCode e posti per la chiave identici).
DIALETTI = {
    "mano": ["blog", "anime", "band", "prof", "radio", "calcio", "musica", "y2k", "driver",
             "giochi", "treno", "diario", "nessuno", "tecnico", "numeri"],
    "editor": ["news", "cronaca", "shop", "meteo", "mail", "tv", "viaggi", "comune",
               "biblioteca", "hosting", "vincente"],
    "composer": ["ricette", "animali", "scuola", "oroscopo", "ascolto", "volto", "annunci",
                 "mercatino"],
    "bacheca": ["forum", "genitori", "brutti", "lavoro", "chat"],
}
_GENERATORE = {
    "editor": '<meta name="GENERATOR" content="Hydrophone HomePage 3.0">',
    "composer": '<META NAME="GENERATOR" CONTENT="WebNet Composer 4.5 [%s] (Win95; I)">',
    "bacheca": '<meta name="GENERATOR" content="Corkboard 5.1">',
}
# il commento che si mette prima di certi tag, per dialetto ("" = nessuno)
_COMMENTI = {
    "mano": {"contatore": "counter", "form": "form", "/form": "end form",
             "musica": "music", "marquee": "scrolling text",
             "inizio": "written by hand with Notepad", "fine": "end of page"},
    "editor": {"contatore": 'hpbot bot="HitCounter" i-image="0" i-digits="6"',
               "form": 'hpbot bot="SaveResults" s-format="TEXT/TSV"', "/form": "",
               "musica": "", "marquee": "",
               "inizio": '#BeginEditable "body"', "fine": "#EndEditable"},
    "composer": {"contatore": "counter", "form": "", "/form": "", "musica": "", "marquee": "",
                 "inizio": "", "fine": ""},
    "bacheca": {"contatore": "", "form": "post form", "/form": "end post form",
                "musica": "", "marquee": "",
                "inizio": "Corkboard 5.1 - this page is built by the server, do not edit",
                "fine": "end Corkboard"},
}
# attributi il cui valore, se semplice, chi scriveva a mano lasciava senza virgolette
_SENZA_VIRGOLETTE = {"width", "height", "border", "cellpadding", "cellspacing", "bgcolor",
                     "color", "size", "align", "valign", "colspan", "rowspan", "text", "link",
                     "vlink", "alink", "method", "type", "maxlength", "cols", "rows", "loop",
                     "autostart", "hidden", "behavior", "direction", "scrollamount", "hspace",
                     "vspace", "noshade"}
_tag_html = re.compile(r"<(/?)([A-Za-z][A-Za-z0-9]*)([^<>]*)>")
_attributo = re.compile(r"""([A-Za-z][A-Za-z-]*)(\s*=\s*)("[^"]*"|'[^']*'|[^\s"'>]+)""")
_semplice = re.compile(r"^[A-Za-z0-9#%]+$")


def dialetto_di(sid):
    for d, siti in DIALETTI.items():
        if sid in siti:
            return d
    return ""


def _in_maiuscolo(html):
    def attr(m):
        nome, uguale, valore = m.group(1), m.group(2), m.group(3)
        if valore[:1] == '"' and nome.lower() in _SENZA_VIRGOLETTE and _semplice.match(valore[1:-1]):
            valore = valore[1:-1]
        return nome.upper() + uguale + valore

    def tag(m):
        return "<" + m.group(1) + m.group(2).upper() + _attributo.sub(attr, m.group(3)) + ">"
    return _tag_html.sub(tag, html)


def _commenta(html, regola, testo):
    """Mette <!-- testo --> prima di ogni tag che risponde alla regola: su una riga sua se
    il tag e' a inizio riga, attaccato al tag altrimenti (un a capo in mezzo a un testo si
    vedrebbe come spazio)."""
    if not testo:
        return html

    def metti(m):
        a_capo = m.start() > 0 and html[m.start() - 1] == "\n"
        return "<!-- %s -->%s%s" % (testo, "\n" if a_capo else "", m.group(0))
    return regola.sub(metti, html)


_R_CONTATORE = re.compile(r"(?i)<img\b[^>]*\bsrc\s*=\s*\"[^\"]*contatore[^\"]*\"[^>]*>")
_R_FORM = re.compile(r"(?i)<form\b[^>]*>")
_R_FINE_FORM = re.compile(r"(?i)</form\s*>")
_R_MUSICA = re.compile(r"(?i)<(?:embed|bgsound)\b[^>]*>")
_R_MARQUEE = re.compile(r"(?i)<marquee\b[^>]*>")


def dialetto(html, sid, lang="en"):
    """Il sorgente nel dialetto del suo sito (vedi DIALETTI). Una seconda passata non
    cambia niente: se la pagina ha gia' il suo dialetto si lascia com'e'."""
    d = dialetto_di(sid)
    if not d:
        return html
    c = _COMMENTI[d]
    firma = c["inizio"] or "GENERATOR"
    if firma.lower() in html.lower():
        return html
    if d in _GENERATORE:
        riga = _GENERATORE[d] % lang.upper() if "%s" in _GENERATORE[d] else _GENERATORE[d]
        html = re.sub(r"(?i)</title>", lambda m: m.group(0) + "\n" + riga, html, count=1)
    html = _commenta(html, _R_CONTATORE, c["contatore"])
    html = _commenta(html, _R_FORM, c["form"])
    if c["/form"]:
        html = _R_FINE_FORM.sub(lambda m: m.group(0) + "<!-- %s -->" % c["/form"], html)
    html = _commenta(html, _R_MUSICA, c["musica"])
    html = _commenta(html, _R_MARQUEE, c["marquee"])
    if c["inizio"]:
        html = re.sub(r"(?i)(<body\b[^>]*>\n?)", lambda m: m.group(1) + "<!-- %s -->\n" % c["inizio"],
                      html, count=1)
    if c["fine"]:
        html = re.sub(r"(?i)\n?</body>", lambda m: "\n<!-- %s -->%s" % (c["fine"], m.group(0)),
                      html, count=1)
    if d == "mano":
        html = _in_maiuscolo(html)
    return html


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
            html = dialetto(snellisci(html), sid, lang)
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


# python tools/web/sito.py dialetti  -> mette ogni pagina esistente nel dialetto del suo sito
if __name__ == "__main__" and sys.argv[1:] == ["dialetti"]:
    cambiate = 0
    for lang in sorted(os.listdir(RADICE)):
        if not os.path.isdir(RADICE + lang):
            continue
        for sid in sorted(os.listdir(RADICE + lang)):
            cartella = RADICE + lang + "/" + sid
            if not os.path.isdir(cartella):
                continue
            for f in os.listdir(cartella):
                if f.endswith(".html"):
                    percorso = os.path.join(cartella, f)
                    prima = io.open(percorso, encoding="utf-8", newline="").read()
                    dopo = dialetto(prima, sid, lang)
                    if dopo != prima:
                        io.open(percorso, "w", encoding="utf-8", newline="").write(dopo)
                        cambiate += 1
    print("pagine nel loro dialetto: %d" % cambiate)
