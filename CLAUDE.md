# CLAUDE.md

The short map every session loads. **The detail is in [docs/code/](docs/code/README.md)**,
one file per area: read the one for the area you are about to touch, not all of them.

## 1. What this project is

**Search Through the Files**: a first-person horror game in **Godot 4.6.1** (Forward Plus).
*Five Nights at Freddy's* (watch the room, survive) meets *Welcome to the Game* (dig through a
fake Win95/98 OS). The player sits at a desk and hunts **4 keys** hidden in the PC - on the disk,
on two web sites, in a photo - to open a protected folder, while enemies threaten **both the room
and the PC**. Every run randomizes the disk, the sites (10-15 of 40), the keys and their places.

**The story** (GDD §2b): Noah finds the old PC of his **father** and switches it on alone one
night (2022). The PC carries a curse started by a lonely young man who hanged himself; it
possessed the father, who killed his wife and attacked Noah's brother (spring 1999). **Every
in-game text follows [docs/GDD.md](docs/GDD.md) §2b**; what is OPEN there (names, how the curse
passes) is written around, never invented. Build order: [docs/ROADMAP.md](docs/ROADMAP.md).

## 2. How to run and validate

```powershell
$godot = "C:\Users\ffria\Desktop\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
$proj  = "z:\Progetti\Search Through the Files"
& $godot --headless --path $proj --import                                   # parse everything
& $godot --headless --path $proj "res://tests/<name>.tscn"                  # a headless test
& $godot --path $proj "res://tests/<name>.tscn"                             # a WINDOWED test (reads pixels)
& $godot --headless --path $proj -s res://tests/html_bb_test.gd             # a script test
```

- **Run tests through the `godot-tester` agent** (it returns only PASS/FAIL and the failing
  lines). Which test covers what, and which ones are windowed: [docs/code/TESTS.md](docs/code/TESTS.md).
- **A scene test whose script does not COMPILE hangs forever** (its timeout lives in `_ready`).
  Silent test = run `--import` and read the parse error (usually rule 3 below).
- In a `-s` script, `_initialize()` must `get_root().add_child(...)` then `await process_frame`.
- Sabotage new checks: break the code on purpose, require red, restore.
- After touching the browser, the HTML compiler or many pages, run `siti_audit_test` (headless, ~13 min, every page of every site).
- **Do not commit or push unless asked.** `docs/`, `web/` and `CLAUDE.md` are tracked: commit their changes too.

## 3. Architecture in one picture

```
Main Menu (main_menu.tscn) ─ Start ─► Room (main.tscn)
   ├─ Camera3D ← player.gd (look around, click, torch, enter/exit PC)
   ├─ Monitor + MonitorScreen (quad showing the OS viewport live)
   └─ spawned by player.gd:
        ├─ SubViewport 1440×1080 ── OSDesktop (desktop.gd): the whole fake OS
        ├─ CanvasLayer "PCLayer" ── fullscreen CRT overlay (only when "inside")
        └─ ThreatDirector (room enemies) + VirusDirector (PC viruses)
```

The OS renders once; the room samples it for the monitor and the overlay. Inside the PC, input
is forwarded with `push_input()` and the cursor shape comes from `cursor_shape_at(pos)`.
`GameManager` (autoload) holds what survives scene changes: run state, keys, language, debug
switches. Overlay layers: PC view 10, win 20, debug 30, death 50, pause 60, FPS counter 70 (debug builds only). Full data flow:
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## 4. Where things live

| Working on... | Read first |
|---|---|
| GameManager, room/player, menus, pause, death, F12 panel, CRT, translations | [docs/code/CORE.md](docs/code/CORE.md) |
| desktop, taskbar, boot, windows, icons, rename, VFS, Explorer, Notepad | [docs/code/OS.md](docs/code/OS.md) |
| browser, HTML compiler, sites, web keys, portal | [docs/code/WEB.md](docs/code/WEB.md) + WEB_AUTHORING / WEB_SITES / WEB_CATALOG |
| random disk, key map, secret folder | [docs/code/CONTENT.md](docs/code/CONTENT.md) + DISK_CONTENT |
| the photo key, image viewer, adjust.gdshader | [docs/code/PHOTO_KEY.md](docs/code/PHOTO_KEY.md) |
| Jester / HaloMan / Ghosty / torch, PC viruses, apparitions | [docs/code/THREATS.md](docs/code/THREATS.md) |
| tests | [docs/code/TESTS.md](docs/code/TESTS.md) |
| vocabulary, Italian names in the code | [docs/code/README.md](docs/code/README.md) |

```
project.godot            autoload GameManager; "pause" action; translations (fallback "en")
locale/ui.csv            THE translation table (keys,en,it): every player-facing string. --import after editing
scenes/                  main_menu (main scene), main (room), room (shell+furniture), corridor, window_left, enemies/*, fade_transition,
                         ComputerMode (DEV-ONLY OS harness, not in the live flow)
scripts/
  GameManager.gd         run lifecycle, keys, language, debug switches, F8-F12 dev keys
  player.gd              the room: camera, clicks, torch, enter/exit PC, ESC/P handling
  main_menu.gd, options_screen.gd, pause_screen.gd, death_screen.gd, crosshair.gd, nav_arrow.gd
  debug_panel.gd         the F12 DEBUG PANEL (dev-only, English): keys, status, buttons for every threat, "All sites"
  threats/               threat_director (room enemies + torch), virus_director (PC viruses),
                         nemico_affaccio + jester + halo_man (peeking enemies), ghosty
  os/                    the fake OS:
    desktop.gd             desktop, taskbar, Start menu, window manager, boot/login/shutdown, modals
    os_window, os_item, os_icon, glyph_button, win95, stylebox_win95   windows, icons, Win95 chrome
    vfs.gd                 virtual filesystem (Dictionaries) + rename rules
    content.gd             random disk + keys 1 and 4 + photos;  catalogo_disco.gd = its data
    app_browser, page_view, html_bbcode   the browser (one RichTextLabel per page)
    gif_decoder, web_effetti, midi, midi_synth   page GIFs, marquee/blink, MIDI music (GDScript synth)
    web_runtime, web_anchor   run's sites, portal, keys 2 and 3;  catalogo_siti.gd = the 40 sites
    app_file_explorer, app_notepad, app_image_viewer   the other apps
    apparizione, virus_mortale, virus_stupido, schermo_blu   PC threats
    audio_pc.gd            audio bus "PC": tray volume/mute, sound from the desk in the room
    secret_glitch.gd       the secret folder's glitch
    crt / adjust / glitch / secret_glitch .gdshader
assets/                  fonts (Arimo, Cousine), textures (3D models, photos)
web/pages/<lang>/<site>/<page>.html   the 40 sites, one folder each, EN + IT; img/ = page images
tests/                   tests + dev photo tools (siti_check, ascii_check, icone_check...)
tools/web/               sito.py (site generator + checks), registra.py (add a site to catalog + CSV)
.claude/agents/          the sub-agents (see §8)
docs/                    GDD, ROADMAP, ARCHITECTURE, recipes, docs/code/ (the detail)
```

## 5. Conventions you MUST follow

Full text with the reasons: [docs/code/README.md](docs/code/README.md).

1. **UI is built in code**, not in `.tscn` (see `desktop.gd`).
2. **Icons and chrome are drawn** (`os_icon.gd`, Win95 bevels), not imported.
3. **Strict typing:** never infer `:=` from a `Variant` (`min`/`max` return Variant): write
   `var x: float = min(a, b)` or use `minf/maxf/clampf`.
4. **Code comments in Italian**; docs and this file in English.
5. **The VFS is plain Dictionaries**; never serialize `_parent`, use `VFS.path_of()`.
6. **Cross-scene state goes in `GameManager`**, not in statics expected to reset per run.
7. **Reuse `Win95`** for colors (`Win95.C_*`), Theme and styleboxes.
8. **No player-facing string in code:** every one is a key in `locale/ui.csv` (`tr()`, or
   `TranslationServer.translate()` / `_t()` in static code; `\n` read with `_testo()`). A web page
   is a file per language. Exceptions: code comments, and **dev-only text (F12 panel, test
   output), which is always ENGLISH**. `--import` after editing the CSV.
9. **Menu-bar labels carry their accelerator as `&`** in the CSV; ALT+letter must open it
   (`Win95.menubar_button` / `premi_acceleratore`); strip it elsewhere with `Win95.testo_semplice()`.
10. **Web sites** (rules in [docs/WEB_CATALOG.md](docs/WEB_CATALOG.md), enforced by
    `siti_catalogo_test`): a site is closed in itself (links only inside it, to the WebNet portal
    or to dead addresses in `morti`); forms stay inside the site (they work; scripts answer 500); no footer link back to WebNet; dates absolute and not
    after 1999. Everywhere: **no text shaped like a key** (digit, dash, 4 letters/digits).
11. Every chrome button either works or is visibly disabled; a dead button is a bug.

## 6. Current state

Implemented (details in the area docs):
- Menu → room → OS flow; boot (BIOS, splash, login - password `123`, not skippable), desktop,
  taskbar, Start menu, shutdown; pause (P); options with the language (EN/IT, saved).
- Window manager (outline drag/resize, clamped to the screen), Explorer, Notepad, Recycle Bin,
  rename (F2, copyable names), browser (selection, links, view-source, loading wait), image
  viewer with sliders.
- Random disk per run; 4 keys (disk / two sites / photo) and the secret folder that wins.
- 40 web sites (24 ordinary, 16 lore), 10-15 per run, generated WebNet portal.
- Room threats: Jester, HaloMan, Ghosty, held torch with battery.
- PC threats: lethal apparitions, false alarms, YouAreStupid, blue screen.
- Game over with per-cause lines; F12 debug panel (dev-only) with every threat on a button.

NOT implemented yet: real enemy models/animations (placeholders, owner's art comes last); the final
3D room (today a furnished starter room from primitives + owner's models); sound; options beyond language; the planned ending (GDD §2b); other PC threats
(self-opening windows, corrupted files, hunting cursor). Cut on purpose: PC session persistence.
"Continue the game" = the next item in ROADMAP.md.

## 7. Known traps (full text in docs/code/README.md)

- A SubViewport fed by `push_input` gets no mouse-MOTION events until
  `notify_mouse_entered()` (player.gd `_set_os_mouse_in`; tools and tests must do the same).
- A full-screen `Control` defaults to `mouse_filter = STOP` and steals the room cursor: keep
  room overlays `IGNORE`.
- The room opens with a 1 s fade from black: a screenshot earlier than ~1.6 s measures the veil.
- `set_anchors_preset()` on a node already in the tree keeps its size: use
  `set_anchors_and_offsets_preset()`.
- An app reading global `_input` keeps receiving it while minimised: check `is_visible_in_tree()`.
- player.gd reaches room nodes by relative path; the monitor's desktop is drawn on the MODEL's
  own screen triangles (`_vetro_del_modello`, found by their atlas UV rect); the hidden node
  `test-schermo` only gives the orientation (and the flat-quad fallback).
- Never hand-edit UIDs; `.godot/` is cache.

## 8. Working with Claude on this project (saving tokens)

- **One chat per task.** Continuity lives in this file, the memory and docs/, not in an old
  chat. `/clear` between tasks, `/compact` when a chat gets long, `/effort medium` for routine.
- Read only the area doc you need. After a change, **docs-keeper** updates that doc.
- **Sub-agents** (`.claude/agents/`, they work in their own context and return a summary):
  - `godot-tester` (Haiku): runs `--import` and tests, reports only results. Use it for every test run.
  - `web-writer` (Sonnet): writes/fixes pages of the ORDINARY sites, runs the site tests.
  - `disk-writer` (Sonnet): adds/changes ordinary disk files, folders, programs.
  - `docs-keeper` (Sonnet): updates docs/code/ (and one line here) after a change.
- **Lore texts and design decisions stay in the main chat**, never in a sub-agent.
