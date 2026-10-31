# 02 — Asset Plan

Goal: ship a coherent, chunky low-poly look using **free CC0 assets plus small procedural parts**, with a small install size and clean licensing.

## 1. Rules

1. Use **CC0** (public domain) assets only for shipped content. Record each used asset in `assets/CREDITS.md` (pack, author, URL, license, date downloaded), even though CC0 needs no attribution.
2. Import **only the files the game uses** (copy the needed `.glb` files and small textures into `assets/`). Keep full pack zips outside the repository.
3. Prefer **GLB** (`.glb`) for models. Kenney and Quaternius both publish glTF/GLB.
4. Keep textures small. The lab measurements showed ETC2 compression loads fastest and uses the least memory, and 4K lossless textures cost more than a gigabyte of texture memory. Use **VRAM-compressed ETC2** at **≤ 1024 px**; Kenney-style colormap textures are tiny and can stay as they are.
5. Keep a single **palette material** language (section 5) so parts from different packs look related.
6. Record every decision in `assets/ASSET_MANIFEST.md`: slot → chosen file → triangle count → notes.
7. When a pack lacks a suitable model for a slot, build the part from **primitives** (box, cylinder, sphere, prism) with the procedural recipes in section 4. Procedural parts are an equally valid shipping choice and match the all-procedural approach proven in earlier prototypes.
8. Verify each pack's license file at download time and save the `license.txt` next to the imported files.

## 2. Verified pack sources (all CC0)

| Pack | Author | What it offers for this game | Where to get it |
|---|---|---|---|
| **Space Kit** (150+ models) | Kenney | Ships, turrets, characters, weapons, modular sci-fi props; good base for chassis details and weapon barrels | `https://kenney-assets.itch.io/space-kit` and `https://kenney.nl/assets/space-kit` |
| **Blaster Kit** (20+ weapons, bullets, targets) | Kenney | Cannon and gun barrels, bullet meshes | `https://kenney-assets.itch.io/blaster-kit` and `https://www.kenney.nl/assets/blaster-kit` |
| **Conveyor Kit** (60+ models, includes robot arms) | Kenney | Factory zone environment; robot-arm model for the Grabber Arm | `https://kenney-assets.itch.io/conveyor-kit` |
| **Car Kit** (40+ models) | Kenney | Wheels, vehicle bodies, trucks and wrecks as junkyard scenery | `https://kenney-assets.itch.io/car-kit` |
| **Space Station Kit** (80+ models) | Kenney | Modular metal pieces for Factory zone | search `Space Station Kit` on `kenney.nl/assets` |
| **Sci-Fi Essentials Kit** (65 models incl. animated robot enemies, guns, props) | Quaternius | Enemy robots (Scrapper, Gunner candidates), crates, props; files are large (about 160 MB zip), import only chosen GLBs | `https://quaternius.itch.io/sci-fi-essentials-kit` |
| **Ultimate Space Kit** (90+ models incl. animated characters and mechs) | Quaternius | Mech models usable as Bruiser / boss base | `https://quaternius.com/packs/ultimatespacekit.html` |
| **Modular Sci-Fi MegaKit** (270+ modular pieces) | Quaternius | Factory zone walls, floors, pipes | `https://quaternius.itch.io/` (search the pack name) |
| **LowPoly Robot**, **LowPoly Cars**, **LowPoly Spaceships** | Quaternius | Robot body references, wheels, rocket-like props | `https://quaternius.itch.io/` |
| **Kenney Interface Sounds** (100 sounds) | Kenney | UI clicks, confirmations | Godot Asset Library asset 794: `https://godotengine.org/asset-library/asset/794` |
| **Kenney Sci-Fi Sounds** (70 sounds: lasers, engines, explosions) | Kenney | Weapon fire, explosions, boss telegraphs | Godot Asset Library asset 1834: `https://godotengine.org/asset-library/asset/1834` |
| **Kenney Impact Sounds** (130 sounds) | Kenney | Metal thunks for attach, part break, boss slam | `https://github.com/Loppansson/kenney-impact-sounds-for-godot` |
| **Kenney Digital Audio**, **UI Audio**, **Music Jingles** | Kenney | Extra UI blips, level-complete jingle | search names on `kenney.nl/assets` |
| **Kenney Skyboxes (Skies)** | Kenney | Sky textures | `kenney.nl/assets` (texture category) |

Kenney's audio sets are CC0 across all packs; the Godot Asset Library ports above are CC0 too. Short sound effects convert well to **WAV** for lower CPU cost on mobile; use WAV for SFX under about 2 seconds and OGG for music.

Items to verify at download (not confirmed during research): exact wheel, rocket and armour models inside Car Kit, Space Kit and Blaster Kit; Kenney UI Pack, Game Icons and Particle Pack availability and license text; free CC0 music loops. Use `assets/ASSET_MANIFEST.md` to record what exists.

## 3. Slot map (what each part needs)

For every part, supply **three level meshes** (Lv1, Lv2, Lv3), one attach-socket type, and an optional muzzle point. Use the first available option; fall back to the procedural recipe.

### 3.1 Parts

| Part | Slot group | Primary candidate | Fallback recipe (section 4) |
|---|---|---|---|
| Extra Wheels | `wheel_*` | Wheel from Car Kit (scaled, recoloured) | `wheel`: cylinder + hub disc |
| Tank Tracks | `wheel_*` (replaces wheels) | Procedural | `track`: rounded box + 6 small boxes as treads |
| Cannon (Lv1 → Twin → Gatling) | `top_*`, `side_*` | Barrel meshes from Blaster Kit / turret from Space Kit | `cannon`: cylinder barrel(s) on a box mount; Lv2 two barrels; Lv3 four barrels around a drum |
| Rocket Launcher (Lv1 → Dual → Rack) | `back_c`, `side_*` | Rocket / pod from Space Kit | `rocket_pod`: box pod with 1/2/6 cone-tipped cylinders |
| Flamethrower | `front_c`, `side_*` | Procedural | `flame`: tank (capsule) + nozzle (cone) + orange emissive tip |
| Heavy Armour | `front_c`, `shoulder_*` | Procedural plates or Space Kit panels | `armour`: bevelled boxes, Lv2 more plates, Lv3 spikes |
| Energy Shield | `head` / `back_c` | Procedural | `shield`: small emitter + translucent cyan sphere that flickers when it blocks |
| Scrap Magnet | `back_c`, `top_c` | Procedural | `magnet`: red-blue horseshoe from a torus section + two boxes |
| Storage Pack | `back_c` | Crate / container from Space Kit or Quaternius props | `storage`: box with straps; Lv2/Lv3 bigger |

### 3.2 Chassis, enemies, boss

| Item | Candidates | Fallback |
|---|---|---|
| Chassis stage 1–3 | Robot body from Quaternius LowPoly Robot, Space Kit robot, or Ultimate Space Kit mech; scale and recolour consistently | Procedural stacked boxes with panel lines; three sizes with shared socket names |
| Scrapper | Small animated robot enemy from Sci-Fi Essentials Kit | Procedural sphere body + 2 spikes, bobbing animation |
| Gunner Turret | Turret from Space Kit | Procedural cylinder + barrel |
| Bruiser / Elite | Mech from Ultimate Space Kit | Procedural large box body with horn plates |
| **Scrap Titan** (boss) | Assemble from mech + junk pieces; build body, arms, head, plate, core as separate nodes so each can animate and take damage | Procedural giant robot from primitives with red emissive eyes |
| Grabber Arm | Robot Arm A/B from Conveyor Kit | Procedural segmented arm |

### 3.3 Environment (Junkyard zone first)

| Item | Source |
|---|---|
| Road segments | Procedural flat quad strips with a sand texture or flat colour; 3 chunk variants |
| Scenery | Wrecked cars (Car Kit), crates and containers (Space Kit / Quaternius), tyres, barrels, simple buildings |
| Sky | Kenney Skyboxes (Skies) or a gradient via `Environment` |
| Fog | Depth fog tinted to the sky for distance fade (supported in Compatibility) |

Place scenery in a few batched chunks and reuse via pooled road chunks. Use `MultiMeshInstance3D` for repeated tyres, barrels and scrap.

### 3.4 Pickups and VFX

| Item | Recipe |
|---|---|
| Scrap pickup | Small low-poly nut/bolt/gear mesh in 3 colours via one `MultiMesh`; sparkle on pickup |
| Bullet | Small elongated sphere, emissive |
| Rocket | Small capsule with tail particles |
| Explosion | `CPUParticles3D`: orange/yellow sprites, 12–20 particles, 0.4 s, plus a flash quad and a shockwave ring |
| Attach spark | `CPUParticles3D` burst of 8 yellow points |
| Muzzle flash | Billboard quad, 2 frames |
| Telegraph | Flat unshaded translucent red quad with pulse shader |
| Debris | 6–10 pooled small boxes with physics for 1.5 s |

Use particle textures from a CC0 pack (such as Kenney's particle pack once its license is confirmed) or flat white points with colour ramps.

### 3.5 UI and fonts

| Item | Source |
|---|---|
| Panels, buttons, bars | Kenney UI Pack (verify at download) or `StyleBoxFlat` in code with rounded corners and bevels |
| Icons | Kenney Game Icons (verify) or simple vector icons drawn as `TextureRect` from SVG |
| Font | One bold display font under SIL OFL (for example a rounded or industrial Google Font); one clean sans for body text. Save the license file. The lab runs confirmed custom fonts perform fine on the phone. |

### 3.6 Audio

See the full event map in `06_UI_JUICE_AUDIO.md`. Packs: Kenney Impact, Sci-Fi, Interface and UI audio; one short CC0 music loop for gameplay and one for the Hangar (record license per file).

## 4. Procedural part recipes

Build each recipe as a small scene `assets/parts/<id>_lv<n>.tscn` with a root `Node3D` named `Part`, a `MeshInstance3D` or several, and an optional `Marker3D` named `muzzle`. Use the palette materials (next section).

| Recipe | Construction |
|---|---|
| `wheel` | `CylinderMesh` radius 0.28 height 0.18 rotated 90° on Z, hub `CylinderMesh` radius 0.12 in accent colour |
| `track` | Rounded `BoxMesh` 0.35 × 0.3 × 1.2 + 6 small boxes along the underside |
| `cannon` | Box mount 0.3 + `CylinderMesh` barrel radius 0.07 length 0.7 pointing −Z; Lv2 two barrels; Lv3 four barrels around a drum |
| `rocket_pod` | Box 0.5 × 0.3 × 0.6 + 1 / 2 / 6 cylinders with cone tips |
| `flame` | Capsule tank + cone nozzle + emissive orange tip |
| `armour` | Bevelled boxes; Lv2 doubled; Lv3 add small cone spikes |
| `shield` | Small cylinder emitter + `SphereMesh` radius 0.9 with translucent cyan material, hidden until a block |
| `magnet` | Horseshoe from a partial `TorusMesh` or three boxes in red/blue |
| `storage` | Box with two strap boxes |

Each part must read at phone size from a distance of about 7 m (the gameplay camera). Use thick shapes and strong colour accents.

## 5. Material unification (palette)

Create a small set of shared materials in `assets/materials/` and apply them to every imported mesh through a **material override pass at import time** (or at runtime in `RobotBuilder`). Use:

| Material | Colour (hex) | Used for |
|---|---|---|
| `steel_dark` | `#4A5568` | Chassis, mounts |
| `steel_light` | `#8FA3B8` | Plates, panels |
| `rust_orange` | `#F28C28` | Accent stripes, tips |
| `warning_yellow` | `#F2C230` | Hazard stripes, scrap |
| `glow_blue` | `#35B6FF` | Shield, energy |
| `danger_red` | `#E53935` | Telegraphs, boss eyes |
| `good_green` | `#43D17A` | Positive gate panels |
| `sand` | `#E0B070` | Road, desert |
| `ui_navy` | `#1B2340` | UI panels |

Use `StandardMaterial3D` with roughness 0.8, metallic 0 to 0.2, no normal maps, and `shading_mode = per-vertex` where it looks fine (cheaper on phones). Use at most **8 materials** across robot and enemies to keep draw calls low. Use emissive only for tips, eyes and shield.

## 6. Budgets

| Item | Triangle budget |
|---|---|
| Chassis stage 1 / 2 / 3 | 1.5k / 3k / 5k |
| Part (per level) | ≤ 800 |
| Fully built Monster robot | ≤ 15k |
| Scrapper / Turret / Bruiser | ≤ 600 / 800 / 2k |
| Scrap Titan (all pieces) | ≤ 20k |
| Gameplay frame total | ≤ 150k triangles, ≤ 150 draw calls |

## 7. Asset spike (milestone M0) — do this before building content

Purpose: confirm the chosen packs import cleanly, look cohesive and perform on the phone.

1. Download Space Kit, Blaster Kit, Car Kit, Conveyor Kit, Sci-Fi Essentials Kit and Ultimate Space Kit. Save licenses.
2. List each pack's models and pick candidates per slot in section 3. Write them in `assets/ASSET_MANIFEST.md`.
3. Build `res://spike/AssetSpike.tscn`: a grid showing every candidate part on a chassis stage-1 mock, with the palette material pass applied. Take a screenshot.
4. Measure on the phone: scene load time, draw calls, memory, frame time, with all candidate meshes visible.
5. Decide per slot: Pack mesh or procedural recipe. Fill the manifest.
6. Verify tri counts against budgets. Decimate or substitute heavy meshes.

Exit criteria: every slot in section 3 has a decided source, the combined look is cohesive in the screenshot, and the spike scene holds 60 fps on the phone.

## 8. `CREDITS.md` template

```
# Credits
| Asset | Author | Pack/URL | License | Used for |
|---|---|---|---|---|
| ... | Kenney | https://... | CC0 1.0 | ... |
```
Add a "Thanks to Kenney.nl and Quaternius" line on the in-game credits screen as a courtesy.
