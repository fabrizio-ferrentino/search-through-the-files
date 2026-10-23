# Game Design Document — Search Through the Files

This is the creative vision. Some of it is **not built yet**; for what exists in
code today see [ARCHITECTURE.md](ARCHITECTURE.md), and for build order see
[ROADMAP.md](ROADMAP.md).

---

## 1. High concept

> You found an old computer. Somewhere inside it are the keys to a locked folder.
> Find them, open the folder, and you can leave. But something in the room — and
> something in the machine — does not want you to look away from it for too long.

**Search Through the Files** is a single-player first-person horror/puzzle game.
It crosses two inspirations:

- **From *Welcome to the Game*:** the core loop is *investigation* inside a
  believable fake operating system — reading files, browsing fake websites,
  inspecting "HTML source", studying images for hidden clues.
- **From *Five Nights at Freddy's*:** the core *tension* is *vigilance* —
  threats build while you are distracted, and surviving means periodically
  checking your surroundings. Failure is a sudden jumpscare and a restart.

The two layers run **at the same time**: you investigate on the PC while the room
(and the PC itself) can turn hostile. The fun is the conflict between "I need to
keep reading" and "I need to look up and check."

## 2. Player fantasy & tone

- Late-1990s home-office aesthetic: a CRT monitor, a beige tower, a desk lamp,
  a dim room. Teal desktop, gray windows, dial-up websites.
- Cozy-but-wrong: the nostalgia is comforting, which makes the intrusions worse.
- The horror is *quiet dread punctuated by spikes* — not constant action.

## 2b. Story & lore

*Given by the owner on 2026-10-18. This section is the reference for every in-game text
(files, web pages, dialogs). What is marked **open** is NOT decided: do not invent it in
the game's texts — write around it.*

### The story (what the player lives)

- The protagonist is a young man called **Noah** (the name may change: in the texts it is
  the placeholder `{PROTAGONISTA}`, see [DISK_CONTENT.md](DISK_CONTENT.md)).
- He has just moved into a new house to live with his **girlfriend**.
- While moving out of his old home he finds an **old PC that belonged to his father**, and
  takes it with him to find out something about his parents. They died when he was small:
  he knows very little about them, and grew up with an **aunt and uncle**.
- One night his girlfriend goes to work on a **night shift**. Alone in the house, Noah
  switches the PC on and starts to investigate. **That night is the game.**

### The lore (what the player uncovers)

- The computer carries a **very old curse that passes from person to person**.
- It began with a **young man, frustrated at always being alone** — in love and in
  everything else — who **hanged himself** and cast the curse.
- The curse **takes possession of a person's body** and drives them to **kill the family**
  of the one it possesses. Its logic: *"I never had a family, so nobody must have one."*
- **How the curse shows itself** (owner, 2026-10-18): as a **child with a noose around
  the neck**. The origin is still the young man above; the child is the *form it takes*
  when it appears. In the game it is one of the PC "apparitions" (§7.2): the dark
  silhouette of a hanging **boy** (the curse is male), with a true child's outline — never a
  face, never graphic.
- The curse reached this PC, and **Noah's father**. Possessed, the father **killed his
  wife** (Noah's mother) and attacked **Noah's brother**, who was saved by a **neighbour**:
  the neighbour intervened and stopped the father by **killing him**.
- **The planned ending**: when Noah has found all the keys and opens the folder, **he is
  possessed** and kills his girlfriend. (Not implemented: today the win screen is a plain
  "you won". It reframes the whole hunt — every key brings him closer to it.)

### Open (decided later by the owner)

- **Why a child**: the curse appears as a child while its origin is a young man — the
  reason is open.
- **How the curse passes** from one person to the next (the PC is the vehicle this time;
  the rule is open). Texts may hint that it *moves*, never say *how*.
- **Names**: the original young man, the parents, the brother, the neighbour, the
  girlfriend, the family surname. Texts use roles ("my wife", "the boys", "the neighbour").
- **The brother after that night**: saved, but where he is now, and whether Noah was there
  that night, are open.

### When (decided by the owner on 2026-10-20)

- The family tragedy happens in **spring 1999**, the night between Monday 29 and Tuesday
  30 March in the web's texts (the newspaper archive keeps the date unreadable). Noah is
  about **5**; the brother who was attacked is the elder.
- The game night is in **2022**; Noah is about **28**.
- The web on the father's PC is **frozen in 1999**: no page carries a date after 1999, and
  no page uses relative timestamps ("today", "yesterday"). The young man's traces on the
  web run from October 1997 to June 1998.

### Writing guide for in-game texts

- **The PC belonged to the father.** Its ordinary files (diary, letters, phone numbers, the
  kids' homework, recipes) are **his family's normal life** — the contrast is the horror:
  the warmer the ordinary files, the worse the rest.
- **Three voices** for the lore files:
  1. **the father**, getting worse — diary entries that start normal and slip, a moment of
     lucidity written to his sons;
  2. **the original young man** — loneliness, nobody answering, never graphic about his
     death. (Until 2026-10-23 the **52-Hz whale**, the OS logo, was his emblem and his
     nickname was whale52; the owner changed it: his nickname is now ~missedtrain /
     ~trenoperso and the whale stays the **curse's** emblem.)
  3. **the curse itself**, speaking to whoever is at the PC *now* — short, in lowercase,
     it knows the room and knows you are alone tonight.
- **Weight on the father** (owner's call): every run has at least one of his files.
- **Never a fake key** in a text (a digit, a dash, four letters/digits): see §6.

### TODO

- **Lore on the websites** (owner, 2026-10-18; planned in [WEB_CATALOG.md](WEB_CATALOG.md),
  16 lore sites out of 34 since 2026-10-23, 12 out of 30 before): fragments about the
  original young man and about the father,
  spread across the fake sites. 2026-10-23 (owner): the young man keeps ONE site (`treno`)
  and appears in at most two others (chat, annunci); the threads of lavoro, vincente and
  ascolto are other people's stories; four lore sites were added (brutti, volto, numeri,
  diario), see WEB_CATALOG.md. **Built (2026-10-20), the first twelve:** the young man's
  personal page, the lonely hearts column, the chat archive, the job board, the "method"
  site and the listening line (his voice); the newspaper archive, the parents' forum and
  the repair technician's notes (the father); the mysteries site, the second-hand PC market
  and the page where the curse speaks. Map in WEB_CATALOG.md.
- The **ending** above (possession → the girlfriend).

## 3. Win & lose conditions

- **Win:** collect all required **keys**, use them to derive/unlock the password
  of the **secret folder**, open it, and trigger the ending.
- **Lose:** get caught by a threat (room enemy reaches you, PC entity triggers,
  or you ignore a warning too long) → **jumpscare** → **game over** → restart a
  fresh, re-randomized run.

## 4. Core loop

```
   ┌─────────────────────────────────────────────────────────┐
   │  INVESTIGATE on the PC                                   │
   │   • read files, browse sites, inspect HTML, study images │
   │   • find a KEY (a code/word/fragment)                    │
   │            │                                             │
   │            ▼                                             │
   │  STAY VIGILANT                                           │
   │   • a threat builds (room and/or PC)                     │
   │   • look around the room / react to glitches            │
   │   • mishandle it ──► JUMPSCARE ──► GAME OVER ──► restart │
   │            │                                             │
   │            ▼                                             │
   │  PROGRESS                                                │
   │   • enough keys ──► open the SECRET FOLDER ──► WIN       │
   └─────────────────────────────────────────────────────────┘
```

## 5. The two spaces

### 5.1 The Room (Main)
A small 3D room. The player is seated and cannot walk; they **look** by moving
the mouse (left / center / right / back). The desk (center) holds the monitor and
the tower.

**Layout (vision — partly built):**
- **Center** — the desk with the monitor and tower (where you investigate).
- **Right** — a **corridor** with several rooms opening off it (on its left and
  right), partly visible from the seat; enemies approach down it.
- **Left** — a small **window** to the outside.
- **Back** — the rest of the room behind the chair, where the **Ghost** lurks.

Interactions:
- Click the **tower/case** → power the computer on/off.
- Click the **monitor screen** → "dive in" to the fullscreen PC view.
- Look **around** (right = corridor, left = window, back = behind you) to spot and
  respond to threats.
- Raise a **flashlight/torch** while looking **left/right**: the corridor and the
  window are dim, so the torch lets you *see* what's there — and shining it on an
  approaching enemy can **drive it back**. Likely a limited resource (battery or
  cooldown) so it can't simply be held on. *(Planned.)*

Design intent: the room is the "FNAF camera" — the place you must keep checking;
the torch makes *checking* an active, resource-managed act, not a free glance.

### 5.2 The PC (ComputerMode)
A fake Windows 95/98 OS rendered on the monitor and, when you dive in, fullscreen
with a CRT effect. Contains a desktop, taskbar, Start menu, and apps:

- **File Explorer** — browse the virtual drive and folders.
- **Notepad** — read/edit text files (clues live here).
- **Browser** — visit fake sites; right-click → **Inspect element** reveals the
  page's "HTML", where clues can hide in comments/attributes.
- **Trash** — deleted files aren't gone; they can hide clues too.
- an **image viewer / photo tool** (`ImageViewerApp`) — opens the run's pictures. A
  code is hidden *in* one photo yet not plainly visible; the player **adjusts
  brightness / contrast / saturation / levels** until the text (e.g. `1-AB12`)
  emerges. *(Implemented M3 — the photos are procedural placeholders for now; an
  authored set, made in Photoshop and dropped into an assets pool, can replace them.)*

Design intent: the PC is the "puzzle box" — deep enough to reward careful reading.

## 6. Keys & the secret folder

The central puzzle system, modeled on *Welcome to the Game* (the player **reads
and spots** codes; they are **not** auto-collected into an inventory).

### 6.1 What a key is
A **key** is a short alphanumeric **code with an index**, e.g. `1- A9SC`.
Baseline (tunable per run):
- **4 characters** per code, uppercase letters + digits (`A–Z`, `0–9`).
- **3–5 keys** per run.
- Each key "belongs" to a row (its index: `1-`, `2-`, …).

### 6.2 Where keys hide
A run scatters the keys across the OS. A key can appear as:
- **hidden inside an image** — a code that lives in an author-made photo but isn't
  plainly visible; the player reveals it by **adjusting the image** (brightness /
  contrast / saturation / levels) in the image tool,
- **in a web page** — either in its **visible text** (easy to skim past) *or* in the
  **HTML source** (a comment/attribute, found via the Browser's *Inspect element*);
  which of the two — and which site — is **chosen at random per run** from a pool of
  authored sites,
- **as the name of a folder** in the file system,
- **inside a `.txt` or `.cfg` file's content**.

**Changed 2026-10-18 (owner):** the four keys are no longer one per technique. Key
**1** is the **disk** key — *either* a file's content *or* a folder's name, drawn at
random each run; keys **2 and 3** are **web** keys on two **different** sites, each
randomly in the visible text or the HTML source; key **4** is the **image**. A key never
sits inside a binary (.EXE/.SYS/.COM): the file carrier is always a readable `.txt`.
The paragraph below describes the first version.

**Implemented (M1 + M3):** four keys, **one per technique** — a **file**'s content, a
**folder name**, a **web** page (visible text *or* HTML source), and a **photo**. Their
exact spot is **randomized per run** by the seeded generator (`OSContent`): the file
key lands in a random carrier file in a random folder, the folder key in a random
"backup"-style folder, the web key on a random site (randomly in the visible text or an
HTML comment), and the **image key** in one of the run's photos — visible only after
the player adjusts that photo in the image viewer. Each code is still shown **with its
index prefix** (e.g. `2-7MC9`), so spotting it also tells you which row it belongs to.

### 6.3 The secret folder (win condition)
A special password-protected node in the VFS. Opening it shows an **entry panel:
one input row per key**, with **no on-screen labels**:

```
[ A9SC ]
[ ____ ]
[ ____ ]
```

The player types each found code (just the **bare code**) into the **right row**,
which they deduce from the prefix they saw in the content (`2-…` → 2nd row). When
**every row matches** the run's keys, the folder unlocks → the **ending** triggers.
(Empty/partial input just stays locked.)

**Implemented (M1):** a glitchy **"ACCESSO NEGATO" modal**
(`desktop.open_secret_folder`) with one unlabelled field per key; the secret folder
node lives **on the Desktop**. The dialog **breaks down** (`SecretGlitch`, rebuilt
2026-10-17 to be "more real and scarier"): the failures of a PC of the era rather than
TV snow — tears that wrap, corrupted tiles, the trail of a hung Win95, a blood-red
palette — with a title that reads as if decoded wrong and, rarely, a line flashed for a
few frames (CAN YOU HEAR ME? / NO ONE ANSWERS / ARE YOU STILL THERE? — the 52-Hz-whale
seed). It twitches while you type, lashes out at a wrong entry, and fits come faster
the longer you stay. Mostly readable between fits; it never alters what you typed. Validation is row-bound
(`GameManager.check_keys`: each bare code must be in the correct row). A full
correct entry emits `game_won` → the room fades to a "SEI FUGGITO" screen → menu.

### 6.4 Decided vs. still open
Decided (and implemented in M1):
- keys are **typed in** (not collected); the password **is** the set of codes
  entered into the rows; codes are short fixed-length alphanumerics.
- **No on-screen row labels** (the GDD "hard mode"): the player types only the
  bare code and must deduce the **right row** from the prefix shown in the content
  (`2-…` → 2nd row). Validation is row-bound.
- **Baseline:** 4 keys × 4 chars, charset `A–Z`/`0–9` minus ambiguous glyphs
  (no `O/0`, `I/1`).
- **Look:** a "broken/glitched" `ACCESSO NEGATO` dialog (`SecretGlitch`, bursts),
  kept visually distinct from the full-screen threat warning.
- **Wrong/partial entry:** silent reject (no penalty yet — threats aren't built).

Still open (easy to change later):
- Exact **count** and **length** per run / difficulty tuning.
- An **easier mode** that shows the `1-`/`2-` row labels again, if play-testing
  finds deducing the order too cryptic.
- A **penalty on a wrong full entry** (a bump in threat level) once the threat
  systems exist (M4–M5). A purely *visual* reaction is in (the rejection fit); a
  gameplay cost is still undecided.

## 7. Threats (enemies, jumpscares, glitches)

The **enemies** (the things that threaten you) are still to be built. The
**lose flow** they will trigger is done (M2): `GameManager.game_over(cause)` →
a placeholder **jumpscare** (`scripts/death_screen.gd`: red flash + drawn face +
glitch + shake) → a **GAME OVER screen** with a subtitle (random for now;
`_pick_subtitle(cause)` is the hook so it can vary **per ghost/character** later)
→ main menu. For testing, a DEV-ONLY **F10** triggers it. The vision for the
threats themselves:

### 7.1 Room enemies
Threats that build while you investigate; each has its own counter, so vigilance means
checking different directions. Decided by the owner on 2026-10-19; **models and animations
are placeholders**, replaced last, after the gameplay.

- **Jester** *(called Clown until 2026-10-19)* — **peeks** from one of the three doors of
  the **corridor (right)** or from the **window (left)**. He is dark: only the torch shows
  him. **Hold the torch on him** and he slides away in **1–2 seconds** (random every time);
  stop too early and he comes back out. Ignore him too long → death.
- **HaloMan** — the Jester's counterpart: same spots, but a light of his own (a halo) makes
  him visible in the dark — and that is the point: **pointing the torch at him kills you**.
  Tell him from the Jester before you light anything, then **switch the PC off** (case
  button / Start ▸ Shut down) to send him away. He only comes while the PC is on.
  **Never at the same time as the Jester.**
- **Ghosty** *(working name)* — strikes only from **behind**. The longer you do not look
  back (or sit inside the PC), the closer he gets; **looking at him freezes him**, and **the
  torch makes him vanish** at once. Inside the PC a light sign gives him away: the screen's
  edges cool and darken as he closes in.

**Fairness rules:** Jester and HaloMan share one peek slot, and after each peek there is a
guaranteed calm; nobody peeks during the lethal PC virus, and Ghosty does not strike while
someone is peeking or during that virus — he waits one step away. Two lethal threats in the
same instant are a lottery, not tension.

The **flashlight** (§5.1) is **held**: on while you keep the button pressed, with a battery
that drains while lit and recharges while off.

Each enemy calls `GameManager.game_over(<id>)` on failure (`"jester"`, `"halo"`,
`"ghosty"`); the `cause` selects that enemy's GAME OVER subtitles.

### 7.2 PC threats (the machine turns hostile)
A presence inside the OS — some lethal, some just harassment:

- **Shutdown-or-die virus** — a warning appears; if you don't **power off the PC**
  in time → game over. (Tension: powering off interrupts your investigation.)
- **"YouAreStupid"** — spam-opens windows/dialogs that crowd the screen and get in
  the way (annoyance + obscures clues, not instant death).
- **Crashes / BSOD** — sudden fake **blue screens** that disorient and interrupt.
- *(General)* self-opening windows, corrupted files/text, a "hunting" cursor.

Mishandling a lethal one → jumpscare on the PC view → game over.

*Built 2026-10-18 (M5).* The owner's brief: PC enemies "should not be too invasive"; the
lethal one must be something that, **once you see it, you understand you must switch the
PC off**. As built (`scripts/threats/virus_director.gd`):
- **Pacing** — rare, one at a time: the first after ~3 minutes of PC switched on, then one
  every 2-4 minutes, never the same twice in a row, only while the player is inside the PC
  (they must see it begin), never over a dialog (the secret folder included) and never while
  the Jester is peeking (and the Jester waits during the lethal one).
- **The lethal virus is an apparition that stays** (owner, 2026-10-18 — ONE phase, one
  rule). An apparition appears; *if it vanishes in a moment it was a false alarm, if it
  stays it is real* and the PC must be switched off within 10 s (Start ▸ Shut down or the
  case button), or `game_over("virus")`. The same apparitions come alone as **false
  alarms** every 3-5 minutes, gone after 2-2.5 s. Real and false start identical, so the
  only way to know is to watch — and both mistakes cost: switching off for nothing means a
  reboot and every window lost, waiting too long means death. A real one never turns into
  something else; it only grows slowly.
  - **Small** ones, only in the wallpaper or the clock: **the child with
    the noose** (§2b) hanging near the edge of the wallpaper, a boy made of small **black
    ASCII characters**, detailed like a drawing — darker hair and shorts, lighter skin, shading
    from one side, lines where the clothes end, a few folds — straight on the wallpaper
    (owner, 2026-10-19: the curse shows itself with the PC's own characters; no halo); two **realistic eyes**
    made of characters — lids, lashes, iris, pupil, highlight — whose iris follows the
    cursor; the taskbar clock going wrong (backwards, 03:33); a line of the curse that
    **types itself** on the wallpaper like a terminal line ("i can see you", "she won't come
    back tonight").
  - **Grave** ones, same rule: the **whole screen goes dark** — Start menu and dialogs included —
    **and flickers like a dying light bulb**: mostly steady, now and then a burst of short drops
    or a long drop almost to black that slowly recovers, never brighter than usual (owner,
    2026-10-19 — it used to darken only the wallpaper; never more than 3 drops a second); blood dripping over the windows (a wavy rim along the top,
    drips of different length running in viscous surges, each swelling into an elongated
    drop at the tip — never a round ball —, now and then a drop falling with a trail); the
    windows shaking.
  - Rejected on the way, so they do not come back: the whole screen flashing red (the
    owner did not like it at all), a quiet phase escalating into a red
    phase ("tutto un'unica fase"), and a version that blacked out the screen around a
    cursor light, renamed icons and hung the child over the windows ("troppo invasivi").
- **YouAreStupid**: a burst of small smiley windows ("YOU ARE STUPID", English in every
  language), some bouncing around, that multiply when closed; capped so it always ends.
  Annoyance only — but it **cannot be ignored**: the windows stay on top of everything, cannot
  be minimized (the button is there but greyed out), steal the keyboard, and more keep arriving while any is
  left open.
- **Blue screen**: Win95's text-mode crash. Nothing to press: after a 5-second countdown
  the PC restarts by itself — a moment of black, the BIOS, the boot and the login again, and
  every open window is lost. A crash is something you suffer, while the room keeps going.

### 7.3 Glitches
Visual/audio corruption driven through the **CRT shader** and the OS:
flicker, rolling scanlines, color tears, frozen frames, wrong text. Glitches
serve double duty — **atmosphere** and **mechanic** (a glitch can be a warning
that a threat is escalating, or can hide/reveal a clue).

## 8. Per-run randomization

Every new game should feel different and prevent memorized solutions:
- Which files exist, their names, and their contents. *(Done: the key carrier file
  varies in name/content/folder; filler is fixed.)*
- Which **websites** exist — **10 to 15** drawn from a catalog of about **30 authored
  sites**, **4 or 5 of them carrying lore** (owner, 2026-10-19; the list:
  [WEB_CATALOG.md](WEB_CATALOG.md)) — and, for the two key-bearing pages, **whether the
  code sits in the visible text or in the HTML source**. *(The engine is done; the sites
  are being written in batches — RetroForum and the young man's page are the first two.)*
- Which **images** exist — a random set of photos — and which one hides a code
  (revealed by adjusting its levels). *(Done — M3 part 3; photos are procedural
  placeholders, an authored pool can replace them.)*
- Where the **keys** are placed and **what the keys are**. *(Done.)*
- (Optional) threat timings/behaviors.

This is implemented as **data-driven content** + a **seeded generator** in
`OSContent` (the VFS template and the site pool are data; the run seed drives site
selection, the generated photos, and key placement across file / folder / web /
image). The only stand-in is the **art**: the photos are procedural placeholders for
an authored pool. See Roadmap and [ARCHITECTURE §4.2b](ARCHITECTURE.md).

## 9. Aesthetic direction

- **Visual:** Win95/98 chrome (gray bevels, teal desktop, navy title bars),
  drawn procedurally (see `os_icon.gd`, `win95.gd`). CRT shader on the PC view.
  Dim, warm room lighting (desk lamp) with cold fill light.
- **Audio (planned):** CRT hum, key clicks, dial-up, HDD chatter; stingers for
  jumpscares; a low drone that tracks threat level. (The "52-Hz Whale" boot logo
  — the world's loneliest whale — is a thematic seed: isolation, a signal no one
  answers.)
- **Text:** player-facing strings are **localized** (see §10); code comments stay
  Italian. The in-world flavor is authored per language, so it reads naturally in
  each shipped language rather than as a translation of the other.

## 10. Localization (languages)

The game is **multilingual**: **English is the base/source language**, with
**Italian** as the first translation. Built on Godot's localization (`tr()` +
translation files, `TranslationServer.set_locale()`).

**Done** — both layers go through translation keys:
- **UI chrome** (main menu, taskbar and Start menu, boot and login, dialogs,
  Notepad / Explorer / Image viewer, the whole browser chrome, pause and death
  screens): keys in **`locale/ui.csv`** (`keys,en,it`), which Godot imports into
  the `.translation` files the game loads.
- **In-world content** (folder and file names, file text, the photo's file
  comment, site names and descriptions, the generated gateway, the sentence that
  carries the web key): the same table. The **authored web pages** are one file
  per language — `web/pages/en/*.html`, `web/pages/it/*.html` — because a page is
  a piece of writing, not a string: the language changes its layout, its length
  and its jokes.

`GameManager.set_lingua()` is the single entry point (`LINGUA_BASE = "en"`,
`LINGUE = ["en", "it"]`) and the game **forces** the base language at startup
instead of following the operating system's.

The player picks the language in **Options** (main menu → Options), which holds that
one setting today: a button per language labelled with its own name, and the choice is
**remembered** between sessions (`user://impostazioni.cfg`). It is deliberately
reachable only from the menu, not mid-run: the in-world text is generated when a run
starts, so switching language in the middle would leave the PC in the old one.

Comments inside the fake HTML *source* are deliberately left in English in every
language: that is how period code read everywhere, and the player finds them in
*view source*.

## 11. Out of scope (for now)

- Multiplayer, walking/free movement in the room, save slots / mid-run saves,
  controller support. Revisit after the core loop is fun.

---

*Design status: living document. Update this when a system moves from "vision"
to "implemented", and mirror the change in [ROADMAP.md](ROADMAP.md) and
[CLAUDE.md](../CLAUDE.md) §6.*
