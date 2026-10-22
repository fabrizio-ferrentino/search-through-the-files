# Core: run state, room, menus, overlays, debug panel, CRT

Read before touching GameManager, player.gd (the room), the menus, the pause/death screens, the F12 debug panel, the CRT shader or the translation table.

Moved here from CLAUDE.md on 2026-10-22, word for word (CLAUDE.md now keeps only a one-line map).

## Files

### `project.godot`

Engine config. Autoload: GameManager. Input action: "pause".
[internationalization]: the two .translation files + fallback "en".

### `locale/ui.csv`

THE TRANSLATION TABLE (keys,en,it): every player-facing string,
UI chrome AND in-world content (file/folder names, file text,
site names, the gateway's words, the web-key sentence). Godot
imports it into ui.en.translation / ui.it.translation - after
editing it, run --import or the game keeps the old strings.
Quote a cell that contains a comma; a line break is the two
characters \n (read back with c_unescape, see OSContent._testo).

### `scenes/main_menu.tscn`

Start screen (this is the main scene).

### `scenes/main.tscn`

The 3D room. Camera3D runs player.gd.

### `scenes/ComputerMode.tscn`

DEV-ONLY harness: runs the OS (desktop.gd) in a CRT
SubViewport without the 3D room. Not in the live flow.

### `scenes/fade_transition.tscn`

Reusable black ColorRect + AnimationPlayer (fade_in / fade_out).

### `scripts/GameManager.gd`

Autoload. Global run state + run lifecycle
(start_new_run / game_over / restart) + the LANGUAGE:
LINGUA_BASE "en", LINGUE ["en","it"], NOMI_LINGUA (the endonyms,
deliberately NOT in the CSV). _ready() loads the saved choice
(user://impostazioni.cfg) or falls back to English - it never
follows the OS locale, which here would start the game in it_IT.
set_lingua(codice, salva := true) is the one entry point; the
TESTS pass salva=false, because a test must not rewrite the
language of whoever plays.

### `scripts/player.gd`

Camera3D: look-around, raycast clicks (incl. torch door-clicks),
enter/exit PC, monitor quad, and the room's WorldEnvironment
darkness (_setup_atmosphere: clean dark, NO fog — FNAF4 style;
@export "Buio" group).
ESC inside the PC leaves for the room EXCEPT when the OS wants it
(_os.trattiene_esc(): a rename in progress, or a closable dialog
such as the About) - then it is forwarded instead. Before
2026-10-18 ESC ALWAYS left, so the OS never saw it: "ESC closes
the About" only ever worked in the tests, which push keys straight
into the SubViewport.

### `scripts/main_menu.gd`

Menu buttons + fade to the room. _etichette() assigns the
three button labels from tr() (UI_START/UI_OPTIONS/UI_QUIT):
the buttons live in the SCENE (authored by the owner), so the
text is set in code and the scene is left alone. It is called
again on the options screen's "lingua_cambiata", or the menu
would stay in the language it was built in.
"Options" opens options_screen.gd (one screen at a time).

### `scripts/options_screen.gd`

OPTIONS overlay (2026-09-19): a CanvasLayer built in code like
the other overlays, spawned by main_menu.gd. Holds ONE setting,
the LANGUAGE: a toggle button per GameManager.LINGUE showing the
ENDONYM ("Italiano", not "Italian" - in a language list each one
is written in itself, or you cannot find yours). Which one is
active is drawn BY HAND (text colour + frame, all states): the
default theme's pressed state only darkens the button a shade,
and in the first screenshot the chosen one had lost even its
frame. Solid black background for the same reason pause_screen
uses one - through a translucent veil the menu's own buttons
showed through and it read as a drawing defect. Language is
changed only HERE, i.e. from the menu: the in-world text (file
names, web pages) is generated when the run starts, so changing
it mid-game would not rewrite the PC. _riga() is there so the
screen can grow (volume, sensitivity - M6).
Test: options_test.tscn.

### `scripts/crosshair.gd`

Draws the center dot.

### `scripts/debug_panel.gd`

DebugPanel (DEV-ONLY, 2026-10-18): the F12 DEBUG PANEL, a CanvasLayer
on the root (layer 30) built in code by GameManager.toggle_keys_panel.
It used to be one label with the keys; the owner could not trigger
every threat on demand ("non riesco a ricreare tutti i bug": F9 only
cycles the three viruses and the lethal one picks its apparition at
random), so now it has BUTTONS: every apparition as REAL (lethal) or
FALSE (false alarm), lethal-random / YouAreStupid / blue screen, Stop
current, "next virus / false alarm: no wait" (the natural path, with
its normal conditions), Jester / HaloMan peek now, "Peek: send away", Ghosty come
now / go away (2026-10-19), both threat
switches, Die, Boot to desktop (OSDesktop.salta_al_desktop: no boot,
no password) and Power off. WEB (2026-10-20, owner: "fai in modo che
io li possa vedere tutti"): "All sites: ON/OFF" flips
GameManager.debug_tutti_i_siti - WebRuntime.raggiungibili() then
returns the WHOLE catalog, so every site answers and the portal lists
them all (the ones not in tonight's run marked "[DEBUG: not in
tonight's run]"); the keys stay on the sites the seed picked - and
"Open the portal" opens a browser on it. The browser tests switch it
on too, because they open fixed pages and a run picks 10-15 of 30.
A STATUS block rewritten 4x a second:
PC state and where the player is, the peek state (who, GRACE/WAIT/PEEK, light
progress or PC state, with seconds), Ghosty's distance, heat, torch
state and battery, the PC virus running and the
countdowns, and WHY a virus cannot start now (VirusDirector.
perche_no). The last button's outcome is printed in green/red
("refused: PC threats are OFF (F8)"). "-" collapses it to the keys
(GameManager.debug_compatto, kept across F12). It finds the directors
by GROUP ("regista_stanza", "regista_virus"), not by current scene.
Two input rules: player.gd does NOT pass a mouse event over the panel
to the room or the PC (GameManager.debug_sotto_mouse; releases still
pass, or a drag started in the OS would stay "held") - without it a
click on a button also clicked the desktop under it; and every button
is FOCUS_NONE, or a space typed in Notepad would press the last one.
The directors' side: VirusDirector.forza_debug / ferma_debug /
azzera_attesa / stato_debug, ThreatDirector.forza_affaccio /
allontana / stato_debug. All text English (see §6, DEV-ONLY keys).

### `scripts/nav_arrow.gd`

Room look-around arrows: a big semi-transparent rectangle
OUTLINE (hollow) with a centred chevron; brighter on hover.
The rect is the hover hotzone (player.gd, which re-arms
with hysteresis so jitter won't re-trigger).

### `scripts/death_screen.gd`

Game-over overlay (M2): jumpscare → GAME OVER screen → menu.
Built in code; spawned at root by GameManager.game_over().
Per-cause subtitles (M4: Jester lines when cause=="jester";
M5: DEATH_VIRUS_* when cause=="virus").

### `scripts/pause_screen.gd`

PAUSE overlay: black screen, "GIOCO IN PAUSA", Riprendi /
Torna al menu / Chiudi il gioco. Built in code, spawned at ROOT
by player._pausa() so it covers the room AND the PC view;
PROCESS_MODE_ALWAYS + get_tree().paused (so it keeps running
while everything else is frozen - which is also why the resume
key is read HERE: a paused player.gd gets no input). The trigger
is the "pause" action (P) in player._input, placed BEFORE the
in-PC branch (which forwards every key to the OS and returns)
and suppressed while OSDesktop.typing() is true - inside the PC
"p" is a LETTER (Notepad, address bar, the key dialog whose codes
can contain P), not a command. Layers: PC view 10, win 20, debug
panel 30, death 50, pause 60. Test: pause_test.tscn.

### `scripts/os/crt.gdshader`

Flat CRT effect (scanlines, RGB mask, aberration, vignette,
rounded corners + bezel shadow). FLAT ON PURPOSE: curvature moves
pixels, and the mouse is forwarded to the OS in a straight line,
so it would no longer land where it is seen - everything in it
changes a pixel's LIGHT, never its position.
TWO UNITS (rewritten 2026-10-17): what sits ON THE GLASS
(scanlines, phosphor mask) is counted in REAL screen pixels
(FRAGCOORD) with an INTEGER period = round(height / 360), never
under 2; what sits IN THE IMAGE (convergence, corners, bezel
shadow) in OS pixels. The scanlines used to be counted in OS
pixels (uv.y * 1080), and the OS never reaches the screen 1:1:
in the default 1280x720 window the intended period was 1.33 px
and what got drawn was 4 (180 fat lines instead of 540 thin
ones), and at 1886x1061 the per-row swing beat between 0.005 and
0.085 - moire bands rolling across the desktop (43% variation,
now 1%). On bright pixels the beam widens (scanline_chiaro), so
white pages are not striped under black text.
TRIED AND REMOVED, measured with tests/crt_look_check: HALATION
(black text on white 0.792 -> 0.740: the white bleeds into the
letters, i.e. exactly where the keys are read - Notepad, web
pages) and CONVERGENCE GROWING TOWARD THE EDGES (black on grey
menu 0.589 -> 0.572: it smears the dark letters right in the
corners where menus and title bars sit). No noise and no rolling
band either: those belong to TVs and cameras, not to a VGA
monitor, and an image that moves by itself would make the tests'
two-frame comparisons unreliable. Readability after the rewrite,
1280x720 then 1886x1061 (old -> new): white on blue 0.607 ->
0.648 / 0.616 -> 0.625, black on white 0.792 -> 0.799 / 0.798 ->
0.813, black on grey 0.589 -> 0.610 / 0.623 -> 0.621.
The photo key through it (photo_chain_test): 614 px on screen
(was 609), reveal core 123 levels (was 116), watermark at rest
13.5 levels (was 12.1 - the new CRT smears less).
Tune it live: open scenes/ComputerMode.tscn, whose TextureRect
carries the same shader, and move the sliders in the Inspector.

### `assets/fonts/`

Period fonts, SIL OFL 1.1 (see its README): Arimo = Arial clone
(OS chrome + page text), Cousine = Courier New clone (face="Courier
New"). Loaded via Win95.font(); add Tinos-*.ttf for a serif.

### `assets/textures/`

Wallpapers, the 3D models (computer, desk, lamp), the arrow sprite.

### `docs/`

GDD, architecture, roadmap, web authoring guide,
WEB_SITES.md (how the fake sites are wired: which file holds
which string, recipes to change/replace a site, and the trap
that period HTML splits words across tags -- searching for
"WEBNET" finds nothing because the file says WEB<b>NET</b>),
DISK_CONTENT.md (the recipe for the OWNER to add or change a file,
a user folder, a program or an extra folder on the random disk:
which CSV rows, which catalog line, the zones, the two rules),
WEB_CATALOG.md (the 30 sites and their rules) and docs/code/ (this
folder: the code, area by area). [2026-10-22: GLOSSARY.md was merged
into docs/code/README.md and the beginner's Claude Code guide removed.]

## Feature notes

- Main menu → room → fake OS flow.

- The room: look left/center/right/back, click the case to power on/off, click
  the screen to enter/exit the PC, animated camera "fly into the screen".

- **Pause** (`scripts/pause_screen.gd`): **P** freezes the tree and shows a black
  "GIOCO IN PAUSA" screen with Riprendi / Torna al menu / Chiudi il gioco; P or ESC resume.
  The `pause` action existed in `project.godot` from the start but nothing listened to it, so
  the key did nothing until 2026-09-16. It is deliberately inert while typing in the OS.

- CRT shader on the fullscreen PC view.

- **Game over & restart** (M2): `GameManager.game_over(cause)` is the single lose
  entry point (guarded against re-entry). It spawns `scripts/death_screen.gd` — a
  `CanvasLayer` added to `get_tree().root` so it covers the room **and** the PC view
  — which **pauses the tree** (`get_tree().paused`; the overlay is
  `PROCESS_MODE_ALWAYS` so it keeps running) to freeze the player and OS, then plays
  a procedural **jumpscare** (red flash + drawn face + `glitch.gdshader`
  + screen shake, ~1.2 s, no audio yet), then a **GAME OVER screen** with a random
  placeholder **subtitle** (hook: `_pick_subtitle(cause)` will pick per-ghost lines
  once enemies exist) and a "Torna al menu" button → main menu. **DEV-ONLY keys** (in
  `GameManager._input`, remove before release): **F12** = the DEBUG PANEL
  (`scripts/debug_panel.gd`) — one compact line per key (code, kind, where it is) plus the
  seed and the state of both threat switches, printed to the console and shown top-right
  above the room *and* the PC view (`keys_report()` / `toggle_keys_panel()`, fed by
  `note_key()` calls from the content builders), then a live STATUS (Jester, PC virus,
  countdowns, why a virus cannot start) and BUTTONS to trigger every apparition (real or
  false), every virus, the Jester's peek, the switches, boot-to-desktop and power-off; "-"
  shrinks it to the keys; **F11** = ROOM threats on/off (`room_threats_enabled`, read by the
  ThreatDirector); **F8** = PC threats on/off (`pc_threats_enabled`, read by the
  VirusDirector) - two switches since 2026-10-18 so one can be tried without the other;
  **F9** = start the next PC virus now (in `virus_director.gd`, not here); **F10** = forced
  `game_over("debug")` (remove when M4 wires real triggers).
  **ALL debug text is ENGLISH, whatever the game language** (owner, 2026-10-18): the panel,
  the `note_key()` notes written by content.gd / web_runtime.gd / web_anchor.gd, and every
  console line. It is not player-facing, so it never goes through the CSV. The names of
  in-game things inside a note (a file, a folder, a site) stay as the player sees them.
  A test that disables threats must now switch off BOTH flags.
  **F12/F10 only work while a run is in progress** (`run_active`, true from `start_new_run`
  until death or win). The panel lives on the *root* so it can cover the room and the PC
  view and survive a scene change — which is exactly why it used to keep showing the
  previous run's codes in the menu after dying. Now `finish_run()` (called by `game_over`
  and by `player._on_game_won`) closes it and disables the keys, and `start_new_run`
  refreshes it if left open, so it can never show stale data. Covered by
  `tests/debug_panel_test.tscn`. `restart()` (→ `start_new_run`) is kept as a hook but the
  lose flow goes to the menu.

- **Localization — English base + Italian** (2026-09-19, ahead of M6): every
  player-facing string is a key in **`locale/ui.csv`** (`keys,en,it`) — the main
  menu, the whole OS chrome (taskbar, Start menu, boot, login, dialogs, Notepad,
  Explorer, image viewer, the browser's menus and toolbar), the pause and death
  screens **and the in-world content** (folder and file names, file text, the
  photo's file comment, site names and descriptions, the generated gateway, the
  sentence that carries the web key). The authored web pages are **one file per
  language** (`web/pages/en/`, `web/pages/it/`) with the same file names, and the
  **domains follow the language** (catalog fields `en` / `it`: `www.thenewstoday.com` vs
  `www.notizieoggi.it`) — an English site on a `.it` gives the theme away faster than
  anything. `GameManager.set_lingua()` is the one entry point and `LINGUA_BASE`
  (`en`) is **forced** in `_ready()`, because Godot would otherwise start in the OS
  language (`it_IT` here) and the base language would never be seen. What is left is
  the **selector in Options** (M6) and persisting the choice. `tests/web_locale_test.tscn`
  is the guard: pages complete per language, every href landing somewhere, no
  translation key or foreign domain on the gateway, and the two languages actually
  differing. Recipe for a third language: docs/WEB_SITES.md §3.

- **Options screen + language selector** (2026-09-19): the main menu's "Options" button
  was **disabled in the scene** and its callback called `get_tree().quit()` — it now opens
  `scripts/options_screen.gd`, a code-built overlay holding **one** setting, the language
  (a button per language, labelled with its own endonym, the active one framed). The choice
  is **saved** to `user://impostazioni.cfg` and reloaded at startup, and changing it
  re-translates the screen and the menu behind it on the spot. It is reachable **only from
  the menu**, on purpose: the in-world text is generated when the run starts, so changing
  the language mid-run would not rewrite the PC. Volume / sensitivity stay M6, and
  `_riga()` is the hook for them. Test: `tests/options_test.tscn`.
