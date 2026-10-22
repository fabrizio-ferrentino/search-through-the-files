"""Aggiunge siti al catalogo (catalogo_siti.gd) e le loro righe al CSV. Strumento di scrittura."""
import io, csv, os, re

PROJ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..") + os.sep

def _q(s):
    return '"%s"' % s.replace('"', '""') if ("," in s or '"' in s) else s

def registra(siti):
    cat = io.open(PROJ + "scripts/os/catalogo_siti.gd", encoding="utf-8").read()
    righe_csv = io.open(PROJ + "locale/ui.csv", encoding="utf-8").read()
    nuove_csv = []
    blocchi = []
    for s in siti:
        pag = sorted(f[:-5] for f in os.listdir(PROJ + "web/pages/en/" + s["id"]) if f.endswith(".html"))
        pag.remove("index")
        pag = ["index"] + pag
        if ('"id": "%s"' % s["id"]) in cat:
            print("gia' nel catalogo:", s["id"])
            continue
        b = ""
        if s.get("commento"):
            b += "".join("\t# %s\n" % r for r in s["commento"])
        b += '\t{"id": "%s", "nome": "%s", "desc": "%s_D",\n' % (s["id"], s["ws"], s["ws"])
        b += '\t\t"en": "%s", "it": "%s",\n' % (s["en"], s["it"])
        b += '\t\t"tipo": "%s", "voce": "%s", "featured": %s, "stato": "completo",\n' % (
            s.get("tipo", "normale"), s.get("voce", ""), "true" if s.get("featured") else "false")
        lista = ", ".join('"%s"' % x for x in pag)
        b += '\t\t"pagine": [%s]' % lista
        if s.get("morti"):
            b += ',\n\t\t"morti": [%s]' % ", ".join('"%s"' % m for m in s["morti"])
        b += "},\n"
        blocchi.append(b)
        if ("\n%s," % s["ws"]) not in righe_csv:
            nuove_csv.append("%s,%s,%s" % (s["ws"], _q(s["nome"][0]), _q(s["nome"][1])))
            nuove_csv.append("%s_D,%s,%s" % (s["ws"], _q(s["desc"][0]), _q(s["desc"][1])))
    i = cat.rindex("]\n\n# Il sito con quell'id")
    cat = cat[:i] + "".join(blocchi) + cat[i:]
    io.open(PROJ + "scripts/os/catalogo_siti.gd", "w", encoding="utf-8", newline="\n").write(cat)
    # le righe WS_ nuove dopo l'ultima WS_ esistente
    linee = righe_csv.split("\n")
    ultimo = max(k for k, l in enumerate(linee) if l.startswith("WS_"))
    linee = linee[:ultimo + 1] + nuove_csv + linee[ultimo + 1:]
    io.open(PROJ + "locale/ui.csv", "w", encoding="utf-8", newline="\n").write("\n".join(linee))
    print("registrati:", [s["id"] for s in siti], "righe CSV:", len(nuove_csv))
