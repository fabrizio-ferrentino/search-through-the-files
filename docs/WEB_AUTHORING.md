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
| `<font color="#..." size="1..7">` | color + size (`face` is ignored) |
| `<h1>..<h6>` | bold heading sizes |
| `<br>`, `<p>`, `<p align="center/right">` | line break / paragraph (blank line) / aligned paragraph |
| `<center>`, `<div align="center">` | centered block |
| `<a href="pagina.html">` | link (color from `<body link>`) |
| `<hr>`, `<hr width="50%" size="4" color="#...">` | native horizontal rule |
| `<ul><li>`, `<ol><li>` | • bullets / numbered list |
| `<blockquote>` | indented block (forum quotes) |
| `<img src="file.png" width="W" height="H">` | image from `web/img/` (see below) |
| `<input type="text/submit" value="...">` | DECORATIVE only (`[ Value ]` / underline). **Not used in the sites** (owner, 2026-10-20): a field that cannot be typed in is a broken promise, so `siti_catalogo_test` forbids it; write the login or the search as closed instead |
| `<table> <tr> <td> <th>` | real table, see below |
| entities | `&nbsp; &copy; &raquo; &laquo; &middot; &hellip; &quot; &mdash; &deg; &lt; &gt; &amp;` |

**Body attributes** drive the page colors — this is how dark pages work:

```html
<body bgcolor="#000000" text="#9a9a9a" link="#66FF66">
```

`bgcolor` = page background, `text` = default text color, `link` = link color.

### Tables

- `border="1"` → gray cell borders; `cellpadding="N"` → cell padding;
  `bgcolor` on `<table>`, `<tr>` or `<td>` (most specific wins).
- `<th>` = bold + centered. `<td align="center/right">` supported.
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

CSS (classes, `style=`), `colspan`/`rowspan`, `<span>`, `<form>` logic,
`<script>`, `cellspacing`, `bordercolorlight/dark` (parsed but ignored).

`face=` is **partially** supported: anything containing *courier*, *mono* or
*fixedsys* switches to the monospace font, everything else uses the page sans.
That covers what the pages actually ask for (`Arial`, `Verdana`, `Helvetica`,
`Arial Black` all mean "the sans" here).

## Fonts

The OS and the pages share two bundled families (`assets/fonts/`, SIL OFL 1.1),
both metric-compatible clones of what the 90s web actually used:

| Family | Clone of | Where |
|---|---|---|
| Arimo | Arial / Helvetica | OS chrome + page body, `<b>`, `<i>` |
| Cousine | Courier New | `face="Courier New"` runs |

They are wired once in `Win95.make_theme()` (`default_font` plus the
RichTextLabel `normal/bold/italics/bold_italics/mono_font` slots), so a page gets
them for free — do not set fonts per page. Note that Godot's `[b]` always uses
the theme's bold slot, so a run cannot be both "a different family" and bold;
that is why `face=` maps to the two families above instead of pushing arbitrary
fonts.

## Images

Drop files in **`web/img/`** (PNG/WEBP; they import as normal Godot resources
and ship automatically). Reference them by bare filename:

```html
<img src="occhio.png" width="240" height="140">
```

A missing file renders a drawn "broken image" placeholder (gray box + red X)
— the page never errors. Current placeholders (`avatar1-3.png`, `occhio.png`)
are procedural; replace them with authored art freely.

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

- **Complex community site** → `web/pages/en/forum/` (banner with tagline, a navigation
  bar on every page, section listings with alternating row colors, per-post tables with
  an author column, avatar `<img>` and `<blockquote>` quotes, a member list, a profile, the
  rules, and a "members only" page that the locked topics link to).
- **Personal homepage** → `web/pages/en/balena/` (dark body, an ASCII drawing in
  Courier, a visitor counter, a link list, a guestbook that no longer accepts entries).
- **Newspaper archive** → `web/pages/en/cronaca/` (masthead, section bar, article pages
  with a byline, an archive listing).
- **Shop** → `web/pages/en/shop/` (catalog grid, product pages, a fake cart and terms).
- **Forum-style posts** → `web/pages/en/vincente/thread_diary.html` or `lavoro/` (one
  cell per post, author and date on top: a narrow author COLUMN would take half the
  table, because the declared widths of several columns are split evenly).
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
```

The e2e test saves screenshots of every showcase page for eyeballing.

## Export note

PNGs in `web/img/` are imported resources and ship automatically. The
`web/pages/<lang>/*.html` files are NOT resources: the export preset must include
`web/**` as non-resource files — **recursively**, or a language folder ships empty
(TODO when the preset exists, see CLAUDE.md).
