# Content: the random disk, the keys, the secret folder

Read before touching content.gd, the disk catalog, the key map or the secret-folder dialog. Adding disk files: docs/DISK_CONTENT.md.

Moved here from CLAUDE.md on 2026-10-22, word for word (CLAUDE.md now keeps only a one-line map).

## Files

### `scripts/os/content.gd`

OSContent (M3): the content library + seeded generator for the
VFS + photos.
THE DISK IS RANDOM (2026-10-18, owner's request): build_filesystem
is SKELETON (_disco_c: what every Win95 PC had and what the game
looks up - drives, boot files, WHALE + SYSTEM/FONTS/TEMP/Desktop,
Program Files with WebNet + PhotoLab, My Documents\My Pictures
ALWAYS in place, TEMP, Recycle Bin) -> FILLING (_riempi_disco,
from catalogo_disco.gd: user folders, invented programs, extra
C:\ folders, system binaries, period files by zone, 2-3 horror
notes) -> KEY 1, the DISK key, which may land in the new
folders too.
THE KEY MAP (owner, 2026-10-18; it used to be one key per
technique - file / folder / web / image): KEY_DISCO 1 = a FILE's
content OR a FOLDER's name, drawn 50/50 AFTER the photos (so no
seed changes its photo carrier) - never both; KEY_WEB_1 / KEY_WEB_2
(2, 3) = two web keys on two DIFFERENT sites (web_runtime.gd);
KEY_IMAGE 4 = the photo, unchanged. The kind of key 1 is recorded
with GameManager.note_key(i, where, kind) in key_kinds, which the
F12 panel prints (FILE / FOLDER / WEB / WEB / IMAGE).
A KEY NEVER SITS INSIDE A BINARY (.EXE/.SYS/.COM/.DLL...): the file
carrier is always a NEW .txt with an FT_CARRIER_* sentence, and
binaries are only unreadable noise - a rule, so that opening every
binary is never needed. Where the .txt can go stays as it was
(owner's call: system folders and TEMP included).
The filling has ITS OWN RNG (VFS_SALT + 2), so it does not shift
the photo/key draws, and editing the catalog does not change which
photo carries the code. Every choice is made by catalog INDEX and
"already here?" is asked of the catalog KEY, never of the
translated name - that is what keeps both languages the same
shape (filesystem_test STESSA_FORMA). Pool nodes carry "voce"
(their catalog key), which the tests read.
THE TREE IS A DISK OF THE '90s (2026-09-20, owner's request
"coerente con l'OS ispirato a Windows 95/98"):
My Computer -> 3.5 Floppy (A:) | Local Disk (C:) | CD-ROM (D:)
| Recycle Bin   (A: and D: empty on purpose: no disk in)
C:\ -> WHALE\ (the system folder, this OS's C:\WINDOWS:
SYSTEM, FONTS, TEMP, Desktop, Start Menu\Programs,
Favorites, *.INI), Program Files\<app>\, My Documents\
(with My Pictures\ = the run's photos), TEMP\, and the
BOOT FILES IN THE ROOT (AUTOEXEC.BAT, CONFIG.SYS,
COMMAND.COM, IO.SYS, BOOTLOG.TXT) - they used to sit in a
"Sistema" folder, where no PC of the era ever had them.
System names are 8.3 UPPERCASE and are NEVER translated (WHALE,
SYSTEM, AUTOEXEC.BAT) while the user folders ARE (My Documents /
Documenti, Program Files / Programmi, Start Menu / Menu Avvio):
that is how the Italian releases shipped, and the contrast is
half of the period feel. _binario() gives .EXE/.DLL/.VXD/.FON a
body of unreadable bytes (filetype "bin", read-only in Notepad),
which also teaches what a binary looks like in a text editor -
the thing that makes the JPEG-comment key land as a find.
_cartelle_chiave() is where the file key can go: PERCORSI, not
names (with a deep tree, looking among C:'s children is not
enough), and the F12 panel prints the DOS path.
Test: filesystem_test.tscn.
From the run seed it builds the filesystem tree,
generates the run's photos, and places the DISK (file or folder)
and IMAGE keys
at random (for the IMAGE key it also picks WHERE to hide it —
_prepare_hiding_spot, scoring by BAND-PASS energy — and which
photo carries it, chosen uniformly at random). (The WEB sites
moved to web_runtime.gd — content.gd no
longer holds the site pool; it keeps the KEY_* indices + key_label.)

### `scripts/os/catalogo_disco.gd`

CatalogoDisco (2026-10-18): DATA ONLY - what MAY be on the disk:
FILE_EPOCA (the family's ordinary life) / FILE_LORE_PADRE (the
father slipping - at least one EVERY run, owner's call) /
FILE_HORROR (the young man the curse started from, and the curse
speaking to whoever is at the PC; 2026-10-23: the 52 Hz whale is the CURSE's emblem, the
young man's nickname is now ~missedtrain / ~trenoperso - comment in catalogo_disco.gd) - all [name key, text key,
zones] and all written from GDD §2b; {PROTAGONISTA} in a text is
the hero's name, ONE CSV row (LORE_PROTAGONIST, "Noah" today),
FILE_DEI_PROGRAMMI (README/LICENSE with {PROG}), PROGRAMMI,
CARTELLE_RADICE, CARTELLE_DOCUMENTI, BINARI_SISTEMA and the
QUANTI_* per run. Zones: DOCUMENTI (never My Pictures), RADICE,
SISTEMA, TEMP, PROGRAMMA, EXTRA. The owner edits THIS plus the
CSV (the owner chose "everything in the CSV, like today" over a
folder of .txt files): add a file = 2 CSV rows + 1 line here.
Recipe: docs/DISK_CONTENT.md. Rules: names unique per language
case-insensitively, and NO text shaped like a key (digit-dash-4).
Test: disco_casuale_test.tscn.

### `scripts/os/secret_glitch.gd`

SecretGlitch (2026-10-17, owner: "piu' reale e piu' spaventoso"):
the GUASTO of the secret-folder dialog, with its own shader
secret_glitch.gdshader. It replaced glitch.gdshader on that
dialog, which read as a FILTER: uniform TV snow, RGB split
everywhere, always the same, and boxed inside the dialog's
rectangle (shifted slices were clipped by its border, i.e. you
could see it was a layer laid on top). Now it is PC failures of
the era: tear bands of IRREGULAR height that slide and WRAP
inside the dialog (a video-memory offset), corrupted 16x16
tiles (copied from elsewhere, wrong palette, 16-colour fill),
the "hall of mirrors" TRAIL of a hung Win95 (stepped copies
outside the border - the effect rect is the dialog plus
MARGINE for this), and a blood-red low-level palette. It
REACTS: a twitch while typing (one key in two), and on wrong
codes the REJECTION - red, tiles, tears, a shake and the screen
behind dimming like a power sag; bursts get more frequent the
longer it stays open (~2.8 s -> ~1 s apart after a minute). The
title is read "with the wrong encoding" during bursts, and
rarely flashes for ~4 frames a SECRET_SUB_* line tied to the
GDD's 52-Hz-whale seed ("a signal no one answers"): CAN YOU HEAR
ME? / NO ONE ANSWERS / ARE YOU STILL THERE? - change or drop them
in the CSV. THREE CONSTRAINTS, on purpose: it never touches the
typed text (losing a code to an effect is punishment, not fear);
no burst exceeds MAX_RAFFICA 0.4 s, so the ending stays
playable; and it stays AROUND THE DIALOG and off glitch.gdshader,
because the full-screen glitch is the ThreatDirector's warning
that an enemy is peeking, and must not get a double. It lives
on the dialog's layer and runs on _process (not Tweens): it dies
with the dialog and freezes with the pause.
Test: cartella_segreta_test.tscn.

## Feature notes

- **Random disk** (2026-10-18): every run builds different folders and files on top of a
  fixed Win95 skeleton (My Pictures always in place) - user folders, invented programs,
  extra `C:\` folders, period files and 2-3 rare horror notes - from
  `scripts/os/catalogo_disco.gd` + `locale/ui.csv`. Recipe for adding/changing a file:
  `docs/DISK_CONTENT.md`. Test: `tests/disco_casuale_test.tscn`.

- **Keys & the win condition** (M1): `start_new_run` generates `GameManager.keys`
  (`{index,code}`, 4×4-char codes) and hides them **with their index prefix** (the
  player finds `1-Q9FY`, not `Q9FY` — `GameManager.key_label(i)`) in OS content
  (owner's map since 2026-10-18): key 1 either in a `.txt` (a carrier file dropped in
  one of `_cartelle_chiave()`) OR in a folder *name* (`Backup <label>`, in the root of C:
  or in My Documents), 50/50; keys 2 and 3 on two different sites of the run, each
  in the visible text or an HTML comment (see the web-key entry below; the old fixed
  `blog.io` / `news.com` are gone); key 4 in a photo. The VFS has a `type:"secret"` node
  ("Cartella protetta") **on the Desktop** (not deletable). Opening it (from the
  desktop or explorer) shows a glitchy **"ACCESSO NEGATO" modal**
  (`desktop.open_secret_folder`) with one **unlabelled** field per row; the player
  types only the bare code (`7MC9`) into the row they deduce from the prefix found
  in the content (no on-screen `1-`/`2-` hints — the "hard mode" of GDD §6.4).
  Validation is row-bound (`GameManager.check_keys`: the code must be in the right
  row); a full match emits `game_won` → `player.gd` fades to a fullscreen
  "HAI VINTO" → menu. The dialog is broken by **`SecretGlitch`**
  (`scripts/os/secret_glitch.gd` + `secret_glitch.gdshader`, 2026-10-17): period PC
  failures (wrapping tears, corrupted tiles, a hung-Win95 trail, a blood-red palette),
  a corrupted title with a rare subliminal line, a twitch while typing and a violent
  REJECTION on wrong codes - never touching the typed text, bursts under 0.4 s, and
  confined around the dialog so it cannot pass for the threat warning. The wrong-code
  message is now `SECRET_WRONG` in the CSV (it was Italian hardcoded in the code).
  (Modals set `desktop._modal_layer` so `cursor_shape_at` stops window-resize
  cursors leaking through the dialog.)
