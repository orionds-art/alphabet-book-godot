# alphabet book (Godot) — handoff (19 Oct 2026)

Astrid, the alphabet book and the leaf-1 page turn from Blender, as **baked playback** with Astrid in the **woodcut**
look. Godot 4.7.2, Forward Plus, same settings as Parrots France. Its own git repo (remote
`origin` = github.com/orionds-art/alphabet-book-godot, not pushed by the export agent).

Blender side: `F:\WOODCUTS Blender\woodcut alphabet book\` (repo alphabet-book), working file
`ASTRID book arena animations.blend`, action `ASTRID walk + page turn` (frames 1–1050, 30 fps).

## What's here

| Path | What | Who writes it |
|---|---|---|
| `alphabet_book_MAIN.tscn` | main scene (run it with F5) | exporter once, then **Orion's** |
| `playback.gd` | one clock for Astrid's clip + the page turn; follow camera / lights | exporter once, then Orion's |
| `astrid_import/` | `astrid_IMPORT.glb`, `astrid_IMPORT.tscn` (root **Astrid IMPORT**), `astrid_setup.gd`, `mat/<m> IMPORT.tres`, `tex/` cutout masks | exporter (rewritten every export) |
| `book_import/` | `book_IMPORT.glb`, `book_IMPORT.tscn` (root **Book IMPORT**), `book_setup.gd`, `book_paper.gdshader`, `mat/`, `pages/`, `leaf01_vat_hi.png`, `leaf01_vat_lo.png`, `leaf01_vat.json` | exporter |
| `astrid_main/mat/`, `book_main/mat/` | not created yet: put `<m> MAIN.tres` there to override an IMPORT material (setup scripts load MAIN first) | Orion |
| `woodCUT.gdshader`, `OUTLINE.gdshader` (+ `.uid`) | copies from Parrots France (the copy is independent; Parrots France was not touched) | copied once |
| `paper/` | the watercolour scan multiplied over the frame (`paper_scan.gdshader`), as on the other characters | exporter |
| `tools/` | `check_import.gd`, `pose_check.gd` (headless), `render_probe.gd` (windowed) | — |
| `export_report.json` | last export's numbers | exporter |

### MAIN scene
- **Book Camera** (the whole book on the table, current) and **Astrid Follow / Astrid Camera** (her salon's
  ASTRID FULL CAMERA, following her ROOT's x / z, not her turns).
- **Book Light** (sun from Blender's Book Light, energy = strength / π, shadows on). Lights render layer 2 only
  (light linking in Blender → `light_cull_mask` here): the book is on layer 2, Astrid on layer 1. She still casts her
  shadow on the book.
- **Astrid Body Light** and **Light**: her two salon spots, children of Astrid Follow so they move with her (in Blender
  they stand still at her start). Layer 1 only. The accent `Spot` is left out (as every character export: woodCUT
  combines lights with max()). Energies = `watts_to_energy` × 2 (see "Look" below). 3 real lights in all.
- Inspector on the root: `playing`, `loop`, `speed`, `frame` (drag to scrub, Blender numbering), `view` (Book /
  Astrid / Fly), `play_in_editor`, `fly_speed`. Run-window keys: **Space** play/pause, **←/→** one frame (Shift: 10),
  **Home**, **C** Book/Astrid camera, **F** fly camera.
- **Fly camera (19 Oct):** `fly_cam.gd` copied from Parrots France (+ `addons/spacemouse_native` for the SpaceMouse).
  F makes a fresh camera at the one you were looking through: hold right mouse to look, W A S D, Q / E down / up,
  Shift ×4, Ctrl ×¼, wheel = speed, R = back to where it started; F again = Book Camera. Made at run time in
  `playback.gd`, never saved into the scene. Test: `-s res://tools/fly_check.gd` (headless).
- **Anti-alias (19 Oct):** Astrid's materials carry the Parrots France teen's settings: Edge AA + Paper Tooth AA on,
  width 1 px, line fade 2–4 px, Anti-Moire off (the city / props run it with smooth + extras). All her layers are
  View Aligned with Plate Step 25 in Object space, the aquatint included. Set in the exporter (`write_astrid_materials`).
  Note: `astrid_godot_export.py -- main` would rewrite `playback.gd` from its template, which has no fly camera.

## Export command (Godot closed; Blender file only read, never saved)

```powershell
& "F:\WOODCUTS Blender\woodcut alphabet book\tools\hb.ps1" `
  -Blend "F:\WOODCUTS Blender\woodcut alphabet book\ASTRID book arena animations.blend" `
  -Script "F:\WOODCUTS Blender\woodcut alphabet book\godot_export\astrid_godot_export.py" `
  -ArgList '--' -Out "$env:TEMP\alphabet_export.log" -MaxSec 1800
```
~2.5 min. Arguments after `--`: `astrid`, `book`, `vat` (any mix; default all three), `main` (rewrite the MAIN scene
and playback.gd — only when asked, they are Orion's), `vat_step N`, `godot <folder>`.
Then open the project (Godot imports the new files), or headless: `Godot_console --headless --path "<project>" --import`.

## Units
Everything inside the glbs stays in **Blender units** (the woodcut lines are measured in model units, so line spacing
is exactly Blender's). Each IMPORT scene scales its root by **1/11** (11 units = 1 m): Astrid stands 1.70 m, the
book is ~14 m wide. Cameras and lights in MAIN are in metres.

## Astrid
- 520 rigid pieces (render-visible meshes under ASTRID; the portal-only `SHIELD_mid_fback_remesh` and render-hidden
  `Cylinder.001`, `clear_lens_2_PUPIL_` left out) joined into ONE skinned mesh `Astrid Body` (109,354 verts, 5
  surfaces = 5 materials), each piece weighted 1.0 to the bone it rides. Rest pose exact.
- Skeleton: the 27 deforming bones (the 8 IK targets / poles are left out; their result is baked in).
- Animation: one clip, named **"Animation"** (34.97 s = frames 1–1050; Blender frame f = (f − 1) / 30 s), every frame
  baked (no constraints in Godot). The ROOT bone's motion is moved onto the node **Astrid** above the skeleton
  (root motion), so the mesh's model frame walks and turns with her: woodCUT's View Aligned + Plate Step read that frame.
- **Rest Anchor**: UV3/UV4 = rest positions → CUSTOM0; every Astrid material has `pattern_rest_anchor = true` and
  `plate_step_space = 1` (Object: the plate re-lays when the camera has swung round HER). `pattern_arms` does not apply
  (her rest is her designed pose, not a T-pose; that setting is for the parrots' mixamo arms).
- Materials (`wc2_godot_export.write_tres`, so the same uniform mapping as the other characters): her own Blender
  values, her own ink / paper colours (no Lucifers colour scheme), none of Joan's Godot-side tweaks. Shields: the
  fleur-de-lis cutouts as woodCUT Alpha Cutout masks (`tex/cutout_*.png`, red = keep, threshold 0.5). No outline
  hulls (her Blender pieces have no Stamp Outline).

## The page turn (VAT)
- `Leaf 01` in the glb = Page Turn + Leaf Thickness at frame 1 (Grip Marker left out), 25,026 Blender vertices.
- Bake = the Page Turn result only (12,513 verts) for frames **1–1004** (the paper is still after 1004; the shader holds
  the last row), every frame (`vat_step 1`). Two lossless RGBA8 PNGs, width = vertex, height = frame:
  position 16-bit per axis inside the bake's box (hi bytes `_hi.png` RGB, lo bytes `_lo.png` RGB), normal octahedral
  8 + 8 bit (the two alphas). **Size: 0.22 MB + 0.73 MB** (rows are frames, PNG "Up" filtering makes them tiny).
- The mesh's UV2 holds k = 2 × vertex + side (two bytes); `book_paper.gdshader` reads the two stored frames around
  `vat_frame` (instance uniform, set by `book_setup.gd`), blends linearly, and rebuilds both paper faces at ± half
  thickness (0.0311) along the normal, as solidify does.
- Import settings written with the PNGs (keep them): lossless, no mipmaps, **fix_alpha_border off**, detect 3D off.
  The glb: no LODs, no shadow meshes, no vertex compression.

## Book / table
Plain look as in Blender (no woodcut): `book_paper.gdshader` = flat / noise colour ramp / wave bands / wave rings in
Blender object coordinates, × the page PNG (Page 02 mirrored, as in Blender). The marbled blue/cream endpaper and the
broad table-wood stripes are Blender's own materials (checked against Blender EEVEE renders).

## Verified (19 Oct 2026)
- Blender side: every piece = its bone × rest within **0.00002**; the export rig = the original rig (world matrices,
  frames 1/300/500/990/1050) within **0.00001**; VAT 16-bit round trip ≤ **0.001** units; the shader's two-face rebuild
  vs Blender's solidify ≤ **0.03** units (frame 500, inside the paper's own 0.06 thickness).
- Godot (`tools/check_import.gd`, `tools/pose_check.gd`, headless): CUSTOM0 == rest vertex (0.00000); one clip;
  HIPS / HEAD / PAW.R at frames 300 / 990 / 1050 equal Blender's to 0.001 m; VAT textures decode to Blender's sampled
  positions within 0.001 units; leaf UV2 indices 0..25025 = vertices 0..12512.
- Stills (`tools/render_probe.gd`, side monitor, 1280×720) vs Blender EEVEE stills from the same cameras
  (`godot_export/astrid_reference_render.py ... look`), frames 1, 300, 500, 990, 1050, both cameras — sheets in
  `Claude outputs/renders/compare_look_book.png` and `compare_look_astrid.png` (git-ignored):
  page standing at 300, over the spine at 500 (her in its shadow), flat on the left page at 990 / 1050; she bends
  over to lay it down at 990, stands at 1050; feet on the page; book and table colours match.

## Not verified / open
- **Look on Astrid is close, not equal**: her head reads darker and coarser in Godot than in Blender; the tail lacks
  Blender's grey tone. The spot energies are ×2 over `watts_to_energy` by eye (x1 / x2 / x4 tested). Tune lights and
  materials in Godot (MAIN .tres overrides).
- "No pattern sliding" is verified structurally (rest positions exact, Rest Anchor on), not with a moving-camera
  measurement.
- Not opened in the editor by the agent (headless import + run-window probes only): Orion, open it and watch the
  Output panel for shader errors.
- The VAT PNGs are plain files: an exported game build needs nothing extra (they are imported textures).
- Grab-ramp strain / the 6.3-unit jump at frame 227 come from the Blender animation itself.
- Live page solver, the dragon, gameplay: later.
