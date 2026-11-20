# Fonts

Period-looking fonts for the fake OS and its web pages. The Arimo, Cousine and Tinos
families are **metric-compatible clones** of the fonts the 90s web actually used, which is
why pages authored with `face="Arial"` / `face="Courier New"` / `face="Times New Roman"`
land on the right shapes. Comic Neue stands in for Comic Sans.

| File | Clone of | Used for |
|---|---|---|
| `Arimo-*.ttf` | Arial / Helvetica | the whole OS chrome and page body text (`sans`) |
| `Cousine-*.ttf` | Courier New | `face="Courier New"` runs (`mono`) |
| `Tinos-*.ttf` (4: Regular, Bold, Italic, BoldItalic) | Times New Roman | `face="Times New Roman"` / serif runs (`serif`) |
| `ComicNeue-Regular.ttf`, `ComicNeue-Bold.ttf` | Comic Sans | `face="Comic Sans MS"` runs (`comic`) |

Licence: **SIL Open Font License 1.1** — free to bundle and ship with the game.
`LICENSE-OFL.txt` (Arimo, Cousine), `LICENSE-OFL-Tinos.txt`, `LICENSE-OFL-ComicNeue.txt`.
Sources: <https://github.com/googlefonts/Arimo>, <https://github.com/googlefonts/Cousine>,
Tinos from the same Google Fonts / Chrome OS core-fonts source, Comic Neue by Craig Rozynski.

They are wired in `scripts/os/win95.gd` (`Win95.font()` + `make_theme()`; the web families
through `_FONT_FILES`, which gained `serif`, `serif_b`, `serif_i`, `serif_bi`, `comic` and
`comic_b` on 2026-10-23), so every OS window, menu and page picks them up automatically.
`HtmlBB.famiglia(face)` maps a page's `face=` to one of the four families (sans / serif /
comic / mono). Comic Neue has no italic file: italic inside a comic run falls back to
the regular one. To add another family, drop its files here and add its entries to
`_FONT_FILES` and a branch to `famiglia()`.
