# The disk content — what is on the fake PC, and how to change it

Every run builds a **different disk**: different folders, different files, a couple of
horror notes in different places. Only the **skeleton** stays the same — the things every
Windows 95/98 PC had, and that the game itself relies on.

This page is the recipe for **adding or changing** a file, a folder or a program.
You only touch two files:

| What | Where |
|---|---|
| the **words** (file names, file texts, folder names) | `locale/ui.csv` |
| the **list** of what can appear, and where | `scripts/os/catalogo_disco.gd` |

The code that reads them is `OSContent._riempi_disco` in `scripts/os/content.gd`; you
should not need to open it.

---

## 1. What is fixed and what is random

**Fixed (the skeleton)** — in `OSContent._disco_c` / `_cartella_sistema`:

```
My Computer
├─ 3½ Floppy (A:)            (empty: no disk in)
├─ Local Disk (C:)
│  ├─ WHALE\                  the system folder (this OS's C:\WINDOWS)
│  │  ├─ SYSTEM\  FONTS\  TEMP\
│  │  ├─ Desktop\             ← the game looks this up BY NAME
│  │  ├─ Start Menu\  Favorites\
│  │  └─ WHALE.INI  SYSTEM.INI
│  ├─ Program Files\
│  │  ├─ WebNet Explorer\     (the browser)
│  │  └─ PhotoLab 2.0\
│  ├─ My Documents\
│  │  └─ My Pictures\         ← ALWAYS here: the run's photos + the readme hint
│  ├─ TEMP\
│  └─ AUTOEXEC.BAT  CONFIG.SYS  BOOTLOG.TXT  COMMAND.COM  IO.SYS
├─ CD-ROM (D:)               (empty)
└─ Recycle Bin
```

**Random every run** — from the catalog:

- 1-3 **user folders** inside My Documents (Letters, School, Recipes, ...);
- 1-3 **invented programs** in Program Files, each with its `.EXE`/`.DLL` and maybe a
  README and a LICENSE;
- 0-2 **extra folders** in `C:\` (GAMES, DRIVERS, DOWNLOAD, INTERNET);
- extra system files in `WHALE\SYSTEM`, a few `~DFxxxx.TMP` in the TEMP folders;
- **period files** (diary, letters, logs, `.INI` files, ...) spread by zone;
- **2-3 story files** per run, rare on purpose so that finding one lands: **1-2 of the
  father** (always at least one — the story weighs on him) and **1 horror** (the voice of
  the young man the curse started from, or of the curse itself).

### Write them from the story

The texts follow the story in [GDD.md §2b](GDD.md): the PC belonged to Noah's **father**.

| List in the catalog | Whose voice | What it is |
|---|---|---|
| `FILE_EPOCA` | the family | ordinary life: the diary of the first days, a letter to grandma, the kids' homework, the phone list. The warmer these are, the worse the rest. |
| `FILE_LORE_PADRE` | the father | diaries that start normal and slip, a note written to his sons in a moment of lucidity, the last night |
| `FILE_HORROR` | the young man / the curse | loneliness, nobody answering (the 52-Hz whale is his emblem); the curse speaking to whoever sits at the PC *now* |

What the GDD marks as **open** (names, how the curse passes from one person to the next)
is not written in the texts: write around it ("my wife", "the boys", "the neighbour").

**The protagonist's name**: write `{PROTAGONISTA}` in a text and the game puts the name
there. The name itself is one row of the CSV, `LORE_PROTAGONIST` (today `Noah`): change
that row and every text follows.

The same run seed always gives the same disk, in every language.
The keys 1 (inside a file) and 2 (in a folder name) can land in the new folders too.

---

## 2. Add a file

Example: a new horror note that can end up in My Documents or in a TEMP folder.

**Step 1 — the words**, two new lines at the end of `locale/ui.csv`
(columns: key, English, Italian):

```
FN_HR_MIRROR,mirror.txt,specchio.txt
FT_HR_MIRROR,The monitor reflects the room.\nThe room has one more person.,Il monitor riflette la stanza.\nNella stanza c'e' una persona in piu'.
```

- `FN_` = the file **name**, `FT_` = the file **text**. Any name works as long as it starts
  with those prefixes and is not already used.
- A line break inside the text is written `\n` (backslash + n), not a real new line.
- If a cell contains a **comma**, put the whole cell between double quotes: `"Hello, you"`.

**Step 2 — the list**, one line in `scripts/os/catalogo_disco.gd`, inside `FILE_HORROR`
(or `FILE_LORE_PADRE` for one of the father's files, or `FILE_EPOCA` for an ordinary one):

```gdscript
	["FN_HR_MIRROR", "FT_HR_MIRROR", [DOCUMENTI, TEMP]],
```

The last part says **where** the file may go. The zones:

| Zone | Where |
|---|---|
| `DOCUMENTI` | My Documents and its user folders (never My Pictures) |
| `RADICE` | the root of `C:\`, next to AUTOEXEC.BAT |
| `SISTEMA` | `C:\WHALE` |
| `TEMP` | `C:\TEMP` and `C:\WHALE\TEMP` |
| `PROGRAMMA` | inside a program's folder |
| `EXTRA` | the extra folders of `C:\` (GAMES, ...) — only when the run has some |

**Step 3 — import**: open the project in the Godot editor (it re-imports the CSV by
itself), or run `--import` from the command line. Without it the game keeps the old texts.

**Step 4 — check**: run `tests/disco_casuale_test.tscn`. It tells you if a translation is
missing, if the new name clashes with another file, if the file never appears in 30 runs
(usually a wrong zone), checked over 80 runs, or if the text contains something shaped like a key.

### Change a file

Only step 1: edit the text (or the name) in `locale/ui.csv`, then import.

### Two rules

- **Names must all be different**, in every language — also just by upper/lower case:
  on a Windows disk `Note.txt` and `NOTE.TXT` are the same file.
- **Never write something shaped like a key** in a text: a digit, a dash and four
  letters/digits (`2-AB7K`). The hunt is fair only if the real keys are the only things
  with that shape. The test refuses it.

---

## 3. Add a user folder (inside My Documents)

1. CSV: `FD_PHOTOS_OLD,Old photos,Foto vecchie` (`FD_` = folder name, translated).
2. Catalog: add `"FD_PHOTOS_OLD"` to `CARTELLE_DOCUMENTI`.

It starts empty; period and horror files with zone `DOCUMENTI` can land in it.

## 4. Add a program (inside Program Files)

One line in `PROGRAMMI` — no CSV needed, product names are the same in every language:

```gdscript
	["PaintBox 2", ["PAINTBOX.EXE", "PBFILTER.DLL"]],
```

The `.EXE`/`.DLL` files are generated as unreadable binaries. Each program also gets,
with some probability, the README and LICENSE of `FILE_DEI_PROGRAMMI`, where `{PROG}` in
the text becomes the program's name. Use invented names, not real brands.

## 5. Add an extra folder in `C:\`

One line in `CARTELLE_RADICE`: an 8.3 UPPERCASE name (not translated, like the system
folders of the time) and its binaries, e.g. `["UTILS", ["UNZIP.EXE"]]`.

## 6. How many of each

The `QUANTI_*` constants at the bottom of the catalog: `[minimum, maximum]` per run.
`QUANTI_PADRE` and `QUANTI_HORROR` set the tone — keep them low. The test insists on at
least one father file per run, whatever the catalog says.
