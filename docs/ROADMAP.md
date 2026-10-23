# Roadmap — what to build, in order

A suggested build order from the current prototype to a playable vertical slice.
Each milestone is small enough to finish and test before the next. Check items
off as you go and keep [CLAUDE.md](../CLAUDE.md) §6 ("Current state") in sync.

Legend: `[ ]` todo · `[~]` partially there · `[x]` done.

---

## Milestone 0 — Foundations & cleanup (do first)
Make the codebase ready for the new systems.

- [x] **Run lifecycle in `GameManager`.** `start_new_run(new_seed)` stores the
  seed + RNG and resets PC state in one place; `game_over()` / `restart()` are
  hooks (restart re-runs a fresh seed). Called from the menu's Start.
- [x] **Make the VFS per-run, not static.** Added `VFS.build_run(seed)`, called by
  `start_new_run`, which rebuilds `_root` from scratch each run (fresh files +
  empty Trash). Kept the static API so call-sites are untouched; the seed param
  is the hook for randomization (M3).
- [x] **Session persistence — cut.** Decided to drop it: removed the dead
  `pc_session` / `pc_screenshot` / `returning_from_pc` fields and the apps'
  `get_session()` / `restore_session()`. The OS just keeps running while away.
- [x] **Retire the legacy PC.** Deleted the dead `computer_mode.gd`. Kept
  `ComputerMode.tscn` (it already loads `desktop.gd`) as a dev-only OS harness,
  documented as such in CLAUDE.md.

## Milestone 1 — Keys & the secret folder (the win condition)
The smallest thing that makes it a *game*. Design is fixed in [GDD §6](GDD.md#6-keys--the-secret-folder):
keys are short indexed codes (e.g. `1- A9SC`) the player **reads** and then
**types** into a grid; no auto-collected inventory.

- [x] **Define the "key" data type.** `{ index:int, code:String }`, baseline
  `KEY_COUNT=4` × `KEY_LEN=4`, charset `A–Z`/`0–9` minus ambiguous glyphs
  (no `O/0`, `I/1`). Generated with the seeded `rng` in `start_new_run`, stored on
  `GameManager.keys`.
- [x] **Place keys in OS content.** Codes are hidden **with their index prefix**
  (`1-Q9FY`, via `key_label`). 4 techniques, one key each: a `.txt`
  (`Sistema/seriale.txt`), a **folder name** (`Backup <label>`), a Browser page's
  visible text, and a Browser page's HTML (source only). Both land on one of the
  run's sites, at a position drawn from the seed (see `web_anchor.gd`); the old
  fixed `blog.io` / `news.com` are gone. Pages rebuild per run via
  `BrowserApp.reset_pages()`.
  (Image-hidden key deferred to M3.)
- [x] **The secret folder node.** VFS `type:"secret"` node ("Cartella protetta")
  **on the Desktop** (non-deletable); opening it (desktop or explorer) calls
  `desktop.open_secret_folder`, a glitchy **"ACCESSO NEGATO" modal** (reusing
  `_make_modal`) with one **unlabelled** field per row, distorted by
  `glitch.gdshader` in short bursts (M5 groundwork).
- [x] **Validation + unlock.** The player types only the **bare code** into its
  row, deduced from the prefix found in the content (no on-screen labels — the
  GDD §6.4 "hard mode"); `GameManager.check_keys` is **row-bound** — the code must
  be in the correct row. Full match → `game_won`. Wrong/partial → silent reject.
- [x] **Ending screen.** Chosen room-side: `player.gd` catches `game_won`, fades to
  a fullscreen "SEI FUGGITO" overlay with a **Torna al menu** button → main menu.
- [ ] *(Optional, skipped)* in-game notes — player types codes as found.

## Milestone 2 — Game over & restart (the lose condition)
You can win; now you must be able to lose.

- [x] **Jumpscare system.** Reusable overlay `scripts/death_screen.gd` (a
  `CanvasLayer` at root → fires over the room **and** the PC view). Procedural
  placeholder: red flash + drawn face + `glitch.gdshader` + screen shake (~1.2 s);
  audio stinger is a TODO (M6). Hooked to `GameManager.game_over(cause)` (single
  guarded entry point); a **DEV-ONLY F10** triggers it for testing until M4.
- [x] **Game-over flow.** jumpscare → **GAME OVER screen** (random placeholder
  subtitle; `_pick_subtitle(cause)` is the hook for per-ghost lines later) →
  **main menu** (owner's choice over a direct fresh run). `restart()` (→
  `start_new_run`) is kept as a hook for M4 / a future "Retry".

## Milestone 3 — Content randomization
Make every run different (prevents memorized solutions).

- [x] **Data-driven content.** Done: the hardcoded VFS (`vfs.gd::_build`) and
  Browser pages (`app_browser.gd::_pages`) now live as authored **data** in a new
  content library, `scripts/os/content.gd` (`OSContent`). `vfs.gd` and
  `app_browser.gd` are pure consumers (`OSContent.build_filesystem()` /
  `OSContent.build_sites()`). Keys are injected via `{{KEYn}}` placeholders
  (`_apply_keys`) so the authored text carries no codes. The sites are an **authored
  pool** (8 sites today, more than a run needs) and the home page is **generated**
  from the run's sites. *Still fixed:* every pool site is included and key slots are
  fixed — the seeded **selection** of ~5 sites and **random** key placement is the
  next bullet.
- [x] **Seeded generator.** Done (sites + key placement; images are the next
  bullet). `OSContent` now generates content from the run seed: `build_sites()` picks
  **~5 sites** (`SITE_COUNT`) from the 8-pool *(superseded 2026-10-19: 10-15 sites from the
  site catalog, see the web bullet below)*, prunes inter-site links to non-selected
  sites (no dead 404s) and drops the **2 web keys** into 2 distinct random sites, each
  randomly in **visible text** (a `<p>`) or the **HTML source** (a `comment`), from
  carrier templates; `build_filesystem()` drops the **file key** into a random carrier
  file (random name/text) in a random folder and the **folder-name key** into a
  random "backup" folder. Each build seeds its **own** `RandomNumberGenerator` from
  `run_seed` (+ a salt), so it's reproducible **and order-independent** (the browser
  builds pages lazily). The index→category map is fixed (1=file, 2=folder, 3/4=web)
  so VFS and sites place their own keys without coordinating. *Images still pending.*
- [x] **Image viewer + image-adjustment puzzle.** Done. `ImageViewerApp`
  (`app_image_viewer.gd`) opens the run's photos and adjusts them live via
  `adjust.gdshader` (brightness / contrast / saturation / black & white levels)
  driven by sliders. The `Immagini` folder holds 3–4 generated photos
  (`OSContent.make_photo`: tinted, vignetted, grainy fields); **one** hides the
  **image key** (key 4) as a low-contrast `Label` sharing the photo's material — so
  it's invisible until the player adjusts the image. Photos are **procedural
  placeholders** for now (an authored Photoshop pool can drop in later). With this,
  the 4 keys are one per technique: file / folder name / web / image.
  **Changed 2026-10-18 (owner):** key 1 = file OR folder (50/50), keys 2-3 = web on two
  different sites, key 4 = image.
- [x] **The web: real sites** (owner, 2026-10-19). A site is a folder of pages
  (`web/pages/<lang>/<site>/`) listed in the site catalog (`scripts/os/catalogo_siti.gd`);
  each run picks 10-15 of them, 4-5 with lore; the web keys land on any page of two
  sites of the run; a site not in the run answers "cannot find server". **Done:** all 30
  sites written (2026-10-20); 34 since 2026-10-23 (four lore sites added, the young man
  reduced to one site of his own, nickname ~missedtrain) — see [WEB_CATALOG.md](WEB_CATALOG.md).
- [~] **Web variety** (owner, 2026-10-23: "most sites are very similar, if not identical").
  **Done:** the engine (animated GIFs, MIDI music with a synth, tiled backgrounds, side-bar
  columns, Times and Comic faces, marquee/blink, `&nbsp;` ASCII art), the placeholder media
  (`tools/web/media.py`), the PC speakers (tray volume/mute, sound that comes from the desk
  in the room), six pilot sites restyled and four new sites each with its own look; since
  2026-10-24 ALL sites are restyled (the last twenty: ordinary ones by web-writer, lore ones
  by a script that touched only header/nav, fonts, colours and container), plus the narrow-table
  and `<hr>`-in-cell fixes in the compiler. **Next:** the owner's review of the sites; the owner
  will also rewrite or replace some sites himself. **Later:** simplifying what "view source" shows, to
  help the player spot the key (owner: "vedremo dopo"); real art and music replacing the
  placeholders (same file names).

## Milestone 4 — The room threat (FNAF layer)
The reason you can't just read in peace. Enemies & layout per GDD §5.1 / §7.1.
Built as a **vertical slice first**, then rebuilt on 2026-10-19 with the owner's three
enemies (see `threat_director.gd` in CLAUDE.md and GDD §7.1). **Design note:** the door
enemies do **not** advance — they **peek** from a spot in a **zone** (right = corridor,
left = window); Ghosty comes from behind on a clock of his own.

- [x] **Room layout (starter).** The corridor (`scenes/corridor.tscn`, three doors in
  **`enemy_spots`**) and the **left window** (`scenes/window_left.tscn`; the wall is a CSG
  box with the opening cut, `SpotFinestra` in `enemy_spots` + `spot_left`). Ghosty's path is
  two markers in `main.tscn` (`ghosty_lontano`, `ghosty_vicino`). Plain geometry: refine or
  replace in the editor.
- [x] **Jester.** Peeks from a door or the window; **hold the torch** on him 1–2 s (random)
  to send him away; else → `game_over("jester")`.
- [x] **HaloMan.** Same spots, never with the Jester, only with the PC on; **lighting him
  kills you** — **switch the PC off**; else → `game_over("halo")`.
- [x] **Ghosty** *(working name).* From behind: approaches while unwatched, freezes when
  watched, vanishes in the torch light; light tell inside the PC; else → `game_over("ghosty")`.
- [x] **Flashlight.** **Held** (press = on, release = off), a real beam that follows the
  view, a battery that drains while lit and recharges while off (HUD bar). **Still TODO:**
  SFX.
- [ ] **Real models and animations** for the three enemies (placeholders today) — LAST.
- [~] **Attention mechanic & pacing.** Framework in `scripts/threats/threat_director.gd`
  (runs always, even inside the PC): pacing `GRACE → WAIT → PEEK → CALM` (one peek slot
  for Jester and HaloMan; Ghosty on his own clock). **After
  every check there's a guaranteed `CALM` window** (`CALM_TIME` ≈ 25 s) with no peeks, so
  you can investigate. A **`_heat`** value (0..1) rises **slowly** in the PC and decays
  watching the room, gently shifting the interval (`INTERVAL_CALM`↔`INTERVAL_HOT`) and
  reaction window (`REACT_CALM`↔`REACT_HOT`). Spawn spot is random per peek (`_choose_spot`,
  no repeat). **Repel:** hold the light on the Jester, switch the PC off for HaloMan, light
  Ghosty from behind (see above). A **tell** (a `glitch.gdshader` pulse on
  the PC overlay, scaling with heat) warns you while inside the PC; failure →
  `game_over(<id>)` (subtitle keys off `cause`).
  (DEV-ONLY F10 stays until all triggers are wired.) *Note:* "keys found" can't drive
  aggression — keys aren't collected (read + typed at the end) — so **time-in-PC** is the
  exposure signal.

## Milestone 5 — The PC entity & glitches
Threat *inside* the machine + atmosphere. Viruses per GDD §7.2.

- [ ] **Glitch driver.** Animate `crt.gdshader` / `glitch.gdshader` params and OS
  visuals (flicker, tears, frozen frames, corrupted text). Expose a `glitch(level)`
  entry point. (Foundation already exists in `glitch.gdshader`.)
- [x] **Shutdown-or-die virus.** (2026-10-18, `virus_mortale.gd` + `apparizione.gd`) One
  phase: an **apparition** (five small ones in the wallpaper or clock, three grave ones:
  blood, shaking windows) that **stays** — power off within 10 s (Start >
  Shut down or the case) or → `game_over("virus")`. The same apparitions come alone as
  **false alarms**, gone after 2-2.5 s.
- [x] **"YouAreStupid" virus.** (2026-10-18, `virus_stupido.gd`) A burst of bouncing
  smiley windows that multiply when closed, capped (9 open, 16 in all) so it always ends.
- [x] **Crashes / BSOD.** (2026-10-18, `schermo_blu.gd`) A text-mode blue screen; after a
  5-second countdown the PC reboots by itself (black, BIOS, boot, login).
- Pacing for all three: `scripts/threats/virus_director.gd` — rare, one at a time, only
  while the player is inside the PC. Test: `tests/virus_test.tscn`.
- [ ] **PC entity behaviors.** Self-opening windows, corrupted files, cursor
  "hunting", messages — escalating to a PC jumpscare.
- [ ] **Glitch-as-clue (optional).** Let a glitch momentarily reveal/conceal a
  key, marrying horror to puzzle.

## Milestone 6 — Audio & polish
- [ ] **Audio pass:** CRT hum, key clicks, dial-up, HDD chatter, drone that
  tracks threat level, jumpscare stingers. (The only audio today is the web pages' music,
  2026-10-23, through the "PC" bus of `scripts/os/audio_pc.gd`: PC sounds should use that
  bus too, so the tray mute and the room positioning apply to them.)
- [~] **Menu/options:** the Options screen **exists** (`scripts/options_screen.gd`,
  opened by the main menu) and holds the **language selector**. Still missing:
  volume, maybe mouse sensitivity, and whatever else settles as a setting —
  `options_screen.gd::_riga()` adds a row of them.
- [x] **Localization (EN base + IT)** — *done ahead of this milestone
  (2026-09-19).* Every player-facing string is a translation key in
  **`locale/ui.csv`** (`keys,en,it`), UI chrome *and* in-world content (file and
  folder names, file text, site names, the generated gateway, the web-key
  sentence). The authored web pages are one file per language
  (`web/pages/<lang>/*.html`). `GameManager.set_lingua()` switches, `LINGUA_BASE`
  is `en` and is forced at startup instead of following the OS.
  See [GDD §10](GDD.md#10-localization-languages).
- [x] **Language selector + persistence** — *done 2026-09-19.* Options shows one
  button per language (its own endonym, the active one framed); the choice goes to
  `user://impostazioni.cfg` and is reloaded at startup, and the menu re-translates
  immediately. Only reachable from the menu, since in-world text is generated when
  the run starts. Adding a third language is documented in
  [WEB_SITES.md](WEB_SITES.md) §3 ("Add a language").
- [ ] **Onboarding:** a light intro so a new player understands the loop.

---

## Cross-cutting reminders
- Build OS UI **in code**, reuse `Win95` styling, add icons in `os_icon.gd`
  (see [CLAUDE.md](../CLAUDE.md) §5).
- Reference VFS locations by `VFS.path_of()`, never by holding `_parent`.
- After each milestone: validate headlessly (`--import`, run `main.tscn` a few
  frames) and update the "Current state" list in CLAUDE.md.
