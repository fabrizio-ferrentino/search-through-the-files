# Threats: room enemies, PC viruses, apparitions

Read before touching the room threats (Jester, HaloMan, Ghosty, torch), the PC viruses, the apparitions or the scenes they use.

Moved here from CLAUDE.md on 2026-10-22, word for word (CLAUDE.md now keeps only a one-line map).

## Files

### `scenes/corridor.tscn`

STARTER right-side corridor (M4): plain box geometry + door
Marker3Ds in group "enemy_spots", kept DARK (dim lights — the
torch lights it). Instanced inside main.tscn (node "Corridor");
move/refine/replace in editor.

### `scenes/window_left.tscn`

PLACEHOLDER window on the LEFT wall (M4, 2026-10-19, owner: "un
place holder, poi quando bisognera' sistemare la grafica 3d si
sistemera'"): plain boxes (frame, cross bars, sill), a transparent
glass quad, a weak cold SpotLight3D "LuceLuna", and OUTSIDE a dark
ground ("Terreno", at floor height) and a far UNSHADED night sky
("Notte"). THE WALL IS CUT: wallLeft in main.tscn is a CSGBox3D (it
was a MeshInstance3D with the same 7x2x0.5 box) whose child
"BucoFinestra" (operation = subtraction) removes the opening - move
the window, move the hole. "SpotFinestra" (the FEET of whoever peeks,
outside on the ground) is in "enemy_spots" AND "spot_left": Jester
and HaloMan peek from here like from the corridor doors, and the
zone to light is the left. Instanced in main.tscn as node
"WindowLeft" at (-1.6, 1.35, -0.75), rotated so its +Z faces into
the room: that is where the camera looks at pos_left (70 deg). Each
node carries an editor_description. Look at it with
tests/finestra_check.tscn.

### `scenes/enemies/jester.tscn`

Jester prefab (M4): the (downloaded) Slender model + base PBR
material (NO own light - only the torch reveals it); root runs
scripts/threats/jester.gd. The model is a PLACEHOLDER: the owner's
own model and animations replace the "Model" child, LAST, after
the gameplay (owner, 2026-10-19).

### `scenes/enemies/halo_man.tscn`

HaloMan prefab (M4, 2026-10-19): PLACEHOLDER - a dark capsule body,
a head and a glowing HALO (emissive torus) with its own OmniLight
"LuceAureola" that halo_man.gd makes pulse: unlike the Jester he
is visible in the dark, his light shows on the corridor walls.

### `scenes/enemies/ghosty.tscn`

Ghosty prefab (M4, 2026-10-19, working name): PLACEHOLDER - a pale
translucent capsule with a head and two dark eyes on its -Z (the
side look_at turns toward the player); ghosty.gd floats it.

### `scripts/threats/threat_director.gd`

ThreatDirector (M4): the room-threat director, rebuilt 2026-10-19
on the owner's design. Runs always (even inside the PC). THREE
enemies: JESTER and HALOMAN share ONE peek slot (never together):
GRACE -> WAIT -> PEEK (reaction window) -> CALM (a guaranteed safe
CALM_TIME 25 s) with the gentle "heat" (0..1) shifting interval and
window; spots = "enemy_spots" (the three corridor doors + the
window), never the same twice in a row, zone "left" if also in
"spot_left". _scegli_chi: HaloMan only with the PC ON, HALO_PROB
0.4 (halved right after one of his). JESTER: dark, only the torch
shows him; repel by HOLDING the light on his zone for
USCITA_MIN..MAX 1-2 s, drawn anew each peek (_uscita_serve) - he
visibly slides back (NemicoAffaccio.ritira); the reaction clock is
frozen while lit; let go early and he comes back out at RIENTRO
0.5x and the clock runs again; REACT 8 -> 4 s. HALOMAN: lighting
him KILLS - torch on while facing his zone = game_over("halo") on
the spot (owner, 2026-10-19: his halo shows him in the dark so you
can tell him from the Jester BEFORE switching the torch on);
switching the PC OFF (case button or Start > Shut down) sends him
away; HALO_REACT 12 -> 8 s, because you must leave
the PC, turn to the centre and click the case. GHOSTY: his own
clock in parallel - first after GHOSTY_PRIMO 45-70 s, back
GHOSTY_PAUSA 25-45 s after being sent away; _g_p 0..1 grows only
while you are NOT looking back (inside the PC counts as not
looking), GHOSTY_DURATA 60 -> 40 s from start to strike; he is in
the room from GHOSTY_VISIBILE 0.15, walking the straight line
between the Marker3Ds "ghosty_lontano" and "ghosty_vicino" in
main.tscn; looking back FREEZES him; the torch ON while facing
back makes him vanish at once; he never strikes during a peek or
the lethal PC virus - he waits at GHOSTY_TRATTIENE 0.97 (two lethal
threats in the same instant are a lottery). Causes "jester",
"halo", "ghosty". THE TORCH is HELD now, no longer a 2 s flash
(owner: "la torcia non si comanda quanto tempo deve rimanere
accesa"): player.gd calls torch_accendi on press (looking
left/right/back, near the centre of the screen) and torch_spegni
on release; BATTERY_DRAIN 12/s while lit (~8 s), RECHARGE 6/s
while off, empty -> off and no relight under BATTERIA_RIACCENDE
15, flickers under 20; the beam follows the camera every frame
(_punta_torcia). TELLS inside the PC: a peek (either enemy) =
the glitch.gdshader pulse, which does not say WHO (go and look);
Ghosty = a different, LIGHT tell - the screen edges cool and darken
as he closes in (inline shader, forza_velo_ghosty, from
GHOSTY_TELL_DA 0.35). solo_annota_morte (tests only) records the
cause in "morte" instead of calling game_over. Debug: forza_affaccio
(chi), allontana, ghosty_forza, ghosty_allontana, stato_debug.
Test: minacce_stanza_test.tscn.

### `scripts/threats/virus_director.gd`

VirusDirector (M5, 2026-10-18): the PC-threat director, twin of
the ThreatDirector, spawned next to it by player._spawn_threats
(it holds `player` and `os`). Three viruses, ONE AT A TIME:
"mortale" (VirusMortale), "stupido" (VirusStupido), "crash"
(OSDesktop.schermo_blu). Pacing chosen by the owner ("rari", not
too invasive): time counts only with the PC ON and LOGGED IN;
first virus after PRIMO_VIRUS 180 s, then one every PAUSA_MIN..
PAUSA_MAX 120-240 s, never the same twice in a row (PESI
0.4/0.3/0.3). One starts ONLY with the player inside the PC for
ENTRATA_MIN 4 s (they must see it begin - _in_pc_da counts only
inside, so it also means "is inside") and the desktop free
(OSDesktop.pronto_per_virus: no login, boot, dialog - the secret
folder included - or rename), and never while the Jester is
peeking (ThreatDirector.in_agguato); the ThreatDirector in turn
does not peek during the lethal virus (its `virus` ref): two lethal
threats at once are a lottery, not tension. Powering off (Start >
Shut down OR the case button) cancels the lethal one; F8 (PC
threats off) freezes the clock and removes it - F11 is the ROOM's
switch and does not touch it; stop() on win. DEV-ONLY: F9 forces the
next virus now (mortale -> stupido -> crash), SHIFT+F9 a false
alarm. avanza(delta) is public so tests run minutes in a loop.
FALSE ALARMS (2026-10-18, owner): a fourth event, "falso", on its
OWN clock - first after FALSO_PRIMO 90-180 s of PC on, then every
FALSO_MIN..MAX 180-300 s ("rari", owner's pick) - shows an
Apparizione for FALSO_DURATA 2-2.5 s (owner; it was 0.3-1.2 s) and removes it. It does not
count for "never the same twice" and does not move the real
viruses, except that after one the next real virus waits at least
DOPO_FALSO 15 s (a real one right after a false one would read as
the same). Same conditions as the viruses; never over another
event. Test: virus_test.tscn.

### `scripts/threats/nemico_affaccio.gd`

NemicoAffaccio (2026-10-19): the shared body of the enemies that
PEEK from a spot (Jester, HaloMan) - appear_at (slides out from
behind the jamb, facing the player), ritira(t) (0 = out on the
spot, 1 = gone behind the jamb: the director drives it while you
light the Jester), dismiss, nascondi, head_world_pos. NOT
advancing.

### `scripts/threats/jester.gd`

Jester (extends NemicoAffaccio): no logic of its own - the rules
are in the ThreatDirector.

### `scripts/threats/halo_man.gd`

HaloMan (extends NemicoAffaccio): only pulses the halo light.

### `scripts/threats/ghosty.gd`

Ghosty's body: percorso(da, a, guarda), metti_a(t) along the line,
sparisci, a slow float. How far he is comes from the director.

### `scripts/os/apparizione.gd`

Apparizione (M5, 2026-10-18, owner): an APPARITION of the curse in
the PC - it IS the lethal virus and it IS the false alarm. ONE
PHASE, ONE RULE (owner): gone in under SOGLIA_FALSO 3 s = false
alarm; STAYS = real, switch the PC off before it kills. It never
turns into something else: in the real one it only grows slowly
(crescita = VirusMortale.DURATA, intensita 0..1), "more of the
same". Real and false START IDENTICAL (COMPARSA 0.25 s curve, same
spot). SEVEN TIPI (PESI picks, all equal for now - the owner can
make the grave ones rarer): four SMALL ones that live ONLY in the
wallpaper (OSDesktop.sopra_sfondo: under icons and windows) or the
clock - "bambino" (the curse SHOWS
ITSELF as a child with a noose - GDD §2b - MADE OF BLACK ASCII
CHARACTERS since 2026-10-19 (owner, from a video of ASCII art),
~470 px tall (SCALA_BAMBINO 1.35), hanging near the right edge of
the wallpaper: a BOY (the curse is male - owner) whose TRUE
outline - child proportions, messy short hair, ears, sleeves,
shorts, thumbs, knees, toes pointing down, the head bent too far,
arms hanging a little AWAY from the body - is not drawn: each PART
is filled into a stencil with its own id (_prepara_maschera, a
scanline fill in _PARTI order, so the arm covers the shirt), and
_prepara_distanza measures the distance to the edge OF ITS OWN
PART (chamfer, half resolution), so there are edges INSIDE the
figure too. _prepara_toni (once, ~30 ms all in) gives every point
a TONE, i.e. how dark: the MATERIAL (_MATERIALE: hair 1.0, shorts
0.88, shirt and sleeves 0.68, PELLE 0.42 - the face is skin only,
never features), darker toward the edge and on the side away from
LUCE (upper left), a full dark line where a part ends or covers
another (shirt hem on the shorts, sleeve on the shirt) and on the
_PIEGHE (collar, folds from the armpits and at the bottom of the
shirt, the shorts seam, the knees) - DETAILED like the eyes. The
FIXED text grid (_componi_ascii, 4 samples per cell, every
ASCII_PASSO 0.09 s, ~6 ms) gives each cell the ASCII_RAMPA
" .:-=+*#%@" character of its tone, in Cousine BOLD 9 (8 banded
through the CRT, 10 lost detail), C_BAMBINO near black. The grid
stays still while he sways and turns under it, so the characters
change and the edge "fizzes"; the rope is a column of ")("; a few
faint ASCII_SPARSI symbols float around him (more as the real one
grows). History, so it does not come back (owner, 2026-10-18/19):
the first silhouette, made of round shapes, "was ridiculous"; a
realistic figure in COLOUR (a girl in a nightgown - "looks like a
woman" - then a boy from behind in a T-shirt) "is not scary"; the
solid dark silhouette was "not perfect yet"; ASCII with a pool of
darkness behind - "non mi piace", no halo; WHITE characters
"si vede poco", even with a black outline per character; so: black
characters, detailed. Never a face, never graphic. Everything sits
in a CanvasGroup that fades as a whole.
res://assets/textures/virus/bambino.png, if present, becomes the
STENCIL (its alpha)), "occhi" (two REALISTIC eyes MADE OF
CHARACTERS on the same small grid, OCCHIO_A 110 px half-width
each: _tono_occhio computes a real eye - upper and lower lid, a
thick lash line, a few lashes curving out, the lid crease, a
shaded sclera (darker at the corners and under the upper lid), a
DARK iris with radial fibres and a darker rim, the pupil (it
dilates in the real one) and a white highlight - in TWO TONES:
white characters where the eye is light, dark ones
(C_ASCII_SCURO) where it is dark, nothing around it. The iris
follows the cursor (guarda_test in the tests), cell by cell;
they open and blink. Two stylised "(%@@@@%)" eyes were rejected:
the owner wanted real ones), "orologio" (OSDesktop.orologio_finto:
time backwards, 03:33, --:--), "scritte" (a VIRUS_SCRITTA_* line
that TYPES ITSELF on the wallpaper like a terminal line: a red
">" prompt, the letters appearing one by one in SCRITTA_DIGITA
0.9 s - Label.visible_characters, so the Label's text stays the
whole sentence - and a blinking "_" cursor, WHITE mono bold with
no smear behind, in
the wallpaper) - and three GRAVE ones, apparitions like the others
with the same rule: "buio" (since 2026-10-19, owner: it used to
darken only the wallpaper - now the WHOLE screen goes dark: windows,
icons, taskbar, AND the Start menu and dialogs opened LATER, Shut
down included. OSDesktop.sopra_tutto puts it in its OWN CanvasLayer
(layer 5, freed with it): as a plain desktop child the Start menu and
the dialogs, which move_to_front when they open, ended up above it
and "stayed unchanged" (owner). And it FLICKERS like a DYING LIGHT
BULB (_sfarfalla, owner: the first flicker, which came back almost
normal in flashes, "non mi piace" - it read as a switch): mostly on
at its usual dimness with a barely visible tremor; now and then a
BURST of 2-3 short drops (the filament losing contact) or, one time
in four, a LONG drop almost to black that recovers slowly (the
filament cooling and reheating); then quiet. No jumps - the light
follows its target with inertia, down fast (tau 0.025 s) and up
slower - and never BRIGHTER than its usual. At most 3 drops a second
(BUIO_RAFFICA_MAX, then BUIO_PAUSA_MIN 1 s of quiet): a faster
flicker can hurt photosensitive players. The darkness grows in the
real one, up to 0.85, so Start can still be found), "sangue" (over the windows, under taskbar and
Start menu: a soft wavy RIM along the top - dark where it clots, a
few swollen sacks, a wet sheen - and GOCCE 28 drips of DIFFERENT
width and reach that flare out of the rim, meander slightly, thin
out and end SWELLING into an elongated drop that is part of the
same outline, slightly darker at the bottom, and run in viscous
surges, not as rain; now and then a drop detaches from a long
drip and falls as a drop with a fading TRAIL. Redrawn 2026-10-18
on the owner's request "migliora l'effetto del sangue": it used
to be 60 straight identical bars under a saw-tooth rim, a
barcode; then the tips were a separate round ball, wider and
brighter with a dot of shine, plus loose spatter dots and round
falling drops - "le gocce appaiono come pallini": all gone) and "tremito"
(the window layer shakes; pulisci puts it back at 0).
History, so it does not come back: a third grave one, "lampeggio"
(the whole screen flashing red like a heartbeat), was REMOVED -
the owner did not like it at all. A version with a quiet first
phase that escalated into a red/blood second phase was rejected
(owner: "tutto un'unica fase"), and so was a "scarier" version that
blacked out the whole screen around a cursor light, renamed the
desktop icons, hung the child over the windows and flashed it
subliminally - "troppo invasivi". durata > 0 = false alarm
(self-removes), crescita > 0 = real. Nothing takes the mouse;
pulisci() puts everything back (layers, clock, window layer).

### `scripts/os/virus_mortale.gd`

VirusMortale (M5): the LETHAL virus - now a THIN wrapper: it picks
an apparition type (Apparizione.scegli, or a given one for tests),
grows it for DURATA 10 s (owner: 25 was too long) and then emits "scaduto" ->
game_over("virus"). Powering off in time (Start > Shut down or the
case button) saves you: the director calls pulisci(). No phases,
no red wallpaper, no "non spegnermi" (VIRUS_CURSE_MSG removed from
the CSV): the old blood / shaking code moved into apparizione.gd
as apparitions of their own. It lives INSIDE the OS, so the 3D
monitor shows it too, and does not use glitch.gdshader (the
corridor enemy's warning). Known risk, accepted by the owner: a
real SMALL apparition hidden behind a maximized window may go
unseen - raise DURATA or the grave PESI if it proves unfair.

### `scripts/os/virus_stupido.gd`

VirusStupido (M5): "YouAreStupid", NOT lethal. A burst of
PRIMA_ONDATA small OSWindows (smiley icon, three faces, "YOU ARE
STUPID" / "SEI UNO STUPIDO", black/white swapping every 0.6 s -
under 1 Hz, no strobe), QUOTA_VAGANTI of them bouncing inside the
usable area (left alone while dragged/resized/maximized:
OSWindow.occupata / is_maximized), and closing one sometimes
spawns 1-2 more - like the real "You are an idiot". Two caps make
it always END: MAX_VIVE 9 open at once, MAX_TOTALE 16 in all.
Spawns wait while the desktop is not free, and power_off closes
them all without respawns (the respawn is queued, and by then the
PC is off). It CANNOT BE IGNORED (owner, 2026-10-18): the windows
are OSWindow.blocca_in_cima() - ALWAYS ON TOP (OSDesktop._alza
re-raises them over any window that gets focus, clicked or not),
it CANNOT BE MINIMIZED: the three title-bar buttons are there
(the owner wanted them back after a version that hid min/max)
but "minimize" is DISABLED (GlyphButton.disabilitato: grey
embossed glyph, clicks do nothing) and the taskbar button does
not hide it either (a version where it minimized and popped
back after 2 s was tried and dropped by the owner) - each
new one takes the keyboard focus away (gui_release_focus), and
while any is open another arrives every INSISTENZA 5 s, within
the caps. The text stays ENGLISH in every language (it is the
virus's name, like "You are an idiot"). A moving window FREEZES
while one of its title-bar buttons is held (OSWindow.occupata ->
GlyphButton.premuto): a button fires on RELEASE only if the mouse
is still over it, so on a window sliding away the X visibly
pressed and did nothing (owner's report).

### `scripts/os/schermo_blu.gd`

SchermoBlu (M5): the Win95 BLUE SCREEN, text mode (mono font,
~80 columns, the system name "WHALE" in a grey box, real
exception codes and VxD names, blinking cursor). It REBOOTS THE
PC BY ITSELF after DURATA 5 s, with a countdown on the last line
("Restarting in N seconds..." / BSOD_RESTART with {N}) - owner,
2026-10-18, who did not like having to press a key. A crash is
something you SUFFER, like the unskippable boot, while the room
threats keep running. On "scaduto", OSDesktop.riavvia closes
every window, shows RIAVVIO_NERO 1.2 s of BLACK (a boot state:
no input, no virus, the case button cancels it via _boot_token),
then the BIOS POST, boot and login. Keys and clicks are EATEN
(its _input runs before the desktop's, children first) so they
do not reach the windows below - but ESC and P are decided in
the room first: ESC leaves the PC while the countdown carries on
on the 3D monitor, P pauses and the countdown freezes with the
tree. History, so it does not come back: it was "misto" (usually
only the front program closed), then "any key to restart" - which
needed a 0.7 s key delay, because the same F9 that starts it also
reached the OS and closed it in the very instant it opened ("with
F9 the blue screen never appears" - owner). No CTRL+ALT+DEL line:
the host OS takes that combination before the game ever sees it.

### `scripts/os/glitch.gdshader`

Reusable glitch (RGB split, slice-tear, scanlines, noise);
the ThreatDirector's full-screen WARNING and the death screen,
foundation for M5. NOT the secret folder any more (see below).

## Feature notes

- **PC viruses** (M5, 2026-10-18): `scripts/threats/virus_director.gd` runs three, rare
  and one at a time (first after 3 min of PC on, then every 2-4 min; only while the player
  is inside the PC): the **lethal** one (an **apparition**, `scripts/os/apparizione.gd`: four small
  ones in the wallpaper or the clock - the hanged child (detailed black ASCII characters), two
  realistic eyes made of characters, wrong time, a line that types itself - and three grave ones - the whole screen going dark and
  flickering, blood dripping over the windows, shaking windows. The same apparitions come alone every 3-5 min as **false alarms** that vanish in
  2-2.5 s; the real one stays and grows: power off within 10 s - Start > Shut down or
  the case - or `game_over("virus")`), **YouAreStupid** (a burst of bouncing smiley windows that
  multiply when closed, capped so it always ends; not lethal) and the **blue screen** (after a
  5-second countdown the PC reboots by itself: black, BIOS, boot, login; every window lost). DEV-ONLY **F9** forces the next one.
  Test: `tests/virus_test.tscn`.

- **Room threats** (M4, rebuilt 2026-10-19 on the owner's design): the starter corridor
  **`scenes/corridor.tscn`** (instanced in `main.tscn`, three doors = `Marker3D`s in
  **`enemy_spots`**) and the **window** on the left wall (`scenes/window_left.tscn`, the wall
  really cut, its spot in `enemy_spots` + `spot_left`). `player.gd::_spawn_threats()` spawns
  the **ThreatDirector** (see its entry above), which runs always, even inside the PC:
  - **Jester** (`scenes/enemies/jester.tscn`, the Slender model as a placeholder): peeks from
    a door or the window, dark - only the torch shows him; **hold the torch on him** for 1-2 s
    (random each time) and he slides away; let go early and he comes back.
  - **HaloMan** (`halo_man.tscn`, placeholder with a glowing halo): same spots, never together
    with the Jester, only with the PC on; **do not light him** - the torch on him kills you;
    **switch the PC off**.
  - **Ghosty** (`ghosty.tscn`, working name, placeholder): from **behind**; the longer you do
    not look back (or sit in the PC) the closer he gets; looking back freezes him, the **torch**
    makes him vanish. He never strikes during a peek or the lethal PC virus.
  The **torch** is HELD (press = on, release = off) with a battery (HUD bar in the room). Inside
  the PC a glitch pulse warns of a peek and the screen edges cool down as Ghosty approaches. The
  room is kept dark (`player._setup_atmosphere`: low ambient, **no fog** — FNAF4-style). Deaths:
  `game_over("jester" / "halo" / "ghosty")`, each with its own subtitles
  (`DEATH_JESTER_*`, `DEATH_HALO_*`, `DEATH_GHOSTY_*`). Stopped on win. Models and animations
  are placeholders, to be replaced LAST (owner). Test: `tests/minacce_stanza_test.tscn`.
