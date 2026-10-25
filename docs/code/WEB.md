# The web: browser, pages, sites, web keys

Read before touching the browser, the HTML compiler, the site catalog or the web keys. Writing pages: docs/WEB_AUTHORING.md; wiring sites: docs/WEB_SITES.md; the 40 sites and their rules: docs/WEB_CATALOG.md.

Moved here from CLAUDE.md on 2026-10-22, word for word (CLAUDE.md now keeps only a one-line map).

## Files

### `scripts/os/app_browser.gd`

2026-10-24/25, PAGE WIDTH AND THE SCROLLBAR STRIP (owner: 1:1 late-90s web; "test accurati"). The
page ALWAYS reserves the vertical scrollbar's strip on the right: the stylebox right margin is
`PageView.PAD + PageView.BARRA` (BARRA = 20) and `_page_width()` subtracts `2*PAD + BARRA`, like
IE did. WHY: in 4.6 a table that fills its line does not shrink enough when the scrollbar appears
(a long page), and its right edge went UNDER the bar. After compiling, `_render_html` checks
`get_content_width()` against `_page_width()`: if the content is wider (and the page used widths,
`ctx["uses_width"]`) it recompiles with a page narrower by the overflow + 2 px, at most TWO
attempts, and leaves it as it is if it still does not give. KNOWN LIMIT, not fixed: tables that
fill the line overrun by a few px per column (RichTextLabel does not count the cell borders when
it shrinks them); the right margin absorbs it, and the news layout table is `width="96%"` for that
reason (siti_audit_test LARGHEZZA allows up to `page width + PAD`).
2026-10-25 refinement of that limit: RichTextLabel 4.6 ignores a cell's padding inconsistently when a
table fills its line; a probe measured an overrun anywhere from 0 to ~48 px. Not fixable from here;
it is absorbed by the reserved right strip (`PageView.BARRA`).

2026-10-25 (owner, Italian: "mi sembrano ancora artificiali e non come se fossero veri siti anni 90.
problema numero 1 il menu a tendina si comporta in modo strano. 2 quando passo vicino ad un campo
input deve uscire l'icona a stanghetta. Poi vedi se ci sono cose strane."), DROP-DOWN AND BUTTON MENUS:
- `_apri_tendina(id)` is a coroutine. It asks the page where the select box is
  (`await _rtl.rettangolo_di("__tendina:" + id)`, see page_view.gd) and shows the browser's own list
  EXACTLY under the box: same width, white with a black 1 px border, items in the control font
  (`Win95.font_pagina("sans")` at `HtmlBB.CTRL_FONT`), rows `TENDINA_RIGA` = 18 px. The item under the
  mouse is navy (`Win95.C_TITLE_TEXT` text), the CURRENT value is navy when the list opens and goes out
  as soon as the mouse enters any item. It opens UPWARD when there is no room below (`size.y - 4`), and
  scrolls past `TENDINA_MAX_RIGHE` = 10 items. Members `_tend_panel` (Panel "Tendina"), `_tend_scorri`
  (ScrollContainer), `_tend_lista` (VBox), all inside `_ctx_layer` (the context-menu layer);
  `_chiudi_menu` hides the panel too. If the page changed while the rect was being found, nothing
  opens. HEADLESS: `rettangolo_di` returns `Rect2()` (nothing is drawn), and the list opens at the
  mouse with width 150.
  History, so it does not come back: the list used to be the right-click menu (`_riempi_menu` /
  `_mostra_menu`) opened at the mouse; it looked like another thing, not a Windows combo box (owner:
  the drop-down "si comporta in modo strano").
- BUTTON MENUS: the meta is now `__vai:<href>` (html_bbcode `_pulsante`). `_on_meta` strips the prefix
  and then follows it like any link. CORRECTED the same day (see the "buttons look fake" block
  below): `_su_link` ignored every `__` meta at first, so the status bar showed NO address over a
  button menu; it now strips `__vai:` and shows the target address again, and the cursor is the hand.

2026-10-25 (later, owner: "i pulsanti ora si comportano in modo strano"; asked, he picked three
things: the cursor, the missing status-bar address, and that the buttons "look fake" - flat, no
press), FORM BUTTONS ARE REAL PUSH BUTTONS:
- Status bar: `_su_link` keeps the `__vai:` rule: `m.begins_with("__vai:")` -> `m = m.substr(6)`, then
  the usual `risolvi_link` / `display_url`. Every OTHER `__` meta (field, check, select, submit, reset,
  player) still shows nothing. A submit button therefore shows no address; a button menu does.
- The look and the press are in html_bbcode.gd (`_pulsante`, `tex_pulsante`), win95.gd
  (`_tex_pulsante`, `scrivi_in_immagine`) and page_view.gd (`_premi`/`_rilascia`), see those entries.
  History, so it does not come back: the first 2026-10-25 version drew a button as a small table of
  text with transparent side spacers (selectable label, flat, no press) and gave the ARROW over
  button menus and over submit/reset, with no address in the status bar (the reasoning was "as with
  IE buttons"; the owner then named the cursor and the missing address as wrong).

2026-10-24, FORMS (details in the feature note): members `_valori`, `_campo` (the field being typed
in), `_moduli`. Clicking a field activates it; `_input` types into it (Backspace; Enter sends, or
inserts a newline in a textarea; Tab goes to the next field of the form; ESC stops typing; ctrl/alt
combinations pass through). A click elsewhere on the page stops typing (`_forse_fuori`, deferred
after the meta). `_spunta` toggles (radios exclusive by form+name). `_apri_tendina` opens the
browser's own white list under the select box (see the 2026-10-25 block above). `_invia` builds
`name=value&...` (checked boxes send their value) and goes to the action; `_azzera` resets. While
typing the browser is in the group "campo_web_attivo" and `scrive()` is true. Status bar:
meta_hover_started shows the target address (display_url of risolvi_link), meta_hover_ended restores
`_stato_fermo` (the "done"/"stopped" text). Visited links: see web_runtime.

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

2026-10-25 (owner: "quando passo vicino ad un campo input deve uscire l'icona a stanghetta"),
CURSOR OVER FORM CONTROLS:
- `cursore_a(pos) -> int` is the cursor the GAME shows. `OSDesktop.cursor_shape_at` calls it when the
  hovered control has the method (`hov.has_method("cursore_a")`), instead of the control's own
  `get_cursor_shape`. Rule (CORRECTED later the same day, see the "CURSOR AND PRESSED BUTTONS" block
  below): I-beam over text fields and textareas (meta `__campo:`), ARROW over check boxes, radios and
  selects (`__spunta:`, `__tendina:`), HAND on real links and on buttons (`__vai:`, `__invia:`,
  `__azzera:`, `__audio:`). While a button is held, or when the engine says
  anything but the hand, the engine's shape is returned as it is.
- WHY it needs a memory: the engine puts the hand on EVERY `[url]`, and form controls are metas too,
  and it does not say which meta is under the point. `_meta_sotto` is kept from `meta_hover_started` /
  `meta_hover_ended` (connected in `_init`). It is trusted ONLY when the engine itself reports a link
  (hand) under the point, so a stale value never counts; `set_page` clears it when the new BBCode no
  longer holds `[url=<that meta>]` (typing redraws the page under a still mouse).
- `rettangolo_di(meta) -> Rect2` (coroutine, a couple of frames): where, in PageView coordinates
  (scroll included), the control with that meta sits. The engine does not say, so it renders an
  OFFSCREEN twin of the page with everything transparent except that control's cell painted
  (`_solo_controllo`: backgrounds, borders, images and every `[color]` made `#00000000`, the layout
  stays the same; the cell gets `bg/border #FF00FF`) and reads `get_used_rect()` of the image.
  Headless returns `Rect2()` (nothing is drawn, the image would never arrive), as do a page over
  `MASC_ALT_MAX` and a control not found. Used by `BrowserApp._apri_tendina` and by the tests.
- `_gemello(alt)` now builds the offscreen twin for BOTH the text mask (`_prepara_maschera`) and
  `rettangolo_di` (same theme, margins, width, still effects, the scrollbar's width subtracted when
  it shows). Before, the mask built it inline.

2026-10-25 (later, owner: the buttons "behave strangely"; picked cursor, status-bar address and
"look fake: flat, no press"), CURSOR AND PRESSED BUTTONS - this CORRECTS the cursor rule above:
- `cursore_a` now: I-beam on `__campo:`; ARROW on the `__` metas that are NOT buttons (`__spunta:`
  check boxes and radios, `__tendina:` selects); HAND on real links AND on buttons. A button is a
  meta for which `static _e_pulsante(meta)` is true: prefixes `__vai:` (button menu), `__invia:`
  (submit), `__azzera:` (reset) and `__audio:` (the media player's play/pause/stop,
  `HtmlBB.META_PLAY` = `__audio:play`, `META_STOP` = `__audio:stop`). The rest of the rule (stale `_meta_sotto`, `_held`) is unchanged.
- A button is ONE IMAGE (a Win95 push button with its label, see html_bbcode.gd `tex_pulsante`), so
  the page shows it pressed by laying the "_giu" image over it:
  - `_prepara_pulsante(meta)` runs from `meta_hover_started` (connected in `_init`). If the meta is a
    button (`_e_pulsante`) whose image is a `_pulsante_*.tex` (`_immagine_giu(meta)` finds it in the
    BBCode `[url=<meta>][img]path[/img]` and returns the path with `PULSANTE_SUFFISSO_GIU`), it asks
    `rettangolo_di(meta)` ONCE and stores the rect in `_rett_pulsanti` (meta -> `Rect2`, CONTENT
    coordinates: the scroll is added back). The search costs a couple of frames, so it is done on the
    first hover and the rect is ready at the click; the entry is set to `Rect2()` first so it is not
    asked twice, and dropped if the page changed meanwhile. `set_page` clears `_rett_pulsanti`.
  - `_premi(meta)` (called from `_gui_input` on LMB press with `_meta_sotto`) loads the "_giu"
    texture and shows it in a `TextureRect` child `_premuto` (`mouse_filter` IGNORE, `STRETCH_KEEP`)
    at the rect minus the current scroll. Without a rect (the mouse never hovered it, or headless)
    nothing is shown. `_rilascia()` hides it on LMB release and in `set_page`.
  - `pulsante_premuto() -> bool`: true while the pressed image is visible (for the tests).
- `rettangolo_di` / `_solo_controllo` now also find an IMAGE control: when the BBCode holds
  `[url=<meta>][img`, the twin keeps everything transparent (`_senza_fondi` forces every `[img]`
  to `color=#00000000`) and rewrites THAT image's `color=#00000000` to `color=#FF00FF`, so the image
  is what gets painted (before, only table cells with a `[url]` were found, and a button was one).

2026-10-25: `const BARRA := 20.0`, the strip of the scrollbar that is always reserved (see
app_browser.gd). `_utile()` (the width the cursor bands work on) is `size.x - 2*PAD - BARRA` minus
the real scrollbar when it is visible, so the cursor logic stays right at the reserved edge.

2026-10-24: `meta_underlined = false`. Page links carry their own `[u]` (so the visited colour and
the underline are the compiler's), and buttons and fields are metas too, which must NOT be
underlined.

PageView: the browser PAGE (a RichTextLabel subclass) — real
browser click semantics: a single click never leaves a selection
(the RTL's internal timer would), sub-6px hand shake stays a CLICK
so links fire (meta_clicked needs no active selection), double click
= word, drag = range; cursor = hand on links / I-beam only over
text / arrow elsewhere (get_cursor_shape can't be overridden from
script in 4.6 - 4.7 adds Control._get_cursor_shape, so the
_aggiorna_cursore detour could be dropped after a migration). Form
controls and button menus are the exception to "hand on links": see
`cursore_a` above.
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
- <marquee> → [marquee w len v dir mode n] (WebEffetti; `n=` added 2026-10-25). Top level only: inside a table cell
  (ctx _in_cella) or when the text is longer than the page it comes out STATIC, as in
  Netscape. <blink> → [blink].
- <bgsound> / <embed> print no text; they fill ctx["audio"] = {src, path, loop, auto}
  (audio_path() resolves web/audio/). A VISIBLE <embed> draws a small player whose links are
  META_PLAY "__audio:play" and META_STOP "__audio:stop" (BrowserApp intercepts them).
Tests: html_bb_test.gd, section _prova_varieta.

2026-10-24 (owner: "continuiamo con i siti"; the last twenty sites were restyled and their
tables exposed three width problems):
- NARROW TABLES (_stringi): a table whose width is smaller than the page (px or %) is wrapped
  between empty filler columns (centred: one per side; left-aligned: one on the right). WHY:
  Godot's spacer row only gives a table its MINIMUM width, so a long paragraph used to stretch
  a "560 px card" to the page edge (Granny Rose's card; the helpline column). Any table with a
  width sets ctx["uses_width"], so the browser recompiles the page once the page width is known.
  A 100% table is not wrapped.
- `<hr>` inside a table cell (_hr): a percentage (or no width = 100%) is converted to pixels of
  the CELL when the cell width is known (ctx page_width is the cell's while it is walked).
  WHY: Godot measures `[hr]` percentages on the whole page, and a rule in a side column pushed
  the table out of the page.
- CELLA_EXTRA = 4: a cell takes 4 px beyond its padding (measured with a probe); the spacer
  formula used 2. Used in _table (the width a nested table gets inside a cell) and in _spacer_row.
- KNOWN LIMIT, not fixed: a full-width table with several text-heavy columns can still exceed
  the page by 5-10 px (Godot's own distribution of widths; measured on news/index: 910 on 900).
Tests: html_bb_test.gd (stretta_*, piena_non_stretta, hr_in_cella).

2026-10-24 (forms, text tags, visited links; see the feature note in this file):
- Forms are drawn as small inline tables with special metas: `__campo:<id>` (text/password/
  textarea), `__spunta:<id>` (checkbox/radio; images Win95._tex_casella / the new
  Win95._tex_pallino, registered on virtual paths like res://web/img/_casella_on.tex),
  `__tendina:<id>` (select, with a drawn arrow button since 2026-10-25), `__invia:<form index>`, `__azzera:<form index>` (reset); the
  buttons are one drawn image each (2026-10-25, see the "buttons" notes below).
  Field ids are "m<form>_<n>" in document order. ctx["moduli"] = [{action, method, campi:[{id,
  tipo, nome, valore, modulo, ...}]}]; ctx["valori"] (id -> value) and ctx["campo_attivo"] come
  from the browser. compile() resets the per-compilation state (moduli, _modulo, _implicito, _pre,
  _in_cella), so recompiling with the same ctx gives the same ids. Fields have a 19 px strut (an
  empty field is a line high); a textarea is rows*19 px. Button labels default to the CSV keys
  WEB_FORM_SUBMIT / WEB_FORM_RESET.
- Text tags: `<pre>` (spaces -> U+00A0, newlines kept, leading newline dropped), `<tt> <kbd> <samp>`
  mono, `<s> <strike> <del>`, `<sup> <sub>` (size 11), `<big>` (20) / `<small>` (12), `<dl> <dt> <dd>`,
  `<address>` italic.
- Links take ctx["vlink_color"] when ctx["visitato"] (a Callable) says the target was visited.
Tests: html_bb_test.gd (moduli_ctx, input_*, checkbox, radio, select, textarea, button, reset,
hidden, pre_spazi, tt, strike, small, address, vlink_visto, vlink_non_visto).

2026-10-24/25 (owner: 1:1 late-90s web, fields that behave "come nella vita reale"; found with the
new siti_audit_test). REAL-LIFE CONTROLS:
- BUTTON MENUS (`pulsante_link`): `<input type=button onclick="location.href='x.html'">` and
  `<button onclick=...>` (also `window.location`, `location=`) are compiled as a link to that
  address (not `__invia`): the meta is `__vai:<href>` since 2026-10-25 (it was the plain address).
  A first 2026-10-25 version made the status bar and the cursor treat it as a non-link (no address,
  arrow, "as IE buttons"); the same day this was reverted by the owner's choice: the status bar
  shows the target again (`BrowserApp._su_link` strips `__vai:`) and the cursor is the hand
  (`PageView._e_pulsante`). The browser follows it like a link (the site rules and SITI_CHIUSI still apply). A `type=image` input
  likewise. siti_catalogo_test SITI_CHIUSI reads the onclick targets too.
- FIXED SIZE (`_scatola`): a text field / password / textarea keeps the size that `size=` /
  `cols=` / `rows=` ask for (PX_CARATTERE per column, PX_RIGA per row), whatever is typed. Text that
  does not fit scrolls: a single line shows its TAIL while typing and its HEAD when inactive
  (`_taglia`); a textarea wraps by itself, by word, and breaks a too-long word where it falls
  (`_a_capo`), and when full shows the last rows while typing, the first ones otherwise.
- OWN FONT (`_ctrl`): all the text of a control is Arimo at `CTRL_FONT` = 14, black, whatever
  `<font>` / `<b>` surrounds it. WHY: it used to inherit the page's font but was measured with the
  sans 16, so the box widened or shrank.
- NEVER WIDER THAN THE CELL (`_largo_campo`, `CAMPO_CORNICE` = 16): a `size=30` field in a narrow
  column is cut to the cell's width (ctx `page_width` is the cell's while it is walked), otherwise
  typing wrapped the trailing spacer and the page grew.
- WHOLE BOX CLICKABLE: every line of the box ends with a transparent spacer image as tall as a line
  that runs to the right border, inside the `[url]` (a 1 px spacer left the white of an empty field
  deaf to the click). (Buttons used to have transparent side spacers and an nbsp label for the same
  reason; since 2026-10-25 a button is ONE image inside its link, so the whole button answers the
  click and cannot wrap - see `tex_pulsante`.)
- THE 1 PX LINE: below the content every field, textarea and select has a line 1 px high and as
  wide as the whole box. WHY: Godot sizes an inline table to its widest piece that cannot break;
  an empty field was its full spacer, and as soon as one typed the spacer shortened, the table
  shrank, and the text wrapped (the page grew).
- SELECTS are as wide as their LONGEST option (not the chosen one), the label in nbsp, cut to the
  cell if it is too long, plus the same 1 px line (a few px wider than the real row, so the row can
  never wrap at a space).
Tests: html_bb_test.gd (pulsante_menu, campo_vuoto_cliccabile, campo_misura_fissa, campo_font_suo,
textarea_tre_righe) and, over every real page, siti_audit_test (CAMPI, SPUNTE, MENU, ...).

2026-10-25 (owner: "mi sembrano ancora artificiali e non come se fossero veri siti anni 90 ... Poi vedi
se ci sono cose strane."). WHAT CHANGED TO LOOK LIKE A REAL 1999 PAGE:
- FIELD BOX (`_scatola`): cell padding is 1 (`padding=1,1,1,1`). Every line starts with a 3 px
  transparent spacer image INSIDE the link (`CAMPO_ATTACCO`), so the whole box, left edge included,
  is hoverable and clickable (the I-beam shows there too). The 1 px line under the content is
  `largo + 2` wide. The caret of the active field is `[blink]|[/blink]` (it blinks like Windows'; the
  `CTRL_PX` = 6 reserved for it is unchanged). Border navy (`#000080`) when active, `#808080` if not.
- DROP-DOWN (`_tendina`): the chosen label on white (nbsp), then a 16 px wide raised arrow button
  drawn by `Win95._tex_freccia_tendina(premuta, alta)` (grey bevel, black triangle pointing down;
  `premuta` reverses the bevel and drops the triangle 1 px) and registered on a virtual path by
  `HtmlBB.freccia_tendina(premuta)` (same take_over_path trick as the check boxes). The "▼" glyph
  is GONE. `_apri_tendina` in the browser draws the list under it. The width formula is
  `ceilf(CAMPO_ATTACCO + piu_larga + 6 + 1 + 16) + 2` for the 1 px line.
- PAGE TEXT IS CRISP, like a 1999 screen. `Win95.font_pagina(nome)`: a duplicate of the font file
  with `antialiasing = NONE`, `hinting = NORMAL`, no subpixel positioning, registered with
  `take_over_path` on `Win95.percorso_font_pagina(nome)` = `"<file>.pagina.res"` so the BBCode can ask
  for it with `[font=...]`. Switch: `Win95.TESTO_PAGINE_NITIDO` (true; false = the antialiased text of
  the rest of the OS, `font_pagina` then returns the normal font and the path is the plain file).
  WHY: antialiased modern text is one of the things that made the pages feel "artificiali". Used by
  the browser's RTL theme overrides (normal, bold, italics, bold italics, mono), `HtmlBB._font_file`
  (every `[font=...]`), the control font and every measurement in the compiler (`_scatola`,
  `_tendina`, `_marquee`). The rest of the OS UI keeps its fonts. Test: html_bb_test `face_serif`
  expects `Win95.percorso_font_pagina("serif")`.
- VERTICAL MARGINS like a browser (`_spazio(out, stack, righe)`, `_a_capo_finali(bb)`):
  `p`, `h1`-`h6`, `blockquote`, `address`, a top-level `ul`/`ol` and the end of a `form` (IE's famous
  bottom margin) leave one BLANK line before and after; `div`, `center`, `li` and nested lists only
  break the line. Margins COLLAPSE: `_a_capo_finali` counts the newlines already at the end of the
  output (tags and blanks do not count), so `</p><h2>` leaves one blank line, never two. Nothing is
  added at the top of a page or of a cell (IE did not put a margin above the first paragraph of a
  cell); `_a_capo_finali` returns -1 when nothing visible exists yet. When there is nothing to add,
  `_spazio` returns "" (no empty close/reopen tag pairs). TABLES have no margins of their own (a table
  just starts on a new line): consecutive tables touch, as in real browsers; a blank line above one
  comes from the paragraph before.
- SOURCE WHITESPACE at the start of a line is dropped (in `_walk`, when the output already ends in a
  newline): the space between `<ul>` and the first `<li>` used to indent the first bullet more than
  the others.
- VISIBLE `<embed>` is drawn like IE's Media Player control: a grey panel (`#C0C0C0`, border `#808080`,
  padding 6,4,6,4) with a sunken seek bar and its thumb (`Win95._tex_traccia_lettore(w)`, 18 px high)
  and below it raised play, pause and stop buttons (`Win95._tex_tasto_lettore(tipo)`, 23x21, "play" =
  triangle, "pausa" = two bars, anything else = square), all through `HtmlBB._tex_lettore(chiave)` on
  virtual paths `_lettore_<chiave>.tex`. No text. Play is `META_PLAY`, pause AND stop are both
  `META_STOP` (pause stops, as with a MIDI). `width=` sets the panel, clamped 120-320, default 200 (the
  seek bar is `width - 12`). It replaces the old small player of two links (play / stop). The hidden
  case is unchanged. Test: web_media_test EMBED_LETTORE.
- MARQUEE now also writes `n=<characters>` (`maxi(1, _solo_testo(testo).length())`) so
  `WebEffetti.Marquee` can clip (see its entry). Its text width is measured with the crisp bold font.
- FORM BUTTONS AS ONE IMAGE (2026-10-25, later; owner: the buttons "look fake", flat, no press).
  `_pulsante(tag, etichetta, ctx)` returns `[url=<meta>][img]<path>[/img][/url]` with NO table, for
  `type=submit/button/reset` and `<button>` (an empty label falls back to the CSV key `WEB_FORM_SUBMIT`
  / `WEB_FORM_RESET`; the label is stripped). The meta is `__invia:<n>`, `__azzera:<n>` or, with an
  `onclick="location.href=..."`, `__vai:<href>`. `type=image` still returns
  `[url=<meta>][img]<img_path(src)>[/img][/url]`, unchanged.
  `static func tex_pulsante(etichetta, premuto) -> String`: draws (once per label, cached in
  `static var _pulsanti`, keyed by the path root) the up and the down version with
  `Win95._tex_pulsante(etichetta, premuto, CTRL_FONT)` and registers them with `take_over_path` on the
  virtual paths `IMG_DIR + "_pulsante_" + str(etichetta.hash())` + `".tex"` (up) and + `PULSANTE_SUFFISSO_GIU`
  (= `"_giu.tex"`, down: `res://web/img/_pulsante_<hash>_giu.tex`). It returns the path of the one asked.
  The "_giu" path is the contract with `PageView._immagine_giu`.
- WIN95 SIDE (win95.gd, documented here because only the browser uses it): `Win95._tex_pulsante(testo,
  premuto, corpo)` builds an `Image` of width `max(label width + 2*PULSANTE_MARGINE + 4, 24)`
  (`PULSANTE_MARGINE` = 8) and height `PULSANTE_ALTO` = 21: face `C_FACE`; raised = top-left `C_LIGHT`
  then `C_HILIGHT`, bottom-right `C_DARK` then `C_SHADOW` (as in Windows: the top-right and
  bottom-left corner pixels take the dark colour); pressed = the bevel INVERTED (top-left `C_DARK` /
  `C_SHADOW`, bottom-right `C_LIGHT` / `C_HILIGHT`) and the label shifted 1 px right and down. The
  label is `font_pagina("sans")` (the crisp page font) at `corpo`, `C_TEXT`, centred.
  `Win95.scrivi_in_immagine(im, testo, font, corpo, origine, colore)` writes a string into an `Image`
  by copying the glyphs from the font's glyph cache through the TextServer (`shaped_text`,
  `font_render_glyph`, glyph atlas region, alpha-blended onto the image), with `origine.y` the
  baseline. WHY not draw on screen: the image is ready at once and it works HEADLESS too (the tests
  read the registered texture without a window). History, so it does not come back: the button used
  to be drawn as a small table of text (nbsp label, 10 px transparent side spacers); it was flat, its label could be selected and it had no pressed state.
Tests: html_bb_test (pulsante_menu now expects `__vai:`, and later the same day `[url=__vai:index.html][img]`;
input_submit / button expect `[url=...][img]` + `HtmlBB.tex_pulsante(...)`; pulsante_premuto_registrato; textarea, select, input_valore expectations
for the new box; face_serif; marquee_v has `n=`), browser_click_test section 9, web_moduli_test.
KEY-INJECTION INVARIANT (html_bb_test `_invariante`): since the margins add and remove empty format
tag pairs depending on what comes before, the comparison now ignores empty pairs of FORMAT tags
(`_senza_vuoti`: color, font_size, font, bgcolor, b, i, u, s, center, left, right, code, blink). Empty
`[cell][/cell]` and tables still count: a lost cell still shows.

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

2026-10-25: the Marquee CLIPS its characters to its box. Before, the moving text spilled out of the
box's width up to the scrollbar. The effect now receives `n=<characters>` from HtmlBB and, for each
character, estimates its x as `relative_index * len / n + dx` (the engine does not say where a
character is) and sets `fx.visible = false` when x is outside `0..w - len/n`. The text enters at the
right edge and disappears at the left one, as in a browser. The estimate assumes equal-width
characters, so a single glyph at the edge can be off by a few px. The "fermo" (still) twin does
nothing, as before.

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
or the address of a site that is gone). All 40 sites (30 written
2026-10-20, four lore sites added 2026-10-23, six ordinary ones - anime, prof, band, hosting, y2k,
radio - added 2026-10-24) and the RULES every site follows: docs/WEB_CATALOG.md;
the recipe: docs/WEB_SITES.md §3. Test: siti_catalogo_test.tscn.

### `scripts/os/web_runtime.gd`

2026-10-24: `WebRuntime.visitate` (static Dictionary, cleared in build()) holds the pages opened
in this run; BrowserApp._load fills it, `_visitato(href)` reads it (visited-link colour).

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

2026-10-24: no rendered key inside select / textarea / button / pre (the MOBILI list: they are
not plain text); form, select, textarea, button and pre count as containers. `<option>` is
deliberately NOT counted (it is usually left unclosed).

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
ordinary, 12 lore; 34 and 16 since 2026-10-23; 40 sites, 24 ordinary, since 2026-10-24 - the map is docs/WEB_CATALOG.md) and the old
one-page placeholders were deleted. Three RULES the owner set that
day, enforced by siti_catalogo_test: a site is CLOSED IN ITSELF (it
never links to another site of the catalog - only to the WebNet
portal or to a dead address in its "morti"; a directory site,
"cerca", was written and REMOVED for this reason), FORMS STAY IN THE SITE
(MODULI_NEL_SITO; until 2026-10-24 the rule was "no form controls", see the
feature note), and DATES ARE ABSOLUTE AND STOP AT 1999 (no "today, 9:05
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
40 sites: docs/WEB_CATALOG.md. (webnet.html = the user's
original mockup, ref.)

## Feature notes

- **"Still artificial": cursor, drop-down, crisp text, margins (2026-10-25).** Owner (Italian): "mi
  sembrano ancora artificiali e non come se fossero veri siti anni 90. problema numero 1 il menu a
  tendina si comporta in modo strano. 2 quando passo vicino ad un campo input deve uscire l'icona a
  stanghetta. Poi vedi se ci sono cose strane." What was done (details in the file entries above):
  (1) cursor: I-beam over fields, arrow over check boxes/radios/selects, hand on links and (corrected
  later the same day, see the next note) on buttons (`PageView.cursore_a`); (2) the drop-down opens a white list exactly under its box, drawn with
  a Win95 combo arrow button instead of a "▼" (`BrowserApp._apri_tendina`, `PageView.rettangolo_di`);
  (3) page text is aliased/crisp like 1999 screens (`Win95.font_pagina`, switch
  `TESTO_PAGINE_NITIDO`); (4) vertical margins like a browser (`HtmlBB._spazio`); (5) fields
  hoverable on the whole box, blinking caret; (6) marquee clipped to its box; (7) a visible `<embed>`
  drawn as IE's Media Player; (8) button menus are `__vai:` links (the first version gave them the arrow and no
  address in the status bar; corrected in the next note).
  KNOWN LIMIT, refined: RichTextLabel 4.6 ignores cell padding inconsistently when a table fills its
  line (overrun 0 to ~48 px measured); absorbed by the reserved right strip. Tests: browser_click_test
  section 9, web_moduli_test, html_bb_test, web_media_test (docs/code/TESTS.md).

- **"The buttons behave strangely": real push buttons (2026-10-25, same day, after the note above).**
  Owner (Italian): "i pulsanti ora si comportano in modo strano"; asked what, he picked three: the
  cursor, the missing status-bar address, and that the buttons look fake (flat, no press). Done:
  (1) every form button (`<input type=submit/reset/button>`, `<button>`, and button menus) is ONE image,
  a Win95 raised push button with its label drawn in (`Win95._tex_pulsante`, registered by
  `HtmlBB.tex_pulsante`); the label is no longer selectable text, as on a real button; `type=image`
  buttons are unchanged; (2) cursor: HAND over buttons and links, I-beam over fields, arrow over
  selects/check boxes/radios (`PageView._e_pulsante`, `cursore_a`); (3) hovering a button menu shows
  its target address again (`BrowserApp._su_link`); (4) while the left mouse button is held on a button
  the page lays the pressed image over it (`PageView._prepara_pulsante` / `_premi` / `_rilascia`).
  Tests: html_bb_test (input_submit, button, pulsante_menu, pulsante_premuto_registrato),
  browser_click_test (CURSORE_PULSANTE = hand, PULSANTE_SI_ABBASSA). Details: the entries of
  app_browser.gd, page_view.gd, html_bbcode.gd (`_pulsante`, `tex_pulsante`) and the win95 notes in
  this file.

- **Late-90s accuracy pass: six sites, button menus, no portal footer, the audit test
  (2026-10-24/25).** Owner asked for the web to be 1:1 late-90s, for form fields that behave "come
  nella vita reale", and for "test accurati" that find the problems of the sites and components.
  What changed: (1) the compiler and browser entries above (button menus, fixed-size fields in
  their own font, the reserved scrollbar strip and the recompile when the content is too wide);
  (2) content: six new ordinary sites (anime, prof, band, hosting, y2k, radio; catalog = 40 sites,
  24 ordinary, 16 lore), button menus on mail / shop / viaggi / giochi / tv / driver, period extras
  (counters, guestbooks, polls, webrings, last-updated lines) on the ordinary sites; (3) the footer
  link back to the WebNet portal was REMOVED from all 570 site pages. Owner: "tutti i siti hanno in
  fondo un link per tornare a webnet rimuovilo". History, so it does not come back: every site used
  to end with a "back to WebNet" link; a link to the portal is still ALLOWED by the closed-site rule
  but no site page uses it any more. The 404 and 500 error pages (not sites) keep their portal
  link; (4) the new tests/siti_audit_test (docs/code/TESTS.md); browser_e2e now also accepts `.edu` domains (the TLD list of its address
  check: it, com, net, org, edu).

- **Forms that work, late-90s page elements (2026-10-24).** Owner asked "Ho notato che non ci sono
  pulsanti in nessun sito, come mai?". Answer: the 2026-10-20 rule forbade form controls because the
  browser could not use them. Owner then: "Cerca di ricreare esattamente lo stile dei siti di fine
  anni 90, quindi se i pulsanti esistevano creamoli. Cos'altro manca?". His choices: forms that REALLY
  work; the link address in the status bar on hover; visited links in the vlink colour; as page
  elements "what you think is essential" -> the text tags (`<pre>` etc.). NOT done (cost vs value):
  frames, Java applets, image maps. Impossible: JavaScript effects (no scripts).
  History, so it does not come back: the rule NIENTE_CONTROLLI (siti_catalogo_test, check 8) is now
  MODULI_NEL_SITO; tools/web/sito.py checks the same. A form's action must be empty, a page of the
  site, or a script of its own server (never http/www/mailto).
  Sending: a page of the same site that exists opens (the address bar shows the query); anything
  else (/cgi-bin/...pl, .cgi, .asp) opens the new web/pages/<lang>/500.html "500 Internal Server
  Error" (a period server page, "WebNet HTTPd/1.2"; the address bar keeps the script URL + query).
  In the room: while a field is typed in, `desktop.typing()` and `desktop.trattiene_esc()` are true
  (group "campo_web_attivo"), so P does not pause and ESC stops typing instead of leaving the PC.
  Content: forms added wherever a 1999 site would have them - forum (search, jump-to, post a reply,
  members login), mail login, shop (search strip, add-to-cart, order form on the cart), news (archive
  search, a real poll), meteo (teletext "go to page", city select), giochi (newsletter, vote), blog
  guestbook, biblioteca catalogue search, ricette send-a-recipe, calcio pre-registration, tv
  (programme search, letter to the editors), musica (search, request), viaggi (quote), comune
  (certificate request), driver (find your driver), oroscopo (ascendant calculator), animali
  (pre-adoption), scuola (write for the paper); lore sites: treno guestbook, annunci answer-an-ad,
  chat enter-the-chat, ascolto write-to-the-volunteers, vincente order form, lavoro CV, cronaca
  archive search, genitori login, tecnico request-a-visit, mercatino post-an-ad, misteri
  send-a-report, volto send-your-measurements, brutti "Post a Followup" under every message. Every
  form goes to a server script, so the server answers 500: the button works, nobody is there any more.
  Tests: web_moduli_test.tscn, html_bb_test (see TESTS.md).

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
