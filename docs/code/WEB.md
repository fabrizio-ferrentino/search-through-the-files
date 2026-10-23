# The web: browser, pages, sites, web keys

Read before touching the browser, the HTML compiler, the site catalog or the web keys. Writing pages: docs/WEB_AUTHORING.md; wiring sites: docs/WEB_SITES.md; the 34 sites and their rules: docs/WEB_CATALOG.md.

Moved here from CLAUDE.md on 2026-10-22, word for word (CLAUDE.md now keeps only a one-line map).

## Files

### `scripts/os/app_browser.gd`

BrowserApp: one page = ONE PageView (RichTextLabel). The HTML subset is
compiled to BBCode by HtmlBB (html_bbcode.gd); the RTL gives
CONTINUOUS drag selection over the whole page (table cells too,
Win95 navy highlight), native links (meta_clicked: 1st click
navigates, a drag over a link selects instead), native scroll +
auto-scroll while selecting. deselect() on LMB press = click
clears selection like a real browser. Ctrl+C/Ctrl+A + right-click
menu (Copia/Copia tutto/Seleziona tutto/...) in _input. Pages =
web/pages/<lang>/*.html - read_page resolves the language folder,
then falls back to "en" and to the old flat folder, so a missing
translation costs that LANGUAGE a page, not the game; loads via
WebRuntime.source_html (injects the
key) then renders strip_comments(...). "Visualizza sorgente" =
pretty-printed source. See docs/WEB_AUTHORING.md + memory
`web-browser`.
BACKGROUND AND MUSIC (2026-10-23): _page_tile is a TextureRect (STRETCH_TILE) between the
page colour and the PageView, showing the <body background> image tiled; _sposta_mosaico
moves it with the scroll (a fixed tile would look painted on the glass). _musica is an
AudioStreamPlayer at MUSICA_DB (-6 dB) fed by ctx["audio"] (_audio_pagina): music starts in
_fine_caricamento if "auto", and stops in _load (navigate / reload), in _interrompi (the
stop button, a music still being rendered will not arrive) and with the window. _musica.bus
= AudioPC.bus() (2026-10-23): the music goes through the PC's speakers bus, so the tray
speaker's volume/Mute (the period way to silence a page, see OS.md) applies, and in the
room it is muffled and panned toward the desk. A MIDI is
first rendered by MidiSynth.prepara in a thread: _musica_attesa holds the file being waited
for and _process polls MidiSynth.pronto, then _avvia_musica. _on_meta intercepts the
"__audio:play" / "__audio:stop" links of a visible <embed> before navigating. Minimising the
window does NOT stop the music (period-accurate). sta_suonando() and musica_in_attesa() exist
for the tests. Test: web_media_test.tscn.
LOADING (WTTG2-style, 2026-09-16): opening a page is NOT instant.
The page is rendered at once but a VEIL (page-background ColorRect
above the PageView, mouse_filter STOP) covers it for a short while,
so nothing can be read or clicked until it "arrives"; the period
STATUS BAR at the bottom says "Connessione a <domain> in corso..."
then "Ricezione dati: N KB di M KB" with a chunky Win95 progress
bar (14 fixed-width blocks - EXPAND_FILL made the single lit block
stretch the whole trough), and the globe by the address bar blinks
(the period throbber). Duration = clampf(kb * CARICA_PER_KB,
CARICA_MIN, CARICA_MAX) + random jitter -> 0.35-1.2 s, where kb is
WebRuntime.fake_kb(page), THE SAME number the wiki lists in its
history. It is a Tween, so it dies with the node, freezes with the
game pause, and a reload/stop just kills it.
The VEIL RETREATS FROM THE TOP as the data arrives (_scopri moves
its anchor_top, driven by the same count that prints the KB), so
the page appears top-down like it did over a modem and the part
that has arrived is readable AND clickable. That is not decoration:
it is what makes "Interrompi" honest. It used to reveal the WHOLE
page at once (owner, 18/09/2026: "se clicco interrompi ferma il
caricamento e mostra subito la pagina"), which turned it into a
button for skipping the wait - and the wait is not an annoyance to
skip, it is tension, because the room threats keep running while
you watch the bar. Now _interrompi() stops the arrival and FREEZES
the veil where it got to: you read the top, the rest is gone, and
to get it you reload and wait again - which is also what period
browsers did (Stop left you a truncated page, usually without its
images). is_loading() is therefore a real flag (_in_carica) and no
longer "is the veil visible": after an interrupt the veil STAYS. `attesa_scala` (static) is the test knob: the
other browser tests set 0.05 so the whole path still runs without
waiting; is_loading() / attendi_caricamento() / load_finished let a
test (or any caller) wait like a player would.
TWO SWITCHES the owner asked for (18/09/2026) to try it both ways,
both static at the top of the file: ATTESA_ATTIVA = false makes
pages open INSTANTLY (no veil, no status count, stop stays grey -
the browser as it was before 16/09), and SCOPERTA_GRADUALE = false
keeps the wait but covers the whole page until the end instead of
retreating from the top (as before 18/09; with it off "Interrompi"
leaves the page BLANK rather than half-drawn - still honest, since
a page that never arrived is blank, but it reads less clearly).
page_load_test proves both by actually flipping them, because a
switch wired to nothing is worse than no switch - and it PINS
them to true for its other sections, because the owner may leave
them either way in the file and a test must not go red over a
documented setting (it did: three checks failed while the game
was perfectly healthy).
Test: page_load_test.tscn.
CHROME (2026-09-18): the menu bar, the toolbar and the address
row each sit on their own RAISED STRIP (Win95._sb raised) with a
dotted GRIP at the left of the toolbar - before they were flat
rows floating on the window face, which read as three lines of
labels rather than as one piece of furniture. Toolbar buttons carry a CAPTION
UNDER the icon (Indietro / Avanti / Interrompi / Aggiorna /
Pagina iniziale / Origine / Preferiti / Stampa), which is how
period browsers looked on Win95 and also why those toolbars were
so tall - icons alone were unreadable here anyway, since the OS
viewport is downscaled to ~2/3 and passed through the CRT. The
content lives in a VBox CHILD (a Button does not lay out its
children) and the width comes from the caption measured with the
real font, because at a fixed width "Interrompi" and "Pagina
iniziale" were clipped. The throbber (_globo) is at the FAR RIGHT of the
toolbar, where period browsers put it (Netscape's N, IE's globe);
it used to sit between the "Indirizzo:" label and the field,
where no browser ever had it.
EVERY chrome button now either works or is visibly DISABLED, on
the owner's request: File / Modifica / Visualizza / Preferiti / ?
open real dropdowns (_apri_menu, reusing the right-click menu's
layer - the items are rebuilt on every open because what is
enabled depends on the moment), "Preferiti" is DISABLED on purpose
(owner, 18/09/2026) - menu entry and toolbar button both grey. It
worked and listed the run's sites, but a clickable list of every
site makes navigation too comfortable: the player is meant to walk
the pages, not jump from a menu. `_voci_preferiti` and
`WebRuntime.sites()` stay (the wiki uses the list anyway) and are
the only things to re-wire if it is ever switched back on - and if
it is, the entries must navigate with _go, not _load, or the visit
does not enter the history and "back" stays grey.
"?" opens a small period About. Print is disabled - there will never be a printer, and a
button that looks active and does nothing is worse than none.
back / forward / stop are disabled from the actual state
(_aggiorna_pulsanti: empty history, not loading) - that is the
disabled state that carries information. Disabled icon buttons
also FADE their icon (_pallido): the theme only greys the text,
and a full-colour icon on a disabled button reads as active.
Test: browser_chrome_test.tscn (every ENABLED menu opens, each
dropdown has both working and disabled items, Preferiti is proven
OFF - grey, no callback, and pressing it opens nothing - the
history buttons tell the truth, and NO enabled chrome button is
left without a callback, the defect that prompted it).

### `scripts/os/page_view.gd`

PageView: the browser PAGE (a RichTextLabel subclass) — real
browser click semantics: a single click never leaves a selection
(the RTL's internal timer would), sub-6px hand shake stays a CLICK
so links fire (meta_clicked needs no active selection), double click
= word, drag = range; cursor = hand on links / I-beam only over
text / arrow elsewhere (get_cursor_shape can't be overridden from
script in 4.6 - 4.7 adds Control._get_cursor_shape, so the
_aggiorna_cursore detour could be dropped after a migration).
"Only over text" is decided by a TEXT MASK (_prepara_maschera):
at the first mouse move over a page it redraws that page ONCE into
an offscreen transparent SubViewport with cell/border/image/rule
colours forced to #00000000 (colours are REPLACED, never removed -
borders and images take space, and dropping them moves the cells),
so the only thing painted is the glyphs; the alpha coverage, kept
as an image downscaled by BLOCCO (halved twice - a single big
resize samples instead of averaging), says where text is. It is in
CONTENT coords, so scrolling never invalidates it; a resize does.
Why a mask at all: for the engine a TABLE is ONE LINE as tall as
the whole block and it exposes nothing about cells (no API in 4.6
or 4.7), so line width alone marks the entire table as text.
The mask is built on hover and never while a button is held: the
offscreen draw costs a frame and would disturb a drag (measured -
it made tests/selection_ghost.gd flaky when built on page load).
FALLBACK when it can't be built (layout mismatch, page over
MASC_ALT_MAX, first frames): line by line (_forma_a / _riga_a) from
each line's offset/height/width (get_line_offset is in CONTENT
space and starts PAD below the top edge), with the line's alignment
from _mappa_allineamenti - which walks the BBCode IN PARALLEL with
get_parsed_text() and gives up if the walk doesn't consume the
whole text, so an unknown tag can't produce a wrong cursor.
Measured against the pixels (6 pages): I-beam in genuinely empty
space 1851-18478 sampled points -> 166-810, ~95% less, and no glyph
loses it. Verified by tests/browser_click_test.gd (incl. text in a
table cell vs empty space inside the same table).

### `scripts/os/html_bbcode.gd`

HtmlBB: static HTML→BBCode compiler for the browser. Legacy
subset: font/b/i/u/a/h1-6/br/p/center/div/hr/ul-ol-li/blockquote/
img/input/table-tr-td-th (+bgcolor/border/cellpadding, nested
tables, entities) — NOT CSS. <table width="70%"> and centering DO
work: [cell expand] does nothing in 4.6 and a [table] is otherwise
content-wide, so _spacer_row appends an invisible row with a
transparent spacer image (web/img/spacer.png) of the exact width —
percentages need ctx["page_width"], which BrowserApp passes and
recomputes on resize. <img src> = files in web/img/ (missing → drawn "broken"
placeholder). Unit test: tests/html_bb_test.gd.

2026-10-23 (nbsp): _txt keeps `&nbsp;` as a real non-breaking space (U+00A0) and replaces it
AFTER the whitespace collapsing. Before, it became a plain space and was collapsed, so ASCII
drawings came out crooked. html_bb_test has an "nbsp" check.

2026-10-23 (owner: "the web sites are mostly very similar, almost identical; I want huge
variety; and start adding GIFs and audio in pages; take inspiration from 90s web design"):
- face= → famiglia(): sans / serif (Tinos) / comic (Comic Neue) / mono, emitted as
  [font=file]. <b>/<i>/<hN> inside a non-sans family emit THAT family's bold/italic FILE
  (_file_di / _font_file; the state {fam,b,i} rides on the tag stack through _push's
  `extra`, read by _stato). Comic Neue has no italic (the original neither). Files in
  Win95._FONT_FILES.
- <td width> px or %: _colonne computes per-column widths and _spacer_row builds the
  invisible spacer row. A NESTED table's % width is relative to its CELL (ctx page_width is
  swapped while a cell is walked). <table bordercolor> works.
- img_path(src): a .gif is decoded ONCE by GifDecoder and the texture is registered on the
  virtual path "<file>.gif.tex" with take_over_path (the same trick as the broken-image
  placeholder), cached in the static _gif; texture(src) gives the same texture for
  <body background> (the browser tiles it).
- <marquee> → [marquee w len v dir mode] (WebEffetti). Top level only: inside a table cell
  (ctx _in_cella) or when the text is longer than the page it comes out STATIC, as in
  Netscape. <blink> → [blink].
- <bgsound> / <embed> print no text; they fill ctx["audio"] = {src, path, loop, auto}
  (audio_path() resolves web/audio/). A VISIBLE <embed> draws a small player whose links are
  META_PLAY "__audio:play" and META_STOP "__audio:stop" (BrowserApp intercepts them).
Tests: html_bb_test.gd, section _prova_varieta.

### `scripts/os/gif_decoder.gd`

GifDecoder (2026-10-23): pure static GIF87a/89a decoder, no engine state. LZW, global and
local palettes, transparency, per-frame delays, disposal 2 and 3, interlace; it composes the
frames onto the logical screen. texture_da_file(path) → AnimatedTexture (an ImageTexture
when there is a single frame). Called by HtmlBB.img_path. Test: tests/gif_test.gd.

### `scripts/os/web_effetti.gd`

WebEffetti (2026-10-23): the RichTextEffects Marquee and Blink. tutti(fermo := false) returns
the list: PageView installs tutti(), and its text-mask twin (the offscreen redraw of
_prepara_maschera) installs tutti(true), the "fermo" (still) versions, so the layout of the
mask matches the real page. page_view.gd's TAG_NOTI gained marquee and blink (the tag walk of
_mappa_allineamenti would otherwise give up on them).

### `scripts/os/midi.gd`

Midi (2026-10-23): Midi.leggi(dati: PackedByteArray) -> Dictionary, an SMF type 0/1 parser:
notes in SECONDS (tempo map honoured, running status, program change per channel, channel 10 =
drums). Test: tests/midi_test.gd.

### `scripts/os/midi_synth.gd`

MidiSynth (2026-10-23; owner's choice: MIDI played by a small GDScript synth, not recorded
audio): renders the notes to 22 kHz mono PCM16 in an AudioStreamWAV with cheap "1997 sound
card" voices picked by General MIDI program family (square / triangle / saw / sine / pulse
+ ADSR, noise drums, one-pole low-pass and a soft limiter). prepara(path) renders in a
WorkerThreadPool task and _consegna (on the main thread) fills a static cache; pronto(path)
says it is done; stream_in_cache(path, loop) reads the cache; stream_da_file(path, loop)
renders synchronously (tests). Test: tests/midi_test.gd.

### `scripts/os/catalogo_siti.gd`

CatalogoSiti (2026-10-19): DATA ONLY - which sites the web MAY have.
One entry per site in SITI: id (= the folder), nome/desc (WS_* CSV
keys), en/it (the period domain per language, may carry a path:
www.webnet.it/~jack99), tipo (normale/lore), voce (lore only:
padre / ragazzo / maledizione / altri - altri, added 2026-10-23, is other people's stories, not the young man's), featured, stato (segnaposto /
completo - a complete site needs COMPLETO_PAGINE 5 pages and
COMPLETO_TESTO 6000 characters of visible text per language),
pagine (every page of the folder, index first: the key can land in
any) and morti (dead links ON PURPOSE: a missing page of the site,
or the address of a site that is gone). All 34 sites (30 written
2026-10-20, four lore sites added 2026-10-23) and the RULES every site follows: docs/WEB_CATALOG.md;
the recipe: docs/WEB_SITES.md §3. Test: siti_catalogo_test.tscn.

### `scripts/os/web_runtime.gd`

WebRuntime: per-run web state (no file IO, no engine). A SITE IS A
FOLDER (2026-10-19, owner: ~30 complex sites, 10-15 per run): a
page is called "<site>/<page>" (forum/index, treno/thoughts); the
pages outside the sites have one name (home, 404, NONSERVER).
build() (from BrowserApp.reset_pages on start_new_run) takes the
pool from the catalog and _scegli_siti picks SITI_MIN..SITI_MAX
10-15 sites, LORE_MIN..LORE_MAX 4-5 of them lore (owner: "2 are too
few"), at least one lore site with voce "padre" and one "ragazzo"
when the catalog has them - or ALL of them while the catalog is
smaller; then the carriers + modes of the TWO web keys (since
2026-10-18, owner: keys 2 and 3): a site of the run, then a PAGE
among that site's pages. _posti holds one Dictionary per key
(indice, key, carrier = "site/page", visible, text, the two
position fractions, the resolved anchor); the SECOND key is drawn
among the run's sites MINUS the first one's - two keys on one site
would be one place to search.
ADDRESSES: dominio(site, lang) from the catalog; display_url /
host_of give the domain plus "/<page>.html" (the index is the bare
domain); page_of resolves domain + path across BOTH languages,
longest match first (www.webnet.it/~trenoperso/thoughts.html ->
treno/thoughts, www.webnet.it -> home) with the period
tolerances (no http://, no www., the bare name, the old internal
id); risolvi_link(href, current) keeps a RELATIVE href inside the
current page's site and sends an absolute one through page_of;
in_partita(page) says whether the site is one of tonight's - the
browser answers "cannot find server" otherwise.
Accessors take an optional n (carrier(n), is_visible(n),
key_text(n), anchor_info(n), indice(n), quanti_posti()); without it
they mean the first key, as before.
home_html() GENERATES the WIKI — the gateway/index the player starts
from, built from _HOME_TEMPLATE (an HTML template modelled on the
owner's hand-written mockup web/webnet.html: WEBNET logo, white
70% box centred on grey, PREFERITI + SITI VISITATI DI RECENTE in
Courier, ISP footer) listing ONLY the run's sites. The home is not
a file, and the run KEY never lands on it (WTTG2-style: the index is
clean — the carrier is always an authored pool page).
source_html(page, src) injects the key into the carrier's HTML
— visible (rendered, selectable) or source-only (view-source). WHERE
it lands is drawn from the seed too (two fractions appended at the
END of build()'s RNG order, so older seeds keep their carrier, mode
and sentence) and resolved by WebAnchor, memoised on src.hash()
because source_html runs on every page load and also feeds
view-source. carrier() / is_visible() / anchor_info() expose the
choice.
ADDRESSES: the domains live in catalogo_siti.gd (fields en / it, read
through dominio()), and display_url()/host_of()/
page_of() are the only places that build or resolve a URL. The
address bar used to show "http://news" (the FILE name: no suffix,
nothing that looked like a real address); now it shows
www.newsoggi.it, www.retroforum.it, www.compratutto.com,
webmail.webnet.it (a provider subdomain), www.webnet.it/~jack99
(a personal page under ~user on the ISP, as it was done) and the
gateway itself is www.webnet.it, matching the "WebNet ISP" footer.
page_of is tolerant like a period browser (with/without http://,
with/without www., the bare second-level name, and the old
internal page id). The wiki lists those URLs and links to them
ABSOLUTELY (it is an index of sites); relative *.html hrefs inside
an authored page still resolve, via the fallback in
BrowserApp._norm. A wrong address gives 404 and the bar KEEPS what
was typed. Add a site: its folder in every web/pages/<lang>/ + two
WS_* rows in the CSV + one entry in catalogo_siti.gd (recipe:
docs/WEB_SITES.md §3). [Corrected 2026-10-22: this used to say "a row
in _pool() + a row in BOTH address tables", which no longer exist.]
PER LINGUA (2026-09-19): _pool() turns the catalog's translation KEYS for
the names/descriptions (WS_*) into text, the gateway's words are WEB_HOME_* and
_HOME_TEMPLATE now uses {named} slots with String.format (so a "%"
in the HTML is just a "%" - it used to have to be doubled).
Every site has TWO domains (catalog fields en / it), and siti()
returns { id: domain } for the language in play - an English site on
a .it gives the theme away faster than anything, and the address is
the first thing read. page_of() scans the other language's domains too
(tolerance, not a shortcut: it leads to exactly the page that address
names).
The carrier sentences (_VISIBLE) are keys; the fake SOURCE
comments (_COMMENT) stay English in every language, because
that is how period code read everywhere - and _frase() falls back
to the bare code if a translation lost its %s, or the key would
never reach the page. lingua() is the two-letter code and is
also what BrowserApp.read_page uses. Test: web_locale_test.

### `scripts/os/web_anchor.gd`

WebAnchor: WHERE the web key hides. It used to be an extra line
before </body> every time, which the owner recognised at a glance;
now the page is scanned for every safe spot and the seed picks one
(WTTG2-style). Rendered: own line between blocks, MID-SENTENCE (the
BARE code between two words — inherits the surrounding font and
colour, so it is the safest spot, not the riskiest), paragraph tail,
new <li>, light table cell. Source-only: comment between blocks /
mid-markup / in the table markup / in <head>, or a title=/alt=
attribute of an existing link or image. Refuses the three things
that were real bugs: a rendered snippet inside a table but OUTSIDE a
cell (HtmlBB drops it — key unfindable), a rendered snippet in a
dark cell (black on dark: MIN_CONTRASTO), and anything inside
<title> (it would show in the window title bar). Pure module (no
GameManager/OSContent) so html_bb_test can sweep it headless over
the real pages; inserisci() injects at ONE given spot, which is what
lets the tests check every spot of every page.
2026-10-23: marquee and blink are containers AND MOBILI (in_mobile counter): no rendered key
spot is offered inside text that moves or blinks (the player could not read it).
Tests: html_bb_test.gd + web_key_inject.tscn.

### `web/`

AUTHORED web pages + images. pages/<lang>/<site>/<page>.html = the
sites, one FOLDER per site with index.html and its pages (since
2026-10-19); pages/<lang>/404.html (the site exists, the page does
not) and nonserver.html ("cannot find server": the address is
nobody's, or the site is not part of tonight's run). ONE FILE PER
LANGUAGE (en, it) with the SAME folder and file names: a site id
and a page name are identifiers, only the content is translated.
The two SAMPLE sites that set the bar for the rest (owner,
2026-10-19): forum/ (RetroForum, 14 pages: index, five sections,
four long threads, members, a profile, rules, a members-only page
the locked topics lead to) and treno/ (the personal page of the
young man the curse started from, GDD §2b, 7 pages; never explicit
about his death; called balena/ and nicknamed ~whale52 / ~balena52 until 2026-10-23,
see the lore note below). On 2026-10-20 all 30 sites were written (18
ordinary, 12 lore; 34 and 16 since 2026-10-23 - the map is docs/WEB_CATALOG.md) and the old
one-page placeholders were deleted. Three RULES the owner set that
day, enforced by siti_catalogo_test: a site is CLOSED IN ITSELF (it
never links to another site of the catalog - only to the WebNet
portal or to a dead address in its "morti"; a directory site,
"cerca", was written and REMOVED for this reason), NO form controls
(<input>/<form>/<button>: logins, searches and carts are written as
closed), and DATES ARE ABSOLUTE AND STOP AT 1999 (no "today, 9:05
PM"; the timeline is in GDD §2b). img/ = page
images (<img src="f.png">; PNGs import as resources and ship)
plus img/spacer.png, the 1x1 transparent image that gives tables
their <table width="N%"> (see html_bbcode.gd).
Write pages by hand in the LEGACY subset — the full authoring
reference (tags, width rule, style templates) is
docs/WEB_AUTHORING.md; how the sites are WIRED (pool, domains,
generated gateway, recipes) is docs/WEB_SITES.md, which also has
the recipe for ADDING A LANGUAGE. The HOME is GENERATED per-run by
WebRuntime (tonight's sites) — there is no home.html. To add a site:
its folder in every web/pages/<lang>/, its WS_* rows in
locale/ui.csv and its entry in scripts/os/catalogo_siti.gd. The
34 sites: docs/WEB_CATALOG.md. (webnet.html = the user's
original mockup, ref.)

## Feature notes

- **Lore change: the young man's site and nickname (2026-10-23).** Owner (Italian,
  paraphrased): he liked the lore spread across the sites, but did not like the nickname
  whale52 (same animal as the OS logo), and the young man appeared in more sites than the
  father. He asked for a parody "forum of the ugly" and for sites about hypergamy / genetic
  determinism / late virginity, always with a creepy touch; modern terms are allowed.
  History, so it does not come back: the site `balena` (www.webnet.com/~whale52 /
  www.webnet.it/~balena52, CSV WS_WHALE) is now `treno` (www.webnet.com/~missedtrain /
  www.webnet.it/~trenoperso, CSV WS_TRAIN); the page whale.html is now binario.html "the
  23:52" (the closed station behind his building, the regional train that does not stop, the
  clock stopped at ten past six). The chat logs use the nick trenoperso / missedtrain. The
  52 Hz whale stays the CURSE's emblem (death screen, glitch, disk files, misteri/whale,
  nessuno/whale).
  He keeps ONE site and appears in at most two others (chat, annunci). His former threads
  became other people's stories: lavoro (a night security guard, nightguard_74 / vigilante_74),
  vincente (the diary thread of a 33-year-old surveyor, surveyor33 / geometra33), ascolto (the
  unanswered messages of a night baker); misteri/letters: a reader's letter no longer says he
  has a page. Those three sites have voce "altri" (new value in catalogo_siti.gd: other
  people's stories, not the young man's).
  Four new lore sites (catalogo_siti.gd + WS_* CSV keys): brutti (WWWBoard-style board, 9
  pages), volto (face-measuring essay, 6), numeri (statistics + field notes, 6), diario (a
  teacher's day counter, 6; voce "maledizione"). New images by tools/web/media.py: volto.gif
  (face diagram with numbered measurements), contatore_giorni.gif. Catalog: 34 sites, 16 lore.
  The facts per site are in docs/WEB_CATALOG.md. Tests moved from balena/* to treno/*
  (browser_chrome_test, browser_e2e check TRENO, page_load_test, siti_catalogo_test address
  cases, siti_check sample pages). Also in this change: the &nbsp; fix (html_bbcode.gd entry).

- **Variety, GIFs and audio in pages (2026-10-23).** Owner (Italian, paraphrased): the sites
  are mostly very similar, almost identical; he wants huge variety, the ability to have GIFs
  and audio in pages, inspired by 90s web design. His choices: MIDI played by a small
  GDScript synth (not audio files); engine first plus SIX PILOT SITES restyled in six
  different styles, the other 24 after he reviews them; placeholder media generated by a
  script. Pilots (EN+IT): blog (GeoCities teen), calcio (loud fan club), comune (bare 1995,
  no tables), driver (dark side-bar portal), oroscopo (splash + mystical), ricette (card on
  gingham); the Style column is in docs/WEB_CATALOG.md. Engine: GifDecoder, WebEffetti, Midi,
  MidiSynth, the HtmlBB additions (fonts, td widths, marquee, blink, bgsound/embed, tiled
  background) and the BrowserApp tile + music player, each described in its entry above.
  Placeholder media: tools/web/media.py writes web/img/*.gif and web/audio/*.mid (four
  original melodies: jack, inno, valzer, notte); the pictures contain no words. Authoring
  rules (tags, fonts, media table, Music section, style archetypes): docs/WEB_AUTHORING.md.
  Not stopped by design: music keeps playing while the browser is minimised. siti_catalogo_test
  check MEDIA_ESISTONO fails if a page references a media file that does not exist.

- **Page loading** (WTTG2-style): opening a site takes 0.35-1.2 s (random, scaled by the
  page's fake KB), the page stays covered and unclickable meanwhile, and a period status bar
  narrates it ("Connessione a www.retroforum.it in corso...", then the KB) with a Win95
  progress bar; the toolbar's stop button interrupts. That wait is also tension: the room
  threats keep running while you sit there.

- **Browser = single-RichTextLabel renderer (real selection, lightweight).** One page = ONE
  `PageView` (`page_view.gd`, a `RichTextLabel` subclass that gives real-browser click
  semantics — see its entry above and docs/WEB_AUTHORING.md "Mouse behavior on a page");
  `html_bbcode.gd` (HtmlBB) compiles the legacy HTML subset
  (`web/pages/*.html`) to one BBCode document. So the page has **continuous drag selection**
  (table cells included, Win95 navy highlight; a click clears it via deselect-on-press),
  native **links** (`meta_clicked`: 1st click navigates, drag-over-link selects), **images**
  (`web/img/`), BBCode **tables** with borders/row colors (width is CONTENT-driven — see
  docs/WEB_AUTHORING.md), native `[hr]`, **reflow** + auto-scroll while selecting. No native
  dependency — gdcef (too heavy) and baked images (no selection/reflow) stay rejected.
  `web_runtime.gd` injects the per-run key into the carrier page (visible legacy `<p>` →
  selectable text, or `<!--comment-->` → only in view-source). Authoring guide:
  **docs/WEB_AUTHORING.md**; templates: the site folders forum/ (complex),
  treno/ (personal page), cronaca/ (newspaper), shop/, chat/ and nessuno/ (minimal dark). Tests: tests/html_bb_test.gd (headless unit),
  tests/browser_e2e.tscn (end-to-end), tests/selection_ghost.gd (SubViewport gate).
  **Export TODO:** the export preset must include non-resource files `*.html` under `web/`
  (the PNGs in web/img/ import as resources and ship automatically). `start_new_run(seed)` resets PC state and
  rebuilds a fresh per-run VFS via `VFS.build_run` (so "lose → fresh run" starts
  clean and randomization has a seed to hang off). Called from the menu's Start.
