# 06 - Economy: Fossil Coins

| | |
|---|---|
| Owner | game-economy-designer |
| Version | 0.1 (first draft, 2026-11-26) |
| Reads with | `AGENT_BRIEF.md`, `00-concept.md`, `01-game-design.md` (species, growth, death, kills), `02-experience-and-monetization.md` (products, guardrails), `05-technical-architecture.md` (data schema, `addCoins`) |
| Simulation | `docs/06-economy-sim.py` (Python 3, no packages). Run `python -I docs/06-economy-sim.py`. Flags: `--rule reset`, `--eff`, `--hazard`, `--growth`, `--only` |
| Hand-offs | Code: `roblox-systems-scripter` (EconomyService, config modules). Shop UI and product setup: `roblox-experience-designer`. Growth, death and kill rules: `game-designer`. |

Every number is a first-pass value, tuned by simulation, not by playtest. They all live in the tuning table (section 9), which should become `src/shared/Economy.luau` plus a server-only `src/modules/EconomyService/AbuseRules.luau`.

---

## 0. Summary

| Question | Answer |
|---|---|
| Currencies | **One:** Fossil Coins, earned only (no coin packs at launch). Robux buys passes and cosmetics directly. |
| Main faucet | Coins per minute alive and active (about half of all income, most of the gameplay part), so surviving and staying big pays most |
| Main sinks | 5 species (10,000 coins total), then a coin cosmetic catalog plus a weekly rotation sized to match a regular player's weekly income |
| Free pacing (simulated) | First new species in session 1–2; all 8 species in about **16 days at 60 min/day**, 27 days at 30 min/day, 10 days at 120 min/day |
| 2x Coins pass | Cuts the 60 min/day timeline from 16 to 11 days (31 % faster, not 50 %), because milestones, login and daily goals are not doubled |
| Power rule | Coins buy species (sidegrades by design) and cosmetics only. Large species (Triceratops, Tyrannosaurus) are **coin-only**, never sold for Robux. Nothing priced in coins or Robux changes growth, stats or survival |
| Death | Coins are never lost. One death costs only 10–35 coins of income (about 2–7 minutes of play), so coins never make death feel worse; growth carries the sting |

---

## 1. Currency spec

### Currency: Fossil Coins

| Field | Value |
|---|---|
| Purpose | Turns playtime into choices: "unlock the next species or the cosmetic I want now". Measures long-term progress without touching combat power |
| Type | Soft currency, earned only. Not tradeable (no trading in v1) |
| Sources | Section 2: survival time, stage-ups, species milestones, kills, meals, Daily Forage, Survival Journal, Daily Instincts, nest parent reward |
| Sinks | Section 3: species unlocks, coin cosmetics (skins, accessories, effects, emotes, nest styles), name reroll |
| Faucet/drain target | 1.3 in weeks 1–3 (players save for species), 0.9–1.0 after all species are owned (weekly rotation absorbs income) |
| Cap | None for players. Server sanity clamp 10,000,000 and an alert on any single grant over 1,000 that is not a milestone |
| Conversion | None. Coins never convert to or from Robux at launch |
| Exploit surface | AFK and macro farming, kill trading with alts or rival packs, nest-hatch farming, private-server farming. Section 7 |

### Flow map
```
[Play: alive + active] --per minute--> Coins --buy--> [Species]  --enables--> new growth climb --> milestone coins
[Stage-ups, first-time milestones] ------^              \--buy--> [Coin cosmetics, weekly rotation, nest styles]
[Kills (size-scaled), meals] ------------^
[Daily Forage, Journal, Daily Instincts]-^
[Robux] --buy--> [Passes, Robux cosmetics, Medium species shortcut]   (never coins, never Large species, never growth)
Rule: every earn path ends in a species or cosmetic purchase; no coin path leads to stats, growth or survival.
```

---

## 2. Sources

### 2.1 Earning state (applies to survival coins and meals)
A player earns per-minute coins only while all of these are true. It is the same test as growth in doc 01 section 3.2, plus a stricter AFK check.

| Condition | Value |
|---|---|
| Alive, spawned, not in a menu | – |
| Hunger and thirst | both ≥ 25 % (doc 01 growth pause threshold) |
| Active | moved ≥ 8 studs or used an action in the last 180 s (doc 01's growth AFK is 5 min; coins use 3 min) |
| Resting | continuous rest earns for the first 180 s, then pauses until the player moves (normal healing takes about 100 s) |
| Adults | earn even though they no longer grow |

### 2.2 Gameplay sources (doubled by the 2x pass)

| Source | Rule | Coins | MVP? |
|---|---|---|---|
| **Survival time** | Per earning minute, by current stage | Hatchling 2, Juvenile 3, Sub-adult 4, Adult 5, **Elder 6** (Adult alive ≥ 60 min in this life) | MVP |
| Survival daily soft cap | Earning minutes per UTC day | 0–180 min full; 180–360 min x0.5; over 360 min x0.25 | MVP |
| **Stage-up (repeatable)** | Paid when growth crosses a stage threshold **above the slot's high-water mark** (so never re-earned by dying and regrowing under the checkpoint rule) | Juvenile 5, Sub-adult 10, Adult 25, x size factor (Small 1.0, Medium 1.3, Large 1.7) | MVP |
| **Kill** | See 2.3 | 0–204 per kill before the share split | Later (with groups) |
| **Meal** | Hunger goes from below 50 % to ≥ 90 % in one feeding. Carnivores: carcass, fish or eggs. Herbivores: plants. Omnivore: either | 5, cooldown 5 min (max 12/h) | MVP |
| Nest parent reward | A hatchling born from your nest reaches Juvenile | 15 each; max 5 per nest, 75 per UTC day | Later (with nests) |

Why meals instead of "per carcass": carcass supply is uneven (a rex carcass feeds a pack for minutes) and herbivores never eat carcasses. A diet-neutral "full meal" pays carnivores for carcasses and herbivores for grazing at the same rate, and the cooldown stops nibble-farming.

### 2.3 Kill rewards
```
killCoins = round( KillBase[victimStage] x SizeFactor[victimSizeClass] x RatioFactor x damageShare )
r          = victimMass / killerMass        (current masses at the moment of the kill)
RatioFactor = 0                    if victim is a Hatchling, or r < 0.15  (doc 01 section 8, doc 02 section 1.3)
            = sqrt( min(r, 4) )    otherwise   (0.39 at the 15 % threshold, 1.0 at equal size, max 2.0 for punching up)
KillBase    = Juvenile 20, Sub-adult 35, Adult 60
damageShare = share of damage dealt in the last 15 s (doc 01 kill credit); contributors under 10 % get 0
```

| Example (adults unless stated) | r | Coins |
|---|---|---|
| Velociraptor kills Velociraptor | 1.0 | 60 |
| Velociraptor kills a Juvenile Velociraptor | 0.20 | 9 |
| Ceratosaurus kills Velociraptor | 0.20 | 27 |
| Tyrannosaurus kills Velociraptor or Ceratosaurus | 0.03 / 0.13 | **0** (much smaller) |
| Tyrannosaurus kills Triceratops | 0.86 | 94 |
| 4 Velociraptors kill a Tyrannosaurus | 39 (capped 4) | 204 shared, about 51 each |
| Anyone kills any Hatchling | – | **0** |
| AI wildlife | – | 0 (the meat and the meal reward are the payoff; stops NPC farming) |

Kill coins are also bound by the anti-abuse rules in section 7 (30-minute pair cooldown, 400 base coins per day, no coins in private servers).

### 2.4 Fixed rewards (never multiplied by the 2x pass)

| Source | Rule | Coins | MVP? |
|---|---|---|---|
| **Species milestones** (first-time, once per species per account) | First Juvenile / Sub-adult / Adult / Elder with that species | Small 25 / 50 / 150 / 200 (425 total); Medium 33 / 65 / 195 / 260 (553); Large 43 / 85 / 255 / 340 (723). All 8 species: 4,380 | MVP (Elder later) |
| Fossil Record | Every launch species reaches Adult at least once | 1,000 + "Paleontologist" title (one-time) | Later |
| **Survival Journal** (doc 02 section 1.2, once per account) | Drink 10, Eat 10, Escape a threat 25, Rest to heal 10, Reach Juvenile 25, Join or make a herd 25, Survive a night 25, Find a nest site 20 | 150 total | Later (with onboarding) |
| First nest | Lay your first nest / first nest-born hatchling reaches Juvenile | 100 / 50 (one-time) | Later |
| **Daily Forage** (doc 02 section 2.2; advances per login day, never resets) | Day 1–7 | 50, 75, *effect*, 100, 150, 200, *calendar skin* = 575 coins + 2 cosmetics per cycle | Later (RewardService, first after MVP) |
| VIP on Forage | Coin days only | +25 % (+144 per cycle) | Monetization |
| **Daily Instincts** (doc 02 section 2.3) | 3 per day, 5–15 min each, none require killing players | 25 each; +150 for 15 in one week | Later (week 6) |

Milestones double as a rebate: buying Ceratosaurus for 1,000 and growing it to Elder pays back 553. That makes "try the new species" the best move after every purchase, which is the loop we want.

### 2.5 Multipliers

| Multiplier | Applies to | Value | Stacking |
|---|---|---|---|
| 2x Fossil Coins pass | Gameplay sources only (2.2) | x2 | Additive with Premium: 1 + 1 + 0.1 = **x2.1 max** |
| Roblox Premium | Gameplay sources only | +10 % | Additive |
| VIP pass | Daily Forage coin days only | +25 % | – |
| Private server (default settings) | All except kills | x1 (kills x0) | – |
| Caps | Survival soft cap and the kill cap count **base** coins, before multipliers | – | – |

Change from doc 02 section 4.3: doc 02 lists Instincts under 2x. I recommend that all fixed goals (milestones, Journal, Forage, Instincts) stay equal for everyone; only per-minute and per-event gameplay coins are doubled. Two kids doing the same daily goal should get the same reward.

### 2.6 Income check (simulated, 60 min/day free player)

| Phase | Coins per hour of play | Share from gameplay sources |
|---|---|---|
| Week 1 (milestones flowing) | about 700 | about 45 % |
| Days 15–30 | about 530 | about 60 % (311/h); rest is Forage, Instincts, late milestones |

---

## 3. Sinks

### 3.1 Species

| Species | Size | Diet | Price | Earn time at 60 min/day (median) | Robux shortcut |
|---|---|---|---|---|---|
| Velociraptor | Small | Carnivore | **Free starter** | – | – |
| Gallimimus | Small | Omnivore | **Free starter** | – | – |
| Pachycephalosaurus | Small | Herbivore | **Free starter** | – | – |
| Parasaurolophus | Medium | Herbivore | 750 | day 2 | 99 R$ (later) |
| Ceratosaurus | Medium | Carnivore | 1,000 | day 3 | 149 R$ (later) |
| Baryonyx | Medium | Carnivore | 1,500 | day 5 | 199 R$ (later) |
| Triceratops | Large | Herbivore | 2,750 | day 9 | **Not sold** |
| Tyrannosaurus | Large | Carnivore | 4,000 | day 16 | **Not sold** |
| **Total** | | | **10,000** | | |

Rationale:
- The cheapest unlock is a herbivore on purpose. Servers skew carnivore (doc 01 section 9.3 has a diet-balance bonus for that reason); a cheap, social herbivore pulls the second species pick toward the herd side.
- Price follows size class and growth time, not strength (every species is balanced as a sidegrade in doc 01 section 2.4). Large species already pay with 60-minute growth, species caps and higher food needs.
- Large species are coin-only. The apex should mean "this player put in the time", and keeping Robux away from the biggest bodies removes the most visible pay-to-win complaint. This is stricter than doc 02's "earnable in about 6 hours" test, which Tyrannosaurus would fail anyway (about 7.5 hours of all-source income).

### 3.2 Cosmetics

| Tier | Coin price | What | Gate |
|---|---|---|---|
| Basic | 300 | Colorway skin, footstep dust colour, simple emote | – |
| **Standard (mid-price)** | **800** | Patterned skin (stripes, camo), accessory (scar, spikes), trail effect | – |
| Deluxe | 1,800 | Full themed skin (lava, arctic), animated effect, special roar colour | – |
| Prestige | 4,000 | Showpiece skin or aura for one species | **Requires** Elder with that species (cannot be bought early by anyone) |
| Nest styles | 600 / 1,200 / 1,800 | Nest ring and egg shell patterns | Later (with nests) |
| Name reroll | 100 (first one free) | New generated dino name (doc 02 Decision 9) | – |

| Channel | Items |
|---|---|
| **Coins** | All base catalog skins and effects (target per species at launch: 1 Basic, 1 Standard, 1 Deluxe, 1 Prestige; plus 6 universal effects and 4 emotes), 4 of 6 weekly Featured slots, nest styles |
| **Robux only** | 2 of 6 weekly Featured slots, bundles, VIP set, Founders Pack, Emote Pack, the "Crystal" premium skin set (doc 02's mythic dino turned into skins), name tag colour |
| **Earned only** (no coins, no Robux) | Daily Forage day 3 and day 7 items, Elder overlay (doc 01), Fossil Record title, Herd Bond, Journal-complete badge |

Rule: at least 60 % of all cosmetic items must be obtainable without Robux (coins or earned). Status items (Elder, Prestige, Fossil Record) can only be earned, so free players always have something a spender cannot buy.

Weekly sink sizing: a regular player earns about 3,700 coins per week after owning every species. The 4 coin Featured slots should total about the same (for example 1 Basic + 2 Standard + 1 Deluxe = 3,700), so the rotation absorbs income without making anyone wait more than a week.

### 3.3 Nest building
Building a nest stays **free**. It is a gameplay and social mechanic (doc 01 section 6.3); a fee would tax the feature that pulls new players into groups and would turn coins into a gameplay gate. Nests are a sink only through nest styles (3.2).

### 3.4 Never priced in coins or Robux

| Banned item | Why |
|---|---|
| Growth boosts, instant growth, revive, checkpoint protection | Buys PvP power and undoes deaths (doc 02 section 4.2) |
| Extra eggs per nest, nest respawn | More bodies in fights (doc 02) |
| Stat mutations or mutation rerolls | Power plus paid randomness |
| Stamina, health or food consumables | Survival power |
| Skipping slot-switch cooldowns or species caps | Escapes fights, breaks apex limits |
| Skill trees or stat upgrades | Widens veteran vs new player power gaps |

---

## 4. Progression simulation

### 4.1 Method
`docs/06-economy-sim.py`: Monte Carlo, 200 runs per profile, 60 days, 1-minute ticks. Each run grows dinosaurs with doc 01's growth times (35 / 45 / 60 min), dies at a per-stage rate, earns from every source in section 2 and buys species cheapest-first as soon as it can.

| Assumption | Value | Why |
|---|---|---|
| Earning efficiency | 85 % of minutes earn and grow | Time drinking with low bars, walking, menus |
| Death rate (per earning minute) | Hatchling 1/30, Juvenile 1/40, Sub-adult 1/50, Adult 1/70 | Typical lives of 30–70 min; hatchlings die often but lose nothing |
| Death rule | Doc 01 checkpoints (default); `--rule reset` for doc 02/05 | Conflict 6b |
| Eligible kills per hour | Juvenile 0.4, Sub-adult 0.8, Adult 1.2 (carnivore); herbivore x0.35, omnivore x0.25 | Most fights are flights or AI hunts |
| Meals | One every 8 earning minutes | Hunger bars last 10–20 min |
| Species played | The newest species without an Adult milestone (new toy first) | |
| Daily goals | 2 Instincts/day at 30 min, 3 at 60 and 120 min | |
| Not modelled | Fossil Record, first nest, nest parent reward, VIP, Premium | Small; results are slightly conservative |

### 4.2 Results (checkpoint rule; median day, P90 day in brackets)

| Profile | Parasaurolophus (750) | Ceratosaurus (1,000) | Baryonyx (1,500) | Triceratops (2,750) | Tyrannosaurus (4,000) | Mid cosmetic (800) from zero | All species + mid cosmetic | Coins/h week 1 | Coins/h days 15–30 (all / gameplay) | Coins/day days 15–30 | Time as Adult |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Free 30 min/day | 2 (2) | 5 (5) | 8 (9) | 16 (17) | 27 (29) | 2 (2) | 30 (31) | 854 | 681 / 283 | 341 | 57 % |
| **Free 60 min/day** | **2 (2)** | **3 (3)** | **5 (5)** | **9 (10)** | **16 (17)** | **2 (2)** | **18 (19)** | 703 | 531 / 311 | 531 | 68 % |
| Free 120 min/day | 1 (1) | 2 (2) | 3 (3) | 6 (6) | 10 (11) | 1 (1) | 11 (11) | 561 | 402 / 315 | 804 | 73 % |
| 2x pass 30 min/day | 2 (2) | 4 (4) | 6 (7) | 12 (12) | 20 (20) | 2 (2) | 21 (23) | 1,071 | 978 / 592 | 489 | 57 % |
| 2x pass 60 min/day | 1 (1) | 2 (2) | 4 (4) | 7 (7) | 11 (12) | 1 (1) | 12 (13) | 961 | 814 / 633 | 814 | 67 % |
| 2x pass 120 min/day | 1 (1) | 1 (2) | 2 (2) | 4 (4) | 6 (7) | 1 (1) | 7 (7) | 849 | 717 / 630 | 1,433 | 72 % |

"Coins/h" for 30 min/day looks high because Forage and Instincts are spread over fewer minutes. "Time as Adult" is the share of earning minutes spent at Adult size over 60 days; the 2x pass does not change it, which is the point: Robux changes coin speed, never body size.

### 4.3 Readout against targets

| Target | Result | Verdict |
|---|---|---|
| First new species in session 1–2 | Day 2 at 30 and 60 min/day, day 1 at 120 min/day | Met |
| All launch species in about 2–3 weeks (regular free player) | 16 days at 60 min/day (P90 17) | Met |
| Casual player not locked out | 27 days at 30 min/day | Acceptable (4 weeks); watch D30 retention of this cohort |
| Mid cosmetic reachable early | Day 1–2 if saved for instead of a species | Met; the player chooses species or cosmetic, which is the intended decision |
| 2x pass is not "coins pointless for free players" | 60 min/day: 16 → 11 days (31 % faster); 30 min/day: 27 → 20 days | Met; a free player who plays 2x as long (120 min/day, 10 days) beats a passholder at 60 min/day |
| Large species earnable by everyone | Tyrannosaurus day 10–27 depending on play time | Met |

### 4.4 Sensitivity
| Scenario (Free 60 min/day) | Tyrannosaurus (last unlock) | All species + mid cosmetic | Gameplay coins/h |
|---|---|---|---|
| Baseline | day 16 | day 18 | 311 |
| Pessimistic: 70 % earning efficiency, deaths x1.5 | day 19 | day 21 | 240 |
| Reset-to-hatchling death rule | day 18 | day 20 | 267 |
| Paid growth boost x1.25 (checkpoints) | day 16 | day 17 | 313 |
| Paid growth boost x1.25 (reset rule) | day 17 | day 18 | 280 |

Even the pessimistic case stays inside 3 weeks. Real death and kill rates from playtests replace these assumptions before prices ship.

---

## 5. Robux pricing (doc 02 products checked against coin values)

Reference: a regular free player earns about 530 coins per hour of play (all sources, days 15–30). A Medium species shortcut at about 7 coins per Robux keeps Robux and play time roughly consistent.

| Product | Doc 02 price | My price | Coin check | Verdict |
|---|---|---|---|---|
| VIP (pass) | 299 R$ | 299 R$ | +25 % Forage = about +20 coins/day (4 % of a regular player's income) | Keep. The coin perk is symbolic; status is the product |
| 2x Fossil Coins (pass) | 349 R$ | 349 R$ | +about 310 coins/day at 60 min/day; speeds all-species from 16 to 11 days | Keep, with the 2.5 rules (gameplay only, caps on base) |
| Extra Dino Slots (pass) | 199 R$ | 199 R$ | No coin effect: milestones are per species per account, so more slots never earn more | Keep |
| Founders Pack (pass) | 249 R$ | 249 R$ | Cosmetic only | Keep |
| Featured cosmetic (product) | 75–299 R$ | 75 / 149 / 249 / 299 by tier | Robux items are their own catalog; never the same item also sold for coins | Keep |
| Cosmetic bundle (product) | 399–599 R$ | 399 / 599 R$ | – | Keep |
| Species shortcut (product) | 149–249 R$ | **Medium only: 99 / 149 / 199 R$** (Parasaurolophus / Ceratosaurus / Baryonyx) | 7.6 / 6.7 / 7.5 coins per R$; each is 1.4–3 hours of regular play | Keep, later; **no Large species** |
| Coin packs S/M/L (product) | 99 / 249 / 499 R$ | **Not at launch** | At doc 02's 10–12 coins/R$, a Tyrannosaurus would cost about 400 R$ through packs, which bypasses the coin-only rule for Large species | Drop for launch (Decision 5) |
| Season Track (pass, later) | 399 R$ | 399 R$ | Premium track may hold at most 1,500 coins per season (about 3 days of regular play) so it is not a coin pack in disguise | Keep, later |
| Private server | 199 R$/month | 199 R$/month | Progression saves only with default settings (doc 02); kill coins always 0 | Keep, later |
| Premium perk | +10 % gameplay coins | +10 % | Additive with 2x (max x2.1) | Keep |

---

## 6. Conflicts between docs (economy view)

### 6a. Paid growth boost: doc 01 (capped x1.25) vs doc 02 (none)
**Recommend doc 02: no paid growth boost of any size.**

| Evidence | Detail |
|---|---|
| It buys PvP power | Simulated time as Adult (60 min/day): 68 % → 73 % under checkpoints, **31 % → 40 %** under the reset rule (+29 %). Each life reaches Adult 7 min sooner (Small) to 12 min sooner (Large), so payers spend more of every fight at full size. That is a stat advantage in a PvP game, exactly what doc 02 rules out |
| It hits the coin economy too | Faster growth means more minutes at the Adult survival rate and faster milestones, so a growth boost is also a hidden coin boost stacked on 2x |
| It crowds out free bonuses | Doc 01 caps combined growth bonuses at x1.5; a paid x1.25 uses most of the room meant for nest parent care (x1.2) and diet balance (x1.2), which are the social reasons to group up |
| Replacement | Keep the free growth helpers (nest care, diet balance, resting with the herd). Sell looks instead |

### 6b. Death: doc 01 checkpoints vs doc 02/05 reset to hatchling

| Aspect | Checkpoints (doc 01) | Reset to hatchling (doc 02/05) |
|---|---|---|
| Gameplay coins/h (days 15–30, 60 min/day) | 311 | 268 (−14 %) |
| Days to all species (60 min/day) | 16 | 18 |
| Time as Adult (60 min/day) | 68 % of earning minutes | 31 % |
| Elder milestones (60 min alive as Adult) | Reachable: deaths do not reset Adult status | Rare for Large species (needs 60 + 60 min in one life) |
| Coin cost of one death | About 10–20 coins (regrow 27.5 % at the Sub-adult rate, plus the respawn minute) | About 20–35 coins (regrow from 0 at lower rates, partly refunded by repeat stage-ups) |
| Can dying ever earn more? | No: stage-ups follow the slot high-water mark | No, by tuning: a full regrow earns about 4.3 coins/min, below 4.8 for staying alive as an Adult and 5.6 as an Elder |
| Kill farming | Victim respawns at 72.5 % and can be killed again for coins, so the pair cooldown and daily cap (section 7) are required | Victim respawns as a Hatchling and is worth 0, so farming self-limits |
| Retention | Gentler; keeps players in their grown dino; better for a 9–15 audience; Extra Dino Slots is about variety | Harsher; slots become insurance (stronger pass value, which risks feeling like paying to protect progress) |

**Recommendation (economy view): checkpoints (doc 01), with stage-ups paid by slot high-water mark and the section 7 kill rules.** Coins work under both rules: the economy is tuned so that death costs growth, not coins. If the reset rule is chosen, lower Triceratops to 2,500 and Tyrannosaurus to 3,600 to keep the 60 min/day timeline near 16 days. Note for the orchestrator: doc 05's schema clears the slot on death (`slots[i] = false`); checkpoints need the slot to survive death with growth set back.

### 6c. 2x Coins and Extra Dino Slots passes
| Pass | Verdict | Condition |
|---|---|---|
| 2x Fossil Coins | **Fine** | Gameplay sources only; fixed goals not doubled; caps on base coins; species timeline 31 % faster, not 50 % |
| Extra Dino Slots | **Fine** | Coins are not affected (milestones are per species, not per slot). One dependency: doc 01 says every owned species saves its own growth, which would leave nothing to sell. Pick the doc 02/05 slot model (3 free, +3 pass) and treat a slot as "one saved dino" |

---

## 7. Inflation and abuse

| Risk | How it works | Counter-rules | Remaining worst case |
|---|---|---|---|
| AFK farming | Stand still or rest forever | Earning state (2.1): 3-min activity check, rest pays only 180 s, needs ≥ 25 % (an AFK dino starves) | 0 coins after 3 min |
| Macro farming (auto-walk) | Script walks in circles | Survival soft cap (x0.5 after 3 h, x0.25 after 6 h per day); needs still drain, so the macro starves without eating; flag accounts with > 6 earning hours/day for 3 days | About 1,600 base coins in a 10-hour day, then flagged for review |
| Kill trading with alts | Alt walks into main, main kills it, repeat | 30-min cooldown per killer-victim pair (either direction); 0 coins if the victim account has < 60 min total playtime; daily kill cap 400 base coins; hatchling kills 0 | 400 base coins/day (about 1.3 h of play) |
| Pack kill-trading | Two packs take turns feeding each other kills | Pair cooldown; 0 coins if killer and victim shared a group in the last 15 min (friendly fire is off in groups, so leaving to trade is the only path); contributors under 10 % damage get 0; daily cap | Same 400/day cap per player |
| Bullying small players | Adult farms juveniles or hatchlings | Hatchling 0; r < 0.15 gives 0; RatioFactor shrinks rewards for smaller victims (a Juvenile Velociraptor is worth 9 to an adult raptor) | Small; danger stays real, the reward does not |
| Suicide loops | Die and regrow for stage coins | Stage-ups by slot high-water mark; milestones once per species per account; regrowing earns less per minute than staying alive | None |
| Slot release loops | Release a slot, re-hatch the same species, re-earn stage-ups | Only the small repeat stage-up (40–68) is re-earned; regrowing earns about 4.3/min vs 4.8 staying alive | None (not profitable) |
| Nest-hatch farming | Alts hatch from your nest to pay parent rewards | 75 coins/day cap; hatchling must reach Juvenile (5+ min of the alt's time) | 75/day |
| Private-server farming | Safe server with alts | Kill coins 0 in private servers; saves only with default settings (doc 02); survival cap still applies | Normal survival income |
| Duplication / client tampering | Fake remote calls | Coins change only server-side through `DataService.addCoins(player, amount, reason)` (doc 05); no remote grants coins; every grant logged with an `AnalyticsService` economy event and ending balance | – |
| Long-term inflation | Veterans hoard coins after buying everything | Weekly rotation sized to income; Prestige items (4,000); new species every 1–2 months at 2,000–4,000; telemetry alarms (section 8) | Add sinks, never cut sources |

No trading in v1 means alts can never pass coins to a main account directly; kills and nest rewards are the only value that moves between players, and both are capped.

---

## 8. Economy health telemetry
Logged from day one with doc 02's `LogEconomyEvent` (SKUs: `survive_time`, `stage_up`, `milestone_<species>_<stage>`, `kill`, `meal`, `nest_parent`, `daily_forage_d1..d7`, `journal_<id>`, `instinct`, `species_<id>`, `skin_<id>`...).

| Metric | Healthy | Trigger for a balance review |
|---|---|---|
| Gameplay coins per hour, median | 280–350 | Outside 220–420 for 7 days |
| Gameplay coins per hour, P99 | < 700 (2x pass max ~650) | > 900: investigate exploit |
| Days to first purchased species, median | ≤ 2 | > 3 |
| Share of D14 players owning all species (60+ min/day cohort) | 40–60 % | < 25 % (prices too high) or > 80 % (too low) |
| Median wallet, players 30+ days old | < 8,000 | > 15,000 for 2 weeks: add sinks |
| Faucet/drain ratio, 7-day rolling, players with all species | 0.9–1.1 | > 1.3 for 2 weeks |
| Kill coins share of gameplay income | 8–15 % | > 25 % (farming or too generous) |
| Same killer-victim pair, 3+ kills in 24 h | Rare | Any account with > 20 % of kills on 1–2 victims: flag |
| Sink participation per cosmetic tier | > 20 % of eligible players | < 10 %: reprice or redesign |

---

## 9. Tuning table (every number; becomes config)

Public values (UI shows them) go in `src/shared/Economy.luau`. Anti-abuse thresholds go in `src/modules/EconomyService/AbuseRules.luau` (server-only, so exploiters cannot read them).

| Key | Value | Module |
|---|---|---|
| `Survival.PerMinute` | Hatchling 2, Juvenile 3, SubAdult 4, Adult 5, Elder 6 | Economy |
| `Survival.ElderMinutes` | 60 (Adult alive in one life) | Economy |
| `SizeFactor` | Small 1.0, Medium 1.3, Large 1.7 | Economy |
| `StageUp.Repeat` | Juvenile 5, SubAdult 10, Adult 25 (x SizeFactor, slot high-water mark) | Economy |
| `Milestone.First` | Juvenile 25, SubAdult 50, Adult 150, Elder 200 (x SizeFactor, once per species per account) | Economy |
| `Milestone.FossilRecord` | 1,000 | Economy |
| `Milestone.FirstNest`, `FirstNestHatchling` | 100, 50 | Economy |
| `Kill.Base` | Juvenile 20, SubAdult 35, Adult 60 (Hatchling 0) | Economy |
| `Kill.RatioFloor`, `RatioCap`, `RatioExponent` | 0.15, 4, 0.5 | Economy |
| `Kill.MinDamageShare` | 0.10 | Economy |
| `Meal.Coins`, `Meal.CooldownSeconds` | 5, 300 | Economy |
| `Meal.FromBelow`, `Meal.ToAtLeast` | 0.50, 0.90 hunger | Economy |
| `NestParent.Coins`, `PerNestMax`, `DailyMax` | 15, 5, 75 | Economy |
| `Journal` | Drink 10, Eat 10, EscapeThreat 25, Rest 10, ReachJuvenile 25, Herd 25, SurviveNight 25, NestSite 20 | Economy |
| `DailyForage` | 50, 75, effect, 100, 150, 200, skin | Economy |
| `Instinct.Coins`, `PerDay`, `WeeklyTarget`, `WeeklyBonus` | 25, 3, 15, 150 | Economy |
| `Mult.CoinPass`, `Mult.Premium`, `Mult.MaxGameplay` | +1.0, +0.1, 2.1 | Economy |
| `Mult.VipForage` | +0.25 | Economy |
| `Mult.PrivateServerKills` | 0 | Economy |
| `Species.Price` | Velociraptor 0, Gallimimus 0, Pachycephalosaurus 0, Parasaurolophus 750, Ceratosaurus 1,000, Baryonyx 1,500, Triceratops 2,750, Tyrannosaurus 4,000 | Economy |
| `Species.RobuxShortcut` | Parasaurolophus 99, Ceratosaurus 149, Baryonyx 199 R$; Large none (product ids, later) | Economy |
| `Cosmetic.CoinTier` | Basic 300, Standard 800, Deluxe 1,800, Prestige 4,000 | Economy |
| `Cosmetic.RobuxTier` | 75, 149, 249, 299; bundles 399, 599 | Economy (display reads `GetProductInfo`) |
| `Cosmetic.NestStyle` | 600, 1,200, 1,800 | Economy |
| `NameReroll` | 100 (first free) | Economy |
| `Featured.CoinSlots`, `RobuxSlots` | 4, 2 | Economy |
| `SeasonTrack.MaxCoinsPerSeason` | 1,500 | Economy |
| `Earning.ActiveMoveStuds`, `ActiveWindowSeconds` | 8, 180 | AbuseRules |
| `Earning.MaxRestSeconds` | 180 | AbuseRules |
| `Earning.MinNeeds` | 0.25 | AbuseRules |
| `Survival.SoftCap` | 180 min full, 180–360 x0.5, > 360 x0.25 (base coins, per UTC day) | AbuseRules |
| `Kill.PairCooldownSeconds` | 1,800 | AbuseRules |
| `Kill.DailyCapBase` | 400 | AbuseRules |
| `Kill.MinVictimPlaytimeMinutes` | 60 | AbuseRules |
| `Kill.SharedGroupWindowSeconds` | 900 | AbuseRules |
| `Alert.SingleGrant`, `Alert.WalletClamp` | 1,000, 10,000,000 | AbuseRules |
| `Alert.EarningHoursPerDay`, `Alert.Days` | 6, 3 | AbuseRules |

---

## 10. MVP vs later

| Phase | Economy work |
|---|---|
| **MVP (Prototype + Core loop)** | Coins in data only, no shop: `DataService.addCoins` with reason codes; survival per minute with the earning-state test and soft cap; repeat stage-ups (high-water mark); species milestones (Juvenile, Sub-adult, Adult); meals; coins shown on the death screen (doc 05 `LifeEvent.Died.coins`); analytics economy events. One species, so no purchases yet |
| Species + map (weeks 4–5) | Species prices and unlock flow; Elder milestone; kill rewards with every section 7 rule (they need groups and multiple species to be tested) |
| Shop + UI (week 6) | Coin cosmetics catalog and weekly rotation; Journal; Daily Forage; Instincts |
| Monetization (week 7) | Passes and multipliers; Robux cosmetics; private-server rules |
| Later (post-launch, after 30 days of telemetry) | Medium species shortcuts; Fossil Record; nest rewards and styles; Season Track; re-run the sim with real death and kill rates |

---

## Decisions for the user

1. **Species prices (Parasaurolophus 750, Ceratosaurus 1,000, Baryonyx 1,500, Triceratops 2,750, Tyrannosaurus 4,000; 10,000 total).**
   Options: (a) as listed (about 16 days at 60 min/day); (b) 25 % cheaper (about 12 days); (c) 25 % dearer (about 21 days).
   **Recommend (a).** Hits the 2–3 week target with headroom to discount at launch events instead of raising prices later.
2. **Paid growth boost (doc 01 x1.25 vs doc 02 none).**
   Options: (a) none; (b) x1.25 capped boost.
   **Recommend (a).** It buys time as an Adult in PvP and is a hidden coin boost (section 6a).
3. **Death rule, economy view.**
   Options: (a) doc 01 checkpoints; (b) doc 02/05 reset to hatchling.
   **Recommend (a)**, with stage-ups by high-water mark and the kill anti-farm rules. Coins are tuned for (a); if (b) is chosen, drop Large prices to 2,500 / 3,600.
4. **Robux species shortcuts.**
   Options: (a) Medium species only (99 / 149 / 199 R$), Large coin-only; (b) all coin species purchasable; (c) none.
   **Recommend (a).** The apex stays earned, and the most visible pay-to-win complaint never starts.
5. **Coin packs.**
   Options: (a) none at launch, revisit after 90 days of telemetry; (b) doc 02's packs (99 / 249 / 499 R$); (c) never.
   **Recommend (a).** Packs would let Robux buy Large species indirectly and blur "earned" status. If added later, they must not buy species (needs a separate "bought coins" balance).
6. **What the 2x pass doubles.**
   Options: (a) gameplay sources only (survival, stage-ups, meals, kills); (b) also Daily Instincts (doc 02 section 4.3).
   **Recommend (a).** Daily goals should pay every player the same.
7. **Coin-buyable extra dino slot (a 4th slot for about 6,000 coins, on top of the +3 pass).**
   Options: (a) no, slots stay 3 free + 3 pass; (b) yes, as a late-game coin sink.
   **Recommend (a) for launch**, (b) as a possible sink if the median 30-day wallet passes 15,000.
8. **Kill coins in private servers.**
   Options: (a) 0, other coins normal with default settings; (b) all coins x0.5 in private servers; (c) normal.
   **Recommend (a).** Removes the safest kill-trading venue without punishing friends who just want a quiet server.
