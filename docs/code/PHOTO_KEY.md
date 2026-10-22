# The photo key

Read before touching the image viewer, adjust.gdshader or how the image key is hidden. It is the most measured part of the project: read the numbers before changing a constant.

Moved here from CLAUDE.md on 2026-10-22, word for word (CLAUDE.md now keeps only a one-line map).

## Files

### `scripts/os/app_image_viewer.gd`

ImageViewerApp (M3): opens a photo + adjustment sliders
(brightness/contrast/saturation/levels/Nitidezza via
adjust.gdshader); the key photo hides a code revealed only by
adjusting it (Nitidezza is the one that actually separates it
from photo detail — see the M3 bullet below).

### `scripts/os/adjust.gdshader`

Photo adjustment: brightness/contrast/saturation/levels
(point-wise) plus "Nitidezza" — a genuine BAND-PASS filter (the
only non-point-wise control) that separates the hidden code from
photo detail by spatial frequency, not amplitude. Shared by the
photo and its hidden-code Label (same material).
The slider is a THRESHOLD, not a gain (2026-09-17): it sweeps a
knee logarithmically (BANDA_KNEE_HI -> LO) with a DEAD zone below
it, so anything under DEAD x knee stays flat grey while the
strokes go to full black/white. With the old linear gain
(band x detail x 60), clipping favoured the code only once its
core beat the noise PEAK (~4x its deviation) while the generator
produced 2.9 — measured with photo_reveal_test: on 4 of 6 photos
the worst glyph separated at NO slider position, and on her.jpg
74% of the background was saturated. The coring drops the
requirement to ~1/DEAD. Consequence on feel, and it is deliberate:
the slider is TUNED, not dragged to the stop, and the sweet spot
differs per photo.
The wide blur uses THREE rings (1.8/3.8/6.8 px): with only 3.5 and
7 it had zero weight between 1 and 3.5 px — a hole right where the
strokes are (2.2-2.5 px of composition; the old comment claimed
3-5 px and was wrong). The crossfade closes at detail 0.04, not
0.25, which used to mix the photo back at full amplitude for the
first quarter of the travel.
sRGB throughout, and MEASURED: the composition SubViewport holds
values in the SAME space as the file bytes (deviation
0.0000-0.0069 of luma over the 6 photos; the "linear" hypothesis
was off by 0.20-0.29), and the code keeps ~1 distinct level per
level of amplitude, so the 8-bit target loses nothing and
use_hdr_2d is not needed. A CPU twin of this kernel lives in
OSContent.bp_shader_at — change the radii or weights here and you
MUST change them there.

## Feature notes

- **Data-driven content + seeded generator + image puzzle** (M3, complete): the
  previously hardcoded VFS tree now lives as **data** in `scripts/os/content.gd`
  (`OSContent`); `vfs.gd::_build` is a thin consumer (`OSContent.build_filesystem()`).
  From the **run seed**, `OSContent` **generates** content reproducibly. The 4 keys
  (owner's map since 2026-10-18 — before it was one per technique): **1 = the disk**,
  `build_filesystem()` drops it 50/50 either into a random carrier file (random
  name/text) in a random folder or into the name of a random "backup" folder; **2 and 3
  = web**, on two different sites; **4 = image**. The **web keys** are handled by
  `web_runtime.gd` (`WebRuntime.build()`, called from `BrowserApp.reset_pages()`): it picks
  a carrier site, a mode (**visible** on the page / **source-only**) and — since 2026-09-16 —
  a **position**, drawn from the seed among every safe spot `web_anchor.gd` finds in that page.
  Before, it was always an extra line before `</body>` and the owner recognised it on sight;
  now it can sit mid-page or mid-code, WTTG2-style: mid-sentence it inserts the **bare code**
  between two words (`...il cielo e' 3-A87G blu`), elsewhere the carrier sentence, and in
  source-only mode a comment (between blocks, mid-markup, in the table markup, in `<head>`) or
  a `title=`/`alt=` attribute. `reset_pages()` resolves it immediately (reading the carrier via
  `BrowserApp.read_page`, since `WebRuntime` does no file IO) so the **F12 panel says where**:
  `3-A87G  WEB  http://www.webnet.it/~jack99 - visibile - in coda al paragrafo 3`. The
  **image key** is hidden in one of the run's photos: `My Documents\My Pictures` holds 3–4
  generated photos (`make_photo`), and `ImageViewerApp` (`app_image_viewer.gd`) shows them
  with **adjustment sliders** (brightness / contrast / saturation / levels / **"Nitidezza"**
  via `adjust.gdshader`); the key photo carries the code as a semi-transparent `Label`
  sharing the photo's material, so it only emerges once the player adjusts the image.

  **The one thing that matters here: the point-wise sliders (brightness/contrast/
  saturation/levels) amplify the label AND the photo's own detail equally, so only the
  RATIO between them decides whether the code can ever be read.** A fixed tiny offset (the
  old `PHOTO_KEY_DELTA = 0.006`) was 3-8x weaker than the local detail of real photos —
  unfindable at any point-wise slider setting; that was a real bug, fixed 2026-09-11. An
  intermediate design (2026-09-13) tried to manufacture a flat hiding spot by locally
  blurring/hazing the photo, but that left a visible pale stain on busy photos and biased
  the carrier toward the ~2 of 6 photos that happened to have a flat area already —
  the owner rejected both (a visible smudge, and broken randomization).

  **Current design: a "Nitidezza" slider that is a genuine band-pass filter** (in
  `adjust.gdshader`: ~21 taps, a fine blur ≈1.2 px minus a wide blur ≈7 px on luminance,
  flat form `0.5 + band*gain`; Godot shader functions cannot read predefined variables like
  `TEXTURE` — pass the sampler as a parameter). This is the only *non-point-wise* control, so
  it is the only one that can separate the code from photo detail by **spatial frequency**
  instead of amplitude — most of a real photo's raw noise is low-frequency (tonal ramps,
  soft silhouettes) that doesn't compete with 3-5 px strokes at all. `OSContent` scores
  candidate hiding boxes by band-pass energy (`_bp_pair`/`_bp_pair_img`/`_box_bp`, a fast
  successive-halving blur pair, cached), not raw variance, and scales the label's offset to
  that (`CODE_DELTA_K` × `sigma_bp`, clamped `CODE_DELTA_MIN`…`CODE_DELTA_MAX`).

  **Measured hard limit: on photos with texture *at* the stroke scale (grain, foliage,
  weave — 5 of the owner's 6 photos) no filter separates code from texture once the code is
  faint enough to be invisible at rest.** Tried and measured negative: a bigger code (worse:
  raw noise at larger scales is 0.03-0.10 vs 0.008-0.027), hiding in chrominance (only
  1.6-2.4x quieter, worse on colourful photos), preferring shadows (not quieter — on
  `beautiful_horse.png` the dark area measured *noisier*, 0.052 vs 0.009 in the light area),
  and blurring harder (a single-step big resize aliases and *raises* band noise; even a
  proper mip-style pyramid barely helps). So the owner chose, deliberately: **any photo can
  host the key, at the cost of a faint watermark visible on close inspection** (not a
  softened patch — the photo pixels outside the label are untouched, measured 0.00 level
  diff). **TWO ROUTES since 2026-09-17.** The image key is drawn from the seed between:
  - **in the pixels** (the original watermark + "Nitidezza" reveal, described below), and
  - **in the FILE** — the code sits in the photo's bytes as a JPEG comment
    (`code_commento` on the VFS node) and is found by opening the image with **Notepad**
    ("Apri con Blocco note" in the desktop and explorer context menus), which shows
    `OSContent.byte_dump`: a plausible JFIF header, unreadable bytes, and the comment in
    clear after the `FF FE` COM marker. Period-accurate, works on **any** photo, and it is
    the game the title promises. `CODE_QUOTA_FILE` (0.5) is the split.
    **WHERE in the file is drawn from the seed** (2026-09-20, owner: *"appare sempre in
    alto"* — measured: line 7 of 31, the 20% mark, on every seed and every photo, because
    the position was written by hand; the same defect the web key had before
    `web_anchor.gd`). Four spots, and they are the only honest ones: after the JFIF header,
    between the quantization tables, right before the start of scan, or in the **tail after
    the end of the image** — a comment cannot sit inside the compressed scan data (there
    are no markers in there, so the file would not be a JPEG), and the tail is what period
    programs really did leave attached. The filler blocks vary in length too, so neither the
    line number nor the file length is a tell: measured 5%-98% of the file over 25 runs.
    Notepad opens images read-only — rewriting random bytes must not be able to change game
    content. Test: `tests/photo_file_key_test.tscn` (40 seeds: both routes must occur, the
    code must be in the bytes XOR in the pixels, decoys stay clean, the dump must be stable
    and JPEG-shaped, and the F12 panel must say which route was used).

  **Why a second route exists — the pixel route has a MEASURED ceiling.** For the code to be
  *both* invisible at rest *and* revealable with the slider, the masking structure has to be
  about **6.8x** the noise at stroke scale; on real photographs the best obtainable is
  **0.4-0.9** (`tests/photo_banda_scan`). It is short by an order of magnitude, so on most
  photos the watermark is either visible immediately or unrevealable — no constant fixes
  that, and neither does a different filter shape (the ratio is invariant to gain; six kernel
  variants were measured, all within ±20%). The point-wise route is no better: the levels
  sliders amplify the code and the texture equally, measured identical to the at-rest figure.
  What the constants below control is only **how visible the watermark is**, not whether it
  can be read.

  **REBUILT 2026-09-17** after the owner reported the code was *too obvious on most photos
  and illegible on `sun_person.jpg`*. Both symptoms had the same three causes, and all three
  are now measured rather than assumed:

  *(The three findings below are the diagnosis. The instrumentation and the defect fixes were
  kept; the retuning they suggested was REVERTED on the owner's call — it made the watermark
  land on the ceiling on 4 of 6 photos, so it read as stronger than before, and the coring
  reveal made the slider feel dead. What survives in the code: `bp_shader_at`/`banda_box`, the
  three-ring wide blur, the rotated measurement rect, the aligned eyeball tool, and the
  tests.)*

  1. **The generator was measuring in the wrong band.** It scored spots and sized the offset
     with a pyramid (`_bp_pair_img`, half-res minus eighth-res => band ~2-8 px), which
     *averages away* the grain and JPEG-block edges between 1 and 4 px that the shader sees
     in full. Where the pyramid estimated a band ratio of 2.3-2.9 the real one was 0.85-1.8.
     `OSContent.bp_shader_at` / `banda_box` are now an exact CPU twin of the shader's kernel
     (same radii, weights, luma and gamma — **keep them in step with `adjust.gdshader`**),
     and every decision uses them. The pyramid survives only to *rank* candidates cheaply;
     the few finalists are re-measured in the real band.
  2. **`CODE_BP_RESPONSE` was 0.65, measured 0.33.** It had been calibrated on the pyramid,
     i.e. on a filter the player never touches — twice the optimism.
  3. **One constant was doing both harms.** The old law `delta = clampf(CODE_DELTA_K *
     noise, MIN, MAX)` pinned delta on the ceiling above noise 0.0129, so calm photos got a
     ceiling-sized watermark and busy ones a relatively too-weak code. The printed "ratio"
     was identically 2.925 for every photo — a read-out of "am I on the ceiling", not a
     measurement. Replaced by **two independent budgets** (`_valuta`): a *floor*
     `CODE_R_TARGET * band_noise / CODE_BP_RESPONSE` for findability and a *ceiling*
     `max(CODE_FILIGRANA_MIN, CODE_FILIGRANA_K * sigma)` for invisibility, relative to the
     spot's own structure (`sigma`, which the old `_valuta` received and threw away).
     Floor > ceiling => the spot is **not feasible**.

  The noise is taken as the **98th percentile inside a 6x2 grid that matches the glyphs**,
  not an RMS over quadrants: the reveal's dead zone has to beat the noise *peak*, and a
  glyph landing on a busy column stayed buried while the quadrant average looked fine
  (measured on `sun_person.jpg`: ratio 2.95 on the first glyph, 0.85 on the last).
  `CODE_R_TARGET` 1.8 is **calibrated against rendered measurements**, not theory — pairs of
  (predicted ratio, measured LEG from `photo_reveal_test`): 0.39->0.00, 0.53->0.08,
  0.59->0.00, 1.57->0.77, 2.22->0.92. The theoretical 1/DEAD = 2.22 double-counted the
  margin, because a 98th percentile is already ~2x an RMS.

  **`CODE_ALPHA` 0.40 is NOT a visibility knob** — `_place_code` divides the offset by it
  (`delta / ALPHA`), so the COMPOSITED offset is `delta` whatever alpha is; alpha only sets
  how much of the photo's own texture survives inside the strokes (less alpha = less of a
  flat-patch tell). `CODE_DELTA_MAX` 0.058 survives only as a safety rail ("never a
  plain-text sign"), no longer as the operative constraint.

  **The blur fallback fires only when it reaches feasibility.** Tried the opposite — keeping
  the best blur even when it falls short — and it *does* buy legibility (`sun_person.jpg`
  LEG 0.02 -> 0.77) but leaves an obvious pale oval with the code readable at rest: the
  visible smudge the owner rejected on 2026-09-13. So an unblurred, unsuitable photo is
  **named by the census** instead (`photo_key_test` prints "NON FATTIBILE" plus what it
  would have needed) — the owner's call: any photo stays a possible carrier, and the test
  flags the file to replace.

  **Where this leaves the current 6 photos** (`photo_reveal_test`; LEG = the worst glyph's
  separation at the best slider position, >=0.75 means readable):
  `beautiful_horse.png` 0.85 at 11.9 levels at rest (blurred, feasible) and
  `thisisjustme.jpg` 0.98 at 3.0 — those two work. `her.jpg` 0.02, `mycity.jpg` 0.00,
  `sun_person.jpg` 0.00, `themasks.jpg` 0.00 — **these four cannot host the code** and are
  named by the census; they are the ones to replace (the photos are not final).
  Before this work the same measure read 0.08 / 0.00 / 0.00 / 0.00 / 0.76 / 0.98, i.e. the
  reveal slider essentially never worked and the only "passing" photo was the blank white one.

  Re-measured with the corrected filter, and still negative: **a bigger code** (stroke
  0.062 -> 0.090 with the band scaled to match: band noise 0.007-0.092 -> 0.065-0.109, and
  `beautiful_horse.png` LEG 0.85 -> 0.00) and **a smaller one** (0.045: a lighter watermark,
  but the glyph cores drop below what can be measured or read). 0.062 stays.
  **Carrier is picked uniformly at random** among the run's photos —
  distribution measured 11-23% across 6 photos over 60 runs, no more bias toward "easy"
  photos. `make_photo` always CPU-resizes to `CODE_SCAN` (matching what the search measured)
  even for untouched photos, which also killed a latent GPU-downscale-aliasing bug.
  The chosen spot, average colour and offset are stored on the VFS node (`code_uv` /
  `code_base` / `code_delta`); `make_photo`/`ImageViewerApp` only draw. Tests:
  `tests/photo_reveal_test.tscn` (**the real gate**: per-GLYPH legibility measured through
  the real shader while sweeping the `detail` uniform. Masks come from UPSTREAM — the
  composition with and without the Label, so stroke positions are exact and noise-free —
  and values from DOWNSTREAM, the post-shader host viewport. `L_g` = the fraction of a
  glyph's core falling outside [P1, P99] of that same glyph's background, which unlike a
  signal/noise ratio does not lie when the output clips. `LEG` = the best the WORST glyph
  reaches over the slider's travel; one buried letter makes the whole code unreadable, which
  is exactly what the old global `>= 0.5*dmax` core average hid. Set `SEVERO = true` to turn
  its findings into failures);
  `tests/photo_key_test.tscn` (per-photo census with floor/ceiling/feasibility, 6 seeds, and
  a 60-run carrier-uniformity check. Its measurement rect now follows the label's +-12deg
  ROTATION — the axis-aligned rect never measured the extremes of the first and last glyph,
  and fixing that alone exposed a real failure that had been passing);
  `tests/photo_banda_scan.tscn` (dev tool: the quietest spot in the real band on each photo
  and the offset it would need — answers "does a good spot exist at all?");
  `tests/photo_look_check.tscn` (dev tool: original-vs-shown plus a reveal STRIP at five
  slider positions. Its CPU twin now uses the shader's own kernel and output law — it used
  gain 14 against the shader's 60, so the images the owner judged by eye were ~4x gentler
  than the game).

  Each build seeds its **own** `RandomNumberGenerator` from
  `run_seed` + a salt, so content is reproducible **and order-independent** (the
  browser builds pages lazily). The index→category map is fixed (1=disk: file or
  folder, 2-3=web, 4=image) so the builders place their own keys without coordinating.
  **Photos:** author images dropped into `assets/textures/photos/` are picked up
  automatically (a seeded subset per run, via `OSContent._photo_files`); if the folder
  is empty, `make_photo` generates procedural placeholders. Either way the code is
  overlaid at runtime by the viewer (it can't be baked into a file — the key is per-run).
