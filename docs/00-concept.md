# Concept (from the user, 2026-11-26)

This is the user's original pitch, kept as written. The design docs in this folder refine it.

---

Plan: a blocky survival dinosaur game for Roblox

One note first: I can copy The Isle's gameplay systems (survival, growth, hunger, thirst, herds, nests), because mechanics are fair game. I shouldn't copy Jurassic Blocky's actual models, names or branding. We'll make our own blocky dinosaurs in the same chunky, Lego-like style, which also keeps you safe from Roblox takedowns.

## 1. Core game (The Isle systems)

| System | How it works in Roblox |
|---|---|
| Dino selection | Pick a species at spawn. Start as a hatchling, so you need to unlock or earn adults. |
| Growth | Hatchling → Juvenile → Sub-adult → Adult. Bigger means more health, damage and speed, but more food needed. |
| Hunger / Thirst | Two bars. Carnivores eat carcasses and fish, herbivores eat plants. Drink at water. |
| Health regen | Rests and heals when fed and watered. Injuries (bleeding) slow it. |
| Stamina | Sprint and attacks use it. |
| Combat | Bite, tail swipe, charge, and a species special (e.g. T-Rex roar stun). Hitboxes via raycasts or GetPartsInPart. |
| Herds / packs | Create a group, share a group chat and map pings. |
| Nests / eggs | Adults lay eggs and hatchlings spawn near the nest. |
| Carcasses | Dead dinos leave a carcass that can be eaten. |
| Day/night + weather | Night is darker and more dangerous. |
| Map | Big blocky island with biomes: forest, swamp, desert, volcano, river. |
| AI wildlife | NPC herbivores and small prey so the map feels alive. |

## 2. Technical architecture (Luau)

- Server-authoritative for health, damage, hunger, growth and currency. Never trust the client for these.
- ModuleScripts per system: DinoData (stats table per species), GrowthService, NeedsService, CombatService, ShopService, DataService.
- RemoteEvents for client requests (attack, drink, buy).
- DataStore (use ProfileService or a similar wrapper) to save coins, owned dinos, skins and effects.
- Dino models: one rig per species made from Parts with Motor6D joints. Animate with the Animation Editor and a simple walk, bite, idle and death set.
- Performance: stream the map (StreamingEnabled), keep part counts low (blocky style helps), and cap NPC count.

## 3. In-game shop

**Categories**
- Skins: color patterns (tiger stripes, lava, arctic, camo, galaxy).
- Accessories: hats, scars, spikes, glowing eyes, back saddles.
- Effects: footstep dust, fire trail, glitter, lightning aura, roar shockwave color.
- Emotes: sit, dance, special roar.
- Extra dinos: premium species (e.g. Spinosaurus-style or a mythic "crystal" dino).
- Boosts: growth boost, XP boost, extra nest slot.

**Shop UI:** a ScreenGui with tabs, a 3D ViewportFrame preview of your dino wearing the item, and Equip / Buy / Locked states.

## 4. Monetization (Roblox-compliant)

- **Game Passes (one-time):** VIP (daily coins, chat tag), Extra Dino Slots, 2x Coins, Exclusive Skin Pack.
- **Developer Products (repeatable):** coin packs, instant growth, revive, nest respawn.
- **Premium Payouts:** you earn Robux when Premium members play, so give Premium players a small perk.
- **Cosmetic-first rule:** sell looks and convenience, not unbeatable stats. Pay-to-win kills survival games' communities.
- **Rotating limited shop:** new items weekly or monthly to create urgency.
- **Rules to follow:** if you sell random rewards (egg or crate), Roblox requires you to show the odds. Avoid anything that looks like gambling.
- **Ads:** Roblox sponsored ads can bring players early on.

**In-game currency:** Fossil Coins, earned by surviving, growing, and killing. Premium currency is bought with Robux.

## 5. Build phases

1. **Prototype (week 1):** terrain, one dino (e.g. a Raptor), movement, hunger and thirst, a simple bite.
2. **Core loop (weeks 2–3):** growth stages, carcasses, AI prey, saving data.
3. **Species + map (weeks 4–5):** 6–8 dinos, biomes, day/night.
4. **Shop + UI (week 6):** shop, inventory, viewport previews.
5. **Monetization (week 7):** game passes and products, then test purchases.
6. **Playtest + polish (week 8):** balance, fix exploits, add sound and effects.
7. **Launch:** icon, thumbnails, description, then update weekly.

## 6. More ideas

- Mutations: random trait on hatch (night vision, thick hide).
- Skill tree per species, unlocked by playtime.
- Boss event: a giant roaming dino that the whole server fights for rewards.
- Meteor / volcano events that reshape the map temporarily.
- Territories: packs claim areas and earn bonuses.
- Tamed baby dinos or companions as pets.
- Seasons + battle pass with free and premium tracks.
- Fishing and swimming for aquatic prey and boss fish.
- Leaderboards: biggest dino, longest survival, most kills.
- Photo mode with emotes and cosmetic showcases (good for social sharing).
- Private servers as a paid option, a reliable earner for survival games.
- Admin / mod tools to manage exploiters.

## 7. How we'll work together

I can write the Luau scripts (services, shop logic, UI code, data saving) and design each system, and you paste them into Studio (or run them through a Studio MCP connection if you set one up). Build in small pieces: one script at a time, test, then continue. Models and animations you'll make or source in Studio yourself.
