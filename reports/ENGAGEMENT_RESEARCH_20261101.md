# Gameplay research — 1 November 2026

## What comparable games actually describe

- [Mob Control, official VOODOO listing](https://play.google.com/store/apps/details?id=com.vincentb.MobControl): multiplier and moving gates, deployable Champions, collectible evolutions, visible base building, and different battle modes.
- [Count Masters, official Freeplay listing](https://play.google.com/store/apps/details?id=freeplay.crowdrun.com): gate decisions grow the crowd, followed by obstacles, battles, a boss and castle payoff.
- [Survivor.io, official Habby listing](https://play.google.com/store/apps/details?id=com.dxx.firenow): one-handed play, escalating enemy waves and combinable roguelite skills.

These are documented features, not evidence that any one mechanic causes retention. The recommendations below are design inferences for Scrap Dragon. A research subagent independently reviewed the sources and current game design/code.

## Why our current loop may feel passive

Scrap Dragon already has coin chains, frenzy, utility gates, combos and daily rewards. More counters would add interface complexity. Auto-forward plus nearest-target auto-fire leaves most offense automatic; steering mostly avoids threats and selects gates. Part additions change stats and appearance, but need a stronger immediate encounter payoff.

The first gate is at z80 and the first authored enemy formation at z125. That is 45 m, approximately five seconds of base-speed travel. Shooting starts sooner because auto-fire has range; this is not a measured five-second firing delay. The useful experiment is to make the upgrade's effect obvious within the next one or two seconds.

## Recommended implementation order

### 1. Upgrade → immediate payoff

Put a small destructible formation just beyond the first gate. Make Cannon and Wheels produce different clear outcomes: Cannon shreds clustered targets; Wheels reaches a bonus route or escapes a closing hazard. Preview the next actual level/evolution before selecting it. Use existing scrap and combat systems.

Success check: first-time players can explain what their choice changed; record time from crossing the gate to the first visible payoff, aiming for 1–2 seconds. Avoid making one choice an automatic mistake.

### 2. Steering selects the attack opportunity

Add a short guarded-salvage encounter with two lane-specific targets: an explosive barrel beside enemies and a valuable crate behind a guard. Favor targets in the player's aimed lane with clear targeting feedback, retaining auto-fire. Build on the existing Hauler encounter rather than adding another action button.

This adds offensive agency: the thumb chooses what gets destroyed, not only where the robot stands. Telegraph lane choices early enough that players can react. Keep projectile targeting in the pure sim and test fairness at realistic reaction delays.

### 3. One unmistakable weapon evolution

Prototype one evolved attack: ricocheting cannon rounds, splitting rockets, or a wider flame sweep. Show the missing build requirement ahead of the next gate. Existing repeat-part levels and combo systems provide the foundation; avoid adding another meter.

Success check: players identify the evolution from its behavior without reading a stat panel. Audit enemy counts, projectile caps and balance so the effect remains readable.

### 4. Short tension/release encounter blocks

Author collect → choose → destroy → dodge → reward sequences, with breathing room between peaks. Keep major choices every 10–20 seconds, but give players a useful small action every few seconds. Alternate convoy interception, guarded salvage and survival-wave blocks before expanding into whole new modes.

### 5. Visible victory destination, later

A workshop/trophy project on the existing home pedestal could visibly advance after a boss victory, adapting Mob Control's visible rebuilding idea. Keep it secondary until the run itself is enjoyable. More menus, daily currencies or compulsory ads will not address passive combat.

## Suggested pilot

Prototype items 1 and 2 first, then compare with the current build using several new players. Observe whether choices are understood, offensive targets are deliberately selected, and players retry voluntarily. Measure run completion, payoff timing and retry delay. A small pilot provides qualitative direction, not a reliable retention forecast.

This research pass does not silently rebalance or add these gameplay experiments. The completed code change in this pass is the Mac rendering-quality fix.
