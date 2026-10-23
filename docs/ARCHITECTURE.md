# Architecture — how the code works

This describes the code **as it exists today**. For the design of unbuilt
systems, see [GDD.md](GDD.md) and [ROADMAP.md](ROADMAP.md).

Engine: **Godot 4.6.1**, Forward Plus. Language: **GDScript**.

---

## 1. Scene & state overview

```
project.godot
  ├─ run/main_scene  ──► scenes/main_menu.tscn
  └─ autoload        ──► GameManager (scripts/GameManager.gd)  [always alive]

main_menu.tscn  (Node2D, main_menu.gd)
  └─ "Start" ─► fade_in ─► change_scene_to_file("res://scenes/main.tscn")

main.tscn  (Node3D "Main")
  ├─ Camera3D            ──► player.gd      (THE room controller)
  │    └─ RayCast3D
  ├─ Monitor (StaticBody3D)  ← 3D model + collision shapes:
  │    ├─ CollisionShape3D    (the screen face — click to enter the PC)
  │    └─ Computer            (the tower — click to power on/off)
  ├─ test-schermo (hidden BoxMesh)  ← reference rect to place the live screen quad
  ├─ Desk / DeskModel / DeskLamp / Bed / walls / floor / lights
  ├─ HUD (CanvasLayer)
  │    └─ ArrowsUI: ArrowLeft / ArrowRight / ArrowDown  (look-direction hints)
  └─ Fade_transition (instanced)  ← black ColorRect + AnimationPlayer (fade_in/out)

ComputerMode.tscn  (Control, desktop.gd)   ← DEV-ONLY OS harness (see §6)
fade_transition.tscn (ColorRect + AnimationPlayer; animations: RESET/fade_in/fade_out)
```

`GameManager` is the **only** thing that persists across scene changes. Fields:

| Field | Meaning |
|---|---|
| `first_time_in_room` | First entry into the room → play the reveal fade once. |
| `pc_on` | Is the tower powered? Off → monitor shows "NO SIGNAL". |
| `logged_in` | Has the login password been entered this power cycle? |
| `run_seed` / `rng` | Run seed + its seeded `RandomNumberGenerator` (reproducible content; the hook for M3 randomization). |
| `keys` | The run's keys, `[{index:int, code:String}, …]`. The secret folder validates typed input against these. |

**Run lifecycle** (resets all run state in one place):
- `start_new_run(seed)` — seeds the RNG, generates `keys`, resets `pc_on`/`logged_in`/`first_time_in_room`, rebuilds the VFS (`VFS.build_run`) and the browser pages (`BrowserApp.reset_pages`). Called from the menu's **Start**.
- `game_over(cause)` — single lose entry point (guarded by `_game_over_active`): spawns `scripts/death_screen.gd` at `root`, which **pauses the tree** (the overlay is `PROCESS_MODE_ALWAYS`) and plays jumpscare → GAME OVER screen → menu (unpauses before the scene change). Works over the room and the PC. A DEV-ONLY **F10** in `_input` triggers it until M4 wires enemies. `restart()` (→ `start_new_run`) is kept as a hook.
- `key_code(i)` / `key_label(i)` — the bare code (`Q9FY`) and the prefixed label (`1-Q9FY`); `check_keys(rows)` validates the entry grid (row-bound: each bare code must be in its own row).

---

## 2. The big idea: room and PC coexist

There is **one** running instance of the fake OS, and it runs **all the time** —
even while you are looking around the room. The OS is rendered into an offscreen
`SubViewport`. The room consumes that render in two ways:

1. **On the 3D monitor:** a `QuadMesh` ("MonitorScreen") textured with the
   viewport texture directly (live, every frame), filtered against moire by
   `schermo_monitor.gdshader`. Nothing is copied to the CPU except a 16x12
   average for the screen light, read back asynchronously (`_poll_monitor`).
2. **As a fullscreen overlay:** a `CanvasLayer` ("PCLayer") with a `TextureRect`
   of the same viewport texture, plus the **CRT shader**. Shown only when you
   "enter" the PC.

Entering/exiting the PC is therefore **not a scene change** — it's showing/hiding
the overlay and flying the camera toward/away from the screen. This is why boot,
login, and the desktop are all visible *live* on the 3D monitor before you ever
dive in.

```
SubViewport (1440×1080, UPDATE_ALWAYS)
   └─ OSDesktop (desktop.gd)         ← the entire fake OS
        │  get_texture()
        ├──────────────► MonitorScreen quad   (3D, in the room)
        └──────────────► PCLayer TextureRect   (2D fullscreen overlay + CRT)
```

All of the spawning above happens **at runtime in `player.gd`**
(`_spawn_computer()`), not in the scene file. `main.tscn` does not contain the
SubViewport or the OS node — they are created in code as siblings of the camera.

---

### CanvasLayer order (overlays)
`PCLayer` (the fullscreen PC view) 10 · win screen 20 · F12 debug panel 30 · death screen 50 ·
**pause screen 60**. Everything above 10 is spawned on the SceneTree **root**, not under the
room, so it survives a scene change and covers both the room and the PC view. The pause and
death overlays set `get_tree().paused` and run with `PROCESS_MODE_ALWAYS`; a paused
`player.gd` receives no input, which is why each overlay reads its own keys.

## 3. `player.gd` — the room controller (on Camera3D)

Responsibilities:

- **Look-around:** in `_process`, the camera yaw turns between fixed angles
  (`pos_left/center/right/back`) when the cursor is **over the on-screen nav
  arrow** — a compact button-like zone at the center of each side (not the whole
  edge). The arrows are `Control`s in `HUD/ArrowsUI` running `nav_arrow.gd` (drawn
  in code: a big **semi-transparent rectangle outline** (hollow) with a centred
  chevron, brighter on hover — no images); the hotzone is each arrow's
  `get_global_rect()`. After a turn, `can_change_pos` re-arms only once the cursor
  leaves the
  arrow's rect **plus a ~70 px margin** (hysteresis) — so a small jiggle can't
  immediately re-trigger another turn. `_update_arrows()` shows the relevant
  arrows; movement is a `lerp` toward `target_yaw`. An exported flag
  **`click_to_turn`** switches the mode: `false` = hover (above), `true` = the arrow
  must be **clicked** (`_setup_arrow_input` sets the arrows' `mouse_filter` to STOP
  and wires each `clicked` signal to `_arrow_action`). Arrow **size lives in the
  scene** (`HUD/ArrowsUI/*` offsets), not the script.
- **Click interaction:** in `_input`, casts a ray from the mouse. If it hits the
  `Monitor` body while looking center, it checks which collision shape:
  `Computer` (tower) → `_power_button()`; the screen → `_enter_pc()`.
  `_update_room_cursor()` (each frame, in the room) ray-casts from the mouse and
  shows the **pointing-hand** cursor (`Input.set_default_cursor_shape`) over the
  `Monitor` body, so the player sees it's clickable.
- **Enter/exit PC:** `_enter_pc()` tweens the camera into the screen (with FOV
  zoom) and fades the room to black, then reveals `PCLayer`. `_exit_pc()` fades
  the overlay, hides it, and tweens the camera back to its home pose.
- **Input forwarding while inside the PC:** `_forward_to_os()` duplicates mouse
  events, offsets their position into screen space, and calls
  `SubViewport.push_input()`. `_update_pc_cursor()` asks the OS
  `cursor_shape_at()` and applies the shape to the overlay's background
  `ColorRect` (the SubViewport does not control the real cursor).
- **Power button:** `_power_button()` calls `OSDesktop.boot()` or `power_off()`.
- **Live monitor:** `_setup_monitor_screen()` / `_build_screen_quad()` build the
  quad, aligning it to the hidden `test-schermo` reference box if present;
  `_kill_monitor_emission()` disables the 3D model's green "fake terminal"
  emissive so the real OS shows through.

Key constants: `OS_SIZE = Vector2i(1440, 1080)`, exported `fly_time`,
`fly_fov_zoom`, and the screen-panel tuning (`screen_w/h/push/nudge`).

---

## 4. The fake OS (`scripts/os/`)

### 4.1 `desktop.gd` — `OSDesktop` (the OS controller)
Built entirely in code in `_ready()`:

- **Wallpaper / icons layer / window layer / taskbar / Start menu / context menu.**
- **State overlays** (mutually exclusive, via `_clear_state()` + `_state_overlay`):
  - `_show_no_signal()` — black screen with a bouncing "NO SIGNAL" box (moved in
    `_process`). Shown when `pc_on == false`.
  - `_play_boot()` — black splash, "52-HZ WHALE" logo, progress bar tween → login.
  - `_show_login()` — modal asking for the password (**hardcoded `"123"`**); on
    success sets `GameManager.logged_in = true` and clears to the desktop.
  - `_show_shutdown()` — Yes/No confirm → `power_off()`.
- **Runtime power control:** `boot()` (sets `pc_on`, runs the splash) and
  `power_off()` (closes windows, sets flags, shows NO SIGNAL). These are called
  by the room — there is no scene reload.
- **Window manager:** `open_window()`, `open_app(kind, arg)` (kinds:
  `"explorer"`, `"browser"`, `"notepad"`, `"image"`), `focus_window()`, taskbar buttons,
  minimize/restore/close, z-order via `move_child`.
- **Desktop icons:** built from a hardcoded list (My Computer, Documents, Web,
  Trash) plus the Desktop folder's VFS children — which include the user's created
  files and the **secret folder** ("Cartella protetta", made non-deletable). The
  Trash icon swaps between `trash`/`trash_full`.
- **Secret folder (win condition):** `open_secret_folder(node)` opens a glitchy
  **"ACCESSO NEGATO" modal** (`_make_modal`) with one **unlabelled** input field
  per run key; the player types the **bare code** into the row they deduce from the
  prefix seen in the content. A full match (`GameManager.check_keys`, row-bound)
  emits the **`game_won`** signal → the room runs the ending. Reached from both the
  desktop icon and the File Explorer. A `glitch.gdshader` overlay (mouse-ignored,
  so the fields stay usable) distorts the dialog in short random bursts.
- **Cursor:** `cursor_shape_at(pos)` returns the desired `Control.CursorShape`
  for a desktop point (resize edges, link hand, text I-beam…). The room calls
  this to drive the real cursor on the overlay. While a modal dialog is open
  (`_modal_layer`, set by `_make_modal`) it returns only the modal's own cursor,
  so window-resize shapes don't leak through the dialog.
- **`_input`:** ESC emits `exit_requested` (→ room hides the overlay); left-click
  closes an open Start menu when clicking outside and focuses the window under
  the mouse.
- **Signals:** `exit_requested` (ESC → back to the room) and `game_won` (secret
  folder unlocked → the room shows the ending).

### 4.2 `vfs.gd` — `VFS` (virtual filesystem)
A tree of plain `Dictionary` nodes, held in a **static** `_root`. It is now
**per-run**: `build_run(seed)` rebuilds `_root` from scratch on every
`start_new_run` (fresh files, empty Trash), so "lose → fresh run" starts clean.
`get_root()` still lazily builds on first access if nothing built it yet.

Node shapes:
```gdscript
folder = { "name", "type":"folder", "icon", "children":[ ... ] }
text   = { "name", "type":"file", "icon":"text", "filetype":"text", "content":String }
html   = { "name", "type":"file", "icon":"ie",   "filetype":"html", "url":String }
secret = { "name", "type":"secret", "icon":"locked" }   # the password-protected folder
```
Helpers: `get_root()`, `build_run(seed)`, `resolve_path(names)`,
`resolve_node(names)`, `path_of(node)` (→ array of names, the safe way to
reference a location), `get_desktop()`, `get_trash()`, `move_to_trash()`,
`_unique_name()`. Every child gets a runtime `"_parent"` back-reference via
`_link_parents()` — **do not serialize it** (it forms cycles); use `path_of()`.

Contents are no longer inlined here: `_build()` now just returns
`OSContent.build_filesystem()` (see §4.2b). The authored tree lives as **data** in
`OSContent`, which also **places the run's keys** (file-content key, folder-name key) at
random and puts the **secret folder** node on the Desktop.

**The shape is a late-90s disk** (2026-09-20), not a folder with some files in it:

```
My Computer
├─ 3½ Floppy (A:)              empty on purpose — no disk in the drive
├─ Local Disk (C:)
│   ├─ WHALE\                 the system folder (this OS's C:\WINDOWS)
│   │   ├─ SYSTEM\  FONTS\  TEMP\
│   │   ├─ Desktop\           ← VFS.get_desktop(); holds the secret folder
│   │   ├─ Start Menu\Programs\   Favorites\
│   │   └─ WHALE.INI  SYSTEM.INI  …
│   ├─ Program Files\<app>\  fake apps: an .EXE + a readme
│   ├─ My Documents\
│   │   ├─ My Pictures\       the run's photos (image key)
│   │   └─ diary.txt  password.txt  shopping_list.txt
│   ├─ TEMP\
│   └─ AUTOEXEC.BAT  CONFIG.SYS  COMMAND.COM  IO.SYS  BOOTLOG.TXT
├─ CD-ROM (D:)                 empty on purpose
└─ Recycle Bin
```

Three rules hold it together:
- the **boot files live in the root of C:**, where they belong. They used to sit in a
  "System" folder, which no PC of that era ever had;
- **system names are 8.3 uppercase and are never translated** (`WHALE`, `SYSTEM`,
  `AUTOEXEC.BAT`) while the **user folders are** (`My Documents` / `Documenti`,
  `Program Files` / `Programmi`, `Start Menu` / `Menu Avvio`) — that is exactly how the
  Italian releases shipped, and the contrast is half of the period feel;
- **binaries look like binaries**: `.EXE`/`.DLL`/`.VXD`/`.FON` nodes carry
  `filetype:"bin"` and a body of unreadable bytes (`OSContent._binario`), read-only in
  Notepad. It also teaches the player what a binary looks like in a text editor, which is
  what makes the JPEG-comment key (§4.2b) readable as a *find* rather than a curiosity.

`tests/filesystem_test.tscn` pins all of it, in both languages.

### 4.2b `content.gd` — `OSContent` (the content library + seeded generator)
Holds all content as data **and** generates each run from the seed (M3, all parts),
separated from the code that builds/renders it. The 4 keys (owner's map since
2026-10-18): **1 = disk** (a file's content OR a folder's name, 50/50), **2 and 3 = web**
(two different sites, `web_runtime.gd`), **4 = image**:

- `build_filesystem() -> Dictionary` — the VFS root tree (consumed by `VFS._build`), built
  in three steps since 2026-10-18: the **skeleton** (`_disco_c`, fixed: drives, boot files,
  `WHALE` with SYSTEM/FONTS/TEMP/Desktop, Program Files with WebNet + PhotoLab,
  My Documents\My Pictures, TEMP, Recycle Bin), the **filling** (`_riempi_disco`, random:
  user folders, invented programs, extra `C:\` folders, system binaries, period files by
  zone and 2-3 horror notes, all drawn from the data in **`catalogo_disco.gd`**
  (`CatalogoDisco`) with its **own RNG**, so the photo and key draws do not move), then the
  **keys**. Choices are made by catalog index and duplicates are checked on catalog keys,
  never on translated names, so both languages build the same shape. Recipe for editing
  the catalog: `docs/DISK_CONTENT.md`; test: `tests/disco_casuale_test.tscn`.
  Before, the filler was fixed; the **file key** is dropped into a
  random carrier file (random name + carrier text) in a random folder
  (`_place_file_key`), and the **folder-name key** into a random "backup"-style folder
  (`_place_folder_key`, in the root of C: or inside My Documents). The **file key's folder
  is drawn from `_cartelle_chiave()`, a list of PATHS** (My Documents, My Pictures,
  `WHALE\TEMP`, `TEMP`, a program folder, `WHALE`) — with a tree this deep, looking only
  among C:'s direct children was not enough — and now also the folders the filling created
  (user folders, invented programs, extra `C:\` folders); the folder key may also go one
  level down, into a user folder of My Documents. The F12 panel prints the DOS path.
  `My Pictures` is filled with the run's photos (below).
- **Web sites moved out** — the browser now renders real HTML via Chromium, so the web
  content lives in **`web_runtime.gd`** (`WebRuntime`), not here. `OSContent` only keeps the
  `KEY_*` indices + `key_label()`. See **§4.2c**.
- `byte_dump(node)` — what a photo looks like in Notepad: JFIF header, unreadable bytes and,
  for the carrier, the comment in clear after the `FF FE` marker. **Its position is drawn from
  the file name's hash** (so it varies per run and is stable on reopen): after the header,
  between the tables, just before the scan, or in the tail past the end of the image. Those
  are the only legal places — nothing can sit inside the compressed scan — and before
  2026-09-20 it was always the same line (7 of 31). `tests/photo_file_key_test` fails if the
  position stops varying.
- **Photos** — `_make_photos` builds 3–4 image nodes (`filetype:"image"`) and hides
  the **image key** in one of them (a `code` field). Source: if `PHOTO_DIR`
  (`res://assets/textures/photos/`) holds author images, the run draws a seeded subset
  (file nodes carry a `path`); otherwise it falls back to **procedural** nodes
  (`photo_seed` + `tint`). `make_photo(node) -> Texture2D` returns the loaded texture
  for a `path`, else generates a tinted/vignetted/grainy field on the CPU from the
  seed. The hidden code is **not** baked into the pixels (it can't be — the key is
  randomized per run, while a file is fixed): `ImageViewerApp` composites the code over
  the photo as a very low-contrast `Label`, placed at a **random position and rotation**
  (seeded by `code_seed`, stable per run) with a colour sampled from the photo *at that
  spot* so it blends. Photo + label are composited in a SubViewport and the
  `adjust.gdshader` runs on the result, so the code is invisible on open and only
  emerges when the player adjusts the image (§4.5 / §4.6).

**Seeding model.** Each build calls `_run_rng(salt)` — a fresh
`RandomNumberGenerator` seeded with `GameManager.run_seed + salt` (distinct salts for
VFS vs sites). So the output is **reproducible** from the run seed **and
order-independent**: it doesn't matter that the browser builds its pages lazily (on
first open) long after the VFS was built, nor whether anything else touched a shared
RNG in between. The **index→category** map is fixed (key 1 → a file, 2 → a folder, 3 →
web, 4 → an image), which lets the builders each place *their own* keys with no
cross-call coordination — only the position *within* a category is seeded-random. Keys
are kept out of the authored pool strings; carrier templates hold a single `{{KEY}}`
slot the generator fills with `GameManager.key_label(n)` (before a run, `run_seed = 0`
→ deterministic filler with empty key labels, so nothing is placed).

### 4.2c `web_runtime.gd` — `WebRuntime` (per-run sites + web key)
The site pages are authored files (§4.5), but **which sites appear and where the key is** is
per-run. `WebRuntime` (static, no file IO, no engine):
- `build()` (from `BrowserApp.reset_pages()` on each `start_new_run`): seeds an RNG from
  `run_seed + SITE_SALT` and picks the run's sites from the **site catalog**
  (`scripts/os/catalogo_siti.gd`, one folder per site under `web/pages/<lang>/`): 10-15
  sites, 4-5 of them lore, at least one about the father and one about the young man (all
  of them while the catalog is smaller). Then, for each of the TWO web keys, a site of the
  run and a page of that site as the **carrier**, plus the **mode** (visible / comment) and
  the carrier sentence/comment. `_ensure()` rebuilds if the seed changed.
- A page is `"<site>/<page>"`; `page_of` / `risolvi_link` / `display_url` turn addresses and
  links into pages and back; a site that is not part of the run answers "cannot find
  server".
- `home_html()` → **generates** the gateway HTML (WEBNET GATEWAY, featured + recent) listing
  the run's sites with links — the home is NOT a file.
- `source_html(page, src)` → the authored HTML with the key **injected** for the carrier page.
  WHERE it lands is part of the run: `build()` draws two fractions (appended at the end of
  the RNG order, so older seeds keep their carrier/mode/sentence) and `_risolvi()` turns them
  into a concrete offset via **`WebAnchor`** (`scripts/os/web_anchor.gd`), memoised on
  `src.hash()` because `source_html` runs on every page load and also feeds view-source.
  Rendered spots: own line between blocks, mid-sentence (the **bare code**, inheriting the
  surrounding style), paragraph tail, new list item, light table cell. Source-only spots:
  comment between blocks / mid-markup / in the table markup / in `<head>`, or a `title=`/`alt=`
  attribute. `carrier()` / `is_visible()` / `anchor_info()` expose the choice (the tests use
  them instead of guessing from where the string turned up). `BrowserApp` calls it at load and
  renders `HtmlBB.strip_comments(...)`. To add a site: its folder in every
  `web/pages/<lang>/`, its `WS_*` rows in `locale/ui.csv` and one entry in
  `scripts/os/catalogo_siti.gd` (with both domains) — recipe in docs/WEB_SITES.md §3.
- **Language** (§7): `lingua()` is the two-letter code in play; `siti()` returns `{ id: domain }`
  for that language, built from the catalog; site names (`WS_*`) and the gateway's words come
  from `locale/ui.csv`. The **carrier
  sentences** (`_VISIBLE`) are keys; the fake **source comments** (`_COMMENT`) are deliberately
  left in English in every language, because that is how period code read everywhere.
- `WebAnchor` (`web_anchor.gd`) → pure scanner, no `GameManager`/`OSContent`, so
  `tests/html_bb_test.gd` can exercise it headless over the real pages: `ancore(src, visible)`
  lists every safe spot, `inserisci()` injects at one, `inietta()` picks one from the two
  fractions. It refuses the two spots that were real bugs (inside a table but outside a cell —
  HtmlBB drops the text; a dark cell — black on dark) and never touches `<title>`.

### 4.3 Styling: `win95.gd` + `stylebox_win95.gd`
- `Win95` (static helpers): the palette (`C_DESKTOP`, `C_FACE`, `C_TITLE`, …),
  `make_theme()` (the global `Theme` applied at the OS root; children inherit),
  `bevel_rid()` (draws the 3D raised/sunken border), `menu_width()`, and `_sb()`
  (builds a `StyleBoxWin95`).
- `StyleBoxWin95` extends `StyleBox`; its `_draw()` fills the rect and calls
  `Win95.bevel_rid()`. Used for buttons, panels, fields, menus.
- **Menu bar** (2026-09-21): `menubar_button(text, enabled)` takes the label with the
  accelerator marked by an `&` (`&File`, `F&avorites`), drops the `&`, **underlines** that
  letter (measured with the real font, because the Button centres its text — and it follows
  the 1 px shift of the pressed state) and records the letter in the button's
  `acceleratore` metadata. `premi_acceleratore(buttons, key_event)` is the other half:
  each app calls it from `_input` while its own window is active, so **ALT+letter** opens
  that dropdown. They ship together deliberately — an underline that ignores ALT would be
  the same broken promise as a button that does nothing. `testo_semplice(s)` strips the `&`
  where the same translation key is reused as a toolbar caption.
- **Chrome pieces** (2026-09-20): `tool_button(kind, caption, cb, enabled)` (icon over a
  caption, width measured with the real font), `fade(button, off)` (the theme greys only the
  button's own text, so a disabled button whose icon is a *child* still looks live),
  `strip(parent, h)` (the raised bar the buttons sit on), `grip()` and `menu_separator()`.
  They live here and not in an app because the browser and the File Explorer must build the
  *same* bar — a disabled button has to read the same in both. `MENUBAR_H` / `ADDRBAR_H` are
  shared for the same reason **and** because they have to clear the real height of a menu
  button (31 px here): a shorter strip lets the entries spill onto the bar below, which is
  what made the Explorer's chrome look broken on 2026-09-20. An app also sets its window's
  **minimum width** from its own toolbar, or a narrow window cuts the last buttons off.

### 4.3b The ABOUT dialog (shared)
`OSDesktop.apri_informazioni(title, icon, lines)` is the one About box, used by the File
Explorer and the browser. It is built on `_make_modal`, so it is **centred on the OS screen**
and lives on a desktop layer — before 2026-09-21 each app drew it inside its own window with
the menu-dropdown machinery, so its position followed the window (and a narrow window clipped
it). Title bar + program icon + name/version/copyright + OK, with the width measured from the
longest line. `_modal_chiudibile` is what lets ESC close it while leaving ESC-exits-the-PC
intact for the login and the secret-folder dialogs.

### 4.4 Widgets
- `OSWindow` — frame + title bar (icon, label, min/max/close `GlyphButton`s),
  drag by the title bar, **edge resize** (`_edges_at`, `_rect_resize`,
  `cursor_at`), maximize/restore. `content_root` is where apps add their UI,
  inset so window borders stay grabbable.
  **A window cannot leave the screen** (2026-09-20): `area_utile()` is the screen minus
  the taskbar — the same rect maximize fills — and both dragging and resizing clamp to it
  (`_dentro`, and per-edge in `_rect_resize`: the dragged edge stops, the opposite one
  stays put). `assesta()` puts a window back inside and is called by `open_window` and by
  restore-from-maximized. The monitor is a fixed 4:3 with no second screen and no scrolling
  desktop, so anything pushed past the edge is gone for good; before this, a drag could
  leave 40 px on screen and a resize had no limit at all.
  Test: `tests/finestre_confine_test.tscn`.
  **Only the outline moves** (2026-09-21): during a drag or a resize the window does not
  change at all — a **dotted rectangle** shows where it is going, and the geometry is
  applied in one go on **release**. That is Win95 with *"show window contents while
  dragging"* off, which was the default setting; it was not only taste, since repainting
  the contents at every pixel was too much for those machines, and here it has the same
  good side effect (a browser page re-lays out its tables once instead of on every mouse
  move). `_rect_resize()` returns the clamped `Rect2` instead of assigning it, so the
  outline and the release use the *same* numbers — the outline cannot promise a geometry
  that the release would correct. The rectangle is drawn by the **desktop**
  (`OSDesktop.mostra_contorno` → `Win95.contorno`, a 2 px black/white checker tiled along
  four snapped strips): the window has `clip_contents` and the outline exceeds it on every
  side, and in Win95 that rectangle was painted on the *screen*, over the other windows.
  Win95 used an XOR brush (`PATINVERT`); there is no XOR blend mode for a canvas item
  here, but what one recognises is the checker, not the inversion. The block is 2 px and
  not 1 because this viewport is shown at ~2/3 with the CRT on top, where a 1 px checker
  averages to flat grey — measured, not assumed: the border's swing after a real 2/3
  reduction is 1.00 with 2 px blocks and 0.25 with 1 px.
  Two **static switches**, `CONTORNO_RIDIMENSIONA` and `CONTORNO_SPOSTA` (Win95 treated
  the two as one setting), both flipped by the test; a window with no desktop falls back
  to the live behaviour.
  Test: `tests/finestre_contorno_test.tscn`.
- `OSIcon` — every icon is **drawn in `_draw()`** via a `match kind` (folder, ie,
  text, trash, win flag, toolbar glyphs…). Add a new icon = add a case + a draw
  helper. No PNGs.
- `DesktopItem` — selectable icon+label used on the desktop and in Explorer;
  emits `activated` (double-click), `picked` (single click), `context_requested`
  (right-click) and `rinomina_finita` (a rename confirmed).
  **Rename** (2026-10-18), Win95-style: `inizia_rinomina()` swaps the label for a
  `LineEdit` with the whole name selected — Enter confirms, ESC cancels, a click elsewhere
  confirms (detected by `OSDesktop._input`, since clicking something that takes no focus
  would leave the box open). Being a real text field it supports selection and CTRL+C, so
  a name can be copied without being changed — the point of the feature: the folder key
  lives in a folder *name*. Banned Windows characters are dropped while typing; commits are
  deferred, because focus is lost *during* a click and redrawing the folder then would hand
  that click to an icon being freed. The owner applies the name through
  `OSDesktop.rinomina_nodo`, which refuses duplicates (case-insensitive, as on a Windows
  disk) with a period error dialog and redraws the desktop and every open Explorer. What
  may be renamed is one rule, `VFS.rinominabile`: not the protected folder, not the drives
  or the Recycle Bin (children of the root), not what is in the bin, and not the chain to
  `C:\WHALE\Desktop` — `VFS.get_desktop()` finds it **by name**, so renaming it would empty
  the desktop. ESC reaches the OS only when it asks for it (`trattiene_esc()`; see
  `player.gd`). Test: `tests/rinomina_test.tscn`.
- `GlyphButton` — the small beveled title-bar buttons (min/max/close glyphs).

### 4.5 Apps (each is a `Control` added into `OSWindow.content_root`)
- `FileExplorerApp` — toolbar + address bar + icon grid over a VFS folder; open
  folders (navigate), files (text → Notepad, html → Browser, image → Image Viewer),
  and the **secret** node (→ `OSDesktop.open_secret_folder`); back/up; new/delete
  (delete → Trash, or permanent if already in Trash).
- `NotepadApp` — `TextEdit` over a file's `content`; File/Edit menus and a custom
  right-click menu; Ctrl+S saves back into the VFS dictionary; tracks a modified
  flag in the title.
- `BrowserApp` — renders a **HTML subset to native Godot Controls** (`_render_html`); no web
  engine, no images. The chrome (menu/tool/address bars; back/fwd/home) is Godot; the page is a
  `VBoxContainer` of blocks: inline runs → **selectable** `RichTextLabel` (BBCode), `<table>` →
  `PanelContainer` cells (bgcolor/border/`width%`), `<center>`/`<div align=center>`, `<hr>`,
  `<input>` → `LineEdit`/`Button`. So text **selects** (Ctrl+C / right-click **"Copia"**),
  links open on the **first click** (`_on_rtl_gui_input` tracks the hovered link + a clean
  click — a normal `meta_clicked` loses to the selection), and the page **reflows** with the
  window. **Selection is real-browser:** a clean single click clears any selection
  (`_clear_page_selection.call_deferred()`); drag = range, double-click = word. Pages are
  `res://web/pages/<lang>/*.html` (legacy subset: `font/table/bgcolor/center/div/hr/ul-li/input` —
  **not** CSS classes); the **home is generated** (`name == _home` → `WebRuntime.home_html()`,
  the run's 5 random sites), not a file. `_load` runs the HTML through
  `WebRuntime.source_html()` (injects the per-run key) and renders `strip_comments(...)`;
  **"Visualizza sorgente"** shows the pretty-printed source (with the key). Right-click menu
  via `_input`. A missing page → `404`. `reset_pages()` → `WebRuntime.build()` on each
  `start_new_run`. *Lightweight, interactive; not pixel-identical to Chromium — chosen after
  rejecting the gdcef embed (weight) and a baked-image approach (no selection/reflow). Renderer
  fixes (stack-based inline, `default_color`, 1st-click links) are in memory `web-browser`.*
- `ImageViewerApp` (`app_image_viewer.gd`) — opens a run photo (`OSContent.make_photo`).
  Photo + (for the key photo) a faint, randomly placed/rotated code `Label` are
  composited in a **SubViewport**; the displayed `TextureRect` shows that viewport
  texture through an `adjust.gdshader` `ShaderMaterial`, with sliders for **brightness /
  contrast / saturation / black & white levels / "Nitidezza"** and a Reset. Adjusting the
  composite reveals the code (§4.2b / §4.6). Reached from the file open dispatch
  (`open_app("image", node)`).
  The four point-wise sliders amplify the code and the photo's own detail *equally*, so they
  can never separate them; **"Nitidezza" is the one that actually solves the puzzle**,
  because it is a band-pass and separates by spatial frequency instead. It behaves like a
  tuning dial rather than a gain: there is a sweet spot, and it differs from photo to photo.
  Where the code may be hidden at all is decided at generation time by `OSContent`
  (`_best_hiding_spot` / `_valuta`), measured in the *same* band the shader uses.

### 4.6 `crt.gdshader` + `glitch.gdshader` + `adjust.gdshader`
- `crt.gdshader` — a flat (non-curved) `canvas_item` shader: scanlines, RGB
  phosphor mask, mild chromatic aberration, vignette, rounded corners with a bezel
  shadow, brightness compensation. Applied to the fullscreen PC overlay (and configured
  on `ComputerMode.tscn`, which is where to tune it live from the Inspector).
  **Flat on purpose:** curvature would move pixels, and the mouse is forwarded to the OS
  in a straight line; every effect here changes a pixel's light, never its position.
  **Two units** (2026-10-17): what sits *on the glass* — scanlines and the phosphor
  mask — is counted in real screen pixels (`FRAGCOORD`), the scanlines with an
  **integer** period `round(height / 360)` (never under 2), each line a small gaussian
  beam that widens on bright pixels; what sits *in the image* — convergence, corners,
  bezel shadow — in OS pixels. The scanlines used to be counted in OS pixels
  (`uv.y * 1080`) while the OS reaches the screen at 2/3 (default 1280×720 window) or
  near 1:1 (a maximised window), never exactly: at 720p the intended 1.33 px period was
  drawn as a 4 px one (fat lines), and at 1886×1061 the per-row swing beat between
  0.005 and 0.085, i.e. moiré bands (43 % variation, 1 % after). Halation and
  edge-growing convergence were tried and removed because they measurably lowered the
  contrast of dark text, which is where the keys are read; the numbers are in
  `CLAUDE.md` and the shader's header. Dev tool: `tests/crt_look_check.tscn`.
- `glitch.gdshader` — a `canvas_item` shader that reads the screen under it
  (`hint_screen_texture`) and corrupts it: per-slice horizontal tear, RGB split,
  scanlines, sparse noise, all scaled by an `intensity` uniform. Used by the
  ThreatDirector's full-screen **warning** and by the death screen; it's the intended
  foundation for the **M5 glitch driver** (`glitch(level)`).
- `secret_glitch.gdshader` + `SecretGlitch` (`secret_glitch.gd`) — the **secret-folder
  dialog's** own breakdown (2026-10-17). Deliberately *not* `glitch.gdshader`: that one
  means "an enemy is peeking", and the folder must not produce a look-alike. The effect
  rect is the dialog grown by `MARGINE`; the shader reads the screen below and only ever
  shows real dialog pixels taken from the wrong place — tear bands of irregular height
  that wrap inside the dialog, corrupted 16×16 tiles, a stepped "hall of mirrors" trail
  outside the border, a blood-red low-level palette — plus a rare 2-px row jump at rest.
  `SecretGlitch` drives it from `_process` (dies with the dialog, freezes with the pause):
  random bursts that get more frequent the longer the dialog stays open, a twitch on
  typing, a **rejection** on wrong codes (red + tiles + tear + shake + the veil behind
  dimming), a title "read with the wrong encoding" and a rare ~4-frame subliminal line
  (`SECRET_SUB_*`). It never touches the typed text and no burst exceeds 0.4 s.
  Test: `tests/cartella_segreta_test.tscn`; dev tool: `tests/glitch_look_check.tscn`.
- `adjust.gdshader` — a `canvas_item` shader applying **brightness, contrast,
  saturation, levels** (black/white point) and **"Nitidezza"** to its `TEXTURE * COLOR`.
  Identity at default values; works for both a textured rect (the photo) and a `Label` (the
  hidden code), so one shared material drives the image-adjustment puzzle
  (`ImageViewerApp`). Everything runs on sRGB-space values, which is what makes a code
  hidden in shadow recoverable.
  "Nitidezza" is the only **non-point-wise** control: a band-pass (a fine blur minus a wide
  three-ring blur, on luminance) tuned to the width of the code's strokes, ~2.2-2.5 px of
  composition. The slider does not raise a gain — it sweeps a **threshold** with a **dead
  zone** under it, so band amplitudes below the threshold collapse to flat grey while the
  strokes saturate to black or white. That is what lets a faint code win against photo grain
  of a similar size: with a plain gain, clipping favours the code only once it beats the
  noise *peak*, which a watermark faint enough to stay hidden never does.
  The generator must measure in exactly this band, so `OSContent.bp_shader_at` is a CPU twin
  of this kernel — **change radii or weights here and you must change them there**; the
  measured response of the filter to the strokes (`CODE_BP_RESPONSE`) has to be re-measured
  too, with `tests/photo_reveal_test.tscn`.

---

## 5. Data & control flow cheat-sheet

```
New run:    menu Start ─► GameManager.start_new_run() ─► gen keys + VFS.build_run + BrowserApp.reset_pages
Power on:   room click tower ─► player._power_button ─► OSDesktop.boot()
                              ─► splash ─► _show_login() ─► (pass "123") ─► desktop
Enter PC:   room click screen ─► player._enter_pc() ─► camera fly + PCLayer.visible
Use OS:     overlay input ─► player._forward_to_os ─► SubViewport.push_input ─► OSDesktop
Cursor:     player._update_pc_cursor ─► OSDesktop.cursor_shape_at ─► overlay bg cursor
Open file:  DesktopItem.activated ─► OSDesktop.open_app("notepad"/"browser"/"image", node)
                                  └► (secret node) ─► OSDesktop.open_secret_folder
Win:        unlock modal ─► check_keys ─► OSDesktop.game_won ─► player ending ─► menu
Game over:  GameManager.game_over(cause) ─► death_screen (jumpscare ─► GAME OVER) ─► menu
            (DEV-ONLY: F10 triggers game_over; real triggers come with M4 enemies)
Exit PC:    ESC ─► OSDesktop.exit_requested ─► player._exit_pc() ─► camera returns
Power off:  Start ▸ Shutdown ─► _show_shutdown ─► power_off() ─► NO SIGNAL
```

---

## 6. Legacy / things to know

- **`ComputerMode.tscn` is a dev-only OS test harness.** It wires `desktop.gd`
  into a CRT SubViewport directly so you can run/test the OS without the 3D room,
  but the shipped flow does **not** load it (`player.gd` spawns `desktop.gd`
  itself). The old `computer_mode.gd` controller was **deleted** in M0. Prefer
  everything under `scripts/os/`.
- **Sibling node paths** in `player.gd` (`$"../HUD/..."`, `$"../Monitor"`,
  `$"../Fade_transition"`, `$"../test-schermo"`) are positional — renaming room
  nodes breaks them.
- **Session save/restore was cut** (M0): the `pc_session` / `pc_screenshot` /
  `returning_from_pc` fields and the apps' `get_session()` / `restore_session()`
  were removed. The OS simply keeps running while you step away.
- **VFS is per-run** (M0): `build_run()` rebuilds `VFS._root` on every
  `start_new_run`. The tree itself is still hardcoded in `_build()` (only the keys
  vary per run); seeded content generation is M3.

---

## 7. Localization (one table + one folder per language)

**Base language English, Italian as the first translation.** Nothing player-facing is
hardcoded any more:

- **`locale/ui.csv`** (`keys,en,it`) holds every string: UI chrome *and* in-world content
  (folder/file names, file text, the photo's file comment, site names and descriptions, the
  gateway's words, the sentence that carries the web key). Godot imports it into
  `locale/ui.<lang>.translation`; `project.godot` → `[internationalization]` lists them, with
  `locale/fallback="en"`. **After editing the CSV, run `--import`** or the game keeps the old
  strings. Quote a cell containing a comma; write a line break as the two characters `\n` and
  read it back with `String.c_unescape()` (`OSContent._testo`).
- **`GameManager.set_lingua(code, salva := true)`** is the single entry point
  (`LINGUA_BASE = "en"`, `LINGUE = ["en", "it"]`, `NOMI_LINGUA` = the endonyms, which are
  **not** in the CSV: in a language list each language is written in itself). `_ready()`
  loads the saved choice from `user://impostazioni.cfg`, or English — it never follows the
  OS locale (Godot would start in `it_IT` here). Tests pass `salva = false`: a test must
  not rewrite the language of whoever plays.
- **Where the player chooses it:** `scripts/options_screen.gd`, a code-built overlay the
  main menu opens ("Options"). It is the only way in, and only from the menu: the in-world
  text is generated by `start_new_run`, so switching mid-run would leave the PC in the old
  language. On a change it emits `lingua_cambiata`, and `main_menu._etichette()` re-assigns
  the three button labels — they had been read from `tr()` in the previous language.
  Test: `tests/options_test.tscn`.
- **`web/pages/<lang>/*.html`** — the authored pages, one file per language, same file names
  (a page *name* is an identifier; only the content is translated). `BrowserApp.read_page`
  resolves `<lang>` → `en` → the old flat folder, so a missing translation costs that language
  a page, not the game.
- **`tr()` vs `TranslationServer.translate()`** — `tr()` is a method of `Object`, so it is
  **not** available in a `static func`. `OSContent`, `WebRuntime` and the other static helpers
  call `TranslationServer.translate()` through a local `_t()`.
- A missing key returns **the key itself**, which then shows up on screen; that is why
  `tests/web_locale_test.tscn` fails on a `WS_`/`WEB_HOME_`/`WK_V_` prefix appearing in the
  generated gateway, and why `WebRuntime._frase()` falls back to the bare code if a carrier
  sentence lost its `%s` (a broken sentence would leave the key out of the page — unfindable).
- **Debug text is always English** (the F12 keys panel, the key notes, the console lines —
  owner, 2026-10-18), in every game language: it never ships and does not go through the
  CSV. Test output stays Italian, like the code comments.
