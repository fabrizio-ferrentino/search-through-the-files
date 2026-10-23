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

The 3D room. Camera3D runs player.gd. The shell and furniture are NOT
here any more: they are the instance "Stanza" (scenes/room.tscn) at the
origin. main.tscn keeps the desk/PC/monitor, Bed, lights, the Corridor
instance, WindowLeft, the enemies' markers.

2026-10-22 (owner: "sistemare la stanza, il mondo 3d, nulla di troppo
incredibile... rimanere coerente con il tutto"): the room was rebuilt
from primitives + the owner's models, scenes only (no script touched).
Old main.tscn nodes removed: floor, wall, wallLeft (+BucoFinestra),
wallBack, wallRight, Soffitto, the "Root Scene" door. Why: the old walls
were rotated ~1 degree and started 9 cm above the floor, and the floor
top was at y = 0.112 (desk legs sunk 12 cm, bed 22 cm, Ghosty's markers
below the floor). Now the floor top is y = 0.

Main.tscn changes: Bed y = 0; Corridor rotated exactly -90 degrees (was
~-92.8) with its mouth on the right wall, Transform3D(0,0,-1, 0,1,0,
1,0,0, 1.9, -0.0125, 0.12) (corridor axis on z -0.155, the eye's z; see
room.tscn and corridor.tscn); CornerShadow now at (1.4, 2.2, 1.5) (first
(2, 2.2, 1.5) because it was inside the new ceiling, then moved again
on 2026-10-23 because it fell outside the narrower room); DeskLamp is an editable instance with
Lamp_with_shade cast_shadow = off (the shade threw a huge black blob on
the wall). Known, left as is: Ghosty's path (markers z 4 -> 1.05, x 0)
still crosses the bed.

2026-10-22, proportions pass (owner: check they are "non dico realistiche
ma almeno giuste"). The desk was 0.60 m tall (real ~0.74) and the eye
1.07 above the floor (seated ~1.2). The whole desk group was raised by
+0.14 m: Camera3D (eye now y 1.21), test-schermo, Monitor, DeskLamp, the
screen-glow OmniLight3D and "Light". DeskModel keeps its feet on the floor
and is stretched in Y (scale y 1.4 -> 1.723, top at 0.74). The view from
the seat is unchanged relative to the desk. No script holds a hard-coded
height (checked). Bed scaled 1.2 -> 1.1 (~1.63 x 2.15 m, was 1.78 x 2.35),
origin z moved +0.1 so the headboard stays against the wall.
Measured and fine: wardrobe 2.0 h, bookcase 1.7, nightstand 0.5, closet
door 2.05, window sill 0.85 / top 1.85, ceiling 2.5, corridor 2.4; Jester
1.91, HaloMan 2.11 (would brush the 2.1 doorway top), Ghosty 1.7 floating.
(The two items that were "known, left on purpose" here, the 1.2 m door
and the 0.45 m screen, were fixed on 2026-10-23, see below.)

2026-10-23, screen, lamp, door (owner: "se vuoi sistemare lo schermo
fallo", then "fai lo schermo un po piu grande"; he approved the door
plan). main.tscn: the computer model (Monitor node + its collision shapes)
and the hidden reference test-schermo were scaled to 0.9 of their size
around the model's base (the Monitor origin, on the desk top); the
screen-glow OmniLight3D moved the same way. The visible screen is now
~0.40 m wide (was ~0.45, too big for a 1999 CRT); keyboard and tower
shrink with it (one mesh). DeskLamp scale 2 -> 1.6 (0.52 m tall, was
0.65); its "Light" kept the same place RELATIVE to the lamp (offset from
the lamp base x0.8, now (-0.72, 1.17, -1.07)), so the hot spot sits in
the shade again - left at the old height it sat on the shade's top rim. If
you rescale the lamp, move "Light" with it. crt_look_check confirms the screen quad still fits the frame and
its colour matches the OS exactly. Enemies were NOT resized: owner, "i
personaggi se sono tanto grossi o alti non e un problema devono essere
deformi... placeholder, e inutile modificarli".

### `scenes/room.tscn`

The room SHELL and FURNITURE in world coordinates, instanced in main.tscn
as "Stanza". PURE GRAPHICS: no node in it is read by code. Interior
x -1.61 (window wall) .. 1.9 (corridor wall), 3.5 m wide, z -1.98 (desk
wall) .. 4.30 (bed wall), floor top y = 0, ceiling 2.5. Walls are 20 cm
thick and straight. 2026-10-23 (owner: "col rework secondo me si vede poco
il corridoio, e' troppo piccolo, e quindi fa poco paura"): the room was
narrowed (right wall inner face was x 2.6) as part of a corridor rework:
straight longer corridor, normal door, no light at the end. RULE: the
doorway and the Corridor must stay on the eye axis (z -0.155); move one,
move the other. Moved with the wall: PortaRipostiglio (x = X1 - 0.58),
Scatoloni (X1 - 0.27 / -0.24), Bacheca x 1.33, Plafoniera at the room
centre x.
- Guscio: Pavimento, Soffitto, MuroDavanti, MuroDietro, MuroSinistro
  (CSG; child BucoFinestra = the window hole, move it together with
  WindowLeft), MuroDestro (CSG; child BucoPorta = the opening to the
  corridor, 0.9 m wide and CENTRED on the eye's z (-0.155): z -0.605..0.295
  (2026-10-23). History: it was 1.2 m, -1.44..-0.24, before that 1.45 m,
  -1.69..-0.24, always against the bed side, so the corridor was seen
  diagonally and its first ~1.5 m were hidden by the wall; now that the
  player turns straight down the axis (pos_right -90) it is centred),
  SpalleFinestra
  (dark lining of the window reveal: a 50 cm LIT reveal looked like a
  grey box outside the window), Battiscopa, VanoPorta (casing, wood
  lining, light switch).
- Arredo: Tappeto, Termosifone, Tende, Armadio, Plafoniera (off) and the
  doors are still primitives (no equivalent in the bundle). PortaRipostiglio
  = the owner's Door.glb, closed, on the back wall right of the bed (before
  it stood rotated beside the corridor mouth). 2026-10-23 (owner: improve the
  3D graphics with free poly.pizza models): the other props became instances
  of the "Household Props 001" models (all models have the origin at the base centre and face +Z; at scale 1.4,
  the desk's scale, they reach real sizes):
  Libreria = Bookshelf + one different book model per level (shelf tops at
  y 0.014/0.378/0.728/1.092/1.456 at scale 1.4). Each level is split by two
  staggered uprights into three compartments; books go ONLY in the middle
  one (0.41 x 0.22 m, centre (-1.507, y, 0.857)) - placed by eye, rows hung
  out of the shelf ("ci sono dei libri che escono dalla libreria"). From the
  bottom: the bundle's Books row, "Books Row", "Book Stack", "Books
  Leaning", the bundle's Books row turned round. The same row copied on
  every shelf "faceva uno strano effetto" (owner, 2026-10-23), so the three
  middle levels use models from assets/textures/3d/books/ (CC-BY 3.0:
  ATTRIBUTION REQUIRED, see CREDITS.md there). Comodino = End
  Table (scale 1.2) + Alarm Clock (off); Quadro = "Op Art" by Ryan Murray
  (assets/textures/3d/wallart/, CC-BY 3.0: ATTRIBUTION REQUIRED in the game's
  credits, see the CREDITS.md there; centred model facing -Z, scale 0.21 =
  0.80 x 0.60 m; chosen 2026-10-23 among three the owner proposed: its cold
  concentric "tunnel" echoes the corridor; it replaced the bundle's
  Painting, which is now unused); Bacheca = Wall Corkboard (1.2); Scatoloni =
  "Cardboard Boxes" by Quaternius (CC0, assets/textures/3d/quaternius/, a
  single closed stack 1.42 x 1.75 x 0.99 in the model, scale 0.6 = about
  1.05 m tall; 0.9 was "troppo grandi") against the right wall between the
  doorway and the clock (z 0.5..1.35); it
  replaced two stacked open Empty Box, the top one of which floated (owner:
  "c'e' una scatola che vola"). ScatolaAperta = one Empty Box alone on the
  floor between the bookshelf and the bed. Cestino = Trash Bin. NEW: Pendola = Grandfathers Clock on the
  right wall at z 1.95 (owner's choice; meant for a ticking sound later);
  Arredo/Scrivania = Mug With Office Tool + Desk Fan on the desk top (y 0.74).
  The desk itself is in main.tscn: if you move it, move these two.
  room.tscn and corridor.tscn were first written by one-off scripts that are
  NOT in the repo: they are now ordinary scenes, edit them in the Godot editor.
- PortaCamera (2026-10-22, owner: "mi pare strano che la stanza da letto
  non abbia una porta sul corridoio"): the bedroom door, OPEN into the room
  toward the front-right corner. The node is the HINGE (pivot on the jamb
  on the desk side, still so after the 2026-10-23 rework): rotate it on Y to open/close, -10 deg = open (now),
  90 = closed. It must open on this side: opened the other way it would
  cover the corridor peeks. Child "Anta" = instance of Door.glb (leaf
  1.33 x 2.98 x 0.115) scaled onto the opening (sized from it, so it follows
  the 0.9 m doorway), editable instance with the
  model's DoorFrame hidden; the VanoPorta casing is the frame.

### `assets/materials/` (shared by room.tscn AND corridor.tscn)

carta_da_parati.tres (faint vertical stripes: a GradientTexture2D with
world triplanar), pavimento_legno.tres (planks, same trick),
soffitto.tres, legno_scuro.tres (same colour as the window frame),
legno_mobili.tres. Change one, both room and corridor follow.

### `scenes/corridor.tscn`

REBUILT 2026-10-23 (owner: "si vede poco il corridoio, e'
troppo piccolo, e quindi fa poco paura"; chosen: straight longer corridor,
normal door, NO light at the end, narrower room). Straight, 6.5 m long
(lz 0..-6.5), width 1.45 (inner faces lx -1.0 / 0.45, axis -0.275), height
2.4, shared materials, baseboards, dark-wood casings. Side doors 0.8 m,
each with a black box "StanzaBuia" behind it: left lz -2.3 (SpotL1, lx
-0.85), right lz -3.3 (SpotR1, lx 0.30), left lz -4.5 (SpotL2), right lz
-5.6 (no spot, visual rhythm). The end wall has a closed Door.glb
"PortaFondo" (vanishing point, no spot). The hidden Light1/Light2 were
removed: the corridor stays dark on purpose (torch only). Spots must be
deep: through the 0.9 m bedroom door the corridor's sides show only from
~2 m in. History, so it does not come back: SpotL2 was named SpotR2 and
was always on the left; the old corridor had a left side re-cut into two
doors, SpotL1 at lz -1.7, and dim lights. Instanced in main.tscn with the
axis on z -0.155 (see main.tscn). All three spots are visible through the
doorway from the seat after turning right (pos_right -90 in player.gd =
looking straight down the corridor, was -70); check with stanza_check
(stanza_spot_destra.png).

### `scenes/window_left.tscn`

The outside seen through the window. 2026-10-23 (owner: "il mondo fuori
dalla finestra ... sembra vuoto e quando punto la torcia sugli alberi
appaiono neri"): the three primitive cones ("Alberi", 2026-10-22) became
"Esterno", models by Quaternius (CC0, assets/textures/3d/outdoor/ with its
CREDITS.md): near, a wooden fence (z -2.6) and two bushes; then two dead
trees; at the back six pines (z -8.5..-11.5). Real sizes (pines 6-8 m).
Everything stays BEHIND SpotFinestra (z -0.75) so nothing covers the peek.
"Notte" (unshaded sky, 44 x 18 at z -15) and "Terreno" (lawn 44 x 15, from
z -0.1 to -15.1) were enlarged and pushed back to contain them. With the
torch off the trees read as black shapes against the sky; the torch shows
their colours. Glass m_vetro is near-black on purpose (see THREATS.md,
torch). Window-local axes: +Z into the room, X along the wall.

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
Look positions: pos_right = -90 (2026-10-23, was -70: turning right you
look straight down the corridor, which is on the eye axis). Everything
reads the variable (threat_director _facing_zone, arrows, tests).
Monitor quad (2026-10-23, owner: "si vede male ... lo schermo con delle
scanalature"): the 1440x1080 OS image shrunk to ~200 px on screen gave a
moire. _poll_monitor (every 0.08 s - the screen stays LIVE, the owner's
requirement) now calls img.generate_mipmaps() before updating the texture
(~3 ms each time) and the material filter is
LINEAR_WITH_MIPMAPS_ANISOTROPIC. Same date: project.godot [rendering]
msaa_3d = 4x for the room's jagged edges. The 1280x720 window override is
the owner's, for development - leave it.
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

`3d/household/` (2026-10-23): 21 .glb from the poly.pizza bundle "Household
Props 001" (CreativeTrio, CC0), downloaded from static.poly.pizza; its
`CREDITS.md` lists source, author, license and each model's page. Desk.glb,
Bed.glb and Lamp With Shade.glb are byte-identical to the bundle's; Door.glb
is NOT from it (source unknown). Used in room.tscn: Bookshelf, Books, End
Table, Alarm Clock, Painting, Wall Corkboard, Empty Box, Trash Bin,
Grandfathers Clock, Mug With Office Tool, Desk Fan. Downloaded, NOT used yet:
Cabinet, Chandelier, Ceiling Fan, Rocking Chair, Coat Rack, Potted Plant,
Globe, Armchair, Chair, Dresser.

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
