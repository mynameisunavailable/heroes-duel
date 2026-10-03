# Heroes Duel: Plan

A 1v1 real-time, top-down hero duel for phones (iPhone first, landscape), built with
Godot 4.7.2 and GDScript. Each hero has a normal attack plus 2 or 3 skills on cooldowns.
Placeholder shapes stand in for art. Opponent: AI now, online PvP later.

Research behind this plan was checked against live sources on 2026-10-03.

## 1. Decisions

| Topic | Decision |
|---|---|
| Engine | Godot 4.7.2-stable, standard (non-.NET) build. Upgrade only between milestones. |
| Renderer | Compatibility (`gl_compatibility`), recommended for 2D and works in the iOS simulator. A/B test the Mobile (Metal) renderer on device at M3. |
| Screen | 1280x720 base, `canvas_items` + `expand`, sensor landscape, 60 fps cap. A 19.5:9 iPhone gets a viewport of about 1558x720. |
| Simulation | Pure `RefCounted` classes stepped at a fixed 60 Hz. All durations in integer ticks. No Godot physics: manual circle and segment maths. |
| Input | Every controller (touch, keyboard, AI, later network) produces one `HeroCommand` per tick. Commands are quantised in every mode. |
| Data | Heroes, skills, effects and arenas are `.tres` resources. A new hero or a number change is data only. 2 or 3 skills is just the array length. |
| Presentation | Read-only views plus `SimEvent`s. Juice, sound and haptics can never change outcomes. |
| v1 scope | Lean: Knight and Ranger at launch, Easy/Normal AI. Pyromancer and Rogue follow in v1.1. |
| Netcode (later) | ENet (UDP), server-authoritative headless Godot from the same project, client prediction for your own hero, interpolation for the opponent. |

## 2. Combat design (v1)

**Match.** Best of 3 rounds, 60 s each. Overtime from 40 s multiplies all damage by 1.5. At time-out the higher HP% wins. A drawn round (double KO, or HP% within 1 point) is replayed once; a second draw is decided by total match damage. Each round opens with a 2.5 s countdown, and every skill starts the round on a 1.5 s cooldown.

**Arena.** 1000x480 px convex octagon with 120 px top chamfers and 240 px bottom chamfers. The deep bottom chamfers keep walkable floor out from under both thumbs on 16:9 and 19.5:9 screens. Two pillars at (500,130) and (500,350), radius 40, block movement and line of sight. Spawns at (170,240) and (830,240). The arena is scaled down to fit only on narrower screens such as iPad 4:3; gameplay numbers never change.

**Controls.**
- Floating joystick on the left 45% of the screen.
- Attack button (140 px) bottom right. Hold to auto-attack the enemy and walk into range; tap for one attack.
- 2 or 3 skill buttons (100 px) on an arc around Attack. Tap to quick-cast (auto-aim, never leads the target). Drag to aim manually; drag back to the centre to cancel.
- Desktop: WASD/arrows, J or Space to attack, K/L/; to quick-cast, Q/E/R to cast at the mouse cursor, Esc or P to pause, F3 to restart (debug builds).

**Timing rules.** Casting roots the hero (no movement or attacks). The 0.3 s global cooldown starts when a skill *fires*, at the end of its cast time. A press is buffered if it would become legal within 0.3 s. Pressing a skill cancels an attack windup without spending the attack timer.

**Heroes.**

| | Garrick, Knight (MVP, 2 skills) | Wren, Ranger (MVP, 3 skills) |
|---|---|---|
| Look | Blue square, "G" | Green triangle, "W" |
| HP / speed | 1240 / 300 px/s | 1020 / 280 px/s |
| Normal attack | Melee 49 dmg, 95 px (+12 grace), every 1.0 s | Homing arrow 32 dmg, 450 px, every 0.75 s |
| Skill 1 | Shield Charge: 0.15 s brace, 300 px dash, 60 dmg + 0.8 s stun, CD 10 s | Power Shot: 0.35 s draw, 800 px arrow, 120 dmg, CD 8 s |
| Skill 2 | Cleave: 0.35 s windup, 120 px ring, 90 dmg + 30% slow 1.5 s, CD 8 s | Frost Arrow: 0.1 s, 650 px, 40 dmg + 40% slow 2 s, CD 7 s |
| Skill 3 | (none) | Tumble: instant 220 px roll, CD 9 s |
| Sustained DPS | 66.25 | 63.38 |

The Knight's damage (44 → 49) and the Ranger's HP (1100 → 1020) were raised and lowered
from the paper design after measuring real matches; see "Measured balance" below.

v1.1 heroes (already designed): **Ember, Pyromancer** (Fireball, Meteor, Flame Nova; 3 skills; adds `area_over_time` and `knockback`) and **Vex, Rogue** (Shadow Dash, Poison Cloud; 2 skills).

**Balance framework.**
- Sustained DPS = attack_damage / attack_interval + sum(skill_damage / cooldown).
- Pure time-to-kill targets about 18.6 s, with every matchup within ±15%. Real rounds run about 29 s, so a best-of-3 takes about 1.5 minutes.
- Normal attacks supply 55-72% of DPS, no single skill more than 25%, and burst stays at 30% of the lowest HP or less.
- Cooldowns stay between 6 and 12 s. Stuns last 1 s at most, and slows cap at 40% and never stack.
### Measured balance (`tools/ai_batch.gd`, 20 matches per pairing)

Run it with:

```bash
godot --headless --path . -s res://tools/ai_batch.gd -- --matches=20
```

What the batch showed, and what changed because of it:

- **Mirror matches are now exact draws.** They previously had a guaranteed winner,
  because each hero was resolved completely before the next and so measured range
  against an opponent who had already moved. The simulation now decides every hero's
  actions against the same start-of-tick snapshot and applies all hits together. This
  also makes the double-KO draw rule reachable at all.
- **The Knight closing distance was an AI bug, not a stats problem.** He stopped at
  90 px with a 95 px reach, so he drifted in and out of range. Closing to 55 px raised
  his damage per match by 53% on its own. The pre-planned knobs (Ranger speed, homing
  range) were aimed at the wrong cause; a trace showed he reaches her easily.
- **The Ranger still beats the Knight.** Her homing auto-attacks land essentially
  whenever she has line of sight, so her real damage output is near her paper DPS, while
  his melee has real downtime. The paper model assumed 0.8 efficiency for both. After
  the two stat changes above he reaches about 89% of the damage he needs per round.
- **Do not tune this further against the AI alone.** The Ranger AI plays near
  optimally while the Knight AI is simple: it does not lead its charge, use pillars for
  cover, or hold the charge for her Tumble. Buffing the Knight until the AI matchup
  evens out would over-tune him for human play. The next step is a smarter melee AI and
  human playtesting, then stats.
- Caveat the batch prints for itself: a pairing whose AI never consults its RNG plays
  the identical match every time, so "20 matches" is then one match repeated.

## 3. Milestones

| # | Milestone | Exit criteria |
|---|---|---|
| **M0** | Scaffold (done) | `tools/validate.ps1` passes: import, smoke test (data validation, 1200-tick AI vs AI, determinism), clean boot. Boots to the arena with both placeholder heroes, joystick/keyboard movement, HP bars, timer, and skill buttons with cooldown sweeps. |
| **M1** | Greybox combat vs AI (done, except where noted) | Normal attacks (melee check, homing projectile), DamageResolver, RoundRules, SkillExecutor and EffectApplier for damage/slow/stun/dash/projectile/knockback, telegraphs clipped to walls, damage numbers, result overlay with Rematch, pause, drag-aim with a cancel disc, AI line-of-sight and charge-timing rules, `tools/ai_batch.gd`, 37 GUT unit tests, GitHub Actions CI. **Still open:** running the iOS build spike (the workflow is written but has never been run, and needs an iOS export preset first). |
| **M2** | Menus and feel | Main menu, hero select, settings. Hit-stop, flash, shake, damage numbers, audio, haptics (all presentation-only). First real art through `.tres` sprite fields. |
| **M3** | iOS build + TestFlight | Enrol in the Apple Developer Program. iOS export preset, signing, CI upload to TestFlight. On device: safe area, 60 fps, multitouch, audio session. |
| **M4** | App Store release | Final art, icon, screenshots, privacy policy URL, support URL, privacy label, age rating, export compliance, EU trader status, submission. |
| **M5** | v1.1 heroes | Pyromancer and Rogue as data plus 2 new primitives. AI-vs-AI balance batches (45-55% win rate per matchup). |
| **M6** | LAN PvP | Headless authoritative server on the local PC (`godot --headless --path . -- --server --port=7000`), ENet UDP 7000, prediction and interpolation, IP-entry lobby, iOS local-network permission. |
| **M7** | Hosted online PvP | Linux dedicated-server export on a small VPS or Edgegap, hostname with IPv6 support, DTLS, matchmaking. |

## 4. Shipping to iOS from Windows: costs and requirements

- **Apple Developer Program: US$99 per membership year**, charged in local currency at enrolment. You need it for TestFlight and the App Store, and apps leave the store if it lapses. Individuals pay the full fee; waivers are only for nonprofits, schools and government bodies.
- **Google Play** (optional, later): US$25 one-time. New personal accounts must run a 12-tester, 14-day closed test first.
- **A Mac is needed for the build step.** On Windows, Godot can only export the Xcode project. Archiving, signing and uploading need macOS with Xcode 26 or later, required for uploads since 2026-04-28. Uploads must use the iOS 27 SDK (Xcode 27) from April 2027.
- Ways to get a Mac:
  - GitHub Actions macOS runners: free for public repos; private repos are billed at a higher macOS rate.
  - Codemagic: 500 free macOS minutes a month.
  - A used Apple-silicon Mac mini: about US$350-475. It must be Apple silicon to run Xcode 27.
- Required export settings:
  - `rendering/textures/vram_compression/import_etc2_astc=true`, already set. Without it, iOS export fails from an x86 PC.
  - `min_ios_version` "15.0".
  - Device family "iPhone" only, to avoid iPad screenshot requirements.
  - Opaque 1024x1024 app icon.
- App Review requires final art; placeholder shapes are fine for internal TestFlight only.
- If you plan to sell in mainland China: the fee is billed in RMB, and the China storefront needs an ICP filing and an NPPA game approval number, which individuals generally cannot get. Leave that storefront unticked or use a licensed publisher.

## 5. Top risks

| Risk | Mitigation |
|---|---|
| No Mac for signing and upload | iOS CI spike in M1, Codemagic as fallback |
| Thumbs hiding the action | Arena shaped around the thumb zones; verify on a real phone in M1 |
| Ranger out-kites Knight | AI batch at the end of M1 with the tuning knobs pre-decided |
| Netcode rewrite later | Pure sim, quantised HeroCommands, integer ticks, id-based data, `step(emit_events=false)` for re-simulation, state checksum: all in place now |
| Godot templates vs new Xcode | Pin Godot 4.7.2, pin the Xcode version in CI, watch 4.7.x patch notes |
