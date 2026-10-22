# The site catalog: the 30 sites

The fake web the player browses. **30 sites** in all; **every run picks 10 to 15**, of
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

## Ordinary sites (18)

| id | Site (EN / IT) | Pages | Notes |
|---|---|---|---|
| forum | RetroForum | 14 | computer message board: sections, long threads, members, rules |
| shop | BuyItAll / CompraTutto | 9 | mail-order shop; online orders suspended |
| news | NewsToday / NotizieOggi | 11 | news portal, 31/03/1999 edition, six articles |
| meteo | WeatherNow / MeteoNow | 6 | forecasts, cities, satellite (offline), seasonal, glossary |
| giochi | PlayWeb / GiocaWeb | 7 | shareware, chart, cheats, reviews; downloads closed |
| mail | WebNet WebMail | 6 | login closed during the move; service news, help, terms |
| blog | ~jack99 | 7 | a happy sixteen-year-old: friends, band, school trip, a full guestbook |
| biblioteca | Millbrook Public Library / Biblioteca Civica di San Vito | 7 | hours, new books, events, card catalogue |
| ricette | Granny Rose's Kitchen / La cucina di nonna Rosa | 8 | recipes, readers' letters |
| calcio | Griffins Fan Club / Fan Club Grifoni | 7 | results, squad, away trips, notice board |
| tv | CouchGuide / TeleGuida | 6 | listings, films, series, letters |
| musica | MidiMania / MidiWorld | 6 | MIDI archive (downloads suspended), invented lyrics, chart |
| viaggi | Sun & Sea Travel / Viaggi Sole e Mare | 7 | offers, destinations; online booking closed |
| comune | Town of Millbrook / Comune di San Vito al Lago | 7 | offices, notices, events, certificates, waste collection |
| scuola | Millbrook High / Liceo G. Galilei | 7 | circulars, trips, computer room, school paper |
| driver | DriverZone | 7 | drivers by category (files on the FTP server), utilities, FAQ |
| animali | Faithful Friend / Rifugio Amico Fedele | 7 | dogs, cats, adoption, volunteers |
| oroscopo | The Stars / Le Stelle | 6 | the week, signs, compatibility, moon, letters |

The ordinary sites share one invented world: the town of **Millbrook / San Vito al
Lago** (library, town hall, school, shelter, football club, PC repair), the WebNet
provider, the same weeks of March 1999. They cross-reference each other in their texts
(jack99's school trip is the school's fourth-year trip; his dog came from the shelter),
never with links.

## Lore sites (12)

The catalog's `voce` says whose story a site tells (`padre`, `ragazzo`, `maledizione`):
every run has at least one about the father and one about the young man.

| id | Site (EN / IT) | Voice | Pages | Content |
|---|---|---|---|---|
| balena | ~whale52 / ~balena52 | young man | 7 | his personal page: about, the 52 Hz whale, dead links, night thoughts, the empty guestbook, the last update |
| annunci | FreeAds Board / AnnunciGratis | young man | 8 | looks ordinary; the lonely hearts archive with his ad, the same every month, then expired; an answer that came too late |
| chat | ChatPoint | young man | 8 | rooms closed; the archive: he says hello and nobody answers, the room empties, the last night alone |
| lavoro | JobFinder / CercoLavoro | young man | 8 | job offers and advice; in the forum his questions get brisk answers |
| vincente | The Winner Method / Il Metodo Vincente | young man | 7 | the mail-order "method" (the company has closed); his thread in the customer area |
| ascolto | Someone Listens / Qualcuno Ascolta | young man | 6 | a listening line left without volunteers; his messages, unanswered |
| cronaca | The County Herald / La Gazzetta della Provincia | father | 8 | the newspaper archive: the tragedy, the follow-up, ordinary local news |
| genitori | The Kitchen Table / Il Tavolo di Cucina | father | 9 | a parents' forum; the father's posts slipping, the last one to his boys |
| tecnico | PC Doctor at Home / Il Dottore del PC | father | 6 | a technician's job notes from the father's house; the notice afterwards |
| misteri | Hidden Truths / Verita' Nascoste | curse | 7 | reports of computers that watch, objects that pass something on, the whale; the webmaster's last update |
| mercatino | Used PC Market / Mercatino PC | curse | 8 | ordinary ads, and one beige 486 sold again and again, with "don't buy it" |
| nessuno | nobody / nessuno | curse | 8 | the page that should not exist: the curse speaking to whoever is at the PC now |

**Timeline the lore sites agree on:** the young man's traces run from October 1997 (his
page) to June 1998 (the last chat log); the father's from February to the night of
Tuesday 30/03/1999 (the forum); the newspaper and the technician write after it, in
1999. **Lore choice to confirm with the owner:** `mercatino` and `nessuno` show the same
old PC passing through several owners between the young man's flat and the father's
house. They show that it moves, never the rule by which the curse passes.
