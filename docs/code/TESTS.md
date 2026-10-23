# The tests

What every test proves and how it was sabotaged. Run them through the godot-tester agent (see CLAUDE.md).

Moved here from CLAUDE.md on 2026-10-22, word for word (CLAUDE.md now keeps only a one-line map).

## Files

### `tests/`

- Dev test scripts (run with -s or as scene, see WEB_AUTHORING.md):

- html_bb_test.gd (compiler unit test + the per-page census of
  hiding spots, over EVERY language folder, headless). 2026-10-23, check "nbsp":
  `a&nbsp;&nbsp;&nbsp;b  c` compiles to `a   b c` (&nbsp; survives the whitespace
  collapsing). 2026-10-23, section
  _prova_varieta: the gif path, font families + the bold/italic FILES, <td width>
  px and %, a nested table's width relative to its cell, bordercolor, marquee
  (incl. the in-cell and too-long static fallback), blink, bgsound/embed in ctx and
  the player links, anchors never inside moving text, tiled-background textures,

- gif_test.gd (-s, headless, 2026-10-23: every web/img/*.gif decodes; frame
  counts and delays, colours, transparency, disposal 2/3, the textures
  (animated vs single frame), broken files rejected, interlace. Sabotaged:
  LZW code-size growth broken - red),

- midi_test.gd (-s, headless, 2026-10-23: a hand-built SMF with a tempo change,
  running status and drums; the real melodies of web/audio parse; the render is
  not silent, stays limited and ends in a silent tail; the stream loops and
  the cache answers. Sabotaged: tempo changes ignored - red),

- web_media_test.tscn/.gd (headless, 2026-10-23, the real BrowserApp: <bgsound>
  starts only when the load ENDS and loops; navigating stops it; <embed
  autostart=false> stays mute, its play/stop links work and do not navigate; the
  tiled background shows, scrolls with the page and is removed on the next
  page; marquee/blink leave no printed tags. Section 6 (PC audio): the music plays on
  bus "PC"; inside the PC the sound is clean; in the room it is muffled, with echo and
  quieter; monitor on the right -> pan right; back turned -> darker and quieter),

- disco_casuale_test.tscn/.gd (the RANDOM disk, headless, and the
  guard for whoever edits the catalog: every entry translated in
  every language, names unique per language case-insensitively,
  valid zones, no text shaped like a key; over 80 seeds x 2
  languages the skeleton is always there, My Pictures always in
  place with its photos and nothing from the catalog in it, 2-3
  horror per run, no duplicate names in a folder, no {PROG} left, no
  banned characters below the drives, key 1 on the disk and the
  web keys NOT on it, and over 80 seeds key 1 is a FILE and a
  FOLDER at least 30% of the time each (sabotaged: always a file -
  red); same seed = same disk, 80 seeds = 80 different disks, both
  languages the same SHAPE with the same entries; and EVERY catalog
  entry - files, user folders, programs, extra folders - shows up at
  least once, so a wrong zone is caught. Sabotaged: a zone that never
  fills, a choice made on the translated name, My Pictures among the
  places, a fake code in a horror text - all red),

- filesystem_test.tscn/.gd (the SHAPE of the disk: My Computer
  lists the units, the boot files are in the ROOT of C: and not
  duplicated in the system folder, C:\WHALE holds SYSTEM/FONTS/
  TEMP/Desktop/Start Menu/Favorites, VFS.get_desktop() finds the
  Desktop THERE with the secret folder in it - if that path missed,
  the whole desktop would silently go empty - the photos are in
  My Documents\My Pictures, a binary reads as a binary and is
  stable, no translation key reaches the screen as a name or a
  content, key 1 is found EXACTLY in the way the panel declares
  (FILE = once in a file's content, FOLDER = once in a name) with a
  DOS path in the F12 panel, the web keys are not on the disk, and the two languages produce the SAME NUMBER of nodes
  with the system names identical and the user ones translated
  - headless),

- esplora_chrome_test.tscn/.gd (WINDOWED - it reads pixels. The
  explorer's CHROME, the twin of
  browser_chrome_test: every menu opens a non-empty dropdown, there
  are working AND grey entries (with "Modifica" grey in full, on
  purpose), the fake toolbar buttons are disabled AND callback-less,
  Back/Up/Delete/the address arrow tell the truth about the state
  and light up once there is somewhere to go or something selected,
  the PROTECTED folder cannot be deleted from either the button or
  the context menu - binning it would make the run unwinnable - and
  no enabled chrome button is left without a callback - headless),

- esplora_griglia_test.tscn/.gd (the explorer's icon grid follows
  the window width: fewer columns when narrow, never zero, never
  wider than the visible area - and if the layout re-entered its
  own loop the test would hang instead of finishing, which is how
  it reports that - headless),

- options_test.tscn/.gd (the OPTIONS menu: the button must be
  ENABLED and must OPEN the screen - it used to be disabled in the
  scene with a callback that quit the game, so if that came back
  the test would die without printing a result, which is the
  signal; one screen at a time; a button per language with its
  endonym, the current one marked; choosing one must change the
  locale AND re-translate both the screen and the menu behind it
  (which had taken its labels from tr() in the other language);
  the choice must be SAVED to user://impostazioni.cfg; "Back"
  closes and it reopens. It restores the language that was saved
  before it ran - headless),

- siti_catalogo_test.tscn/.gd (the SITE CATALOG, headless: every site
  has all its pages in every language and no page outside its list,
  domains never repeat, NO TEXT SHAPED LIKE A KEY in any page (dates
  with slashes!), a "completo" site has at least 5 pages and ~6000
  characters per language, the run pick on a FAKE 30-site catalog
  gives 10-15 sites, 4-5 lore, a father and a young-man site, the
  same for the same seed and every site over 300 seeds, addresses of
  subpages and ~user pages resolve, a relative link stays in its site,
  and a site not in the run does not answer. Plus the owner's rules of
  2026-10-20: SITI_CHIUSI (no link to another site of the catalog),
  NIENTE_CONTROLLI (no input/form/select/textarea/button),
  NIENTE_DATE_RELATIVE and NIENTE_DATE_DOPO_1999, and DEBUG_TUTTI_I_SITI
  (the F12 switch opens every site, keeps the keys where they were,
  and closes them again). 2026-10-23, check 10 MEDIA_ESISTONO: every file
  referenced by an <img>, <embed>, <bgsound> or <body background> must exist
  (MEDIA_ROTTI is the list of INTENDED broken images, empty today). Sabotaged: a relative link leaving its site,
  the pick without the lore rule, a complete site with 2 pages, a date
  in 2000, the debug switch ignored - all red; the three rules went red
  on the real defects before they were fixed),

- siti_check.tscn/.gd (dev tool, WINDOWED: the real browser in the real
  room through the CRT, maximized, on the sample pages or the ones
  after "--" (first the language: "-- en forum/index") ->
  user://sito_<site>_<page>.png, to judge a site by eye),

- vassoio_check.tscn/.gd (dev tool, WINDOWED: the taskbar tray with the
  volume popup open, then muted -> user://vassoio_volume.png and
  user://vassoio_muto.png, the bottom-right corner at 2x, to judge by eye
  that nothing overflows and that slider/checkbox match the Win95 theme),

- web_locale_test.tscn/.gd (the game in every language: every page
  must EXIST in that language - read_page's fallback to "en" would
  otherwise hide an untranslated page behind an English one, green
  test and an English page inside an Italian game; every href must
  lead somewhere in the SAME language, which catches the easy
  mistake of an Italian link left in an English page; the generated
  gateway must carry no {placeholder} left over, no translation key
  in the clear and no domain of the other language; address -> page
  -> address must close for the whole table; BOTH web keys must land
  on a carrier that exists in that language with a TRANSLATED
  sentence; and the two languages must actually differ, or a
  translation that never gets applied would pass everything else
  - headless),

- browser_click_test.tscn/.gd (mouse behavior: click/double click/
  drag/links/cursor - incl. the I-beam being ONLY over glyphs, empty
  space inside the page and inside a TABLE must give the arrow;
  glyph points are found by LOCAL CONTRAST, not by differing from the
  page background, or a point on a coloured cell would pass as "text"
  and the cursor checks would be fake, windowed),

- photo_key_test.tscn/.gd (the photo key: per-photo census with
  the findability FLOOR vs the invisibility CEILING and whether the
  spot is feasible at all, a visibility ceiling calibrated against
  real full-window renders, and a 60-run carrier-uniformity check
  across all photos — windowed),

- photo_reveal_test.tscn/.gd (THE REAL GATE for the photo key:
  per-GLYPH legibility through the real shader, sweeping the
  "Nitidezza" uniform; masks from the composition upstream, values
  from the post-shader viewport downstream. Reports LEG = how well
  the WORST glyph separates at the best slider position, plus the
  at-rest watermark per glyph and the true band ratio — windowed),

- photo_file_key_test.tscn/.gd (the photo key's SECOND route, the code
  in the file's BYTES: over 40 seeds both routes occur, FILE mode keeps
  the code out of the pixels and PIXEL mode out of the dump, decoys stay
  clean, and the comment's position in the dump varies — headless),

- photo_banda_scan.tscn/.gd (dev tool: the quietest spot in the
  shader's real band on each photo and the offset it would need),

- photo_chain_test.tscn/.gd (the code must survive the REAL chain:
  viewer window -> OS screen -> game window + CRT, and the sliders
  must reveal it — windowed),

- minacce_stanza_test.tscn/.gd (WINDOWED. The ROOM THREATS in the
  real room with the real ThreatDirector, its clock run by the test
  and deaths recorded instead of ending the run
  (solo_annota_morte): the torch is held (on while pressed, off on
  release, drains lit, recharges off, empty -> off and no instant
  relight, never inside the PC); the Jester leaves only if HELD in
  the light for 1-2 s, different each peek, comes back out and the
  clock resumes if let go early, light on the wrong zone does
  nothing, left alone he kills; he also peeks from the WINDOW,
  outside the wall; HaloMan only with the PC on, lighting him
  KILLS (light on the other side does not), powering off sends him
  away, left alone he kills, never
  together with the Jester; Ghosty advances only unwatched (also
  inside the PC), freezes when watched, vanishes at the light when
  facing him (and comes back after a pause), the in-PC tell only
  when he is close, and he never strikes during a peek but does
  right after. Sabotaged: the Jester gone at a flash, the torch
  sending HaloMan away, lighting HaloMan harmless, Ghosty advancing
  while watched, Ghosty
  striking during a peek - all red. Saves jester_finestra,
  halo_corridoio and ghosty_dietro .png under user://),

- ascii_check.tscn/.gd (dev tool, WINDOWED: the ASCII apparitions -
  child, eyes, writing, or the types after "--" - in the real room
  inside the PC, false and real -> user://ascii_<type>.png (through
  the CRT), _os.png (the OS screen) and _vero.png, plus the setup
  and step times),

- finestra_check.tscn/.gd (dev tool, WINDOWED: the real room
  with threats off, photographed looking LEFT and straight ahead ->
  user://finestra_sinistra.png / finestra_centro.png, to judge the
  placeholder window by eye),

- stanza_check.tscn/.gd (dev tool, WINDOWED, 2026-10-22: the real room
  (room.tscn) with threats off, photographed from the four views as
  the player sees it (centro, sinistra, destra, dietro) ->
  user://stanza_<vista>.png, and again with the ambient light raised
  (1.2) -> user://stanza_<vista>_luce.png, plus user://stanza_alto_luce.png
  from above. To judge the furniture and walls by eye; no asserts.
  2026-10-23: also user://stanza_spot_destra.png, the right view with a
  red unshaded capsule (1.8 m) on every "enemy_spots" marker, to check by
  eye that every peek spot is visible from the seat),

- crt_look_check.tscn/.gd (dev tool, WINDOWED: the REAL room, into
  the PC, and photos of what the player sees - full view, a x4
  zoom, the room with the 3D monitor - plus three numbers: the
  scanline profile on flat desktop (a moire shows up as the
  per-row swing VARYING along the band), the contrast of three
  texts (P95-P5: white on blue, black on white, black on grey) and
  the 3D monitor's colour against what the OS draws. Run it twice:
  plain (1280x720, the default window) and with --resolution
  1920x1080. It waits for the room's 1 s opening fade: its first
  run photographed mid-fade and "found" the monitor at a third of
  its brightness, pure white measuring 94/255),

- photo_look_check.tscn/.gd (dev tool: side-by-side original vs
  shown photo + a CPU band-pass reveal crop, to judge the watermark
  by eye),

- cartella_segreta_test.tscn/.gd (WINDOWED - it reads pixels. The
  WIN CONDITION, which had no test at all, and its guasto: one
  field per key; the guasto is not the warning's shader and stays
  around the dialog - in the PIXELS too: during a trail 0 pixels
  change outside its rect while the margin shows the copies; after
  a burst EVERYTHING is back (title, shader parameters, panel
  position after the shake, the dimmed veil, and the pixels: 0
  differing from rest); typing with real key events works and the
  text is never touched; the rejection shows the TRANSLATED error,
  is visibly red and leaves the codes as typed; the subliminal line
  is translated and vanishes; no burst over MAX_RAFFICA; bursts
  more frequent with time; the right codes WIN and the guasto dies
  with the dialog, Cancel included; the new lines exist in every
  language),

- icone_check.tscn/.gd (dev tool, WINDOWED: EVERY OSIcon kind at
  48/24/16 px with its name, on the desktop teal, the window grey
  and white, x2 without smoothing -> user://icone.png - the sheet
  to judge whether the icons look like one series. "-- zoom a,b"
  = just those at 16-48 px x4 (user://icone_zoom.png); "-- web" =
  the network icon at 16-64 px plus the real desktop with the
  browser open (user://icona_web.png, icona_web_desktop.png).
  Add a new icon kind to its TIPI list),

- glitch_look_check.tscn/.gd (dev tool, WINDOWED: a CONTACT SHEET
  of 16 frames of the secret-folder guasto in the real room
  through the CRT - a glitch is judged over time, one photo
  misses the burst - with the burst state and the title printed
  per frame; "-- sbagliato" films the rejection instead),

- debug_panel_test.tscn/.gd (the F12 keys panel must follow the run:
  no panel in the menu, fresh data on restart, closed on death;
  real F11 toggles ONLY the room threats and F8 ONLY the PC ones,
  both shown in the panel; and the panel stays ENGLISH over 6
  seeds x both game languages - no word of the old Italian notes.
  Sabotaged by putting one Italian note back: red. Plus the BUTTONS:
  a REAL and a FALSE for every apparition and one for every virus,
  none takes the focus, outside the room a button answers "refused:
  not in the room", and "-" collapses the panel to the keys while it
  stays on the right edge. The buttons in the REAL room are in
  virus_test, section 4b),

- boot_test.tscn/.gd (the 3-stage PC boot: stage order, keys and
  clicks must NOT skip it, and a power-off mid-boot must cancel the
  chain; also saves a screenshot of each stage under user:// -
  windowed),

- selection_ghost.gd (SubViewport selection gate, windowed),

- pause_test.tscn/.gd (P pauses: it instances the real room and
  pushes keys through Input.parse_input_event, so it tests the
  wiring and not the functions - and it pins the case that makes the
  key usable at all: with the focus in an OS text field, "p" must
  type, not pause. Saves a screenshot under user:// - windowed),

- page_load_test.tscn/.gd (the per-page loading wait: the veil must
  cover the page and take the mouse, the status bar must name the
  domain and count the SAME KB the wiki lists, the progress bar must
  fill, the wait must be short AND random (4 loads of one page must
  not all be equal), "stop" must reveal at once, and navigating
  mid-load must not leave the veil hanging - headless),

- web_key_inject.tscn/.gd (the web keys' POSITION over 60 seeds -
  everything below holds for EACH of the two, plus: always two
  DIFFERENT sites, all four mode pairs show up; a carrier is any page
  of a site of the run. The old PRIMA_CHIAVE_INVARIATA (8 pinned seeds)
  was dropped on 2026-10-19: the catalog grows in batches and every
  new site changes every seed's draw - RIPRODUCIBILE is what keeps
  "same seed, same run". Sabotaged: both on one site, the second never
  injected - red;
  headless: the declared mode must hold — visible => readable on
  screen, source-only => absent from the render but present in the
  HTML; the page must render IDENTICALLY apart from what was added
  (prefix/suffix diff on the compiled BBCode); position stable across
  reloads, reproducible from the seed, and VARIED — all 10 kinds show
  up, ~52 distinct spots over 60 seeds),

- browser_chrome_test.tscn/.gd (the browser's CHROME: the menu
  bar opens real dropdowns, every dropdown has working AND disabled
  items, "Preferiti" lists the run's sites and navigates,
  back/forward/stop reflect the real state, and no enabled button
  is left without a callback - headless),

- taskbar_test.tscn/.gd (the taskbar like Win95: one window must
  NOT fill the bar, buttons shrink together as windows pile up,
  never below the minimum, and past that the spinner appears and
  scrolls them - plus, at every count, the shown buttons must fit
  INSIDE the bar, which is the "they run off the screen" half of
  the report). Section 6 (_prova_volume, 2026-10-23): the tray speaker icon exists,
  its popup opens above the taskbar, Mute really mutes bus "PC" and swaps the icon to
  "speaker_muto", the slider sets the volume, a click outside closes the popup),

- finestre_contorno_test.tscn/.gd (WINDOWED - it reads pixels.
  The Win95 DRAG OUTLINE: while the bottom edge is being pulled the
  window must NOT change size, the outline must promise the right
  geometry and the release must land EXACTLY there - if the two
  differed the outline would be a lie. The outline must be
  TRATTEGGIATO in the pixels, with ink and alternations measured
  SEPARATELY, or a pattern gone solid would be reported as "nothing
  drawn", a different defect (both sabotaged). And it must survive
  the DOWNSCALE: the image is actually reduced to 2/3, as the game
  does before the CRT, and the border must still oscillate - 1.00
  with 2 px blocks against 0.25 with 1 px, which is what makes the
  block size a measurement instead of a claim in a comment. Plus:
  the outline never promises a geometry outside the screen, the
  layer sits above the windows and ignores the mouse, and BOTH
  switches are flipped for real),

- finestre_confine_test.tscn/.gd (windows must stay INSIDE the
  4:3 screen: dragged past any of the four borders they stop at the
  border - at the bottom that means ABOVE the taskbar, since under
  it a window is just as gone - resizing an edge stops there too
  while the opposite edge must NOT move, one bigger than the screen
  sticks to the top-left, and maximize still fills exactly that
  area. The drags are REAL events pushed into the SubViewport, not
  calls to the internals, or it would test the arithmetic instead
  of the behaviour - headless),

- rinomina_test.tscn/.gd (WINDOWED - the system clipboard does not
  exist headless. RENAME through the REAL path: the room, inside
  the PC, keys pushed into the real input queue so they cross
  player.gd. The case it exists for, end to end: F2 on the folder
  holding the run key, only the code selected, CTRL+C puts it on
  the clipboard, ESC cancels WITHOUT leaving the PC, and CTRL+V in
  row 1 of the secret dialog pastes exactly that code (it starts
  from the first seed >= 8080 where key 1 is a FOLDER, since it is
  one only half the time; the clipboard is polled for a few frames,
  Windows updates it late now and then). Plus: Enter
  applies and the icon stays selected under the new name, a "p"
  typed in the box is a letter and not the pause, banned
  characters vanish while typing, a duplicate name (case-
  insensitive) is refused with a dialog that ESC closes while
  staying in the PC, an empty name changes nothing, a click
  outside confirms, the protected things are refused in the rule,
  in the menu (grey) and on F2 - and the Desktop is still found
  afterwards - the desktop has its own Rename and F2, plain ESC
  still leaves the PC, and the new strings exist in both
  languages),

- virus_test.tscn/.gd (WINDOWED - it reads pixels. The three PC
  VIRUSES in the real room with the real VirusDirector; the Jester
  is stopped and the test runs the virus clock itself (avanza), so
  minutes pass in a loop. Pacing: none before PRIMO_VIRUS, none
  with the player in the room or just back in, none over a
  dialog, F8 freezes the clock (F11 does not), the pause after one is inside
  PAUSA_MIN..MAX, never the same twice in a row and all three come
  up. LETHAL: it carries an apparition that stays and grows, the
  Jester does not peek meanwhile, and powering off saves from BOTH
  Start > Shut down and the case button (no death, apparition,
  clock and window offset all gone). YouAreStupid: the burst opens with the translated
  title and taskbar buttons, the bouncers move and never leave the
  screen, it CANNOT BE IGNORED (always above a clicked normal
  window, three title buttons but "minimize" disabled - a real
  click on it and the taskbar button both leave it up, while a
  normal window keeps its own - focus taken
  from Notepad, more arrive when left alone), the X closes a window
  that is MOVING (press, half a second at 500 px/s, release on the
  same spot), closing spawns more but never past the caps, it ENDS,
  and power-off closes it for good. BLUE SCREEN: on top, blue IN
  THE PIXELS (the check that caught the anchoring bug - see §7),
  eats clicks AND keys (none closes it), shows a translated
  countdown that goes down, ESC through player.gd leaves the PC
  while it carries on, and when it runs out the PC REBOOTS BY
  ITSELF: every window closed, black first, then the BIOS, then
  the login; the real F9 opens it; no placeholder or key-shaped
  text. Plus: stop() on win,
  both languages, the "virus" death lines; the APPARITIONS - each
  of the SEVEN shows as a false alarm (wallpaper veil, the child
  visible IN THE PIXELS along his axis, eyes, clock off the real time, a
  translated line, blood flowing between windows and taskbar,
  windows moved) and then vanishes COMPLETELY
  (no layer, clock back, windows at 0); the four SMALL ones stay
  under the icons with the true names; the darkness covers the WHOLE
  screen - the taskbar, and the Start menu and the Shut down dialog
  opened AFTER it, darker in the pixels, mouse ignored
  (BUIO_TUTTO_LO_SCHERMO) - and flickers like a dying bulb: never
  brighter than its usual, drops nearly to black, SMOOTH (no step
  over 0.25 between frames), never more than 3 drops in any second
  (BUIO_LAMPADINA) - sabotaged (a plain desktop child, a light with no
  inertia): red; the red flashing is GONE
  (NIENTE_LAMPEGGIO, and PESI aligned with TIPI); the child is made
  of ASCII characters that CHANGE while he sways (BAMBINO_ASCII),
  all BLACK (BAMBINO_NERO), DETAILED (hair darker than the face, a
  dark line at the shirt hem, darker than the torso -
  BAMBINO_DETTAGLI) and with NO HALO (inside the cells he occupies
  the wallpaper still shows between the strokes -
  BAMBINO_SENZA_ALONE); the line TYPES itself letter by letter with
  a cursor (SCRITTA_DIGITATA) and has no smear behind
  (SCRITTA_SENZA_FONDO); the eyes are white AND dark characters and
  the pupil follows where they look and hides when they blink
  (OCCHI_REALISTICI) - sabotaged (typing at once, no recomposing,
  the dark pool back, tone = coverage, a pupil that does not
  follow): red; the real blood at
  20 s has drips of different reach - some short, some long - and
  a falling drop (SANGUE_VARIO); real and false
  start identical (a small and a grave type); the real one is
  still there, same type, at 3 s and 20 s; power-off removes it,
  the clock and the window offset; the director's false alarm ends
  by itself and schedules the next in FALSO_MIN..MAX, the real
  virus waits DOPO_FALSO, never over another virus, and the real
  SHIFT+F9 starts one (sabotaged: a small one over the windows,
  a false one lasting too long, a real one
  vanishing, the shake not reset - all red); and LAST, because it
  ends the run, the lethal one left alone KILLS with cause
  "virus". Sabotaged: virus clock counting in the room, no caps on
  YouAreStupid, power-off not saving, a moving window not freezing
  under a held X, normal windows rising above the virus,
  minimizing allowed, no insistence, no focus theft, and on the
  blue screen a key that closes it, a countdown that never ends,
  ESC held by the OS - all red. THE DEBUG PANEL in the real room
  (4b): every REAL/FALSE button starts exactly that apparition and
  "Stop current" removes it, YouAreStupid and the blue screen start
  and stop, a refusal says why (PC threats off), the switch works,
  the Jester peeks and goes away on command, and a REAL click inside
  the PC on a panel button over a window does NOT reach that window
  (sabotaged by removing player.gd's guard: red). Saves
  virus_apparizione_<type>, virus_vero_buio/sangue, virus_stupido,
  virus_blu and debug_pannello .png under user:// to look at),

- os_finestre_test.tscn/.gd (window focus and input: a MINIMISED
  window must stop taking input - with the browser minimised, a
  right click where the page had been must open the DESKTOP menu,
  and it clicks exactly on the remembered page centre, since
  anywhere else the browser would not have stolen it and the test
  would prove nothing; minimising the FRONT window must hand focus
  to the one behind, which must then answer a right click with no
  left click first; and with two windows visible, a right click on
  the inactive one must activate it AND open its menu in one go),

- browser_e2e.tscn/.gd (real browser + real pages + key, windowed). 2026-10-23: the site
  balena became treno (check TRENO, was the balena one: treno/thoughts and treno/update).
  The same rename in browser_chrome_test (treno/index), page_load_test (four openings of
  treno/index), siti_catalogo_test (the address cases `www.webnet.it/~trenoperso...`) and
  the siti_check sample pages.
  NOTE for browser_click_test: finding "a point on a glyph" from
  the pixels is where this test kept breaking when the chrome grew,
  and each fix is a different trap. It locates a glyph by LOCAL
  CONTRAST (not by differing from the page background, or a coloured
  cell passes as text), and additionally demands: at least 3 SEPARATE
  strokes on the row (a row crossing a cell or banner BORDER has
  contrast on every pixel, and the cursor is rightly an arrow on a
  line); the pixel with the STRONGEST contrast of the row, i.e. a
  stroke centre (the median match could sit 1-2 px beside a letter,
  where the text mask still says "text" but a double click finds no
  word); and a NEUTRAL colour (links are blue, and a first click on a
  link navigates, so the second click had nothing left to select).
  Offsets are counted from the page's real top ("salta" = pixels
  INSIDE the page), never as screen coordinates - two hardcoded
  heights broke when the chrome grew.

