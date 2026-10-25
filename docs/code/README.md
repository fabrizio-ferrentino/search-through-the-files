# docs/code — how the code works, area by area

CLAUDE.md is the short map that every session loads. The detail lives here and is read
only when working on that area. Each file is the word-for-word text that used to sit in
CLAUDE.md (moved 2026-10-22), plus later corrections.

| File | Read it before touching |
|---|---|
| [CORE.md](CORE.md) | GameManager, player.gd (the room), main menu, options, pause, death screen, the F12 debug panel, crt.gdshader, the translation table, localization |
| [OS.md](OS.md) | the fake OS: desktop, taskbar, boot, windows, icons, items/rename, VFS, Win95 styling, Explorer, Notepad, the window-input trap |
| [WEB.md](WEB.md) | browser, page view, HTML compiler, site catalog, WebRuntime, web keys, page loading |
| [CONTENT.md](CONTENT.md) | content.gd (the random disk), catalogo_disco, the key map, the secret folder and its glitch |
| [PHOTO_KEY.md](PHOTO_KEY.md) | the image viewer, adjust.gdshader, everything measured about hiding the code in a photo |
| [THREATS.md](THREATS.md) | room enemies (Jester, HaloMan, Ghosty, torch), PC viruses, apparitions, the corridor/window/enemy scenes |
| [TESTS.md](TESTS.md) | what every test proves and how it was sabotaged |

Other docs: GDD.md (design and story, §2b is the lore every text follows), ROADMAP.md (build
order), ARCHITECTURE.md (data flow overview), DISK_CONTENT.md / WEB_AUTHORING.md /
WEB_SITES.md / WEB_CATALOG.md (the recipes for disk files and web pages).

## Glossary

### Game terms

| Term | Meaning |
|---|---|
| **Run** | One playthrough, from starting a game to win or game over. The disk, the sites (10-15 of 30), the keys and their places are drawn from the run seed. |
| **Room** | The 3D scene (`main.tscn`) where the player sits at the desk: the FNAF-style vigilance space. |
| **PC / OS** | The fake Win95/98 OS (`OSDesktop`) the player investigates. Entering the PC is a fullscreen overlay of the same viewport, not a scene change. |
| **Key** | A 4-character code shown with its index prefix (`2-7MC9`). Key 1 on the disk (a file's content or a folder name), keys 2 and 3 on two different web sites (visible text or HTML source), key 4 in a photo (pixels or the file's bytes). |
| **Secret folder** | The protected node (`type:"secret"`) on the Desktop; its "ACCESSO NEGATO" dialog takes the four codes, one unlabelled row each. Broken by `SecretGlitch`. Opening it wins. |
| **Jumpscare / game over** | `GameManager.game_over(cause)` -> `death_screen.gd` -> GAME OVER with per-cause lines -> menu. Causes: jester, halo, ghosty, virus, debug. |
| **Jester** | Peeks from a corridor door or the window; hold the torch on him 1-2 s. (Called Clown until 2026-10-19; the scene's UID still reads `b8clown4spook1`.) |
| **HaloMan** | Same spots, never with the Jester, only with the PC on; lighting him kills - switch the PC off. |
| **Ghosty** | From behind; advances while you do not look back, freezes when watched, vanishes in the torch light. |
| **Torch** | Held (press = on), with a battery; repels the Jester and Ghosty. |
| **PC viruses** | The lethal one (an apparition: power off within 10 s), YouAreStupid (window spam), the blue screen (reboots the PC). Plus false alarms. |
| **Apparition** | How the curse shows itself in the PC (`apparizione.gd`): the hanged child in ASCII, eyes, wrong clock, a typed line, darkness, blood, shaking windows. Brief = false alarm, lasting = real. |
| **Site / catalog** | The 40 authored sites (`catalogo_siti.gd`, one folder each under `web/pages/<lang>/`); 24 ordinary, 16 lore. |

### Code terms (and the Italian names in the code)

| Term | Meaning |
|---|---|
| **VFS / VFS node** | The in-memory file tree (`vfs.gd`); a node is a Dictionary `{ name, type, icon, ... }`, `type` in folder / file / app / secret. Never serialize `_parent`; use `VFS.path_of()`. |
| **OSContent** | `content.gd`: builds the random disk from the seed and places keys 1 and 4. |
| **WebRuntime** | `web_runtime.gd`: picks the run's sites, generates the portal, injects keys 2 and 3. |
| **OSDesktop / OSWindow / OSIcon / DesktopItem** | The OS controller, a Win95 window, a drawn icon, an icon+label on the desktop or in Explorer. |
| **Win95 / bevel** | `win95.gd`: palette `C_*`, Theme, the raised/sunken borders. |
| **SubViewport (OS) / PCLayer / MonitorScreen** | The 1440x1080 viewport the OS renders into; the fullscreen CRT overlay; the 3D quad on the monitor. |
| **regista** | director: `ThreatDirector` (room, group `regista_stanza`) and `VirusDirector` (PC, group `regista_virus`). |
| **apparizione, virus_mortale / stupido, schermo_blu** | apparition, lethal / YouAreStupid virus, blue screen. |
| **catalogo_disco / catalogo_siti** | the data catalogs of disk content and of web sites. |
| **lingua, tr / _t / _testo** | language; translation lookups (`_testo` also unescapes `\n`). |
| **sabotaggio** | in tests: break the code on purpose, require red, restore. |
| **affaccio, torcia, velo, chiave, portatore** | peek, torch, veil (browser loading cover / Ghosty tell), key, carrier page of a web key. |

## Naming & style conventions

- `snake_case` vars/functions, `PascalCase` class_name, `SCREAMING_SNAKE_CASE` constants,
  `_` prefix for internals.
- Comments in Italian; docs and CLAUDE.md in English; debug text in English.
- Scenes in `scenes/`, scripts in `scripts/` (OS in `scripts/os/`, threats in
  `scripts/threats/`), art in `assets/textures/{3d,photos}`, pages in `web/pages/`.
- Each `.gd` has its `.gd.uid` next to it; never hand-edit UIDs. `.godot/` is cache.

## Conventions, full text (as it was in CLAUDE.md §5)

These are not optional — match them or the code will feel foreign.

1. **The UI is built in code, not in `.tscn` files.** The entire OS (windows,
   taskbar, menus, icons) is constructed at runtime in GDScript. When adding to
   the OS, build nodes in code the same way (see `desktop.gd`), do not author a
   new scene unless there is a strong reason.

2. **Icons and chrome are drawn, not imported.** `os_icon.gd` and the Win95
   bevels draw everything with `_draw()` / `RenderingServer`. There are almost no
   image assets for the UI. Add new icons as a `match` case in `os_icon.gd`.

3. **Strict typing — beware `Variant` inference.** Godot here treats inferring
   `:=` from a `Variant` value as an error. The global `min()` / `max()` return
   `Variant`, so write `var x: float = min(a, b)` (explicit type), not
   `var x := min(a, b)`. Prefer `minf/maxf/clampf` for floats.

4. **Comments are in Italian.** The existing code is commented in Italian. Keep
   new comments in Italian to stay consistent with the codebase (documentation
   in `docs/` and this file are in English by request).

5. **The VFS is plain Dictionaries.** A node is
   `{ "name", "type": "folder"|"file"|"app", "icon", ... }`. Folders have
   `"children": Array`; text files have `"content": String`; html files have
   `"url": String`. Children get a runtime `"_parent"` back-reference via
   `VFS._link_parents`. Never serialize `_parent` (it makes cycles) — use
   `VFS.path_of(node)` (an array of names) to save/restore a location.

6. **Cross-scene state goes in `GameManager`**, never in statics that you expect
   to reset per run. (Note: `VFS._root` is currently a `static` that persists for
   the whole process — that is a known limitation, see Roadmap "randomization".)

7. **Reuse `Win95` for all styling.** Colors (`Win95.C_*`), the `Theme`
   (`Win95.make_theme()`), and `Win95._sb(...)` styleboxes. Do not hardcode
   colors that already exist in the palette.

8b. **A menu-bar label carries its ACCELERATOR as an `&`** (2026-09-21, owner's
   request): the CSV holds `&File`, `&Modifica`, `F&avorites` — the `&` never reaches the
   screen, the letter after it is UNDERLINED and **ALT+that letter opens the dropdown**
   (`Win95.menubar_button` + `Win95.premi_acceleratore`, called from each app's `_input`
   while its window is active). The two halves ship together on purpose: an underlined
   letter that ignores ALT is the same broken promise as a dead button. The letter is a
   TRANSLATION decision, which is why it lives in the CSV and not in the code — in English
   "Favorites" takes the A because File already took the F, exactly as period programs did.
   Where the same key is reused OUTSIDE a menu bar (a toolbar caption) strip it with
   `Win95.testo_semplice()`. In Win95 the underline was always visible, not only while ALT
   was held, and so it is here.

8. **No player-facing string in the code.** Everything the player can read goes
   through a key in `locale/ui.csv` (`keys,en,it`) — UI chrome *and* in-world
   content (file and folder names, file text, site names, the gateway). English is
   the source column. Use `tr("KEY")`; in a `static func` use
   `TranslationServer.translate()` (`tr()` is a method of `Object`) — there is a
   local `_t()` in `OSContent` and `WebRuntime`. For text with line breaks, write
   `
` as two characters in the CSV and read it with `_testo()` (`c_unescape`).
   An authored **web page** is not a string: it is a file per language,
   `web/pages/<lang>/<name>.html`, same file name everywhere.
   Two deliberate exceptions: **code comments** (Italian, rule 4) and **dev-only
   text** (the F12 panel, test output — it never ships and the tests grep it). The debug
   text itself — panel, key notes, console lines — is always ENGLISH (see §6, DEV-ONLY keys).
   After editing the CSV, run `--import`.

## Known rough edges / gotchas, full text (as it was in CLAUDE.md §7)

- `ComputerMode.tscn` is a DEV-ONLY harness: it loads the real `desktop.gd` in a
  CRT `SubViewport` so you can run/test the OS without the 3D room. It is NOT in
  the live flow (the game spawns `desktop.gd` from `player.gd`). Editing it has no
  effect on the actual game. (The old `computer_mode.gd` script was deleted.)
- `player.gd` reaches sibling nodes by relative path (`$"../HUD/..."`,
  `$"../Fade_transition"`, `$"../Monitor"`). If you rename room nodes, update
  these paths.
- The OS expects the room to provide a hidden reference node named
  `test-schermo` (a thin `BoxMesh`) to align the live monitor quad. If absent it
  falls back to a computed position.
- **A SubViewport fed by `push_input` delivers no mouse-motion EVENTS until you
  say so.** Such a viewport does not know the mouse is inside it
  (`gui.mouse_in_viewport` stays false), and with that flag false the Viewport
  hands motion events to controls **only while a mouse button is held**.
  Enter/exit *notifications* still work (so a Button still highlights), but
  anything driven by the motion event does not: `RichTextLabel`'s
  `meta_hover_started/ended`, tooltips, and any `_gui_input` that tracks the
  pointer. That is why the browser's cursor used to stay stuck on the I-beam.
  `player.gd` calls `notify_mouse_entered()` / `notify_mouse_exited()` on the OS
  viewport when entering/leaving the PC (`_set_os_mouse_in`). Any test or tool
  that drives the OS through `push_input` must do the same.
- **Cursor in the room:** a full-screen `Control` defaults to `mouse_filter = STOP`
  and will own the cursor, silently overriding `Input.set_default_cursor_shape`.
  That's why `Fade_transition`'s `ColorRect` is set to `IGNORE` — so `player.gd`'s
  `_update_room_cursor()` can show the pointing-hand over the monitor. Keep new
  full-screen room overlays `IGNORE` unless they truly need the mouse.
- **The room opens with a 1 s fade from black** (`Fade_transition`, "fade_out", started by
  `player._ready` on the first entry). A screenshot of the room taken earlier measures the
  veil, not the scene - it made the 3D monitor look like it was at a third of its brightness
  (pure white 94/255) when it is exact (0/128/128 for the desktop teal). Wait ~1.6 s.
- **`set_anchors_preset()` on a Control that is ALREADY in the tree keeps its current
  size** - it recalculates the offsets to hold the rect it has now, which for a fresh node is
  zero. Before add_child it "works" because the parent range is still zero. The blue screen
  hit it: its text showed, its blue background did not. Use
  `set_anchors_and_offsets_preset()` for a node you anchor after adding it.
- `.godot/` is gitignored (engine cache); don't commit it. UIDs in `.tscn`/
  `.uid` files matter — don't hand-edit them.
