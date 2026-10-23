# The fake OS: desktop, windows, icons, VFS, Explorer, Notepad

Read before touching anything in scripts/os/ that draws or manages the OS itself (not the browser, the content generator or the threats).

Moved here from CLAUDE.md on 2026-10-22, word for word (CLAUDE.md now keeps only a one-line map).

## Files

### `scripts/os/`

THE FAKE OPERATING SYSTEM (this is the heart of the game):
WINDOW INPUT, a trap worth knowing (fixed 2026-09-19): an app
that handles _input (GLOBAL input, not _gui_input) keeps
receiving events when its window is MINIMISED - the window is
only hidden, its nodes stay in the tree with the same
coordinates. BrowserApp takes the right click that way (so it
works without the page holding focus) and was calling
set_input_as_handled(), so with the browser minimised a right
click WHERE THE PAGE HAD BEEN was eaten and the desktop menu
never opened - _input runs BEFORE gui_input, so the wallpaper
never saw it. Two halves: _on_window_min now also calls
set_active(false) (hiding a window used to leave it "active"),
and such a handler must check is_visible_in_tree(), not just
window.active.
The same rule has a SECOND half, reported the next day: after the
front window goes (minimised, closed, or hidden from its taskbar
button) the desktop used to be left with NO active window - a
state Win95 never has - so the window behind was visible but
"off" and right-clicking it did nothing until you left-clicked
first. _attiva_finestra_sotto() now promotes the topmost visible
window in all three paths (children order in window_layer IS the
z-order: the LAST visible one is in front).
And a right press now FOCUSES the window under the cursor too,
not just a left one - but an app that reads global input cannot
test window.active for that, because _input runs BEFORE the
desktop assigns focus, so the first right click would always be
spent on focusing. Ask desktop.finestra_sotto(point) instead: it
is true immediately AND respects the z-order, so a covered window
cannot steal a click. Hence BrowserApp has two guards on purpose:
_in_primo_piano() for the KEYBOARD (focus decides) and
_sotto_il_mouse() for the MOUSE (the cursor decides).
Test: os_finestre_test.tscn.

### `scripts/os/desktop.gd`

OSDesktop: desktop, TASKBAR, Start menu, window manager,
mostra_contorno/nascondi_contorno = the dotted DRAG OUTLINE
layer (2026-09-21), the LAST child of the desktop so it covers
the windows, and mouse_filter IGNORE - if it took the mouse it
would eat the very drag that is moving it. See os_window.gd.
apri_informazioni(titolo, icona, righe) = the shared ABOUT
dialog (2026-09-21, owner: "mettila sempre al centro dello
schermo"). It lives HERE and not in the apps because each app
used to draw its own inside its own window, reusing the menu
dropdown: the box then moved with the window - maximized in one
place, small in another, and clipped by the border in a narrow
one. _make_modal already centres on the OS screen
((size - dlg) * 0.5) and puts the layer on the DESKTOP, so no
window can clip it. It is a real period dialog: title bar, the
program's icon, name, version, copyright, OK - and its WIDTH
comes from the longest line measured with the real font, because
at a fixed 430 px the copyright was cut mid-word. ESC closes it
(_modal_chiudibile): login and the secret folder are NOT in that
variable, because there ESC is the way out of the PC.
TASKBAR BUTTONS behave like Win95 (2026-09-19): they have a
MAXIMUM width (TASK_MAX_W) and only shrink as windows pile up,
down to TASK_MIN_W. They used to be SIZE_EXPAND_FILL, so a single
window took the whole bar - the thing that gave the theme away
fastest - and many windows ran off the edge. Below the minimum,
the period UP/DOWN SPINNER appears at the right of the task area
and the buttons scroll one at a time; titles that do not fit are
trimmed with an ellipsis instead of widening the button.
_disponi_barra() does the whole layout and needs TWO guards:
a re-entrancy flag (it changes widths, which re-runs the layout,
which re-emits "resized" - without it the game locks up) and the
available width must be computed as tasks_box.size.x PLUS the
spinner when it is showing, or showing the spinner shrinks the
area, which hides the spinner, which grows it back.
Test: taskbar_test.tscn.
TRAY VOLUME (2026-10-23, owner: "mettere un bottone per mutare la pagina,
la musica sempre accesa puo' dare fastidio - come si faceva all'epoca?").
Period answer: 1999 browsers had NO sound button; you left the page, or
(IE) pressed Esc, or clicked the Windows SPEAKER ICON in the tray next to
the clock (slider + "Mute"). We built exactly that: the clock panel holds a
flat Button (_btn_volume) left of the clock with an OSIcon (_icona_volume,
kinds "speaker" / "speaker_muto"). Click -> _apri_volume builds _volume_pop
above the taskbar: a VSlider (volume 0-100) and a CheckBox "Mute"
(TRAY_VOLUME / TRAY_MUTE in the CSV); both go through AudioPC
(imposta_volume / imposta_muto) and the icon follows AudioPC.muto(). A click
outside the popup (and outside the button) closes it, in desktop _input next
to the Start-menu close. Esc was NOT used for muting because Esc leaves the
PC. Values live in GameManager (pc_volume, pc_muto), see CORE.md and
scripts/os/audio_pc.gd. Test: taskbar_test.tscn section 6 (_prova_volume).
The popup is sized on its CONTENT (VBox minimum size + VOLUME_MARGINE): with
a fixed 110 px "Disattiva" ran out of the panel (owner, 23/10/2026: "ci sono i
pulsanti che escono dalla tab... stile uguale al resto dell'OS"). Slider and
checkbox look Win95 because the THEME now styles them (Win95.make_theme:
HSlider/VSlider = sunken thin channel + raised tile icon _tex_rilievo;
CheckBox = sunken white square with a black tick _tex_casella, no button
frame) - which also restyled the image viewer's sliders. Eyeball tool:
tests/vassoio_check.tscn (windowed).
boot/login/shutdown/"no signal" states. The BOOT is a period
3-stage sequence, not a loading bar (see _play_boot): BIOS POST
text screen (live memory count + a System Configuration table)
-> "Avvio di ... in corso" on black -> splash with the bar that
SWEEPS (a Win95 wiper, it never fills) -> login. It is one
coroutine: durations are the BOOT_* consts and _boot_token
cancels the chain if the case is switched off mid-boot (otherwise
the tail of the sequence would write into freed overlays and open
the login on a powered-off PC). It is deliberately NOT skippable
(owner's call) - _input ignores everything while _booting, so a
stray click can't cut the atmosphere short; ESC still leaves for
the room without interrupting it. Fake vendor names only.
Test: boot_test.tscn.

### `scripts/os/vfs.gd`

VFS: the virtual filesystem (a tree of Dictionaries) + Trash.
get_desktop() resolves C:\WHALE\Desktop (where Win95 kept it),
not a Desktop folder in the root of C:.
RENAME (2026-10-18): rinominabile(node) is THE rule, shared by the
desktop and the Explorer - NOT the protected folder, NOT the
children of the root (drives A: C: D:, the Recycle Bin), NOT what
sits in the Recycle Bin, and NOT the chain to the Desktop: it is
the one lookup BY NAME the game does while playing, so renaming
WHALE or Desktop would empty the whole desktop. Everything else
yes, system folders like SYSTEM included (nobody looks them up,
and Win95 let you). rinomina(node, name) refuses Windows' banned
characters and a name already in the folder CASE-INSENSITIVELY,
as on a Windows disk ("foto" -> "Foto" is fine).

### `scripts/os/win95.gd`

Win95: shared palette, Theme, 3D-bevel helpers, THE CHROME PIECES
(2026-09-20: tool_button / fade / strip / grip / menu_separator;
2026-09-21: menubar_button / testo_semplice /
premi_acceleratore, tratteggio / contorno)
and the period
FONTS — Win95.font("sans"/"sans_b"/"sans_i"/"sans_bi"/"mono") from
assets/fonts/, wired in make_theme() as default_font + the
RichTextLabel normal/bold/italics/bold_italics/mono slots (cell
separation 0 = cellspacing="0").

### `scripts/os/stylebox_win95.gd`

StyleBoxWin95: custom StyleBox that draws the Win95 bevel.

### `scripts/os/os_window.gd`

OSWindow: draggable/resizable window with title bar.
IT CANNOT LEAVE THE SCREEN (2026-09-20, owner's request "come
quando usi un pc nella vita reale"): area_utile() is the screen
MINUS the taskbar - the same rect maximize fills, so a window
pushed into a corner and a maximized one stop at exactly the
same line - and drag (_dentro) and resize both clamp to it, the
dragged edge stopping while the opposite one stays put (or the
window would slide while you widen it). assesta() puts one back
inside: open_window calls it, and so does restore-from-maximized.
A window bigger than the screen sticks to the TOP-LEFT: the title
bar is its only handle, so it is the right edge that is sacrificed.
Why at all: the monitor is a fixed 4:3, there is no second screen
and no scrolling desktop, so whatever goes past the border cannot
be brought back with the mouse. Before, a drag could leave just
40 px on screen and a RESIZE had no limit whatsoever (measured by
the test's sabotage run: right edge at 3900 on a 1440 screen).
Test: finestre_confine_test.tscn.
ONLY THE OUTLINE MOVES (2026-09-21, owner's request: the Win95
look): dragging or resizing a window shows a DOTTED RECTANGLE and
the window jumps to the new geometry on RELEASE - i.e. Win95 with
"show window contents while dragging" OFF, which was the default.
_rect_resize() is therefore a CALCULATION and no longer an effect
(it returns the clamped Rect2), so the outline is computed by the
same code that the release applies: the outline cannot promise a
geometry the release would then correct, which on screen would
read as a jolt. The rectangle is drawn by the DESKTOP
(OSDesktop.mostra_contorno / Win95.contorno), not by the window:
the window has clip_contents and the outline leaves it on every
side, and in Win95 that rectangle was painted on the SCREEN, so it
passed over the other windows. Two STATIC switches
(CONTORNO_RIDIMENSIONA / CONTORNO_SPOSTA, like the browser's
ATTESA_ATTIVA) because the original treated the two as one
setting; both false = the old live behaviour, and a window built
WITHOUT a desktop also falls back to live instead of doing
nothing. Free side effect: a browser page no longer re-lays out
its tables on every mouse move, but once.
Test: finestre_contorno_test.tscn.

### `scripts/os/os_icon.gd`

OSIcon: every icon, drawn procedurally in _draw() (no PNGs).
"floppy" / "hdd" / "cdrom" are the three UNITS of My Computer and
"exe" is a program without its own icon (a little window with a
blue title bar): with the folder icon on all of them, that first
window would not look like anything. Same LOD rule as the whale:
under 24 px the small details (label lines, the drive LED, the
window buttons) are dropped instead of turning to mush.
"whale"/"whale_pale" (pale = for the dark Start-menu stripe) is
the SYSTEM LOGO, a 52-hz-whale side profile - NOT a Windows flag
(see _whale): huge blunt head + mouth line, no dorsal fin, thin
peduncle, spout. It must survive 18-26 px, so eye and mouth are
dropped under 24 px and the spout drops to 2 thicker jets under
30 px. "win" stays as an alias of "whale".
"speaker" / "speaker_muto" (2026-10-23, _altoparlante(w, h, muto)) = the tray
volume icon; the muted one is the same speaker drawn muted.

### `scripts/os/audio_pc.gd`

AudioPC (class_name, RefCounted, all static; 2026-10-23): the PC's speakers.
Owns the audio bus "PC" -> Master, created AT RUNTIME the first time it is
needed (the project has no default_bus_layout.tres), with three effects in
this order: Panner (FX_PAN), LowPassFilter (FX_PASSA_BASSO), Reverb
(FX_RIVERBERO). Everything the computer plays goes through it (today the web
page music: BrowserApp._musica.bus = AudioPC.bus()).
- imposta_volume / imposta_muto / volume / muto: backed by
  GameManager.pc_volume (0.8) and pc_muto, session-wide and NOT reset per run
  (whoever muted does not want it back next game).
- dentro(delta): inside the PC the sound is clean and centred (cutoff
  DENTRO_TAGLIO 20 kHz, no reverb). Owner, 2026-10-23: "quando sono nel pc va
  bene mono, ma poi deve arrivare da avanti, dal pc".
- nella_stanza(verso_monitor, delta): in the room the sound comes from the
  desk. verso_monitor = direction of the monitor in CAMERA space: pan from the
  side the monitor is on (x * STANZA_PAN 0.8), lowpass cutoff 5000 Hz facing
  (STANZA_TAGLIO_FRONTE) down to 1600 Hz with the back turned
  (STANZA_TAGLIO_SPALLE), -4 dB facing -> -9 dB behind, reverb wet
  STANZA_ECO 0.18.
- Smoothed (VELOCITA 6, cutoff interpolated in log scale) so the sound glides
  with the camera, also during enter/exit. stato() returns the current values
  for the tests.
Called every frame by player.gd (_aggiorna_audio_pc). Tests: web_media_test
section 6, taskbar_test section 6.
"web" (aliases "ie"/"globe") is the NETWORK icon - desktop, Start
menu, browser window, .html files and the throbber by the address
bar all use it. It was a light-blue "e" with a yellow orbit ring,
i.e. the Internet Explorer logo: the same borrowed-brand problem
as the Windows flag. Since 2026-10-18 (owner's pick, "globo a
rete") it is a period MAPPAMONDO: blue ocean, two invented green
continents (_TERRA_OVEST/_TERRA_EST, inside 0.85 of the radius so
the dark rim closes them without clipping) and over them the NET
of meridians and parallels - the browser is WebNet, the net is
its mark. Parallels are the FRONT arc of a flattened ellipse
(_arco_ellisse), which is what gives the sphere its curve. Grid
lines are thin and slightly transparent: solid and dense, the
first try read as a cage and buried the land. LOD: under 20 px
land + a straight equator; 20-27 adds the vertical meridian and
one meridian ellipse; 28-39 curved equator, two parallels and the
highlight; 40+ the full grid. Radius 0.40 of the box. (Before: a
two-line wire globe floating on two waterlines.) Look at it with
tests/icone_check.tscn -- web.
COHERENCE PASS (2026-10-18, owner: "rendere tutto coerente col
tema, non toccare quelle gia' perfette"): judged on the full
sheet (tests/icone_check), only six were redrawn - the FOLDER
tab now has its outline like every other icon (+ a light fold
line on the front), FOLDER_OPEN really opens (dark back, front
flap tilted forward; before it was the same folder, paler - and it
was never even SEEN: the Explorer's address box started with it
but _refresh put the closed one back at every navigation. Now the
folder being viewed shows it in the address box, the TITLE BAR
and the TASKBAR button, as in Win95, via OSWindow.set_icon; My
Computer and the drives keep their own icon. Test:
esplora_chrome_test ICONA_RISORSE / ICONA_UNITA / CARTELLA_APERTA), FILE
has its dog-ear cut INTO the page (it was a grey triangle hanging
outside the right edge), REFRESH and SEARCH scale their stroke
with the size (fixed 2.5 px = a thread at 48 px, and refresh read
as a "U" at 16) and the lens has glass + a dark handle, and
TRASH_FULL shows crooked sheets instead of three white balls.
Everything else was judged fine and left alone.

### `scripts/os/os_item.gd`

DesktopItem: selectable icon + label (desktop & explorer).
RENAME like Win95 (2026-10-18, owner: "cosi' posso copiare il
codice se si trova nel nome di una cartella o file"): the label
becomes a LineEdit with the whole name selected; Enter confirms,
ESC cancels, a click elsewhere confirms (the desktop's _input
does that - a click on something that takes no focus would not
take it from the box). It is a real LineEdit, so mouse selection
and CTRL+C work: F2 / select the code / CTRL+C / ESC copies a
name without changing it - the reason it exists, since the
FOLDER key lives in a folder NAME. Banned characters are dropped
WHILE typing (nothing typed is lost to a refusal at the end); the
engine's own right-click menu is off (English in every language,
and not Win95). Commits are DEFERRED: focus is lost DURING a
click, and redrawing the folder at that moment would hand the
click to an icon that is being freed. The item only emits
rinomina_finita; whoever owns it applies via
OSDesktop.rinomina_nodo, which also redraws EVERY open Explorer.
Entry points: context menu "Rename", Explorer File menu, F2
(Explorer: when its window is active; desktop: when no window
is). Test: rinomina_test.tscn.
The selection highlight FOLLOWS the label (_label
"item_rect_changed" -> queue_redraw): _draw() reads the label's
position, which at the first draw the container has not laid out
yet. A file created from the explorer is born SELECTED, so the
blue box landed on top of the icon and the (white) name vanished
on the light background - and stayed there, because nothing asked
for another draw (owner, 20/09/2026: "si vede in modo strano").
rett_selezione() also hugs the TEXT when the name fits on one
line, as Win95 did, instead of painting the whole cell width.

### `scripts/os/glyph_button.gd`

GlyphButton: the min/max/close title-bar buttons.

### `scripts/os/app_file_explorer.gd`

FileExplorerApp: navigates the VFS.
EVERY chrome button either works or is visibly DISABLED
(2026-09-20, owner: same treatment as the browser). The menu bar
opens REAL dropdowns (_voci_file / _modifica / _visualizza /
_strumenti / _aiuto, rebuilt on each open because what is enabled
depends on the moment); "Modifica" is entirely grey ON PURPOSE -
there is no clipboard for files in this OS and the selection is
one item at a time - and so are cut/copy/paste/properties/views
on the toolbar, which stay in place because an Explorer without
them is not credible (the same call as the browser's "Print").
Back / Up / Delete and the address arrow are driven by the REAL
state: Up is grey at the top of the tree, Delete without a
selection, the arrow when there is nothing above. _eliminabile()
decides what can go in the bin and closes a real hole: the
context menu used to offer "Delete" on ANYTHING, the protected
folder included - binning it made the run unwinnable - and on
the drives, which cannot be deleted either. The toolbar uses the
SHARED pieces in win95.gd, so a disabled button looks the same
here and in the browser.
TWO DEFECTS OF THAT FIRST VERSION, reported at once ("si e' rotto
tutto") and then MEASURED: the menu bar was a 26 px strip holding
31 px buttons, so the entries spilled 7 px onto the toolbar and
the two bars looked squashed together (the browser had the same
bug, 3 px) - the heights are now the shared Win95.MENUBAR_H /
ADDRBAR_H, sized from the real button height; and in a narrow
window the toolbar ran 29 px past the border, cutting the last
buttons in half - each app now sets the WINDOW's minimum width
from its own toolbar (_impone_larghezza_minima), so it cannot be
squeezed below what its chrome needs (Explorer 457, browser 552).
THREE MORE from playing it (20/09/2026): "About" did not open -
its entry calls _riempi_menu FROM INSIDE its own "pressed"
signal, and the old free() on the button that is emitting makes
Godot refuse ("Object is locked and can't be freed"), leaving the
dropdown half built; it is queue_free() + remove_child() now,
like the browser, and ANY entry that reopens a menu would have
hit it. "Large Icons" did nothing because it was the only view -
a fake entry with the air of working - so the SMALL ICONS view is
now real (_vista, _cella_w, the toolbar "View" button cycles the
two) and the dropdown marks the one in use, which is the answer
to "I clicked it and nothing happened". And a newly created file
was drawn wrong: see os_item.gd.
Test: esplora_chrome_test.tscn (WINDOWED: it reads pixels).
The icon grid REFLOWS with
the window (_aggiorna_colonne on the scroll's "resized"): the
cells had to grow to CELLA_W 132 because the system names are
8.3 uppercase and at 92 px "AUTOEXEC.BAT" wrapped in the middle
of its extension ("CONFIG.SY / S"), and with a FIXED column
count a narrow window then clipped the last column and grew a
horizontal scrollbar, which an icon view never had. Same
re-entrancy guard as the taskbar (changing the columns changes
the container's size, which can re-emit "resized").
Test: esplora_griglia_test.tscn.

### `scripts/os/app_notepad.gd`

NotepadApp: views/edits text files. An IMAGE shows its bytes
(OSContent.byte_dump) and a BINARY (filetype "bin") shows the
body it already carries: both READ-ONLY, because rewriting
random bytes must not be able to change game content.

## Feature notes

- The OS: a period **boot sequence** (BIOS POST -> "Avvio di ... in corso" on black ->
  splash with the sweeping bar -> login; ~6 s total, **not skippable** by design), login
  (password is hardcoded **`"123"`**), desktop icons,
  taskbar with clock, Start menu ("Avvio" + the whale logo; the blue stripe carries the
  system name sideways, period-style), shutdown dialog, "NO SIGNAL" screen.

- Window manager: open/focus/minimize/maximize/close, drag, resize from edges. Moving or
  resizing shows **only the dotted outline** and applies the geometry on release, as Win95
  did with "show window contents while dragging" off (`OSWindow.CONTORNO_RIDIMENSIONA` /
  `CONTORNO_SPOSTA` switch it back to live).

- Apps: File Explorer, Notepad (edit + save into the VFS), Browser (HTML→Control renderer:
  selectable text, clickable links, reflow, "Visualizza sorgente"), Trash
  (move to trash / restore-origin metadata / permanent delete).

- **Rename** files and folders like Win95 (2026-10-18): context menu, Explorer File menu or
  F2; Enter confirms, ESC cancels, a click elsewhere confirms. The box is a real text field,
  so a name can be **copied** (F2, select, CTRL+C, ESC) - which is how the folder key gets
  from a folder name into the secret dialog. Drives, the Recycle Bin and its contents, the
  protected folder and the path to the Desktop cannot be renamed (`VFS.rinominabile`).
