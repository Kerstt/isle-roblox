# Master plan (merged from docs 01–06)

**Status: APPROVED by the user on 2026-11-26.** Decisions: checkpoint deaths (D2), a 2,600-stud island (D3), working title **Brickjaw Island** pending a name search (D4), and the MVP and defaults as written (D1).

This file is the single source of truth. Where the detail docs disagree, **this file wins** (section 3 lists each conflict and how it was settled). The detail docs:

| Doc | Agent | What's in it |
|---|---|---|
| [00-concept](00-concept.md) | the user | The original pitch |
| [01-game-design](01-game-design.md) | game-designer | Species and stats, growth, needs, combat, social, world rules |
| [02-experience-and-monetization](02-experience-and-monetization.md) | roblox-experience-designer | First 2 minutes, mobile UI, retention, shop UX, products, analytics, safety |
| [03-world-and-map](03-world-and-map.md) | game-level-designer | Island layout, biomes, water, spawns, build style, MVP slice |
| [04-art-and-tech-art](04-art-and-tech-art.md) | game-technical-artist | Art style, rig standard, procedural animation, cosmetics, VFX, budgets |
| [05-technical-architecture](05-technical-architecture.md) | roblox-systems-scripter | Modules, player-as-dino, remotes, data, AI, testing, MVP tickets |
| [06-economy](06-economy.md) (+ [sim](06-economy-sim.py)) | game-economy-designer | Fossil Coins sources and sinks, prices, progression sim, abuse rules |

## 1. The game in one paragraph

A blocky, multiplayer dinosaur survival game for 30 players per server. You hatch as a baby dinosaur in a protected nursery grove, drink and eat to stay alive, and grow over 35–60 minutes of play into an adult. You hunt or graze, form packs and herds, avoid or fight bigger dinos, and keep your grown dino between sessions. Death costs growth, not coins. You earn Fossil Coins by surviving and growing, and spend them on new species and cosmetics. Robux buys looks and convenience, never strength.

## 2. Pillars (the rules every feature is checked against)

1. **Survival tension, fair for kids.** Danger is real, but there are nurseries, spawn shields, a beginner shield and no reward for killing hatchlings.
2. **Original and blocky.** Brick-built dinos from a 0.5-stud grid, one signature feature per species, nothing copied from other games.
3. **Server-authoritative.** Health, damage, needs, growth, coins and inventory are decided on the server only.
4. **No pay-to-win.** No paid growth, revive, stats or random paid items. Coins never buy combat power beyond sidegrade species.
5. **Built by Claude end to end.** Script-built rigs, procedural animation and script-generated terrain. Your hands-on work is approvals, play-tests and a few uploads.

## 3. Conflicts between the docs, and how they're settled

| Topic | Disagreement | Settled as | Why |
|---|---|---|---|
| Death penalty | 01: drop to a growth checkpoint. 02/05: reset the slot to hatchling | **Checkpoint** (user decision D2) | The economy sim showed 14 % more income and better retention, and one death costs only 10–35 coins either way. Doc 05's schema and ticket T13 change from "clear slot" to "checkpoint". |
| Growth saving | 01: growth saved for every species. 02/05: 3 saved slots, +3 with a pass | **3 slots (+3 pass)**, each slot keeps its dino's growth | Otherwise the slots pass sells nothing (doc 06). |
| Paid growth boost | 01: capped x1.25. 02: none | **None** | In the sim, a boost raised time spent at Adult by 5–9 points: real PvP power. |
| Premium species | 01: Robux sidegrades. 02: all earnable with coins | **All earnable with coins.** Robux shortcut for Medium species only (99–199 R$) | It's never Robux-only, so it isn't pay-to-win. |
| 2x Coins pass | 02: doubles everything | **Doubles gameplay income only** (not milestones or daily rewards) | It works out about 31 % faster, so coins still matter for free players. |
| Spawn shield | 01/03: 60 s. 02: 90 s | **60 s**, plus nursery zones plus a 30-minute beginner shield on growth loss | Nurseries already protect new players. |
| Map size | 01: about 2,000–2,500 studs, water every 250. 03: 3,500 island, water within 600 | **2,600-stud island on a 3,072 map** (doc 03's option a; user decision D3). Doc 03's grid and coordinates must be rescaled before T07. | Thirst lasts 9–11 min, so either water spacing works. A denser map means more encounters. It can grow later. |
| Parts per player dino | 04: 25–70 visual parts. 05: at most 25 | **Small ≤ 35, Medium ≤ 45, Large ≤ 60 visual parts**, verified in the T14 load test | Visual parts don't collide and have no mass. The real cost is replication, which T14 measures on a phone. |
| Herds in MVP | 02: in MVP. Concept/05: after | **First feature after the MVP** | Keeps the MVP testable by one person. |
| Title | 01/04: Brickjaw Island. 02: Primal Blocks. 03: Cinderfern Island | **Brickjaw Island** (user decision D4) | Still needs a name search on Roblox before launch. |

## 4. Defaults accepted unless you object

The detail docs give the reasoning for each.
- **Server and roster:** 30 players per server (playtests at 12–16). 8 launch species: Velociraptor, Gallimimus and Pachycephalosaurus are free starters; Parasaurolophus 750, Ceratosaurus 1,000, Baryonyx 1,500, Triceratops 2,750 and Tyrannosaurus 4,000 coins. Species caps apply (rex at most 10 % of the server).
- **Growth:** 4 stages. Adult takes **35 / 45 / 60 minutes** (small / medium / large). Growth pauses while starving, dehydrated or AFK.
- **Dino tech:** Humanoid rig as the player's character, script-built from Parts with a standard joint layout, animated in code, and scaled per stage with `Model:ScaleTo`. Dinos pass through each other in the MVP, so nobody can fling another dino.
- **Combat and anti-cheat:** the server decides hits with box math and up to 200 ms lag rewind. Anti-cheat only logs during week-1 playtests, then rubber-bands players back.
- **World:** stepped Part terraces with Terrain water, smooth (no studs). Readable night, not pitch black. Stylised blood cubes with a "reduced effects" setting, aiming for the **Mild** maturity label.
- **Data and libraries:** ProfileStore copied into the repo (no Wally), a mock data store in Studio, and a small test kit run in Studio and in CI (Lune).
- **Money:** Fossil Coins only (no second currency), no paid random items, no coin packs at launch. Products: VIP 299, 2x Coins 349, +3 Slots 199, cosmetics 75–599, Private Servers 199/month. **No products in the MVP**, only the data fields.
- **Before the monetization phase:** check Roblox's current rules: Creator Rewards (the replacement for Premium Payouts), age-based chat, and the paid-random-item rules.

## 5. MVP = Prototype + Core loop

Goal: one Velociraptor on a 1,280 × 1,280 slice (forest, plains, lake, river, one nursery), fully playable and saving.

| # | Ticket (doc 05 §10) | Lead agent | Done when |
|---|---|---|---|
| T01 | Foundations: Signal, Net (remotes from code), Guard/RateLimiter, TestKit + Lune CI step | roblox-systems-scripter | Tests run in Studio and CI |
| T02 | Spike: script-built raptor rig, ScaleTo through 4 stages, touch controls, camera | game-technical-artist + systems-scripter | Raptor walks on PC and the phone emulator at all 4 sizes |
| T03 | DataService: ProfileStore, schema v1 (slots, checkpoints), migrations | roblox-systems-scripter | Join/leave/rejoin keeps data |
| T04 | Species data, DinoService (spawn, death, respawn), minimal spawn menu | roblox-systems-scripter | Spawn, die, respawn |
| T05 | Input, character and camera controllers | roblox-systems-scripter | Playable on PC and phone |
| T06 | Needs + stamina + HUD | game-designer spec, systems-scripter | Bars drain and refill, and starving kills |
| T07 | MVP map slice + water and plant feeding | game-level-designer + systems-scripter | Drink and graze work, and prompts are refused out of range |
| T08 | Combat: bite, cooldowns, lag rewind, hit effects | systems-scripter + technical-artist | Two-client bite works at 150 ms latency |
| T09 | Anti-cheat (speed, teleport, air time), log-only | roblox-systems-scripter | Detects test exploits, with no false positives in 20 min |
| T10 | Growth stages + stat curves | game-designer + systems-scripter | Hatchling → Adult with correct size and stats |
| T11 | Carcasses | roblox-systems-scripter | Kill → carcass → eat → gone |
| T12 | AI prey (one species), sleeping when no one is near | systems-scripter + level-designer | 40 NPCs within budget |
| T13 | Slot persistence, checkpoint death, coins for survival and growth | systems-scripter + economy-designer | Grow, leave, rejoin: same growth |
| T14 | Exploit + performance pass on a phone | code-reviewer → qa-tester | All budgets met, no malformed payload accepted |

Every ticket goes through **code-reviewer** before it's committed, and **qa-tester** checks it in Studio.

## 6. After the MVP (in order)

1. Herds and packs (chat, pings, group slots)
2. Species 2–8 and the full island with day/night and weather
3. Nests and eggs
4. Shop + inventory + cosmetics (coins first)
5. Onboarding polish ("Stalker" scripted predator, Survival Journal)
6. Monetization (after the policy check)
7. Admin and mod tools (required before launch)
8. Launch, then leaderboards, private servers and events

## 7. Decisions for the user

| # | Decision | Recommended |
|---|---|---|
| D1 | Approve the MVP (section 5) and the defaults (section 4) | Yes |
| D2 | Death rule: checkpoint vs back to hatchling | Checkpoint |
| D3 | Island size: 2,600 vs 3,500 studs | 2,600, grow later |
| D4 | Game title: Brickjaw Island / Primal Blocks / Cinderfern Island / your own | Brickjaw Island, pending a name search |
