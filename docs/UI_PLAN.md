# UI plan — 2 November 2026

## Concepts

1. **Scrapyard console (recommended):** compact ivory/steel plates, Rajdhani headings, corner brackets and sparing neutral hazard stripes. A single event receipt plus local rings/panel compression makes actions explicit. Matches the robot-war setting without filling the road.
2. **Pit-crew receipts:** larger cards appear beside the robot for every upgrade. Strong immediacy, but multi-part evolution can cover enemies; retain only one prioritized receipt from this concept.
3. **Bare battlefield:** rings, audio and haptics only, almost no HUD text. Least clutter, but too little explanation of a stolen part or changed gate; rejected as the primary direction.

## Flag and architecture

Add `ui_v2=false` to `data/flags.json`. The old HUD/feedback/menu styling remains the default. `src/ui/ui_v2.gd` will build the new HUD and manage a bounded event-priority/feedback controller; procedural world effects use pooled MultiMeshes and existing world meshes. The simulation only carries the flag dictionary; it has no new mechanics. No gameplay flags are silently enabled. An aim lane is shown only for existing lane-aim/Mob Stream modes; nearest-target mode points at its real target instead.

## Hierarchy and attention budget

- Tier1: one hero card at a time, prioritized danger/boss > damage/part loss > evolution/multiplication > attachment > ready/dodge. Lifetimes≤1.5s. Lower-priority events retain local robot/counter feedback rather than queuing a long toast backlog.
- Tier2: health, weapon state, existing progress, scrap and special. Supporting layer dims briefly during a hero event; danger telegraphs and health remain legible.
- Tier3: broad moving road seams, subtle drive/idle life and bounded dust. During hero feedback particles are reduced. No extra scenery density.
- At-rest painted-HUD rectangle union≤15% (goal12–15%, smaller is acceptable); transient peak≤22%. Max3 world popups, max1 hero card, max1 full-screen effect (planned0). Geometry estimates are conservative, not perceptual pixel segmentation.
- All timed effects have explicit fade/reset. Data/state changes settle immediately under Reduce Motion; no routine camera/FOV/hit-stop changes.

## Implementation sequence / commits

- UI-0: baseline inventory,38 state/resolution captures, activity/clutter method, completed visual-focus rerun, research and this plan.
- UI-1: default-off flag, industrial skin and compact safe-area HUD; mirrored lower-middle controls, existing settings plus optional volume/flash/handedness keys in the same v1 settings dictionary. No root save-schema change.
- UI-2: bounded prioritized feedback map, gate confirmation/pulses and boosted-drone tint, target/aim cues, ready-once animation, local damage/loss/dodge cues; one auditory/haptic response from the same event. Reuse existing procedural SFX where adequate.
- UI-3: result/hangar live build, existing progression cue, restrained road/telegraph/weak-point life; accessibility and comfort gates. No perpetual brightness pumping.
- UI-4: state captures, clutter/activity comparison, reaction/feedback assertions, three-size layout tests, final desktop comparison, package smoke, report and playtest plan.

## Verification

Finish `test_visual_focus.gd`, original trace baseline and full headless suite. Extend UI review to both flags, handedness, safe area and Reduce Motion. Add scripted feedback-map coverage with measured frame latency, flash-rate limits, pool/attention limits, and compatibility of old v1 saves. Measure default and v2 desktop runs sequentially with recorded max-fps/vsync/window settings; phone only if present. Capture the same19 states at two sizes after implementation. Do not claim human preference or phone performance without those tests.

## Deliberate exclusions / owner questions

No new economy, meters, encounters, ads, forced prompts, copied assets, bitmap texture dependency or routine camera effects. Keep rounded robot meshes as identity; replacing all art is a separate direction. No distant enemy landmark that could falsely imply an active target. No new ambient particle system. No five-person responses invented if people are unavailable. Owner questions go in the report: preferred handedness default, preferred theme strength, and approval to enable `ui_v2` after playtesting.
