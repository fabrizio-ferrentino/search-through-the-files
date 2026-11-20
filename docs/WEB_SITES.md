# The fake web: how the sites work

Written for the owner of this project: what a "site" is made of, which file holds
which string, and the exact steps to change or replace one. For how to *write* the
HTML of a page (tags allowed, table widths, styling), see
[WEB_AUTHORING.md](WEB_AUTHORING.md) — this file is about the plumbing around it.

---

## 0. Read this first: why searching for a name can fail

The gateway logo reads **WEBNET GATEWAY**, but searching the project for `WEBNET`
finds nothing in the code. That is not a bug in your search — in the HTML the word
is **split by tags**:

```html
<u>WEB<b>NET</b></u> <font size="4" color="#FF0000">GATEWAY</font>
```

So the file contains `WEB`, then `<b>`, then `NET`. Any search for the whole word
misses it. This happens all over period HTML, because the look comes from tags
sprinkled inside the words (`<b>`, `<u>`, `<font>`).

**How to find a string that "doesn't exist":**

- search for a **fragment** instead of the word: `LOCAL<`, `WEB<b>`, `>NET<`;
- search for a neighbour that is *not* styled: a colour (`#FF0000`), an attribute
  (`Arial Black`), a tag (`<hr width="50%"`);
- for the gateway's **words** (tagline, section headers, footer) search
  `locale/ui.csv` instead: since the game became multi-language they live there as
  `WEB_HOME_*` rows, not in the template;
- or go straight to the file that owns that text — section 1 tells you which.

A related trap: if you rename a string in a **comment** or in a **test** but not in
the template, nothing changes on screen. That is exactly what happened with
`LOCALNET` → `WEBNET`: the word was fixed in a comment and in a test, while the
real logo lived split across tags inside `_HOME_TEMPLATE`. The test still passed
because it accepted the logo **or** the word `GATEWAY` — it now demands both.

---

## 1. Where each piece of text lives

Since 2026-10-19 **a site is a folder**: `web/pages/<lang>/<site>/`, with `index.html`
and its other pages. The list of sites, with everything about each one, is the **site
catalog**: `scripts/os/catalogo_siti.gd`. The 40 sites and how far each one is
are in [WEB_CATALOG.md](WEB_CATALOG.md).

| What you see | Where it lives | Notes |
|---|---|---|
| A site's pages (forum, cronaca, shop…) | `web/pages/<lang>/<site>/<page>.html` — real files you write by hand, **one per language** | free-form HTML in the legacy subset; `index.html` is the home of the site |
| Which sites exist, their pages, domains, kind | `scripts/os/catalogo_siti.gd` → `SITI` | data only; one entry per site |
| The **gateway / wiki** (the start page) | `scripts/os/web_runtime.gd` → `_HOME_TEMPLATE` (structure) + `locale/ui.csv` (its words) | **generated per run**, not a file |
| The site's **name and description** | `locale/ui.csv` → the `WS_*` rows; the catalog only says which key belongs to which site | the gateway list reads these |
| The site's **domain** | the catalog → the `en` / `it` fields of the site | the address bar, the gateway links and `page_of` read these |
| The per-run **key** hidden in a page | injected at load time by `web_runtime.gd::source_html` + `web_anchor.gd` | never write a key into a page by hand |
| Page images | `web/img/*.png`, used as `<img src="occhio.png">` | shared by every language and every site |
| The error pages | `web/pages/<lang>/404.html` (the site exists, the page does not) and `nonserver.html` ("cannot find server": the address is nobody's, or the site is not part of tonight's run) | outside the site folders |

**The language rule, once:** a site id (`forum`) and a page name (`thread`) are
*identifiers* and never change between languages — what changes is the file's content
and the folder it sits in. Everything the player reads is either in `locale/ui.csv` or
in the page file of that language.

`web/webnet.html` is **your original mockup**, kept as a reference only. The game
never loads it; `_HOME_TEMPLATE` is the copy that runs. If you restyle the gateway,
change the template (and, if you like, keep the mockup in sync by hand).

---

## 2. What happens when the browser opens a page

1. A **page** is called `"<site>/<page>"` inside the game: `forum/index`,
   `forum/thread`, `treno/thoughts`.
2. What you type in the address bar goes through `WebRuntime.page_of`
   (`www.retroforum.it/rules.html` → `forum/rules`; `www.retroforum.it` → `forum/index`).
   A **link** you click goes through `WebRuntime.risolvi_link`: a relative href
   (`rules.html`) stays in the site of the page you are on, an absolute one
   (`http://www.newsoggi.it`) goes through `page_of`.
3. If the site is **not one of tonight's sites**, or the address is nobody's, the
   browser shows `nonserver.html` ("cannot find server") with the requested address in
   the bar.
4. `BrowserApp.read_page(page)` reads `web/pages/<lang>/<site>/<page>.html`, where
   `<lang>` is `WebRuntime.lingua()` (`en`, `it`). If that language has no such page it
   falls back to `en` — a missing translation must not make a page disappear from the
   game, only from that language. Still missing → `404.html`. The gateway is the
   exception: it is generated by `WebRuntime.home_html()`.
5. `WebRuntime.source_html(page, html)` returns the same HTML **with a run key
   injected**, but only if this page carries one of the two web keys.
6. The address bar shows `WebRuntime.display_url(page)`: the site's domain, plus
   `/<page>.html` for anything but the index.
7. The HTML is compiled to BBCode (`HtmlBB`) and shown; **comments are stripped
   first**, which is what makes a key hidden in a comment invisible on screen but
   readable in *Visualizza sorgente*.
8. The page is covered for 0.35–1.2 s while the status bar counts the KB (the
   loading wait). See CLAUDE.md, `app_browser.gd::_avvia_caricamento`.

Per run, `WebRuntime.build()` picks **10 to 15 sites** from the catalog (all of them
while the catalog has fewer than 10), **4 or 5 of them lore sites** (or all the lore
there is), with at least one site about the father and one about the young man when
the catalog has them. Then two DIFFERENT sites of the run each get a web key, on a
page drawn among that site's pages. The gateway lists exactly tonight's sites — the
others answer "cannot find server" — and no key is ever on the gateway.

---

## 3. Recipes

### Add a site

1. Make the folder in **every** language, `web/pages/en/<site>/` and
   `web/pages/it/<site>/`, with the **same** file names: at least `index.html`. Copy the
   closest existing site as a skeleton (`forum/` for something rich, `treno/` for a
   personal page, `cronaca/` for a newspaper, `shop/` for a shop).
2. Inside the pages, link the pages of the same site with **relative** hrefs
   (`<a href="rules.html">`). A site is **closed in itself** (owner, 2026-10-20): it never
   links to another site of the catalog. The only absolute links allowed are the WebNet
   portal (`<a href="http://www.webnet.it">` in the Italian pages,
   `http://www.webnet.com` in the English ones) and addresses that are **gone**, listed
   in the site's `morti`. No `<input>`/`<form>`/`<button>`: write logins, searches and
   carts as closed. Dates absolute and no later than 1999. The full rules are at the top
   of [WEB_CATALOG.md](WEB_CATALOG.md); `siti_catalogo_test` checks all of them.
3. `locale/ui.csv`: two rows, the name and the description the gateway shows:
   ```
   WS_MYSITE,My site,Il mio sito
   WS_MYSITE_D,What it is about,Di cosa parla
   ```
4. `scripts/os/catalogo_siti.gd`: one entry in `SITI` (the fields are explained at the
   top of that file):
   ```gdscript
   {"id": "mysite", "nome": "WS_MYSITE", "desc": "WS_MYSITE_D",
       "en": "www.mysite.com", "it": "www.ilmiosito.it",
       "tipo": "normale", "voce": "", "featured": false, "stato": "completo",
       "pagine": ["index", "about", "news"]},
   ```
5. Run `--import` and the tests in section 4. To look at the new site in the game, open
   the F12 panel, switch "All sites" ON and open the portal: every site of the catalog
   answers, even the ones the run did not pick.

`pagine` must list **every** page of the folder, index first: the key can land in any
of them, and `tests/siti_catalogo_test.tscn` fails on a page that is in the folder but
not in the list. A site marked `"completo"` must have at least 5 pages and about 6,000
characters of visible text in each language — the same test checks it.

### Change a site's name or description (as shown on the gateway)

The words are in `locale/ui.csv` (columns: `keys,en,it`) — **edit them there**:

```
WS_FORUM,RetroForum - Message board,RetroForum - Bacheca
WS_FORUM_D,"Floppies, 56k modems and other nostalgia.","Floppy, modem 56k e altre nostalgie."
```

Quote a cell that contains a comma, as above. After editing the CSV run `--import`:
Godot compiles it into the `.translation` files the game actually loads.

`featured` in the catalog puts a site under *YOUR BOOKMARKS* (`true`) or under
*RECENTLY VISITED SITES* (`false`, which also prints the address). The page's own
title (window title bar) is its `<title>`, and the heading at the top of the page is
HTML in that file — the catalog does **not** control those.

### Change the gateway (logo, layout, footer)

The **layout** is `_HOME_TEMPLATE` in `web_runtime.gd`; the **words** are the
`WEB_HOME_*` rows of `locale/ui.csv`. The template is plain period HTML with named
slots filled by `String.format`, so:

- `{title}`, `{tagline}`, `{footer1}`, `{footer2}` are the translated strings and
  `{rows}` is where the list of sites is inserted;
- a `%` in the template is just a `%` (`width="70%"`);
- the rows themselves come from `_header_row` / `_fav_row` / `_recent_row`, just
  below the template.

Remember section 0: the logo text is split across tags.

### Change a site's address

The `en` and `it` fields of the site in the catalog. They feed the address bar, the
gateway's list, the key hint in the F12 panel and the typing resolution (`page_of`).
**Set both**, or one language shows the other's domains — `tests/web_locale_test.tscn`
fails if a domain of one language turns up in the other's gateway. Keep a period TLD
(`.com`/`.net` for the English sites, `.it` for the Italian ones, `.com` for shops and
games in both) and don't use a domain that existed for real. A personal page lives
under the provider: `www.webnet.it/~name`.

`page_of` is tolerant like a period browser: with or without `http://` and `www.`, the
bare second-level name (`retroforum`), a page path (`/rules.html`), and the addresses
of the other language too (it leads to exactly the page that address names).

### Dead links on purpose

Two kinds, both declared in the site's `morti` list in the catalog so that
`web_locale_test` (which checks every href of every page) accepts them:

- a page of the site that does not exist (`"removed"`: the forum's removed thread) — it
  gives the 404, with the requested address in the bar;
- the address of a site that is gone (`"www.webnet.it/~gianlu"`: a friend's vanished
  page) — it gives "cannot find server".

### Remove a site

Delete its folders (all languages) plus its entry in the catalog and its rows in
`locale/ui.csv`.

### Add a language

1. `locale/ui.csv`: add a column with the language code in the header row and
   translate every row (a row left empty falls back to the key itself, which then
   shows up on screen — `web_locale_test` catches that on the gateway).
2. `project.godot` → `[internationalization]`: add
   `res://locale/ui.<code>.translation` to `locale/translations`, and the code to
   `GameManager.LINGUE`.
3. `web/pages/<code>/`: copy every site folder (and `404.html`, `nonserver.html`) and
   translate the pages. Keep the folder and file names — they are identifiers.
4. The catalog: a domain field for the new language in every site, and a branch in
   `WebRuntime.dominio()`.
5. Add the code to `LINGUE` in `tests/web_locale_test.gd` and
   `tests/siti_catalogo_test.gd` and run them: they tell you what is missing.

---

## 4. After a change, run these

```powershell
& $godot --headless --path $proj --import
& $godot --headless --path $proj res://tests/siti_catalogo_test.tscn  # the catalog: pages, domains, complexity, run picks
& $godot --headless --path $proj -s res://tests/html_bb_test.gd        # HTML subset + hiding spots per page
& $godot --headless --path $proj res://tests/web_key_inject.tscn       # the key over 60 runs
& $godot --headless --path $proj res://tests/web_locale_test.tscn      # every language complete and coherent
& $godot --path $proj res://tests/browser_e2e.tscn                     # the real browser on the real pages
```

`browser_e2e` is the one that would catch a broken page, a wrong address, a lost
logo or a key that cannot be found. To LOOK at pages as the player sees them, through
the CRT, run `tests/siti_check.tscn` (windowed; after `--` the language and the pages,
e.g. `-- en forum/index treno/update`): it saves `user://sito_<site>_<page>.png`. It also writes screenshots next to the other
test output, which is the fastest way to see what a page looks like in game without
launching the whole game.

---

## 5. Rules that are easy to break

- **Never write a key (`1-AB2C`) into a page**, nor anything shaped like one (a digit,
  a dash, four letters/digits — so no dates like `2-1999`: write `02/1999`). Keys are
  generated per run; a fake one is a wrong answer the player can find.
  `siti_catalogo_test` checks every page.
- **The gateway must stay clean.** By design the key never lands on it — the index
  is trustworthy, the sites are not. `browser_e2e` asserts this.
- **No CSS.** The renderer is a legacy-HTML subset: tables, `<font>`, `<b>`,
  `bgcolor`. See WEB_AUTHORING.md for the exact list and for the table-width trick.
- **Dark pages:** set the colours on `<body>` (`bgcolor`, `text`, `link`) — the
  browser reads them from there, and the key insertion trusts them to decide where
  text stays readable.
- **Pages have no comments today**, and the key scanner assumes that
  (`tests/html_bb_test.gd` checks it). If you want a comment in a page, say so and
  the assumption can be lifted — leaving it silently would make the key placement
  unpredictable.
