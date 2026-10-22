# Search Through the Files

A first-person horror game built in **Godot 4.6.1** (Forward Plus).

You sit at a desk in front of a retro Windows 95/98-style computer. To win, you
must dig through the machine — files, fake websites, "HTML source", images — to
find hidden **keys** that open a secret, password-protected folder. But you are
not alone: enemies can appear both in the room and inside the computer, and a
moment of inattention ends with a jumpscare. Every run hides the keys somewhere
new.

Think *Five Nights at Freddy's* meets *Welcome to the Game*.

> Status: playable prototype. The retro OS, the 4 keys, the random disk, 30 fake web
> sites, the room enemies and the PC viruses work; models, sound and the ending are
> still to come. See the docs.

## Documentation

| Document | What's inside |
|---|---|
| [CLAUDE.md](CLAUDE.md) | How the project is built; rules for AI assistants and contributors. |
| [docs/GDD.md](docs/GDD.md) | Game Design Document — the full creative vision. |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the code works (room ↔ PC, the fake OS, the VFS). |
| [docs/ROADMAP.md](docs/ROADMAP.md) | What to build next, in order. |
| [docs/code/](docs/code/README.md) | The code area by area, the glossary and the tests. |

## Running the game

Open the project folder in Godot 4.6.1 and press **Play**, or from the command
line:

```powershell
$godot = "C:\Users\ffria\Desktop\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"
& $godot --path "z:\Progetti\Search Through the Files"
```

The game opens on the **Main Menu** → **Start** drops you into the room. Move the
mouse to the screen edges to look around; click the computer case to turn it on;
click the monitor to dive into the PC. The login password is currently `123`.

## License

See [LICENSE](LICENSE).



Le manopole (cosa toccare per tarare)
app_image_viewer.gd: CODE_SIZE_FACTOR (dimensione) e CODE_ALPHA (trasparenza: più basso = più nascosta ma più difficile da trovare; ~0.6 è un buon punto).
content.gd: PHOTO_KEY_DELTA (scarto di colore testo↔sfondo: l'ho alzato a 0.006 perché con la trasparenza serviva un minimo di segnale per restare trovabile).