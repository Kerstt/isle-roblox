# 01 – Game Design: Gameplay Systems Spec

| | |
|---|---|
| Owner | game-designer |
| Version | 0.1 (first draft, 2026-11-26) |
| Inputs | `docs/AGENT_BRIEF.md`, `docs/00-concept.md` |
| Hand-offs | Prices and coin rewards: `game-economy-designer`. Onboarding UI, shop and monetization: `roblox-experience-designer`. Map, biomes and spawn layout: `game-level-designer`. Rigs, VFX and lighting: `game-technical-artist`. Code: `roblox-systems-scripter`. |

**Every number in this doc is a first-pass hypothesis, i.e. `[PLACEHOLDER]` until playtested.** Values that are especially uncertain carry an explicit `[PLACEHOLDER]` tag. All tunable values belong in shared data modules (see section 12), never hard-coded in services.

### Changelog
| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-11-26 | First draft: loops, 8 species, growth, needs, combat, social, world, death, server size, MVP scope. |

---

## 0. Design pillars and fun hypothesis

| # | Pillar | What it means for decisions |
|---|---|---|
| 1 | **You can see yourself grow** | Size changes continuously, not just at stage jumps. Bigger must always look and feel different. |
| 2 | **Every encounter is a choice** | Fight, flee, hide or group up. No encounter should have only one sane answer for both sides. |
| 3 | **Size tells you the danger** | A blocky silhouette and its size read as a threat level at 100 studs. Size drives damage, knockback and daze. |
| 4 | **Deaths sting, lives last** | Dying costs minutes, never hours. Coins and cosmetics are never lost. |
| 5 | **Together is stronger** | Groups and nests are the best strategy, but solo play stays viable. |

**Fun hypothesis (must hold before adding systems):** "Hunting or escaping as a small dinosaur, while visibly growing every few minutes, is fun for 15 minutes with just one species, two AI prey types and other players."

---

## 1. Core loop

### 1.1 Loops
| Loop | Length | Player does | Feedback / reward | Tension |
|---|---|---|---|---|
| Moment-to-moment | 0–30 s | Move, sprint, scan, bite, dodge, eat, drink, rest | Hit sparks, damage numbers on confirmed hits, needs bars filling, growth bar ticking | Stamina runs out, a bigger dino appears, bleed ticking |
| Session | 20–45 min | Grow one dinosaur 1–2 stages (hatchling to sub-adult in a first session) | Stage-up moment (size pop, stat card, coins) | Needs pull you to water and food, where other players are; death costs in-stage progress |
| Long-term | hours–weeks | Reach Adult with each species, unlock new species with Fossil Coins, nest, lead a group, collect cosmetics, climb leaderboards | New species, Elder title, cosmetics, leaderboard rank | Keeping an Adult alive; species caps; group politics |

Session length target: Roblox sessions often run around 20–30 minutes, so a small species reaches Sub-adult in about 16 minutes and a first session ends close to a stage-up ("one more stage").

### 1.2 First 10 minutes (new player, small species)
No separate tutorial island. A 6-step objective tracker (top-left, skippable) runs in the real world. Spawn points for brand-new players are in "nursery" spawn areas: low ground with ferns, a pond, and guaranteed small prey within 40 studs (the level designer places these at the edge of the map, away from the apex hotspots).

| Time | Beat | Objective text | Design goal |
|---|---|---|---|
| 0:00 | Spawn screen: pick a starter species, tap **Hatch** | – | Choice in under 20 s |
| 0:05 | Spawn as a hatchling with a 60 s spawn shield | "Move to the pond" (marker) | Core verb in under 30 s |
| 0:40 | Arrive at water | "Drink" (hold E / tap Drink) | Guaranteed first success |
| 1:30 | Food | Carnivore: "Catch the lizard" (a Scurrylizard spawns 25 studs away for this objective, 3 bites at hatchling). Herbivore: "Eat a fern" | First kill/eat with no failure state |
| 3:00 | Health | "Rest to heal" (tip: resting heals 5x faster) | Teaches safe regen |
| 4:00 | Explore | "Follow the river" (soft marker) | Pulls toward the shared world |
| 5:15 | **Stage-up: Juvenile** | Full-screen pop, size jump, stat card, coin reward | First hook (small species reach it at 5.25 min) |
| 5–10 | Free play | "Hunt a Burrowpig" / "Eat from a bush", then "Press G to ping" or "Join a group" (Phase 3) | Opens up meaningful choice |
| first death | Death screen | Cause of death + one tip ("Big dinos turn slowly. Run in circles!"). Beginner Shield keeps your growth | Death teaches, does not punish |

Onboarding checklist: core verb in 30 s; first success guaranteed; each mechanic introduced safely; crouching in tall grass is discovered through a world prompt, not text; the first session ends near a stage-up.

---

## 2. Species roster (8 at launch, 1 in MVP)

### 2.1 Overview
| Species | Diet | Size class | Role | Growth to Adult | Adult height (studs) | Unlock |
|---|---|---|---|---|---|---|
| **Velociraptor** | Carnivore | Small | Pack hunter | 35 min | 6 | Starter (free) |
| Gallimimus | Omnivore | Small | Runner / scout | 35 min | 8 | Starter (free) |
| Pachycephalosaurus | Herbivore | Small | Skirmisher | 35 min | 6 | Starter (free) |
| Ceratosaurus | Carnivore | Medium | Ambusher | 45 min | 10 | Coins |
| Parasaurolophus | Herbivore | Medium | Herd caller / support | 45 min | 14 (with crest) | Coins |
| Baryonyx | Carnivore | Medium | Swimmer / fisher | 45 min | 11 | Coins |
| Triceratops | Herbivore | Large | Tank / charger | 60 min | 11 | Coins |
| Tyrannosaurus | Carnivore | Large | Apex | 60 min | 20 | Coins (most expensive) |

Balance at launch: 4 carnivores, 3 herbivores and 1 omnivore (grouped with herbivores). Server-side diet balancing is in section 9.3. Coin prices: `game-economy-designer`.

### 2.2 Stat rules shared by all species
- Stats are **keyframed by growth %** and interpolated linearly between keyframes: Hatchling = 0 %, Juvenile = 15 %, Sub-adult = 45 %, Adult = 100 %. The tables below show the value at each keyframe (stage entry).
- Large species start relatively smaller (eggs have a size limit), so a Tyrannosaurus hatchling loses to an adult Velociraptor (the adult raptor needs 5 bites, the hatchling rex needs 15).
- Model scale = (stage mass multiplier)^(1/3): Small 0.37 / 0.58 / 0.79 / 1.0, Medium 0.33 / 0.54 / 0.78 / 1.0, Large 0.27 / 0.49 / 0.77 / 1.0. Reach, hitboxes and hurtboxes scale with model scale.

| Stage multiplier | HP (S / M / L) | Damage (S / M / L) | Mass (S / M / L) | Stomach (S / M / L) | Walk | Sprint | Stamina pool | Hunger drain | Thirst drain |
|---|---|---|---|---|---|---|---|---|---|
| Hatchling | .15 / .12 / .08 | .20 / .15 / .10 | .05 / .035 / .02 | .10 / .08 / .06 | 0.85 | 0.80 | 0.70 | 1.30 | 1.25 |
| Juvenile | .35 / .30 / .25 | .40 / .35 / .30 | .20 / .16 / .12 | .30 / .25 / .20 | 0.95 | 0.92 | 0.85 | 1.15 | 1.10 |
| Sub-adult | .65 / .62 / .60 | .70 / .68 / .65 | .50 / .48 / .45 | .60 / .58 / .55 | 1.00 | **1.03** | 1.00 | 1.05 | 1.05 |
| Adult | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |

Rationale: young dinos drain needs faster (they are growing), which keeps them moving between food and water. Sub-adults get a 3 % sprint edge over adults ("teen speed"), so they can escape adults of their own species.

**Stats columns used below:** HP; primary bite damage (the species' first action); walk / sprint speed in studs/s (Roblox default walk = 16); stamina pool; hunger and thirst drain in % of bar per minute (time for a full bar to empty); mass (drives the size formula and carcass meat); stomach in Food Points (FP).

### 2.3 Species sheets

Universal actions (every species, not counted in the "3 + 1"): Sprint, Jump, Crouch (Small and Medium only), Eat, Drink, Rest, Vocal call (cosmetic, audible for 80 studs), Ping (group only).

Default windup (time from input to hit check): Small 0.20 s, Medium 0.30 s, Large 0.45 s. Ranges are at Adult scale.

---

#### Velociraptor (MVP prototype)
Small carnivore, pack hunter, **Nocturnal**. Stamina: 100 pool, sprint drain 9/s (11 s of sprint), regen 10/s. Swim 9. BleedResist 0.

**Look:** a lean wedge torso made of three stepped bricks and a long stiff tail of four tapering blocks that ends in a flat fan of feather plates. Each foot has one oversized bone-white sickle-claw block. A row of short square feather tiles runs down the neck and flares up when sprinting. Sand-coloured body with dark rust chevrons along the back.

| Stage | HP | Bite dmg | Walk / Sprint | Stamina | Hunger %/min (full bar lasts) | Thirst %/min (full bar lasts) | Mass | Stomach FP |
|---|---|---|---|---|---|---|---|---|
| Hatchling | 60 | 9 | 11.9 / 27.2 | 70 | 9.1 (11 min) | 11.2 (9 min) | 9 | 12 |
| Juvenile | 140 | 18 | 13.3 / 31.3 | 85 | 8 (12 min) | 9.9 (10 min) | 36 | 36 |
| Sub-adult | 260 | 31 | 14 / 35 | 100 | 7.4 (14 min) | 9.5 (11 min) | 90 | 72 |
| Adult | 400 | 45 | 14 / 34 | 100 | 7 (14 min) | 9 (11 min) | 180 | 120 |

| Action | Adult dmg | Cooldown | Stamina | Windup / range / arc | Effect |
|---|---|---|---|---|---|
| Bite | 45 | 0.8 s | 5 | 0.20 s / 4 / 70° | +1 bleed stack |
| Sickle Kick | 60 | 4 s | 12 | 0.30 s / 5 / 60° | +2 bleed; x1.3 damage if target is below 50 % HP (finisher) |
| Pack Call | – | 30 s | 10 | instant / 40 radius | Group members in range: +10 % sprint speed and highlighted for 8 s. **Phase 3 (needs groups).** |
| **Special: Pin Leap** | 30 | 12 s | 25 | 0.25 s / leap 18 | Leap forward. If the target's mass ≤ 1.5x yours: pin it for 1.5 s (counts as a daze) and auto-bite twice. Bigger target: damage only, then you bounce off |

**Why this is the MVP dino:**
1. **Cheapest rig to build and animate**: about 12–15 Parts and 4 core animations (idle, walk/run, bite, death). Large rigs need more parts, slower animations and camera work.
2. **It tests the most systems at once**: chasing (sprint and stamina), the full combat formula (bleed, finisher, pin/daze), carcass eating, AI prey hunting and PvP between raptors. A herbivore would leave combat and carcasses half-tested.
3. **Fast moment-to-moment feel**: 34 studs/s sprints and 0.8 s bites make a 15-minute playtest action-dense, which is what the fun hypothesis needs.
4. **Small size makes the size formula testable**: the raptor is smaller than every AI prey above lizard size, so "punching up" is tested from day one.
5. The concept already names a raptor for the prototype.

Prototype food before AI exists: a "meat pile" test prop with 200 FP that respawns every 60 s.

---

#### Gallimimus
Small omnivore, runner / scout. Stamina: 120 pool, sprint drain 7/s (17 s), regen 12/s. Swim 10. BleedResist 0.

**Look:** a long neck of five small stacked blocks topped by a tiny wedge beak; long, thin two-block legs; a light frame. White body with teal bands, and a flat paddle block at the end of the tail that bobs when running.

| Stage | HP | Peck dmg | Walk / Sprint | Stamina | Hunger %/min | Thirst %/min | Mass | Stomach FP |
|---|---|---|---|---|---|---|---|---|
| Hatchling | 70 | 5 | 11.9 / 28.8 | 84 | 10.4 (10 min) | 11.2 (9 min) | 15 | 15 |
| Juvenile | 160 | 10 | 13.3 / 33.1 | 102 | 9.2 (11 min) | 9.9 (10 min) | 60 | 45 |
| Sub-adult | 290 | 18 | 14 / 37.1 | 120 | 8.4 (12 min) | 9.5 (11 min) | 150 | 90 |
| Adult | 450 | 25 | 14 / 36 | 120 | 8 (12 min) | 9 (11 min) | 300 | 150 |

| Action | Adult dmg | Cooldown | Stamina | Effect |
|---|---|---|---|---|
| Peck | 25 | 0.7 s | 4 | – |
| Kick | 40 | 4 s | 10 | Medium knockback (creates escape space) |
| Alarm Honk | – | 20 s | 5 | Marks the nearest carnivore within 60 studs for 6 s, visible to your herd and to herbivores nearby |
| **Special: Zigzag Sprint** | – | 30 s | 0 | 5 s: +20 % sprint speed, no sprint drain, immune to pins |

Passive: Keen Eyes (sees carnivore nameplates from 1.5x the normal distance). Diet: Low and Mid plants, fish, eggs, and carcasses of Small species only. Intent: the fastest dino in the game; wins by escaping and scouting, never by fighting.

---

#### Pachycephalosaurus
Small herbivore, skirmisher. Stamina: 110 pool, sprint drain 10/s, regen 10/s. Swim 8. BleedResist 0.1.

**Look:** a stocky body under a thick, rounded dome built from stacked blocks with a ring of small square spike-knobs at the back. Short tail, sturdy legs. Olive-green body with a sunset-orange dome and pale knobs.

| Stage | HP | Headbutt dmg | Walk / Sprint | Stamina | Hunger %/min | Thirst %/min | Mass | Stomach FP |
|---|---|---|---|---|---|---|---|---|
| Hatchling | 110 | 14 | 10.2 / 22.4 | 77 | 9.1 (11 min) | 11.2 (9 min) | 22 | 22 |
| Juvenile | 260 | 28 | 11.4 / 25.8 | 94 | 8 (12 min) | 9.9 (10 min) | 90 | 66 |
| Sub-adult | 490 | 49 | 12 / 28.8 | 110 | 7.4 (14 min) | 9.5 (11 min) | 225 | 132 |
| Adult | 750 | 70 | 12 / 28 | 110 | 7 (14 min) | 9 (11 min) | 450 | 220 |

| Action | Adult dmg | Cooldown | Stamina | Effect |
|---|---|---|---|---|
| Headbutt | 70 | 1.2 s | 8 | Small knockback |
| Hip Check | 35 | 5 s | 10 | 120° side arc, medium knockback |
| Brace (hold) | – | – | 6/s | Frontal damage -40 %, no frontal knockback, walk only |
| **Special: Skull Rush** | 120 | 14 s | 30 | Charge 20 studs at 1.2x sprint. On hit: heavy knockback + daze 1.5 s (2.0 s if target mass ≤ yours) |

Intent: the herbivore that punches up. It can daze a raptor and escape; it is the counter to small carnivores.

---

#### Ceratosaurus
Medium carnivore, ambusher, **Nocturnal**. Stamina: 100 pool, sprint drain 11/s (9 s), regen 9/s. Swim 10. BleedResist 0.1.

**Look:** a chunky, low body with a single thin blade-shaped block standing upright on the snout and two small brow blocks. A ridge of small flat square back plates runs nose to tail. Dark moss-green with charcoal vertical bands for camouflage in forest.

| Stage | HP | Bite dmg | Walk / Sprint | Stamina | Hunger %/min | Thirst %/min | Mass | Stomach FP |
|---|---|---|---|---|---|---|---|---|
| Hatchling | 130 | 18 | 10.2 / 22.4 | 70 | 7.8 (13 min) | 10.6 (9 min) | 32 | 24 |
| Juvenile | 330 | 42 | 11.4 / 25.8 | 85 | 6.9 (14 min) | 9.4 (11 min) | 144 | 75 |
| Sub-adult | 680 | 82 | 12 / 28.8 | 100 | 6.3 (16 min) | 8.9 (11 min) | 432 | 174 |
| Adult | 1100 | 120 | 12 / 28 | 100 | 6 (17 min) | 8.5 (12 min) | 900 | 300 |

| Action | Adult dmg | Cooldown | Stamina | Effect |
|---|---|---|---|---|
| Bite | 120 | 1.0 s | 8 | +1 bleed |
| Tail Lash | 70 | 6 s | 12 | 150° rear-side arc, knockback |
| Stalk (toggle) | – | 3 s after it breaks | 0 | Crouch-walk at 40 % walk speed. Nameplate hidden beyond 15 studs, footsteps muted, hidden from compasses. Breaks on attack, sprint or taking damage |
| **Special: Ambush Lunge** | 120 x2.0 from Stalk (x1.2 otherwise) | 15 s | 25 | Lunge 14 studs; +3 bleed if it starts from Stalk |

Intent: short sprint, strong opener. Loses long chases, wins the first 3 seconds.

---

#### Parasaurolophus
Medium herbivore, herd caller / support. Stamina: 130 pool, sprint drain 7/s (18 s), regen 11/s. Swim 11. BleedResist 0.15.

**Look:** a tall, slender body with a long tube crest made of three angled blocks sweeping back from the head. Long forelimbs, so it can walk on two or four legs. Cream body with plum stripes; the crest is a bright coral that is visible from far away.

| Stage | HP | Tail dmg | Walk / Sprint | Stamina | Hunger %/min | Thirst %/min | Mass | Stomach FP |
|---|---|---|---|---|---|---|---|---|
| Hatchling | 170 | 9 | 10.2 / 21.6 | 91 | 9.8 (10 min) | 11.2 (9 min) | 63 | 40 |
| Juvenile | 420 | 21 | 11.4 / 24.8 | 110 | 8.6 (12 min) | 9.9 (10 min) | 288 | 125 |
| Sub-adult | 870 | 41 | 12 / 27.8 | 130 | 7.9 (13 min) | 9.5 (11 min) | 864 | 290 |
| Adult | 1400 | 60 | 12 / 27 | 130 | 7.5 (13 min) | 9 (11 min) | 1800 | 500 |

| Action | Adult dmg | Cooldown | Stamina | Effect |
|---|---|---|---|---|
| Tail Whip | 60 | 1.4 s | 8 | Rear arc, knockback |
| Rear Stomp | 90 | 5 s | 14 | Front; daze 0.75 s on targets with mass ≤ 30 % of yours |
| Trumpet Call | – | 25 s | 10 | Herd within 50 studs: +20 % stamina regen for 10 s; places a ping at the caller |
| **Special: Rally Horn** | – | 60 s | 20 | Herd within 50 studs (self included): heal 10 % max HP over 5 s, remove 2 bleed stacks |

Passive: High Reach from Sub-adult (can eat canopy food). Intent: the reason herds want to stay together.

---

#### Baryonyx
Medium carnivore (fish specialist), swimmer. Stamina: 110 pool, sprint drain 10/s, regen 9/s, **no stamina drain while swimming**. Swim **26**. BleedResist 0.2.

**Look:** a long, flat, narrow snout made of two long slim blocks; a big hooked thumb-claw block on each arm; a low, stepped wave-shaped ridge along the back. Slate blue-grey on top, pale sand belly, with a dark stripe through the eye.

| Stage | HP | Bite dmg | Walk / Sprint | Stamina | Hunger %/min | Thirst %/min | Mass | Stomach FP |
|---|---|---|---|---|---|---|---|---|
| Hatchling | 180 | 20 | 9.3 / 20 | 77 | 8.5 (12 min) | 8.8 (11 min) | 60 | 36 |
| Juvenile | 450 | 46 | 10.4 / 23 | 94 | 7.5 (13 min) | 7.7 (13 min) | 272 | 112 |
| Sub-adult | 930 | 88 | 11 / 25.8 | 110 | 6.8 (15 min) | 7.4 (14 min) | 816 | 261 |
| Adult | 1500 | 130 | 11 / 25 | 110 | 6.5 (15 min) | 7 (14 min) | 1700 | 450 |

| Action | Adult dmg | Cooldown | Stamina | Effect |
|---|---|---|---|---|
| Bite | 130 | 1.1 s | 8 | +1 bleed |
| Hook Claw | 80 | 4 s | 12 | +2 bleed, short range (4 studs) |
| Fish Snatch | – | 4 s | 3 | In water: auto-catches the nearest fish within 8 studs for 37 FP (fish give others 25 FP) |
| **Special: Riverburst** | 150 | 12 s | 25 | Only from water: leap 16 studs (toward shore or a target) with a bite and knockback |

Passive: Swimmer. Breath 60 s underwater (others 10 s). Can submerge, which hides its nameplate. Intent: owns rivers and lakes, which are also where everyone must drink.

---

#### Triceratops
Large herbivore, tank / charger. Stamina: 120 pool, sprint drain 10/s, regen 8/s. Swim 8. BleedResist 0.4.

**Look:** a very wide, boxy body and a broad stepped shield-plate behind the head with notched block edges. Two long tapered brow-horn blocks and one short nose block. Earth-red body, bone-white horns, a darker band across the shield plate.

| Stage | HP | Gore dmg | Walk / Sprint | Stamina | Hunger %/min | Thirst %/min | Mass | Stomach FP |
|---|---|---|---|---|---|---|---|---|
| Hatchling | 210 | 20 | 8.5 / 17.6 | 84 | 8.5 (12 min) | 10.6 (9 min) | 120 | 60 |
| Juvenile | 650 | 60 | 9.5 / 20.2 | 102 | 7.5 (13 min) | 9.4 (11 min) | 720 | 200 |
| Sub-adult | 1560 | 130 | 10 / 22.7 | 120 | 6.8 (15 min) | 8.9 (11 min) | 2700 | 550 |
| Adult | 2600 | 200 | 10 / 22 | 120 | 6.5 (15 min) | 8.5 (12 min) | 6000 | 1000 |

| Action | Adult dmg | Cooldown | Stamina | Effect |
|---|---|---|---|---|
| Horn Gore | 200 | 1.4 s | 10 | +2 bleed |
| Shove | 100 | 5 s | 14 | Frontal, heavy knockback |
| Shield Guard (hold) | – | – | 8/s | Frontal damage -50 %, no frontal knockback, walk only |
| **Special: Stampede Charge** | 300 | 20 s | 35 | 3 s charge at 30 studs/s with light steering. First target hit: damage + heavy knockback + daze 1.5 s. Ends on hitting terrain or a target with more mass |

Intent: the only herbivore an adult Tyrannosaurus respects (9 rex bites to kill it, 15 gores to kill the rex).

---

#### Tyrannosaurus
Large carnivore, apex. Stamina: 100 pool, sprint drain 12/s (8 s), regen 8/s. Swim 9. BleedResist 0.5.

**Look:** a massive boxy skull about one third of the body length, tiny two-block arms, thick pillar legs, and a heavy tail. Darker rectangular scale-tiles run along the spine. Deep charcoal-brown with a burnt-orange throat patch and pale teeth blocks.

| Stage | HP | Bite dmg | Walk / Sprint | Stamina | Hunger %/min | Thirst %/min | Mass | Stomach FP |
|---|---|---|---|---|---|---|---|---|
| Hatchling | 225 | 30 | 8.5 / 19.2 | 70 | 6.5 (15 min) | 10 (10 min) | 140 | 72 |
| Juvenile | 700 | 90 | 9.5 / 22.1 | 85 | 5.8 (17 min) | 8.8 (11 min) | 840 | 240 |
| Sub-adult | 1680 | 195 | 10 / 24.7 | 100 | 5.2 (19 min) | 8.4 (12 min) | 3150 | 660 |
| Adult | 2800 | 300 | 10 / 24 | 100 | 5 (20 min) | 8 (12 min) | 7000 | 1200 |

| Action | Adult dmg | Cooldown | Stamina | Effect |
|---|---|---|---|---|
| Crushing Bite | 300 | 1.6 s | 10 | +2 bleed; 0.45 s windup (readable, dodgeable) |
| Tail Sweep | 120 | 6 s | 14 | 160° rear arc, knockback |
| Stomp | 80 | 10 s | 15 | 10-stud area; daze 1.0 s on targets with mass ≤ 20 % of yours |
| **Special: Thunder Roar** | – | 45 s | 20 | 30-stud, 90° cone: daze 1.5 s on targets with mass < 50 % of yours. Non-group dinos within 40 studs: -25 % stamina regen for 6 s. Own group within 40 studs: +10 % damage for 8 s |

Intent: kills Small dinos in one bite, but turns slowly, has a short sprint and needs 60 FP of food per minute, so it must keep hunting.

### 2.4 Matchup sanity check (adult vs adult, hits to kill with primary action, no bleed, no misses)
| Attacker \ Target | Raptor | Galli | Pachy | Cerato | Para | Bary | Trike | Rex |
|---|---|---|---|---|---|---|---|---|
| Velociraptor | 9 | 12 | 22 | 40 | 63 | 66 | 116 | 125 |
| Gallimimus | 14 | 18 | 34 | 62 | 96 | 101 | 208 | 224 |
| Pachycephalosaurus | 5 | 6 | 11 | 20 | 31 | 32 | 75 | 80 |
| Ceratosaurus | 3 | 3 | 6 | 10 | 15 | 16 | 39 | 44 |
| Parasaurolophus | 4 | 5 | 9 | 15 | 24 | 25 | 63 | 71 |
| Baryonyx | 2 | 3 | 4 | 7 | 11 | 12 | 30 | 33 |
| Triceratops | 2 | 2 | 3 | 4 | 5 | 6 | 13 | 15 |
| Tyrannosaurus | 1 | 1 | 2 | 3 | 4 | 4 | 9 | 10 |

Readout: same-species fights take 9–12 hits (about 7–20 s, roughly double with real misses). Small dinos cannot hurt a rex head-on; a 4-raptor pack that hit-and-runs with bleed and back-hits kills a full adult rex in about 25–35 s, which is intended pack play. Re-run this table after every stat change (keep the script in the tuning sheet).

---

## 3. Growth

### 3.1 Stages and timing (real minutes of play with needs satisfied)
| Stage | Growth % range | Small (35 min total) | Medium (45) | Large (60) | Unlocks at stage entry |
|---|---|---|---|---|---|
| Hatchling | 0 – 15 | 0 – 5.3 min | 0 – 6.8 | 0 – 9 | Low plants only; spawn shield; can join groups (slot weight 1) |
| Juvenile | 15 – 45 | 5.3 – 15.8 | 6.8 – 20.3 | 9 – 27 | Low plants; bites now kill Scurrylizards in one hit |
| Sub-adult | 45 – 100 | 15.8 – 35 | 20.3 – 45 | 27 – 60 | Mid plants; tall species reach canopy |
| Adult | 100 | 35+ | 45+ | 60+ | Nesting, Elder progress |

Rationale: 35 minutes gets a small species to Adult across 1–2 sessions; the hardest species (Large) takes about 3 sessions, which is their price. Time is per species: each owned species has its own saved growth.

### 3.2 Growth rules
| Rule | Value |
|---|---|
| Base rate | 100 % / growth time, ticked by the server every 1 s |
| Paused when | Hunger < 25 % or thirst < 25 %; AFK (no movement or action input for 5 min); dead |
| Bonuses (multiply) | Nest-born "parent nearby" x1.2 (section 6.3); diet balance bonus x1.2 (section 9.3); Robux boost (if any) at most x1.25 (Decision 8) |
| Bonus cap | Combined multiplier capped at x1.5 |
| What grows | HP, damage, mass, stomach, speed, stamina pool and model scale (keyframed per section 2.2); reach (plant tiers, hitboxes); group slot weight |
| Elder (Adult) | 60 min alive as an Adult in one life grants the **Elder** title and a cosmetic scar/colour overlay for that species. No stat change |
| Stage-up | Server announces the stage-up; client plays a 1 s size pop with a dust burst. If there is no room to grow (inside a cave or between trees), growth % keeps rising but the visual scale catches up when there is space (check every 2 s, max 10 s, then nudge to the nearest open spot) |

### 3.3 What happens on death (Standard checkpoint rule, recommended; see Decision 2)
- **You keep the species.** Species ownership and coins are never lost.
- Each stage has **checkpoints at its start and at its midpoint**: 0, 7.5, 15, 30, 45, 72.5, 100 %.
- On death, growth falls back to the **highest checkpoint at or below your current growth**.
- **Hatchlings lose nothing** (the stage is too short to matter).
- **Adults fall back to 72.5 % (Sub-adult midpoint).** Small species lose about 9.6 minutes, Large about 16.5 minutes. That is the cost of being at the top.
- **Beginner Shield:** for an account's first 30 minutes of total playtime, death costs no growth.

| Died at | Respawns at | Max time lost (Small / Large) |
|---|---|---|
| Hatchling, any % | same % | 0 |
| Juvenile, 15–30 % | 15 % | 5.3 / 9 min |
| Juvenile, 30–45 % | 30 % | 5.3 / 9 min |
| Sub-adult, 45–72.5 % | 45 % | 9.6 / 16.5 min |
| Sub-adult, 72.5–100 % | 72.5 % | 9.6 / 16.5 min |
| Adult | 72.5 % | 9.6 / 16.5 min |

---

## 4. Needs

All needs are server-side values, ticked at 1 Hz. The client only shows them (and interpolates bars between ticks).

### 4.1 Bars, drain and thresholds
| Need | Range | Drain | Thresholds and effects |
|---|---|---|---|
| Hunger | 0–100 % | Species/stage table (section 2.3), x0.6 while resting | < 40 %: no HP regen. < 30 %: yellow warning. < 25 %: growth paused. < 15 %: red warning + heartbeat sound. 0 %: lose 0.5 % max HP/s (dead in about 3.3 min) and sprint -20 % |
| Thirst | 0–100 % | Species/stage table, x0.6 while resting; weather and biome multipliers (section 7.3) | Same thresholds. 0 %: lose 0.75 % max HP/s (about 2.2 min) and sprint -20 % |
| Stamina | 0–pool | Sprint drain per species (section 2.3); action costs; swimming 4/s for non-swimmers | Regen per species, starting 1.0 s after the last use; x2 resting. At 0: **Exhausted**, no sprint and no stamina actions until 30 % |
| Health | 0–max HP | Damage, bleed, starvation, dehydration, drowning, falls | Regen 0.2 % max HP/s (about 8 min to full) when hunger ≥ 40 %, thirst ≥ 40 %, no bleed and out of combat. Resting: x5 (1 %/s, about 100 s to full). Group comfort: x1.25 (section 6.1) |
| Bleed | 0–5 stacks | Each stack deals 0.25 % max HP/s x (1 - BleedResist) | Lose 1 stack every 8 s (every 5 s while standing in water). Blocks HP regen. Rally Horn removes 2 |
| Wounded | HP < 25 % | – | Sprint -15 %, stamina regen -25 %, visible drip effect. Readable prey for predators; tension for the victim |
| Breath | 10 s (Baryonyx 60 s) | Only while the head is underwater | At 0: 5 % max HP/s drowning damage |

Resting: hold the Rest action out of combat while not moving; 1.5 s to lie down; cancelled by any damage or movement input. Fall damage: falls over (5 x model scale + 15) studs deal 2 % max HP per extra stud.

### 4.2 Refilling
| Action | Rule |
|---|---|
| Eat (carcass, meat) | Mouth within reach (3 studs x model scale) of the carcass. Each 1 s tick moves 5 % of **your** stomach FP from the carcass meat pool to you (empty to full in about 20 s). Damage cancels eating |
| Eat (plants) | Each 1 s tick takes 1 "bite" from a plant node and gives 6 % of your hunger bar (empty to full in about 17 bites). Plant nodes count bites, not FP, so large herbivores do not strip the map faster than small ones |
| Drink | Mouth at the water surface (server raycast hits Terrain water). +5 % thirst per second (about 20 s to full). Ocean water is salty and cannot be drunk (later; only if the map has an ocean) |
| Respawn | Respawn with 70 % hunger and thirst (not 100 %, so suiciding to refill is never worth it) |

### 4.3 Food sources per diet
| Source | Carnivore | Omnivore (Gallimimus) | Herbivore | Value | Notes |
|---|---|---|---|---|---|
| Carcass (player or AI) | Yes | Small-species carcasses only | No | Meat FP = victim mass x 0.5 (min 10) | Section 7.1 |
| Fish (rivers, lakes) | Yes (bite) | Yes (bite) | No | 25 FP each (Baryonyx Fish Snatch 37) | Schools of 3–5 |
| Eggs (nests) | Yes | Yes | No | 40 FP each | Breaking an egg ends it |
| Fern (Low) | No | Yes | Yes | 5 bites, regrows 1 bite / 30 s | Every size can reach |
| Bush (Low + Mid) | No | Yes | Yes | 10 bites, regrows 1 / 30 s | Hatchlings only reach the low part (half bites) |
| Fruit tree (Mid) | No | Yes | Yes | 12 bites, regrows 1 / 30 s | Sub-adult or bigger |
| Canopy (High) | No | No | High Reach species only | 20 bites, regrows 1 / 20 s | Parasaurolophus Sub-adult+. Uncontested food for tall herbivores |
| Swamp reeds (Low) | No | Yes | Yes | 6 bites, also +10 % thirst per bite | Swamp biome only |

Depleted nodes start regrowing after a 120 s delay. Exact counts per biome: `game-level-designer`, using a target of about 1 food node per 2 herbivores within 100 studs of each water source.

---

## 5. Combat

### 5.1 Flow (server-authoritative)
1. Client presses an action. It immediately plays the windup animation (for feel) and sends `ActionRequest(actionId: number, aimYaw: number)`.
2. Server validates, in this order: rate limit; alive; not dazed or pinned; action belongs to the current species and stage; cooldown and global lockout are clear; stamina is enough. On failure the request is dropped and the client gets `ActionRejected(actionId, reason)` so it can cancel the animation.
3. Server deducts stamina, starts the cooldown, and waits the windup on its own clock.
4. At the end of the windup, the server builds a hitbox box in front of the attacker's **server-side** head CFrame and calls `workspace:GetPartBoundsInBox` with `OverlapParams` that include only the `Hurtboxes` folder and exclude the attacker and group members.
5. Each target is hit at most once per swing. The server applies the damage formula, bleed, daze and knockback, then broadcasts `HitConfirmed` to clients near enough to see it (hit sparks and damage numbers only appear on confirmation).

| Hit detection detail | Value |
|---|---|
| Hurtbox | One invisible, non-colliding box per dino (two for Large species: body and head), sized per stage, welded to the rig, in a `Hurtboxes` folder |
| Hitbox | Box of reach x width x height from the action table, scaled by model scale, extended forward by attacker speed x 0.1 s to soften latency |
| Tolerance | Hitbox size x1.15. No lag-compensation rewind in v1 (revisit if testers report "I clearly hit them") |
| Attacker sanity | Reject hits when the attacker's server position moved more than (sprint speed x 1.5 x dt + 4) studs since the last check (teleport) |
| AI | Uses the same pipeline and formula with server-owned NPCs |

### 5.2 Damage formula
```
damage = round( ActionBase x StageDamageMult(growth) x SizeFactor x BackHit x (1 - Guard) x Buffs ),  minimum 1
SizeFactor = clamp( (attackerMass / targetMass) ^ 0.3 , 0.5 , 1.75 )
BackHit    = 1.2 if the attacker is more than 120° away from the target's facing direction, else 1.0
Guard      = Brace 0.4 / Shield Guard 0.5 for frontal hits only (not stacked, max 0.6)
Buffs      = product of active buffs (Thunder Roar +10 %, Sickle Kick finisher x1.3, Ambush Lunge x2.0 / x1.2)
```
Example: adult Velociraptor bites an adult Tyrannosaurus from behind: 45 x 1.0 x 0.5 (clamped) x 1.2 = 27. Adult rex bites the raptor: 300 x 1.75 = 525 > 400 HP, so one bite kills.

| Effect | Rule |
|---|---|
| Bleed | Action adds N stacks (max 5). Tick = 0.25 % target max HP/s per stack x (1 - BleedResist). Decay: -1 stack / 8 s |
| Daze | No attacks or sprint, move at 50 %. Duration from the action; halved if the target's mass is more than 2x the attacker's, immune if more than 4x. **6 s daze immunity** after any daze ends (pins included) |
| Knockback | Impulse = base (Small 20, Medium 35, Heavy 55 studs/s) x clamp(attackerMass / targetMass, 0.25, 3) ^ 0.5, capped at 60 studs/s. Player characters are client-owned physics, so the server sends `ApplyKnockback(vector)` to the victim's client and loosely checks displacement afterward; NPCs get the impulse directly on the server |
| Combat tag | Dealing or taking player damage sets "in combat" for 20 s: no rest, no HP regen, no species switch, logging out counts as death |
| Kill credit | Everyone who dealt damage in the last 15 s shares kill rewards in proportion to damage dealt (values: economy designer) |

### 5.3 Anti-spam
| Lever | Value |
|---|---|
| Per-action cooldown | Action tables; checked on the server with `os.clock()` |
| Global lockout | 0.35 s between any two attacks |
| Stamina costs | Action tables. Exhausted dinos cannot attack with stamina actions |
| Remote rate limit | Token bucket: 8 `ActionRequest`s per second, burst 4. Excess is dropped silently. More than 20 per second sustained for 5 s: log and flag; repeated flags: kick |
| Input buffering | The client may queue one action pressed in the last 0.15 s of a cooldown (feels responsive, does not bypass the server check) |
| Friendly fire | Off for group members (no damage, no knockback, no daze) |

---

## 6. Social

### 6.1 Groups (packs and herds)
| Rule | Value |
|---|---|
| Who | Same diet only: carnivores form **packs**; herbivores and omnivores form **herds**. Mixed species allowed |
| Size limit (slots) | Pack 6 slots, herd 10 slots [PLACEHOLDER] |
| Slot weight | Hatchling or Juvenile 1. Sub-adult: Small 1, Medium 2, Large 2. Adult: Small 1, Medium 2, Large 3. (An adult rex pack is 2 rexes; a raptor pack is 6 raptors) |
| Growing past the cap | Never kicks anyone; no new invites until the group is under the cap |
| Joining | Invite from within 50 studs or from the player list; the invitee accepts a prompt. 60 s cooldown after leaving or being kicked |
| Leader | Creator; can invite, kick and set nest access. Leadership passes to the longest-standing member on leave |
| Benefits | No friendly fire; shared carcasses without contest; member markers through terrain up to 500 studs and HP bars over members; group chat; pings; group-only buffs (Pack Call, Trumpet, Rally, Roar); resting within 30 studs of a member: rest regen x1.25; respawn option "near group" |
| "Spawn near group" | Picks the regular spawn point nearest the group leader, never the leader's location (prevents teleport abuse). Only if the leader is out of combat |

### 6.2 Group chat and pings
| Feature | Rule |
|---|---|
| Group chat | A `TextChatService` `TextChannel` per group, created on the server; members added with `AddUserAsync`. Roblox filters it automatically and respects each player's chat settings |
| Pings | Ping wheel (key G, a radial button on mobile, D-pad on console): **Danger, Food, Water, Gather, Follow me, Help**. A world marker plus a compass icon, visible only to the group, lasting 20 s |
| Ping limits | 1 ping per 2 s per player, max 3 active per player |

### 6.3 Nests and eggs (Phase 3)
| Rule | Value |
|---|---|
| Who can nest | Any **Adult**, hunger and thirst ≥ 60 %, out of combat, on valid nesting ground (not water, not the volcano), ≥ 120 studs from another nest. Solo is allowed |
| Build | Hold Nest for 8 s (cancelled by damage) |
| Eggs | 2, +1 per other Adult **group member of the same species** within 25 studs when the build finishes, max 5 |
| Personal cooldown | 20 min per player |
| Lifetime | Eggs last 10 min; the nest disappears when empty or after 15 min |
| Server cap | 6 active nests |
| Egg defence | Eggs have 40 HP. Non-group carnivores and omnivores can break and eat them (40 FP) |
| Hatching (other players) | The spawn screen lists available nests on the server (species, area, owner's group name). Picking one spawns you as a hatchling of the nest's species next to the nest, at 5 % growth, and sends you an invite to the parent group |
| Access | Nest owner chooses: Anyone (default) / Friends + group / Group only (Decision 7) |
| Parent care | Nest-born Hatchlings and Juveniles within 30 studs of an Adult from the owner's group grow x1.2 |
| Parent reward | Coins when a nest-born hatchling reaches Juvenile (value: economy designer) |
| Species you don't own | Allowed as a "trial life" (Decision 6): growth only saves if you own or unlock the species before leaving |
| Species cap reached | That nest is greyed out on the spawn screen |

---

## 7. World: carcasses, AI wildlife, day/night, weather

### 7.1 Carcasses
| Rule | Value |
|---|---|
| Created by | Any player or AI death, including combat logs (not server shutdowns) |
| Model | The dino's own rig, darkened, lying down, with a few bone-white blocks showing; no gore. It shrinks in 3 visual steps as meat runs out |
| Meat | Victim mass x 0.5 FP (min 10). Adult raptor 90, adult Triceratops 3000, adult rex 3500 |
| Lifetime | Small 4 min, Medium 7 min, Large 10 min; AI carcasses 3 min [PLACEHOLDER] |
| Server cap | 30. When full, the oldest small carcass is removed first |
| Placement | Snapped to the ground by raycast; in water, it sinks to the bed |
| Label | Shows species and stage, never the player's name (avoids harassment) |
| Multiple eaters | Allowed. The server serializes ticks, so the meat pool never goes below 0 |

### 7.2 AI wildlife
All AI is server-owned and does not use Humanoids: simple state machines (Wander, Graze, Flee, Defend, Sleep) at 5 Hz, moving by CFrame with ground raycasts (the scripter may choose `BulkMoveTo`). Original blocky designs.

| AI | Real genus? | Behaviour | HP | Mass | Meat / food | Damage | Cap | Where |
|---|---|---|---|---|---|---|---|---|
| Scurrylizard | Fictional | Wanders; flees from anything within 20 studs | 15 | 40 | 20 FP | – | 20 | Forest, desert |
| Burrowpig | *Lystrosaurus* | Grazes in pairs; flees; kicks when cornered | 80 | 160 | 80 FP | 8 | 12 | Plains, forest edge |
| Frillhorn herd | *Protoceratops* | Herds of 3–4; the herd turns on an attacker, then flees below 30 % HP | 350 | 400 | 200 FP | 25 | 12 (3 herds) | Plains, desert |
| Fish | Fictional | Schools of 3–5 in rivers and lakes; scatter when a dino enters the water | 1 | – | 25 FP (no carcass) | – | 30 | Rivers, lakes |
| Ambient birds and insects | – | Client-only visuals | – | – | – | – | client | Everywhere |

| AI rule | Value |
|---|---|
| Total cap | 74 at 30 players. Each cap is scaled by clamp(players / 20, 0.5, 1.5) |
| Spawning | Per-zone respawn timer 60–120 s; only ≥ 100 studs from every player and out of their view |
| Despawn | No player within 400 studs for 60 s (carcasses excluded) |
| Night | Burrowpigs and Frillhorns sleep in place: easier hunts at night |
| Hits to kill (Velociraptor) | Scurrylizard: 3 as Hatchling, 1 from Juvenile. Burrowpig: 7 as Juvenile, 2 as Adult. Frillhorn: 10 as Adult (pack target) |

Later: a large roaming herbivore AI (sauropod-style) as an apex food source and the base for a boss event.

### 7.3 Day/night and weather (Phase 3)
**Day cycle: 24 real minutes** = Day 14 + Dusk 2 + Night 6 + Dawn 2 [PLACEHOLDER].

| Condition | Gameplay effect |
|---|---|
| Day | Nameplates visible at 120 studs |
| Night | Nameplates visible at 40 studs (ambushes); darker lighting with a minimum brightness so mobile screens stay playable; AI prey sleep; resting heals x1.25 more for everyone; **Nocturnal** species (Velociraptor, Ceratosaurus): +15 % stamina regen and brighter client vision |
| Clear (55 %) | – |
| Overcast (15 %) | Cosmetic |
| Rain (20 %) | Thirst drain x0.6; footstep sounds quieter (cosmetic) |
| Storm (25 % of rain) | Rain effects + thunder that masks footsteps (cosmetic). Later: lightning strikes |
| Fog (10 %) | Nameplates 40 studs, shorter view distance (Atmosphere density) |
| Heatwave | Desert biome only, clear days: thirst drain x1.4 inside the desert |

Weather is server-wide, changes every 6–12 min, and is announced with a 30 s warning (a sky change plus an icon).

---

## 8. Death and respawn

| Step | Rule |
|---|---|
| Causes | Damage, bleed, starvation, dehydration, drowning, falls. Logging out while in combat counts as death (the body becomes a carcass) |
| Death screen | 5 s: cause of death, killer's species and stage (no username), and one tip. Then the spawn screen |
| Spawn screen | Choose an owned species (each shows its saved growth and stage), then a spawn: random diet spawn area / near group / a nest |
| Growth penalty | Checkpoint rule (section 3.3). Beginner Shield for the first 30 min of an account |
| Never lost | Coins, species, cosmetics, Elder titles |
| Respawn values | HP 100 %, hunger and thirst 70 %, stamina full, no bleed |
| Respawn delay | 10 s after death (5 s for hatchlings) |
| Spawn shield | 60 s: cannot be damaged by players; ends early if you attack anyone. Shown as a faint outline |
| Reset button | Allowed (for stuck players) and treated as a death, except within 2 min of spawning (free reset) |
| Unstuck | Out of combat only, 120 s cooldown: moves you to the nearest open ground within 30 studs |
| Safe logout | Out of combat: saves growth, hunger, thirst and HP % for that species. Rejoining spawns you at a normal spawn with those values (minimum 40 % hunger and thirst) |
| Server shutdown | `BindToClose` saves everyone with no penalty |

### Keeping it fair for younger players without losing tension
| Measure | Why it keeps tension |
|---|---|
| Checkpoints (max loss: half a stage) | Dying still costs real minutes |
| Hatchlings lose nothing; Beginner Shield for 30 min | New players learn before stakes start |
| Spawn shield 60 s; nursery spawns for new accounts | Stops spawn camping without making areas safe forever |
| No coin, species or cosmetic loss | Death never feels like losing purchases |
| Death tips; telegraphed big attacks (0.45 s windups) | Deaths are understandable and avoidable |
| Friendly fire off in groups | No griefing by teammates |
| No coins for killing players with less than 15 % of your mass (economy lever) | Removes the reward for bullying hatchlings; the danger stays real |
| Stylized blood (small red cube drips) with a "Reduced effects" setting that swaps it for white sparkles | Suits Roblox's mild-violence expectations |

---

## 9. Server size

### 9.1 Recommendation: 30 players per server (MVP playtests at 12–16)
| Reason | Detail |
|---|---|
| Encounter rate | Target: meet another player every 2–4 min. With a playable map of about 2,000 x 2,000 studs, 30 players give each player about a 365-stud square, which a raptor crosses in about 11 s; players also gather at water |
| Group math | Pack 6 / herd 10 slots: 30 players supports 3–5 real groups plus solo players |
| Species caps | 30 makes caps meaningful (3 rexes = 10 %) without blocking many players |
| Performance | 30 rigs (12–40 Parts each) + 74 AI + 30 carcasses stay within a mobile-friendly part and physics budget, with StreamingEnabled |
| Filling servers | At launch, concurrency is low. 30-player servers fill and feel alive; 60-player servers feel empty |
| Growth path | Raise to 40 if metrics show low encounter rates and server performance holds; map size must grow with it |

Map size note for `game-level-designer`: about 2,000–2,500 studs across for 30 players, with water spaced so that no point is more than about 250 studs from drinkable water.

### 9.2 Species caps (count players of that species at any stage)
| Species | Cap at 30 players | Formula |
|---|---|---|
| Tyrannosaurus | 3 | 10 % of max players |
| Triceratops | 4 | 13 % |
| Baryonyx, Ceratosaurus | 5 each | 15 % |
| Others | none | – |

### 9.3 Diet balance
If carnivores make up more than 55 % of living players, herbivores and omnivores get x1.2 growth (shown on the spawn screen as "Herbivores needed: +20 % growth"). If herbivores are more than 75 %, carnivores get x1.2.

---

## 10. MVP scope vs later

### 10.1 MVP (Prototype + Core loop)
| Phase | In scope | Done when |
|---|---|---|
| **Prototype (week 1)** | Test terrain about 600 x 600 studs with forest, a river and a pond; Velociraptor rig with continuous scaling; movement, sprint, stamina; hunger, thirst, drinking; meat-pile test props; Bite + Sickle Kick + Pin Leap with the server hitbox and damage formula; HP, death and basic respawn | Two testers can chase, fight and eat for 10 minutes with no errors |
| **Core loop (weeks 2–3)** | 4 growth stages with keyframed stats; per-species growth save (DataService with session locking); checkpoint death penalty + Beginner Shield; carcasses from deaths; AI: Scurrylizard + Burrowpig; bleed, regen, resting, Wounded; daze and knockback; spawn shield; combat tag and combat-log rule; reset and unstuck; first-10-minutes objective tracker | A tester grows Hatchling to Adult in about 35 min with the success criteria below |

**Out of MVP:** other species, groups, chat channels, pings, Pack Call, nests, fish, Frillhorn herds, day/night, weather, species caps, shop, coins UI (track coins in data only if the economy designer is ready).

### 10.2 MVP success criteria and "broken" definitions
| Metric | Success | Broken (triggers a balance pass) |
|---|---|---|
| Time to Juvenile (new tester, unassisted) | 5–7 min | > 10 min |
| First food found | < 2 min for 80 % of testers | > 4 min |
| Starvation + dehydration share of deaths | < 15 % | > 25 % |
| Raptor vs raptor adult duel length | 10–25 s | < 5 s or > 45 s |
| Time to Adult | 35 min ± 15 % | ± 30 % |
| Onboarding objectives completed without help | > 90 % | < 75 % |
| "I hit them but it didn't count" complaints | rare | more than 1 per tester per session (add lag compensation) |

### 10.3 Later phases (mapping my systems onto the concept's phases)
| Phase | Systems from this doc |
|---|---|
| 3. Species + map | The other 7 species, groups + chat + pings, Pack Call, fish, Frillhorn herds, day/night, weather, species caps, diet balance, nests |
| 4–5. Shop, UI, monetization | Cosmetics in the 3D preview; Elder overlays; any growth boost (Decision 8) |
| 6. Playtest + polish | Re-run the matchup table, AI caps, lag compensation if needed |

### 10.4 "More ideas" ranked by value / effort
Scores are 1–5. Ratio = value / effort.

| Rank | Idea | Value | Effort | Ratio | Recommendation |
|---|---|---|---|---|---|
| 1 | Admin / mod tools (kick, ban, spectate, server logs) | 5 | 2 | 2.5 | **Required before launch**, not optional |
| 2 | Leaderboards (biggest dino, longest life, Elders) | 4 | 1 | 4.0 | Launch (cheap; OrderedDataStore + in-game board) |
| 3 | Private servers (Roblox built-in) | 4 | 1 | 4.0 | Launch. Set a price; add owner commands later |
| 4 | Photo mode + emotes | 3 | 1 | 3.0 | Launch +1 month (social sharing; sells cosmetics) |
| 5 | Mutations (1 random trait on hatch) | 4 | 2 | 2.0 | Post-launch. Traits must be small sidegrades (±5 %) and never sold for Robux (paid randomness rules + pay-to-win) |
| 6 | Fishing and swimming expansion (boss fish, dive spots) | 3 | 2 | 1.5 | Post-launch; builds on Baryonyx and fish AI |
| 7 | Boss event (roaming giant fought by the whole server) | 4 | 3 | 1.3 | First big update; reuses AI + carcass systems |
| 8 | Seasons + battle pass | 4 | 4 | 1.0 | After 2–3 months of stable content (needs a content pipeline) |
| 9 | Meteor / volcano events | 3 | 4 | 0.75 | Later; terrain changes are expensive and risky with streaming |
| 10 | Territories | 3 | 4 | 0.75 | Later; balance and griefing risk |
| 11 | Skill trees per species | 3 | 4 | 0.75 | Later or never; widens power gaps between veterans and new players |
| 12 | Tamed babies / pet companions | 2 | 3 | 0.67 | Low priority; overlaps with nests and confuses the "you are the dino" fantasy |

---

## 11. Tuning levers (master list)
| Lever | Default | Controls | Tune when |
|---|---|---|---|
| `GrowthMinutes[sizeClass]` | 35 / 45 / 60 | Session pacing | Time-to-Adult outside ± 30 % |
| `StageKeyframes` | 0 / 15 / 45 / 100 % | Stage lengths | Juvenile feels too long |
| `StageMultipliers[sizeClass]` | Section 2.2 | Young vs adult power | Hatchlings of big species beat small adults |
| `SizeExponent`, `SizeClamp` | 0.3, [0.5, 1.75] | How much size matters | Packs can't hurt apexes, or apexes feel weak |
| `BackHitMult`, `BackHitAngle` | 1.2, 120° | Ambush and flank reward | |
| `Bleed.PerStack`, `MaxStacks`, `DecaySeconds` | 0.25 %, 5, 8 s | Attrition | Fights end by bleed more than hits |
| `Daze.ImmunitySeconds` | 6 s | Lockdown chains | Stun-lock complaints |
| `GlobalLockout` | 0.35 s | Attack spam | |
| `Hunger/Thirst drain`, `EatTickPct`, `DrinkPct` | Section 2.3 / 5 % / 5 % | Needs pressure | Starvation share of deaths > 25 % |
| `RegenPct`, `RestMult` | 0.2 %/s, x5 | Downtime between fights | |
| `CheckpointPoints`, `AdultDeathFallback` | Section 3.3, 72.5 % | Death sting | Quit rate after death rises |
| `BeginnerShieldMinutes` | 30 | New player safety | |
| `SpawnShieldSeconds` | 60 | Spawn camping | |
| `GroupSlots[diet]`, `SlotWeight` | 6 / 10 | Group size | Mega-packs dominate |
| `SpeciesCapPct` | Section 9.2 | Apex population | |
| `DietBalanceThreshold`, `DietBonus` | 55 % / 75 %, x1.2 | Diet ratio | |
| `CarcassLifetime`, `CarcassCap`, `MeatPerMass` | Section 7.1, 30, 0.5 | Carnivore food supply | Carnivore starvation |
| `AICap[type]`, `AIScale` | Section 7.2 | Food density, performance | Server heartbeat drops |
| `PlantBites`, `RegrowSeconds` | Section 4.3 | Herbivore food supply | |
| `DayCycleMinutes`, `WeatherWeights` | 24, section 7.3 | Atmosphere | |
| `NameplateDistance[day/night/fog]` | 120 / 40 / 40 | Stealth vs readability | |

---

## 12. Implementation notes for `roblox-systems-scripter`
Design requirements only; how to build them is the scripter's call.

| Item | Note |
|---|---|
| Data modules | `src/shared/Species/<Name>.luau` (stats, keyframes, actions) and `src/shared/Tuning.luau` (all levers above). Shared so the UI can show stats; the server reads the same tables. No secrets in them |
| Services (`src/modules`) | DataService, SpawnService, GrowthService, NeedsService, CombatService, CarcassService, WildlifeService; later GroupService, NestService, WorldService (day/night/weather) |
| Remotes (client to server) | `ActionRequest`, `EatRequest`, `DrinkRequest`, `RestRequest`, `SpawnRequest`; later `GroupRequest`, `PingRequest`, `NestRequest`. All rate-limited and type/range-checked; distances re-checked on the server |
| Remotes (server to client) | `NeedsUpdate` (1 Hz, own player only), `HitConfirmed`, `ActionRejected`, `ApplyKnockback`, `GrowthStage` |
| Saved per species | `growth`, `hunger`, `thirst`, `hpPct`, `elder`, plus `_version` for migrations. Account level: `ownedSpecies`, `playtimeMinutes` (Beginner Shield), coins (economy) |
| Movement validation | The server owns WalkSpeed; sample positions and flag sustained speeds above sprint x 1.3 |

---

## 13. Edge cases
| Case | Resolution |
|---|---|
| Eating or drinking while attacked | Any damage cancels the eat/drink/rest action |
| Two eaters drain a carcass on the same tick | The server processes ticks one at a time; the pool clamps at 0 and the last eater gets the remainder |
| Mutual kill (both die on the same tick) | Both die; two carcasses; kill credit to both |
| Logging out in combat | Counts as death: carcass spawns, checkpoint penalty applies |
| Logging out while starving | Saved as-is but floored at 40 % hunger and thirst on rejoin (not a refill exploit: the floor is below the respawn value of 70 %) |
| Growing inside a tight space | Visual scale waits for space (max 10 s) then nudges to open ground (section 3.2) |
| Pin Leap on a much bigger target | Damage only; the raptor bounces back 4 studs |
| Daze chains from several attackers | 6 s immunity after any daze |
| Group exceeds slot cap through growth | Allowed; no new invites until under cap |
| Rejoining with a saved species that is at its cap | That species is greyed out; the player picks another or waits (spawn screen shows the count) |
| Nest species at cap | Nest greyed out on the spawn screen |
| Player quits a group to hit a former member | 60 s rejoin cooldown; friendly fire turns on immediately after leaving (intended) |
| Suicide to teleport or refill | Death penalty + respawn at 70 % needs + random spawn make it a loss |
| AFK resting to grow | Growth pauses after 5 min without input |
| Carcass inside water or mid-air | Raycast to ground or water bed |
| Non-swimmer in deep water with no stamina | Drowning damage after breath runs out; swimming toward shore keeps working at half speed |
| Server shutdown | Save everyone with no penalty |
| Hatchling in an adult fight | Hatchlings are tiny hurtboxes and take full damage; the spawn shield and nursery spawns are their protection |

---

## Decisions for the user

1. **MVP prototype species.** Options: (a) Velociraptor, (b) Pachycephalosaurus, (c) Triceratops. **Recommendation: (a)**: cheapest rig, and it tests chasing, the full combat formula, carcasses and AI hunting in one dino.
2. **Death penalty.** Options: (a) Hardcore: back to Hatchling, (b) Standard: back to the last checkpoint (max half a stage; Adults to 72.5 %), (c) Casual: no growth loss. **Recommendation: (b)**, plus the 30-minute Beginner Shield.
3. **Time to Adult (Small / Medium / Large).** Options: (a) 20 / 30 / 40 min, (b) 35 / 45 / 60 min, (c) 60 / 90 / 120 min. **Recommendation: (b)**: a first session reaches Sub-adult, and Adults still feel earned.
4. **Server size.** Options: (a) 20, (b) 30, (c) 50. **Recommendation: (b) 30**, with MVP playtests at 12–16.
5. **Species caps.** Options: (a) caps per species (rex 10 %), (b) no caps. **Recommendation: (a)**, otherwise servers fill with rexes.
6. **Hatching from another player's nest as a species you don't own.** Options: (a) not allowed, (b) allowed as a trial life (growth saves only if you unlock the species before leaving), (c) allowed and unlocks the species for free. **Recommendation: (b)**: social hook and a natural reason to unlock, without giving species away.
7. **Default nest access.** Options: (a) Anyone, (b) Friends + group, (c) Group only. **Recommendation: (a) Anyone**, with the owner able to switch. It pulls new players into groups; hatchlings can't do much harm.
8. **Robux growth items** (the concept lists "growth boost" and "instant growth"). Options: (a) none, (b) a timed growth boost capped at x1.25 and no instant growth, (c) both as in the concept. **Recommendation: (b)**. Instant growth to Adult is pay-to-win in a PvP survival game. Final call with `roblox-experience-designer` and `game-economy-designer`.
9. **Premium (Robux) species.** Options: (a) none at launch, (b) sidegrades with the same stat budget as a coin species of the same size, (c) stronger premium species. **Recommendation: (b)**; (c) breaks the brief's no-pay-to-win rule.
10. **Name display.** Options: (a) usernames above everyone, (b) species + stage for everyone, usernames only for group members and friends. **Recommendation: (b)**: better immersion, less targeted harassment, and night/fog stealth works.
11. **Gallimimus diet.** Options: (a) omnivore (plants, fish, eggs, small carcasses), (b) pure herbivore. **Recommendation: (a)**: gives one species a flexible "survivor" playstyle at little cost.
12. **Blood style.** Options: (a) stylized red cube drips with a "Reduced effects" setting, (b) no blood at all. **Recommendation: (a)**.
13. **Game title** (final call belongs to `roblox-experience-designer`). Options: (a) "Brickjaw Island", (b) "Primal Blocks", (c) "Fossil Frontier". **Recommendation: (a)**: short, blocky, dinosaur, and no clash with *The Isle* or *Jurassic Blocky* names (check the Roblox catalogue for clashes before committing).
