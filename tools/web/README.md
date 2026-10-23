# tools/web — writing the fake web sites

Writing tools only: Godot ignores `.py` files, and nothing here ships with the game. The
pages in `web/pages/<lang>/<site>/` are the real source; these scripts help write and check
them. The rules every site follows are in [docs/WEB_CATALOG.md](../../docs/WEB_CATALOG.md);
the HTML subset in [docs/WEB_AUTHORING.md](../../docs/WEB_AUTHORING.md).

## `sito.py`

- `genera(id, skin, pagine, morti=())` **rewrites** the whole folder of a site in both
  languages from a small Python script, then prints the checks.
  - `skin(lang, page, title)` returns `(header_html, footer_html, body_attributes)`. The same
    header and nav go on every page.
  - `pagine` is `{ "index": {"en": (title, body_html), "it": (title, body_html)}, ... }`.
- `controlla(id, morti=())` runs the **same checks** on pages that already exist, without
  touching them. Use it after editing a page by hand.

The checks are the same rules `tests/siti_catalogo_test` enforces, so they catch problems
before Godot runs:
- at least 6000 characters of visible text per language;
- no text shaped like a key;
- no `<input>`, `<form>` and the like;
- no relative timestamps;
- no year after 1999;
- no link outside the site except the WebNet portal and the `morti` addresses;
- no link to a page that does not exist.

Minimal site script (save it anywhere, for example the scratchpad, and run it with `python`):

```python
import sys; sys.path.insert(0, r"<project>/tools/web")
from sito import genera, PORTALE

def skin(lang, page, title):
    nav = '<a href="index.html">Home</a> | <a href="about.html">%s</a>' % ("About" if lang == "en" else "Chi siamo")
    head = '<font face="Arial" size="5"><b>My Site</b></font><br><font face="Arial" size="2">%s</font><hr>' % nav
    foot = '<hr><center><font face="Arial" size="1"><a href="%s">WebNet</a></font></center>' % PORTALE[lang]
    return head, foot, 'bgcolor="#FFFFFF" text="#000000" link="#0000CC"'

P = {"index": {"en": ("My Site", "<p>...</p>"), "it": ("Il mio sito", "<p>...</p>")},
     "about": {"en": ("My Site - About", "<p>...</p>"), "it": ("Il mio sito - Chi siamo", "<p>...</p>")}}
genera("mysite", skin, P)
```

Tips learned writing the 30 sites:
- Since 2026-10-23 `<td width="N">` / `width="N%"` works, so a narrow first column (an
  author column, a side bar of links) is possible; without it the columns share the table
  width evenly.
- `genera()`'s skin puts the SAME header on every page; that is fine inside one site, but
  every site needs its own look (see "Style" in docs/WEB_CATALOG.md).
- Join chat-log lines with `<br>` and no newline, or every line after the first starts with
  a space.
- English pages use dollars, Italian ones lire.
- Write Italian with `e'` / `piu'` like the existing pages.

## `media.py`

Stdlib-only generator of the PLACEHOLDER media (2026-10-23; the owner chose generated
placeholders, to be replaced later). Run it with `python tools/web/media.py` from the
project root (`python tools/web/media.py busta` regenerates only the files whose name
contains "busta"; each file is a placeholder, replace it with a real one under the same name):
- a GIF89a writer (own LZW encoder) draws the animated and still pictures into
  `web/img/*.gif` - no words in the pictures, so there is no text to translate or to
  look like a key (pictograms and digits only, no real brands);
- an SMF writer composes four original melodies into `web/audio/*.mid`: `jack`, `inno`,
  `valzer`, `notte`.
The game plays the MIDI files itself (`MidiSynth`) and decodes the GIFs (`GifDecoder`); after
adding files run `--import` and `tests/gif_test.gd`, `tests/midi_test.gd` and
`siti_catalogo_test` (check MEDIA_ESISTONO). Pages cite them as `<img src="x.gif">` and
`<bgsound src="x.mid">`, see docs/WEB_AUTHORING.md.

## `registra.py`

`registra([ {...}, ... ])` adds sites to `scripts/os/catalogo_siti.gd`, listing the folder's
pages with index first, and adds their two `WS_*` rows to `locale/ui.csv`. Fields of each
dict:

| Field | Required | What it is |
|---|---|---|
| `id` | yes | the site's folder and id |
| `ws` | yes | the CSV key; `<ws>_D` is created for the description |
| `en`, `it` | yes | the domain in each language |
| `nome` | yes | `(en, it)` name shown on the portal |
| `desc` | yes | `(en, it)` description shown on the portal |
| `tipo` | no | `"normale"` (default) or `"lore"` |
| `voce` | no | for lore sites: `"padre"`, `"ragazzo"` or `"maledizione"` |
| `featured` | no | `true` lists the site under Favourites on the portal |
| `morti` | no | dead addresses the site may link to |
| `commento` | no | Italian comment lines written above the entry |

A site already in the catalog is skipped. Afterwards: `--import`, then `siti_catalogo_test`
and `web_locale_test`.
