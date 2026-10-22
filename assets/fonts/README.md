# Fonts

Period-looking fonts for the fake OS and its web pages. Both families are
**metric-compatible clones** of the fonts the 90s web actually used, which is
why pages authored with `face="Arial"` / `face="Courier New"` land on the right
shapes:

| File | Clone of | Used for |
|---|---|---|
| `Arimo-*.ttf` | Arial / Helvetica | the whole OS chrome and page body text |
| `Cousine-*.ttf` | Courier New | `face="Courier New"` runs (monospace) |

Licence: **SIL Open Font License 1.1** (see `LICENSE-OFL.txt`) — free to bundle
and ship with the game. Sources: <https://github.com/googlefonts/Arimo>,
<https://github.com/googlefonts/Cousine>.

They are wired in `scripts/os/win95.gd` (`Win95.font()` + `make_theme()`), so
every OS window, menu and page picks them up automatically. To add a serif
(Times New Roman look) drop `Tinos-Regular.ttf` / `Tinos-Bold.ttf` here from the
same source and map it in `Win95.font()`.
