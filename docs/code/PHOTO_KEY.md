# The photo key

Read before touching the image viewer, adjust.gdshader or how the image key is hidden.

Moved here from CLAUDE.md on 2026-10-22. **Rewritten 2026-11-27** (owner's decisions, branch feature/foto-a-tema-con-licenza): the pixel route is now a secret RECIPE (one slider + one direction); the old watermark + band-pass reveal and its long measurement narrative are gone (short history below).

## Files

### `scripts/os/app_image_viewer.gd`

ImageViewerApp: opens a photo + adjustment sliders (brightness / contrast / saturation / black point / white point / "Nitidezza" via adjust.gdshader). The slider panel (210 px) is a PanelContainer with a ScrollContainer ("Scorri") around the column: in a short window a Win95 scroll bar appears instead of cutting the last sliders and "Reimposta" (owner, 2026-11-25: "alcuni pulsanti sono tagliati"); long labels wrap.

It holds ALL the recipe logic and constants (so the generator in content.gd and the viewer share one source): `CORSE` (travel of each slider), `DEFAULTS`, `posizione` / `valore_a` (value <-> position 0..1 along the travel), `VERSI`, `avanzamento(ing, valori)`, `rivelazione(ricetta, valori)`, `luma_regolata(l, valori)` (CPU twin of the point-wise shader), `valori_ricetta(ricetta)`, `verso_migliore(base_l, ricetta)`.

### `scripts/os/adjust.gdshader`

Photo adjustment: brightness/contrast/saturation/levels (point-wise) plus "Nitidezza" (a band-pass on `detail`). Photo and code Label share the material. Since 2026-11-27 Nitidezza ("detail up") is just one of the sliders a recipe can pick; it no longer has a special role.

## The pixel route of key 4 (recipe, 2026-11-27)

Key 4 is drawn from the seed between two routes (`CODE_QUOTA_FILE` 0.5): **pixels** (below) and **file** (below). Carrier photo is picked uniformly among the run's photos.

**The recipe** (owner, 2026-11-27: "one slider, one direction"). Per run ONE ingredient `{param, verso: +1/-1}` is drawn among `ImageViewerApp.VERSI`: brightness up/down, contrast up, saturation up/down, black_point up, white_point down, detail up (the directions that do not flatten the photo). No hint text for the player (owner's choice).

**At rest the code Label has alpha 0**: truly absent (measured 0 pixels on screen). Reveal (`rivelazione(ricetta, valori)`, 0..1) is the max of:
- `smoothstep(DIR_INIZIO 0.15, DIR_PIENO 0.75, avanzamento)`, where `avanzamento(ing, valori)` is how far the right slider moved from its default in the right direction, divided by the travel on that side (0..1; wrong direction = 0);
- the FALLBACK `smoothstep(TOT_INIZIO 1.2, TOT_PIENO 2.5, tot)`, `tot` = sum over all 6 sliders of |position - default position|. One slider alone, even at its end, gives at most 1.0, so a single wrong slider never reveals; about 3 sliders pushed hard do ("heavy adjustment" as the owner's fallback).

`valori_ricetta` = the right slider pushed to `DIR_PIENO`, used by `_punto_codice` / `verso_migliore`.

**Look of the code**: colour step at full reveal `CODE_FORZA` 0.30, opacity `CODE_OPACITA` 0.85; the sign (lighter/darker) is chosen by `verso_migliore` so it is not burnt out at the recipe values. `DIR_*`, `TOT_*`, `CODE_FORZA` and `CODE_OPACITA` are `static var` (not const) only so tests/photo_lab.tscn can tune them live; in the game they never change.

**History of the recipe, same day.** First version: 2 sliders each with a PRECISE target position (window `RIC_FINESTRA`, fade, a shadow with one right, division by `guadagno()`, wrong-slider penalty `RIC_FUORI`, hidden time help `AIUTO_*` / node `aiuto_t`). Owner: "troppo complicato da gestire e capire". All of that was removed (and `_ingrediente`, `RICETTA_DISTANZA`, `RICETTA_CURSORI` in content.gd); the fallback replaces the time help.

**Found for the stats** only when reveal >= 0.6 (before: on opening the photo).

**Generation** (content.gd `_ricetta(rng)` picks slider + direction, `_punto_codice`, `ricetta_testo`): draws the recipe, then picks among 12 random points the one that stands out most at the recipe values (CPU twin `ImageViewerApp.luma_regolata`); if the best stand-out is below `CODE_STACCO_MIN` 0.12 the recipe is re-drawn (up to 30 times). The chosen point and recipe are stored on the VFS node. F12 panel line: "in the pixels at x%,y% - recipe: detail up" (`ricetta_testo`, e.g. "brightness up").

**Photos**: any photo works now. The old requirements (1600 px, a flat area, JPEG quality) NO LONGER APPLY.

**History, so it does not come back.** Until 2026-11-26 the code was always on the photo as a faint watermark, revealed by the Nitidezza band-pass. It was measured as a dead end: for the code to be both invisible at rest and revealable, the masking structure had to be about 6.8x the noise at stroke scale, while real photos gave 0.4-0.9 (no constant, no filter shape, no bigger/smaller code, no chrominance or shadow hiding fixed it). So the watermark was either visible at once or unreadable. The owner then tested in a live tool: on almost every photo the code was visible at rest and only Nitidezza mattered. Removed from content.gd: `_prepare_hiding_spot`, `_do_prepare`, `_valuta`, `_apply_soft_patch`, `_best_hiding_spot`, the band-pass CPU twin (`bp_shader_at`, `banda_box`, `_bp_pair`...), the blur patch and the `CODE_ALPHA/DELTA/BP/BLUR...` constants.

## The file route (unchanged)

The code sits in the photo's bytes as a JPEG comment (`code_commento` on the VFS node) and is found by opening the image with **Notepad** ("Apri con Blocco note" in the desktop and explorer context menus), which shows `OSContent.byte_dump`: a plausible JFIF header, unreadable bytes, and the comment in clear after the `FF FE` COM marker. Works on any photo.

**WHERE in the file is drawn from the seed** (2026-09-20, owner: *"appare sempre in alto"* - measured: line 7 of 31 on every seed, because the position was written by hand; same defect the web key had before `web_anchor.gd`). Four spots, the only honest ones: after the JFIF header, between the quantization tables, right before the start of scan, or in the **tail after the end of the image** (a comment cannot sit inside the compressed scan data; the tail is what period programs really left). Filler blocks vary in length too: measured 5%-98% of the file over 25 runs. Notepad opens images read-only. Test: `photo_file_key_test`.

## Photos and names

- **Files**: `assets/textures/photos/` is gitignored, local only. Since 2026-11-26/27 it holds 23 licensed photos (Wikimedia Commons, StockSnap via Openverse, Flickr CC BY) + `beautiful_horse.png` (owner's own) + `thisisjustme.jpg` (source still to verify with TinEye before release). Credits (author, license, link) in `assets/textures/photos/CREDITI.md`; **the CC BY ones must go in the game's credits**. `her`, `mycity`, `themasks`, `sun_person` had no license: moved to `/_foto_rimosse/` (gitignored, `.gdignore`). Dropped images are picked up automatically (a seeded subset of `PHOTO_COUNT` = 5 per run, fixed since 2026-11-27, `OSContent._photo_files`); if the folder is empty `make_photo` generates procedural placeholders.
- **Names** (2026-11-27, owner: "non mi piace il nome come appaiono le foto"): in My Pictures the photos are no longer `IMG_0123.jpg`. `OSContent._nomi_foto(count, seme)` names them like a 1997-99 digital camera, ONE camera per run, increasing numbers with gaps (deleted shots): `MVC-014F.JPG` (Sony Mavica), `DCP_0311.JPG` (Kodak), `DSCN0042.JPG` (Nikon), `PICT0019.JPG`, `DSC00087.JPG`, `P1050042.JPG` (Olympus: month in hex, day, counter). Own RNG, so the rest of the folder's sequence is unchanged.
- Every build seeds its own `RandomNumberGenerator` from `run_seed` + a salt, so content is reproducible and order-independent. Index->category map is fixed (1=disk, 2-3=web, 4=image).

## Keys 1-3 in short (kept from the original note)

Owner's map since 2026-10-18: **1 = the disk** (a random carrier file or the name of a random "backup" folder, 50/50), **2 and 3 = web** on two different sites (`web_runtime.gd`, positions from `web_anchor.gd`, F12 says where), **4 = image**. Detail: CONTENT.md and WEB.md.

## Tests

`photo_key_test` (headless, recipe, reveal curve), `photo_chain_test` (windowed, real screen), `photo_file_key_test` (file route), dev tool `photo_lab` (live tuning). What each proves: [TESTS.md](TESTS.md).
