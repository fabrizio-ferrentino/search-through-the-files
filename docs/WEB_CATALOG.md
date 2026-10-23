# The site catalog: the 34 sites

The fake web the player browses. **34 sites** in all (30 until 2026-10-23, when four lore sites were added); **every run picks 10 to 15**, of
which **4 or 5 carry lore** (owner, 2026-10-19). All of tonight's sites are listed on the
WebNet gateway; the others answer "cannot find server". They are period sites of
1998-99, complex (6-14 pages each, navigation, real text), most of them ordinary, some
disturbing. All 30 were written on 2026-10-20, in English and Italian.

This file is the **map**. The data the game reads is `scripts/os/catalogo_siti.gd`; how
to add a site is in [WEB_SITES.md](WEB_SITES.md) §3; how to write the HTML is in
[WEB_AUTHORING.md](WEB_AUTHORING.md). The story every lore text follows is
[GDD.md](GDD.md) §2b: what is **open** there (names, how the curse passes) is never
written, only written around.

**To see them all in one run:** F12 debug panel, section WEB, "All sites: ON" (the whole
catalog answers and the portal lists it, the ones not in tonight's run marked
`[DEBUG: not in tonight's run]`), then "Open the portal". To photograph pages through the
CRT: `tests/siti_check.tscn -- it <site>/<page> ...`.

## The rules every site follows (owner, 2026-10-20)

- **Closed in itself.** A site never links to another site of the catalog. The only
  links that leave a site go to the **WebNet portal**, or to an address that is **gone**
  (listed in the site's `morti`: it answers "cannot find server"). A name of another
  site may appear as plain text, never as a link. `siti_catalogo_test` SITI_CHIUSI.
- **No form controls.** No `<input>`, `<form>`, `<select>`, `<textarea>`, `<button>`: the
  browser cannot use them. Logins, searches, carts, guestbooks are written as **closed**
  ("access suspended during the move to the new server", "online orders are suspended",
  "the guestbook service has been discontinued"). NIENTE_CONTROLLI.
- **Dates are absolute and stop at 1999.** The web on the father's PC is frozen in 1999
  (the timeline is in GDD §2b): no date after 1999, and no relative timestamps like
  "today, 9:05 PM" or "yesterday". Prose may still say "yesterday" inside a dated
  article. NIENTE_DATE_RELATIVE, NIENTE_DATE_DOPO_1999.
- **Invented and period-accurate**: no real brands, no real people. English pages use
  dollars, Italian pages lire.
- **Nothing shaped like a key** (a digit, a dash and four letters/digits). NIENTE_CHIAVI_FINTE.

## Style: every site looks like itself (owner, 2026-10-23)

Until 2026-10-23 almost every site was the same skeleton (coloured banner table, light
nav-bar table, Arial text, centred footer) in different colours. The column **Style** gives
each site its own period archetype (the shapes are described in
[WEB_AUTHORING.md](WEB_AUTHORING.md) "Style templates"): no two sites share a skeleton. The
six **pilot** sites were restyled first with the new tools (GIFs, tiled backgrounds, side
bars, serif and Comic fonts, marquee/blink, MIDI); the others follow after the owner's
review. A restyle keeps the texts, the pages and every rule below.

## Ordinary sites (18)

| id | Site (EN / IT) | Pages | Notes | Style |
|---|---|---|---|---|
| forum | RetroForum | 14 | computer message board: sections, long threads, members, rules | UBB message board: grey bevelled tables, avatars, quotes |
| shop | BuyItAll / CompraTutto | 9 | mail-order shop; online orders suspended | mail-order catalogue: price-tag grid, star bursts, product pictures |
| news | NewsToday / NotizieOggi | 11 | news portal, 31/03/1999 edition, six articles | news portal: left side-bar of sections, headlines in the middle |
| meteo | WeatherNow / MeteoNow | 6 | forecasts, cities, satellite (offline), seasonal, glossary | instrument panel: brushed-metal tile, big tables of numbers |
| giochi | PlayWeb / GiocaWeb | 7 | shareware, chart, cheats, reviews; downloads closed | game zone: black, neon grid tile, flames, scrolling chart |
| mail | WebNet WebMail | 6 | login closed during the move; service news, help, terms | web application: grey Win95 boxes, no pictures |
| blog | ~jack99 | 7 | a happy sixteen-year-old: friends, band, school trip, a full guestbook | **pilot** GeoCities teen page: tiled sky, Comic, GIFs, counter, MIDI, marquee |
| biblioteca | Millbrook Public Library / Biblioteca Civica di San Vito | 7 | hours, new books, events, card catalogue | card catalogue: parchment tile, Times, typed index cards |
| ricette | Granny Rose's Kitchen / La cucina di nonna Rosa | 8 | recipes, readers' letters | **pilot** grandma: narrow card on gingham, Times + Comic, clip-art, waltz |
| calcio | Griffins Fan Club / Fan Club Grifoni | 7 | results, squad, away trips, notice board | **pilot** loud fan club: flames, blink, results marquee, anthem player |
| tv | CouchGuide / TeleGuida | 6 | listings, films, series, letters | TV guide: time-slot grid, coloured channel columns |
| musica | MidiMania / MidiWorld | 6 | MIDI archive (downloads suspended), invented lyrics, chart | MIDI archive: Courier file lists, embedded players |
| viaggi | Sun & Sea Travel / Viaggi Sole e Mare | 7 | offers, destinations; online booking closed | travel brochure: postcards, big pictures, sky colours |
| comune | Town of Millbrook / Comune di San Vito al Lago | 7 | offices, notices, events, certificates, waste collection | **pilot** bare 1995 institutional page: grey, Times, lists, no tables |
| scuola | Millbrook High / Liceo G. Galilei | 7 | circulars, trips, computer room, school paper | student-made: notice board, typewriter Courier |
| driver | DriverZone | 7 | drivers by category (files on the FTP server), utilities, FAQ | **pilot** tech portal: dark left side-bar, badges, mono tables |
| animali | Faithful Friend / Rifugio Amico Fedele | 7 | dogs, cats, adoption, volunteers | charity page: centred column of animal cards |
| oroscopo | The Stars / Le Stelle | 6 | the week, signs, compatibility, moon, letters | **pilot** splash page + mystical pages: night tile, serif gold, ambient MIDI |

The ordinary sites share one invented world: the town of **Millbrook / San Vito al
Lago** (library, town hall, school, shelter, football club, PC repair), the WebNet
provider, the same weeks of March 1999. They cross-reference each other in their texts
(jack99's school trip is the school's fourth-year trip; his dog came from the shelter),
never with links.

## Lore sites (16)

The catalog's `voce` says whose story a site tells (`padre`, `ragazzo`, `maledizione`,
`altri`): every run has at least one about the father and one about the young man.

**The young man is not the protagonist** (owner, 2026-10-23: he "almost becomes a main
character", with more appearances than the father). He has **one site of his own** (`treno`)
and appears in **at most two others**: the chat and the lonely hearts ads. The sites that
used to carry his threads (`lavoro`, `vincente`, `ascolto`) now tell the stories of OTHER
people (voice `altri`), and none of them repeats a detail of his life (night warehouse, the
twelve windows, the girl at the bar).

**His nickname is `~missedtrain / ~trenoperso`** (owner, 2026-10-23). It used to be
`~whale52 / ~balena52`, the same animal as the OS logo, which the owner did not like. The
**52 Hz whale stays the CURSE's emblem** (death screen line, secret-folder glitch, the disk
files 52HZ.TXT and whale.txt, `misteri/whale`, `nessuno/whale`): only the young man lost it.
His symbol is the 23:52 regional train that no longer stops at the closed station behind
his building (the station clock stopped at ten past six); "the train only comes once" is
what people told him.

| id | Site (EN / IT) | Voice | Pages | Content | Style |
|---|---|---|---|---|---|
| treno | ~missedtrain / ~trenoperso | young man | 7 | his personal page: about, the 23:52 train that does not stop, dead links, night thoughts, the empty guestbook, the last update | dark personal page: ASCII art, night blue |
| annunci | FreeAds Board / AnnunciGratis | young man | 8 | looks ordinary; the lonely hearts archive with his ad, the same every month, then expired; an answer that came too late | classifieds: dense small type on newsprint yellow |
| chat | ChatPoint | young man | 8 | rooms closed; the archive: he says hello and nobody answers, the room empties, the last night alone | chat client: room list side-bar, Courier logs |
| lavoro | JobFinder / CercoLavoro | others | 8 | job offers and advice; in the forum a night security guard's questions get brisk answers | corporate job portal: navy, Times headings |
| vincente | The Winner Method / Il Metodo Vincente | others | 7 | the mail-order "method" (the company has closed); a 33-year-old surveyor's thirty days in the customer area | sales letter: one long page, red headlines, yellow highlights, blinking |
| ascolto | Someone Listens / Qualcuno Ascolta | others | 6 | a listening line left without volunteers; a night baker's messages, unanswered | helpline: calm, plain centred text, almost no ornament |
| cronaca | The County Herald / La Gazzetta della Provincia | father | 8 | the newspaper archive: the tragedy, the follow-up, ordinary local news | newspaper: Times masthead, date line, serif columns |
| genitori | The Kitchen Table / Il Tavolo di Cucina | father | 9 | a parents' forum; the father's posts slipping, the last one to his boys | homely forum: cream, Georgia, little clip-art |
| tecnico | PC Doctor at Home / Il Dottore del PC | father | 6 | a technician's job notes from the father's house; the notice afterwards | plain text notes: Courier, like a .txt put online |
| misteri | Hidden Truths / Verita' Nascoste | curse | 7 | reports of computers that watch, objects that pass something on, the whale; the webmaster's last update | conspiracy page: black, green, eyes, blink |
| mercatino | Used PC Market / Mercatino PC | curse | 8 | ordinary ads, and one beige 486 sold again and again, with "don't buy it" | flea market: ad table with pictures, beige |
| nessuno | nobody / nessuno | curse | 8 | the page that should not exist: the curse speaking to whoever is at the PC now | the page that should not exist: almost empty, dark |
| brutti | The Ugly Guys' Board / Il Forum dei Brutti | others | 8 | a 1997 board where men ask to be told "the truth" about their looks; the long words (hypergamy, genetic determinism, the 80/20) are used, never explained (owner, 2026-10-23: no glossaries, no definitions); one member leaves for a dancing class; on 21/11/1998 at 23:52:00 a "guest" posts with the words of the young man's page | WWWBoard: white, Times, threaded message list |
| volto | The Measure of the Face / La Misura del Volto | others | 6 | an amateur "essay" that measures faces with a ruler and turns the score into a sentence; readers' scores; reader 52 sent a photograph of a man on a station bench with a white space for a face (postmark: June) | treatise: numbered sections, figure, ratio tables |
| numeri | Numbers Don't Lie / I Numeri Non Mentono | others | 6 | the board's "Professor": invented statistics presented as truth, a survey of the members, and his field notebook, which in January 1999 records a train where there is no railway | print-out: Courier on pale paper, ASCII bar charts |
| diario | Days Without / Giorni Senza | curse | 6 | a forty-year-old teacher counts the days since he turned eighteen; letters never posted; the last update (29/03/1999, 23:52) is not for the readers of 1999 but for whoever reads it now, in a new house, alone tonight | sepia diary: dark brown, Georgia, a narrow column, a counter |

**Timeline the lore sites agree on:** the young man's traces run from October 1997 (his
page) to June 1998 (the last chat log); after that only echoes of him, never signed (the
board's guest post and the face site's envelope, both on 21/11/1998; 23:52 recurs); the father's from February to the night of
Tuesday 30/03/1999 (the forum); the newspaper and the technician write after it, in
1999. **Lore choice to confirm with the owner:** `mercatino` and `nessuno` show the same
old PC passing through several owners between the young man's flat and the father's
house. They show that it moves, never the rule by which the curse passes.
