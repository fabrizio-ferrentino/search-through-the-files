# Web page authoring guide

> Looking for **which file holds which string**, how the gateway is generated, or how
> to replace a whole site? That is [WEB_SITES.md](WEB_SITES.md). This file is about
> writing the HTML itself.

How to write the in-game web pages (`web/pages/<lang>/*.html`) for the fake browser.
The sites are the core of the gameplay: this file is the reference for adding
or restyling them.

**One page, one file per language.** The pages live in `web/pages/en/` and
`web/pages/it/`; the file name is an identifier and is the same everywhere, the
content is translated. `BrowserApp.read_page` picks the folder of the language in
play and falls back to `en`. Everything below applies to a page in any language.

## How the browser renders a page

One page = **one `RichTextLabel`**. `scripts/os/html_bbcode.gd` (`HtmlBB`)
compiles the legacy-HTML subset into a single BBCode string;
`scripts/os/app_browser.gd` (`BrowserApp`) puts it in the label. Because the
whole document is one control:

- **selection is continuous** across the whole page (table cells included),
  with the Win95 navy highlight; Ctrl+C / right-click "Copia" copies it;
- **links** are native `[url]` metas: first click always navigates, and a
  drag over a link selects instead of navigating (browser-like);
- the page **reflows** with the window and scrolls natively (including
  auto-scroll while drag-selecting past the edge).

The raw HTML file is also what the player sees in **"Visualizza sorgente"**
(pretty-printed), so write source that is pleasant to snoop through — the
`<!-- comment -->` key can hide there.

## Supported HTML subset

| HTML | Renders as |
|---|---|
| `<b> <i> <u>` | bold / italic / underline |
| `<font color="#..." size="1..7" face="...">` | color + size + family (see Fonts) |
| `<h1>..<h6>` | bold heading sizes |
| `<br>`, `<p>`, `<p align="center/right">` | line break / paragraph (blank line) / aligned paragraph |
| `<center>`, `<div align="center">` | centered block |
| `<a href="pagina.html">` | link (color from `<body link>`) |
| `<hr>`, `<hr width="50%" size="4" color="#...">` | native horizontal rule |
| `<ul><li>`, `<ol><li>` | • bullets / numbered list |
| `<blockquote>` | indented block (forum quotes) |
| `<img src="file.png" width="W" height="H">` | image from `web/img/`, PNG or **animated GIF** (see below); inside `<a>` it is a clickable picture |
| `<body background="tile.gif">` | **tiled background** (PNG or GIF, animated too) that scrolls with the page; keep `bgcolor` too, it shows while loading |
| `<marquee>` | **scrolling line** (`scrollamount`, `scrolldelay`, `direction="right"`, `behavior="alternate"`, `width="N"`); top level only, and it must FIT ON ONE LINE (about 90 characters at size 3 in a full-width window): inside a table cell, or when longer than the page, it is shown STILL, as Netscape did |
| `<blink>` | **blinking** text |
| `<bgsound src="tune.mid" loop="infinite">` | **background music** from `web/audio/` (`.mid`, or `.wav`/`.ogg`); starts when the page has finished loading; no `loop` = plays once |
| `<embed src="tune.mid" autostart="true/false" hidden="true" loop="true">` | music too; NOT hidden = a small period player (play ► / stop ■) drawn on the page |
| `<form action="..." method="get/post">` | a REAL form (owner, 2026-10-24). Fields are small inline tables; you can type in them. `action` must stay inside the site: empty, a page of the site, or a script of the site's own server (`/cgi-bin/x.pl`, `.cgi`, `.asp`); never `http://`, `www.` or `mailto:` (`siti_catalogo_test` MODULI_NEL_SITO) |
| `<input type="text">`, `type="password"` (dots), `<textarea rows= cols=>` | typeable field (click it; Backspace, Tab = next field of the form, Enter sends, newline in a textarea, ESC stops typing). An empty field has the height of a line; a textarea is `rows` x 19 px |
| `<input type="checkbox/radio" name= value= checked>` | toggles on click; radios of the same form+name are exclusive; a checked box sends its `value` |
| `<select name><option value>` | Win95 drop-down (the field shows the chosen option and a ▼). `<option>` may stay unclosed |
| `<input type="submit/button/reset">`, `<button>` | button; label from `value=`, else the CSV texts WEB_FORM_SUBMIT / WEB_FORM_RESET. Reset puts the values back. `type="hidden"` is sent but not drawn |
| `<pre>` | monospace block: spaces kept (become U+00A0), newlines kept, a leading newline dropped. Use it for ASCII tables and art |
| `<tt> <kbd> <samp>` | monospace inline |
| `<s> <strike> <del>` | strike-through |
| `<sup> <sub>` | smaller text (size 11, not raised) |
| `<big> <small>` | larger (20) / smaller (12) text |
| `<dl> <dt> <dd>` | definition list (each on its own line, dd indented by 6 non-breaking spaces) |
| `<address>` | italic block |
| `<table> <tr> <td> <th>` | real table, see below |
| entities (`&nbsp;` is a real non-breaking space, kept after whitespace collapsing: **use it to align ASCII art**; plain spaces are collapsed to one) | `&nbsp; &copy; &raquo; &laquo; &middot; &hellip; &quot; &mdash; &deg; &lt; &gt; &amp;` |

**Body attributes** drive the page colors — this is how dark pages work:

```html
<body bgcolor="#000000" text="#9a9a9a" link="#66FF66">
```

`bgcolor` = page background, `text` = default text color, `link` = link color.

### Tables

- `border="1"` → gray cell borders; `cellpadding="N"` → cell padding;
  `bgcolor` on `<table>`, `<tr>` or `<td>` (most specific wins).
- `<th>` = bold + centered. `<td align="center/right">` supported.
- **`<td width="160">` / `width="25%"` WORK** (since 2026-10-23): the first row that declares
  widths fixes its columns, the others share what is left of the table's `width`. This is the
  period **side-bar layout**: `<table width="100%"><tr><td width="170" bgcolor="#000033">menu</td><td>content</td></tr></table>`.
- `bordercolor="#..."` on `<table>` colours the cell borders (default grey).
- Nested tables work.
- `cellspacing` is always **0**: cells sit flush against each other (the theme
  sets `table_*_separation` to 0), which is how these pages were authored.
- **`width="70%"` and `width="500"` WORK**, and so does centering
  (`<table align="center">`, or a table inside `<center>` / `<div align="center">`).
  A BBCode `[table]` is otherwise as wide as its content, so the compiler uses the
  genuine 90s trick: it appends an invisible row holding a **transparent spacer
  image** (`web/img/spacer.png`) of exactly the required width — see
  `HtmlBB._spacer_row`. Percentages need the page width, which `BrowserApp` passes
  as `ctx["page_width"]` and recomputes when the window is resized (real reflow).
  With several columns the declared width is split evenly between them.
- **A table narrower than the page stays narrow** (since 2026-10-24): a `width` smaller than
  the page, in px or %, is wrapped between empty filler columns, so a long paragraph no longer
  stretches a "560 px card" to the page edge. `align="center"` puts a filler on each side.
- `<hr>` inside a table cell is as wide as the CELL (a `%`, or no width, is turned into pixels
  of the cell); Godot alone would measure it on the whole page and push the table out.
- **Known limit:** a full-width table with several text-heavy columns can still exceed the page
  by 5-10 px (Godot distributes the column widths itself; news/index measured 910 on 900). Give
  such columns explicit `width`s.
- Without a `width`, a table stays as wide as its content — which is also
  period-accurate (e.g. a small login box). Give banners
  `width="100%"` if you want them to span the page like the forum's does.

### Mouse behavior on a page

Clicks, drags and the cursor are handled by **`PageView`**
(`scripts/os/page_view.gd`), a `RichTextLabel` subclass, so the page behaves
like a real browser instead of like a bare Godot text box:

| Gesture | Result |
|---|---|
| Single click | No selection; a link under the cursor navigates |
| Click with a few px of hand shake | Still a click (drag needs > `DRAG_SOGLIA` = 6 px) |
| Double click | Selects the word (plain paragraphs — see quirks) |
| Drag | Selects a range and does **not** navigate |
| Cursor | Hand over links, I-beam over text, arrow in the margins and below the text |

Why the subclass is needed (all verified with `tests/browser_click_test.gd`):

- While the button is held, the `RichTextLabel` extends the selection **on its
  own** via an internal 0.05 s timer, so a motionless click used to select a
  whole sentence. `PageView` clears the selection on release when no real drag
  happened.
- The engine emits `meta_clicked` (link) only when **no selection is active**,
  so 2-3 px of hand shake used to kill every link. `PageView` swallows
  sub-threshold motion while the button is held. This matters more than it
  sounds: at a 1280-wide window on a 1920 viewport, one physical pixel is ~1.5
  logical pixels.
- `Control.get_cursor_shape()` **cannot be overridden from GDScript** in Godot 4.
  `RichTextLabel` already hit-tests links (hand) and returns the control's
  *default* cursor elsewhere, so `PageView` keeps that default up to date as the
  mouse moves (I-beam only where text actually is).

### Engine quirks (by design)

- A drag that **starts on plain text** and passes **beyond** a table selects
  the table's cells too.
- A drag that starts **inside** a table stays confined to that table.
- The mouse press must land **on glyphs** to start a selection.
- **Double click inside a table cell selects nothing** (the engine looks the word
  up in the frame it hits, and a cell is a frame of its own). Word selection
  works in normal paragraphs.
- A **SubViewport that receives forwarded input** does not know the mouse is
  inside it: with `gui.mouse_in_viewport` false, the Viewport hands mouse-motion
  *events* to controls **only while a button is held**. Enter/exit notifications
  still fire (buttons still highlight), but `meta_hover_started/ended` and any
  pointer tracking in `_gui_input` never run — which is why the page cursor used
  to stay stuck. `player.gd` calls `notify_mouse_entered()` /
  `notify_mouse_exited()` on the OS viewport when entering/leaving the PC; any
  test that drives the OS through `push_input` must do the same.

### NOT supported (do not use)

CSS (classes, `style=`), `colspan`/`rowspan`, `<span>`,
`<script>` (so no JavaScript effects), Java applets, image maps (`<map>`; cost vs value, owner's call 2026-10-24), `cellspacing`, `bordercolorlight/dark` (parsed but ignored), `valign`,
floating images (`<img align="left">`: an image sits in the line), frames.

### How a form is sent (2026-10-24)

Sending builds `name=value&name=value` (urlencoded) and goes to `action`:
- a page of the same site that exists: it opens, the address bar shows `page.html?query`;
- anything else (a `/cgi-bin/...pl`, `.cgi`, `.asp`): the browser opens the period error page
  `web/pages/<lang>/500.html` "500 Internal Server Error" ("WebNet HTTPd/1.2"); the address bar keeps
  the script URL + query. This is the normal case: the button works, nobody is there any more.
Links the visitor has already opened take the `<body vlink>` colour; hovering a link shows its
address in the status bar.
History, so it does not come back: until 2026-10-24 `<input>` was decorative only and forbidden in the sites
(owner, 2026-10-20: a field that cannot be typed in is a broken promise). Owner, 2026-10-24: "Cerca di
ricreare esattamente lo stile dei siti di fine anni 90, quindi se i pulsanti esistevano creamoli."

## Fonts

Four bundled families (`assets/fonts/`, SIL OFL 1.1), clones of what the 90s web used.
`face=` picks one (a list like `"Verdana, Arial"` takes the first it recognises):

| `face=` contains | Family | Clone of |
|---|---|---|
| arial, helvetica, verdana, tahoma, impact, sans (or no face) | Arimo | Arial — the page default |
| times, serif, georgia, garamond, palatino, book, century | **Tinos** | Times New Roman (regular, bold, italic, bold italic) |
| comic | **Comic Neue** | Comic Sans (regular, bold; no italic) |
| courier, mono, fixedsys, console | Cousine | Courier New |

Arimo and Cousine come from the theme (`Win95.make_theme()`); Tinos and Comic Neue are
pushed by HtmlBB with `[font=file]`, and a `<b>`, `<i>` or `<hN>` inside them picks the
right file of the same family (Godot's `[b]` alone would switch back to Arimo Bold). A
`<font face>` does not cross into a table: each cell starts again from Arimo, so set the
face inside the cells too (that is also how period pages were written).

## Images

Drop files in **`web/img/`** (PNG/WEBP; they import as normal Godot resources
and ship automatically). Reference them by bare filename:

```html
<img src="occhio.png" width="240" height="140">
```

A missing file renders a drawn "broken image" placeholder (gray box + red X)
— the page never errors, but `siti_catalogo_test` (MEDIA_ESISTONO) fails on it: a broken
image ON PURPOSE goes in that test's `MEDIA_ROTTI` list.

**GIFs** (animated or not) are decoded by `scripts/os/gif_decoder.gd` the first time a page
shows them, and kept: Godot does not import `.gif`, so they ship as plain files (see the
export note). Transparency, per-frame delays and frame disposal work.

**The placeholder media** are drawn by `tools/web/media.py` (stdlib Python: re-run it to
regenerate, or replace any file keeping its name). Rule: **no words inside a picture** — an
image is the same in both languages — only pictograms and digits; no real brands.

| File | What |
|---|---|
| `cantiere.gif` | under-construction sign, animated |
| `busta.gif` / `globo.gif` / `smile.gif` / `nuovo.gif` | spinning envelope / spinning globe / bouncing smiley / flashing star burst |
| `fiamme.gif` / `arcobaleno.gif` (480x18 / 480x6) | flame divider (animated) / rainbow divider |
| `floppy.gif` / `ingranaggio.gif` | floppy with a falling arrow / turning gear |
| `pallone.gif` / `pentola.gif` / `fiore.gif` / `stemma.gif` | bouncing ball / steaming pot / flower / town coat of arms |
| `zodiaco.gif` (160x160) | turning zodiac wheel with the moon |
| `volto.gif` (200x240) | face diagram with numbered measurement lines |
| `zampa.gif` / `sole.gif` / `aereo.gif` / `carrello.gif` / `pacco.gif` | paw print / turning sun / small plane crossing (100 px wide) / shopping trolley / parcel with string |
| `contatore_jack.gif`, `contatore_grifoni.gif`, `contatore_stelle.gif`, `contatore_giorni.gif` | counters (green digits) |
| `bottone_monitor.gif`, `bottone_modem.gif`, `bottone_dischetto.gif` | 88x31 badges |
| `stelle.gif` (animated night sky), `griglia.gif` (neon grid), `quadretti.gif` (gingham), `pergamena.gif` (parchment), `metallo.gif` (brushed metal) | tiles for `<body background>` |
| `web/audio/`: `jack.mid` (pop loop), `inno.mid` (stadium anthem), `valzer.mid` (accordion waltz), `notte.mid` (night pad) | page music |

## Music

`<bgsound>` / `<embed>` play a file from **`web/audio/`**. MIDI is the period format and
the default: Godot cannot play it, so `scripts/os/midi.gd` reads the file and
`scripts/os/midi_synth.gd` renders it with cheap "1997 sound card" voices (square,
triangle, saw, noise drums; the General MIDI program picks the voice) in a thread, then
caches it — so the music starts a moment after the page, as it did. `.wav` / `.ogg` work
too. The music stops when the player leaves the page, reloads, presses Stop while loading,
or closes the browser; minimising the window does not stop it (it did not in 1999 either).
The player can mute it or lower it with the speaker icon in the tray (next to the clock), and
outside the PC the music comes from the desk, muffled. Use it sparingly: a page that plays music also covers the sounds of the room.

## Adding a site

A site is a **folder**, `web/pages/<lang>/<site>/`, one per language with the same file
names, and an entry in the site catalog `scripts/os/catalogo_siti.gd`. The full recipe
(CSV rows, catalog fields, dead links on purpose) is in
[WEB_SITES.md](WEB_SITES.md) §3; the planned sites are in
[WEB_CATALOG.md](WEB_CATALOG.md). Each run picks 10-15 of the catalog's sites (4-5 of
them lore), the generated home lists them, and two of them host the two web keys, on
any of their pages.

Inside a site, link pages **relatively** (`<a href="rules.html">`): a relative href
always stays in the site of the page it is on. Link other sites and the portal
**absolutely** (`<a href="http://www.webnet.it">` in Italian pages,
`http://www.webnet.com` in English ones).

## Addresses (the URL of a site)

Each site has a **period domain per language** in the catalog: `www.newstoday.com` /
`www.newsoggi.it`, `www.retroforum.com` / `www.retroforum.it`, `webmail.webnet.com` (a
subdomain of the provider), `www.webnet.com/~jack99` (a personal page under `~user` on
the ISP's webspace — that is how it was done); the gateway itself is `www.webnet.com` /
`www.webnet.it`. A page's address is the domain plus `/<page>.html`
(`www.retroforum.it/rules.html`); the index is the bare domain.

`WebRuntime.page_of()` accepts an address with or without `http://`, with or without
`www.`, the bare second-level name (`retroforum`) and the old internal id. An address
that is nobody's — or a site that is not part of tonight's run — gives "cannot find
server" (`nonserver.html`) with the bar keeping what you typed; a missing page of an
existing site gives `404.html`.

## Loading a page

Opening a page is not instant: the browser covers it for 0.35-1.2 s (random, longer
for "heavier" pages) while the status bar narrates the download, WTTG2-style. The
weight comes from `WebRuntime.fake_kb(page)` — the same number the wiki lists in its
history — so a page's name is what decides how heavy it looks and how long it takes.
Nothing to do when authoring a page; just know that a test which loads pages must
wait (`await browser.attendi_caricamento()`) or set `BrowserApp.attesa_scala` low.

## The web key (per-run)

There are TWO web keys per run (keys 2 and 3, since 2026-10-18), on two different
sites — on a page drawn among each site's pages — each visible or source-only at
random. For each one,
`WebRuntime.source_html()` injects the key into its carrier page at a spot the run
seed picks out of every safe spot the page offers — `scripts/os/web_anchor.gd`
scans for them. It used to always land in an extra line before `</body>`, which
the player learned to recognise; WTTG2-style, it can now be anywhere.

**Rendered on the page** (selectable):

| kind | where | what lands there |
|---|---|---|
| `RIGA` | between two top-level blocks (incl. last, so "at the end" still happens, rarely) | a `<p>` with the carrier sentence |
| `IN_FRASE` | after a space in the middle of one of your sentences | **the bare code only** (`...the sky is 3-A87G blue...`) — inherits the surrounding font and colour |
| `CODA_PARAGRAFO` | just before a top-level `</p>` | the carrier sentence, bare |
| `VOCE_ELENCO` | a new `<li>` in an existing `<ul>` | the sentence + the sibling item's `<font>` |
| `CODA_CELLA` | before a `</td>`, light cells only | the sentence, bare |

**Source only** (invisible on screen, found via "Visualizza sorgente"): a comment
between blocks, mid-sentence *in the markup*, inside the table markup, or in
`<head>`; or the code tucked into a `title=` / `alt=` attribute of a link or image
you already wrote.

**What this asks of a new page:** give it several top-level blocks and at least one
prose paragraph of ~24+ characters, and the scanner will find plenty of spots (the
current pages yield 7-20 rendered and 9-43 source-only). Lists and light table
cells add more. `tests/html_bb_test.gd` prints a per-page census and fails if a page
drops below 3 rendered / 6 source-only spots.

Two things the scanner deliberately refuses, because they were real bugs: a
rendered snippet inside a table but *outside* a cell (HtmlBB discards it — the key
would be unfindable) and a rendered snippet in a dark cell (black on dark). Never
hardcode a key in a page — it changes every run.

## Style templates

**Every site must look like itself** (owner, 2026-10-23: "most sites are very similar, if
not identical"). Until then nearly all of them shared one skeleton — a coloured 100% banner
table, a light 100% nav-bar table, Arial paragraphs, a centred footer — with different
colours. Each site now has its own **style archetype** in [WEB_CATALOG.md](WEB_CATALOG.md)
(column "Style"); never reuse another site's skeleton. The 90s web had many genuinely
different shapes, and the HTML subset now covers them:

- **Bare academic / institutional** — grey default background, no colours, Times, `<h1>`,
  `<ul>` of links, `<hr>`, "last updated", no tables at all.
- **Personal homepage (GeoCities)** — tiled background, Comic, everything centred,
  animated GIFs, a hit counter, a MIDI, a marquee, a guestbook, a "web ring" row.
- **Side-bar portal** — a dark left column of links (`<td width>`), content on the right,
  88x31 badges at the bottom of the column.
- **Splash page** — an index that is only a big picture and an "enter" link.
- **Newspaper** — Times masthead, date line, serif columns.
- **Loud fan site** — flames, blinking, marquees, a visible MIDI player.
- **Card on a tiled background** — a narrow centred white table on gingham or parchment.
- **Terminal / hacker** — black, green Courier, ASCII art (draw it with `&nbsp;` for the
  spaces, 2026-10-23: before, `&nbsp;` was collapsed and the drawings came out crooked).

The examples below predate the archetypes: use them for structure (threads, archives,
listings), not for the look.

- **Complex community site** → `web/pages/en/forum/` (banner with tagline, a navigation
  bar on every page, section listings with alternating row colors, per-post tables with
  an author column, avatar `<img>` and `<blockquote>` quotes, a member list, a profile, the
  rules, and a "members only" page that the locked topics link to).
- **Personal homepage** → `web/pages/en/treno/` (dark body, an ASCII drawing in
  Courier, a visitor counter, a link list, a guestbook that no longer accepts entries).
- **Newspaper archive** → `web/pages/en/cronaca/` (masthead, section bar, article pages
  with a byline, an archive listing).
- **Shop** → `web/pages/en/shop/` (catalog grid, product pages, a fake cart and terms).
- **Forum-style posts** → `web/pages/en/vincente/thread_diary.html` or `lavoro/` (one
  cell per post, author and date on top; a narrow author column is now possible with
  `<td width>`).
- **Chat log, minimal dark page** → `web/pages/en/chat/` and `nessuno/`.
- **Portal / listing** → the generated home (`WebRuntime.home_html()`).

## Testing

```powershell
# unit test del compilatore HTML->BBCode + censimento dei nascondigli, OGNI lingua (headless)
& $godot --headless --path $proj -s res://tests/html_bb_test.gd
# ogni lingua completa e coerente: pagine, link, domini, wiki (headless)
& $godot --headless --path $proj res://tests/web_locale_test.tscn
# end-to-end: browser vero + pagine vere + selezione + chiave (finestra)
& $godot --path $proj res://tests/browser_e2e.tscn
# comportamenti del mouse: clic, doppio clic, trascinamento, link, cursore (finestra)
& $godot --path $proj res://tests/browser_click_test.tscn
# gate storico della selezione nella SubViewport (finestra)
& $godot --path $proj -s res://tests/selection_ghost.gd
# GIF, MIDI, e la musica/lo sfondo/gli effetti nel browser (headless)
& $godot --headless --path $proj -s res://tests/gif_test.gd
& $godot --headless --path $proj -s res://tests/midi_test.gd
& $godot --headless --path $proj res://tests/web_media_test.tscn
```

The e2e test saves screenshots of every showcase page for eyeballing.

## Export note

PNGs in `web/img/` are imported resources and ship automatically. The
`web/pages/<lang>/*.html` files, the `web/img/*.gif` and the `web/audio/*.mid` files are
NOT resources: the export preset must include
`web/**` as non-resource files — **recursively**, or a language folder ships empty
(TODO when the preset exists, see CLAUDE.md).
