# 03 · World and map

Owner: game-level-designer. Status: design draft, nothing built yet.
Reads with: `00-concept.md`. Depends on species sizes and speeds from the species/mechanics doc (game-designer). Until that exists, the **assumptions in 1.1** are the contract. If they change, the size gates (3.6) and travel times (1.3) change with them.

**Design intent in one line:** a readable island where you can always see the volcano and you're never more than ~35 s from water, but the water is where the danger is. Hatchlings live in the cracks of the map, and adults own the open ground.

---

## 1. Island size

### 1.1 Movement assumptions (to confirm with game-designer)

| Size class | Example | Hitbox W × H × L (studs) | Trot | Sprint | Cruise* |
|---|---|---|---|---|---|
| Hatchling (any species) | | ≤ 2.5 × 3 × 4 | 12 | 16 | 12 |
| Small adult | raptor | 3 × 4 × 7 | 16 | 26 | 17 |
| Medium adult | ornithopod | 6 × 8 × 16 | 14 | 22 | 15 |
| Large adult | Tyrannosaurus | 9–11 × 16 × 34 | 12 | 18 | 13 |

\*Cruise = average speed over a long trip: mostly trot with stamina-limited sprint bursts. All travel times below use cruise speed.

### 1.2 Recommendation: 4096 × 4096 map, island about 3,500 studs across

| Metric | Value |
|---|---|
| Map bounds | X and Z from −2048 to +2048, origin at the island centre (no float-precision problems at this range) |
| Grid | 16 × 16 cells of 256 × 256 studs, named A–P (west→east) and 1–16 (north→south). North is −Z |
| Cell centre → studs | `X = (colIndex − 8) × 256 + 128`, `Z = (row − 9) × 256 + 128` (A = colIndex 0) |
| Land | ≈ 156 cells ≈ **10.2 M studs²** (beaches counted as half) |
| Land per player at 30 players | ≈ 340k studs² ≈ a 580 × 580 square each |
| Sea level | Y = 0. Highest point is the volcano peak at Y ≈ 400 |

**Why 30 players and this size.** Keep 30 per server. That's enough for herds, packs and a food chain, and it's well within a stable Roblox server once NPCs are capped. The scaling rule is **island width ≈ 640 × √players** studs (20 players → 2,860; 30 → 3,500; 40 → 4,050). If the server size changes, scale the whole grid instead of redrawing it.

| Island width | Land per player at 30 | Small crosses in | Large crosses in | Verdict |
|---|---|---|---|---|
| 2,500 | 165k | 2.5 min | 3.2 min | Too cramped: one adult T. rex can patrol it all, and there's nowhere to hide |
| **3,500** | **340k** | **3.4 min** | **4.5 min** | Players cross in under a typical Roblox session's first quarter, and quiet zones still exist |
| 5,000 | 680k | 4.9 min | 6.4 min | Empty: 30 players rarely meet outside the water hubs, and the part budget doubles |

### 1.3 Target travel times (cruise speed)

| Trip | Distance | Hatchling | Small | Large |
|---|---|---|---|---|
| Nursery → its own spring | ≤ 30 | instant | – | – |
| Any forest, plains, swamp or highland cell → fresh water | ≤ 600 | ≤ 50 s | ≤ 35 s | ≤ 46 s |
| Desert or ash cell → oasis or springs | ≤ 900 | – | ≤ 53 s | ≤ 70 s |
| Biome centre → neighbouring biome centre | ~1,100 | 90 s | 65 s | 85 s |
| Across the island (volcano → swamp mouth) | ~3,300 | 4.6 min | 3.2 min | 4.2 min |

The water distances were checked cell by cell against the map below: the worst green cells are 572 studs from water, and the worst desert cell is 810.

**Encounter target:** in playtest, an average player has another player within 150 studs about once every 2–4 min outside the hubs, and constantly at the hubs. Log positions every 10 s in playtests to build a heatmap and check this.

---

## 2. Biome layout

### 2.1 Top-down map (1 cell = 256 studs)

```
      A B C D E F G H I J K L M N O P
   1  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   2  ~~~~~~~~..^^^^^^^^^^..~~~~~~~~~~
   3  ~~~~~~..FF^^^^^^^^^^AAVVVV..~~~~
   4  ~~~~..FF--FF^^^^##^^AAVVVVAA..~~
   5  ~~..FFFF--FFFFPP==PPAAAAAAAA..~~
   6  ~~..FFFF--FFPPPP==PP--DDDDDD..~~
   7  ~~..FF--FFFFPPPP==--PPDDDDDDDD..
   8  ..FFFF--FFFFPPLLLLPPPPDDDDDDDD..
   9  ..FFFF--FFPPPPLLLLPPPPDDDDDDDD..
  10  ~~..FF--FFPP==PPPPPPPPDDDDDD..~~
  11  ~~..SSFFSS==PPPPPPPPPPPPDDDD..~~
  12  ~~..SSSS==SSPPPPPPPPPPPPDD..~~~~
  13  ~~~~SSSS==SSSSPPPPPPPP....~~~~~~
  14  ~~~~..SSSS==SSSS........~~~~~~~~
  15  ~~~~~~....==..~~~~~~~~~~~~~~~~~~
  16  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  ~ sea   . coast   F forest   P plains   L lake   = river   - creek
  S swamp   D desert/badlands   A ash fields   V volcano   ^ highlands   # waterfall
```

Points of interest overlay (N = nursery spawn, X = chokepoint, W = special water, M = landmark):

```
      A B C D E F G H I J K L M N O P
   3  ~~~~~~..FF^^N4W4^^^^AAVVM2..~~~~
   4  ~~~~..FF--FFX2^^M1^^X6VVVVAA..~~
   5  ~~..N1FF--FFFFPPX1PPAAW3AAAA..~~
   7  ~~..M3--FFFFPPPPX3--PPDDM5DDDD..
   8  ..FFFF--FFN2PPLLLLPPPPW1DDX7DD..
   9  ..W6FF--FFPPPPLLLLPPM4DDDDDDDD..
  10  ~~..FF--FFPPX4PPPPPPW7DDN6DD..~~
  11  ~~..SSFFSS==PPPPPPPPPPPPDDW2..~~
  12  ~~..SSN3==SSPPPPPPW5PPPPM6..~~~~
  13  ~~~~SSSSX5SSSSPPPPPPPP....~~~~~~
  14  ~~~~..SSSS==SSSS....N5..~~~~~~~~
```

**Structure (in Kevin Lynch's terms):** the **river** is the spine (a path and an edge), splitting the covered west (forest, swamp) from the open east (plains, desert). The **lake** in the dead centre is the node everyone passes through. The **volcano** is the landmark you can see from anywhere, so "volcano = north-east" orients every player without a minimap.

### 2.2 Biomes (zone names are original placeholders)

| Biome | Cells | Centre (X, Z) | Height Y | Food | Water | Cover | Danger | Nesting | Sightline | Purpose |
|---|---|---|---|---|---|---|---|---|---|---|
| **Old Fern Woods** (forest) | B–F / 3–11, 30 cells | (−1100, −300) | 10–40 | High: low ferns, mid bushes, canopy | Fernbrook creek, ponds | Very high: thickets, logs, dens | Low–medium | Clearings | 60–120 | Home turf for small dinos and hatchlings. Herbivore pantry. 3 of 6 nurseries are at its edges |
| **Longgrass Plains** | G–L / 5–13, 36 cells | (+250, +350) | 8–24, rolling | Medium: grass patches, mid bushes; NPC herds | Lake, river, 2 ponds | Low: boulder clusters, hill crests | High | Open (risky) | 300–600 | Big herbivore grazing and big carnivore hunting ground. The arena of the food chain |
| **Stillwater Lake** | H–I / 8–9 | (0, 0) | surface 8 | Fish | Best on the map | West reed beds, open east beach | High (watering hole) | No | 400+ over water | The central hub that guarantees encounters |
| **Bluevein River** | I4 falls → lake → G10 → F11 → E12–13 → F15 mouth, ~2,400 long | – | 120 → 8 → 0 | Fish | Everywhere along it | Banks, reeds | Medium; high at fords | No | Along its length | Water line. Splits west from east. Fords are the chokepoints |
| **Sunken Mire** (swamp) | C–H / 11–15, 13 cells | (−900, +1000) | 0–6 | Medium: reeds, water plants; fish | Everywhere | High: mangrove roots, fog | Medium–high (ambush) | Hummocks | 40–80, foggy | Easy water, hard visibility. Ambush-predator territory. Mud slows the biggest dinos |
| **Greystone Ridge** (highlands) | F–J / 2–4, 13 cells | (−130, −1410) | 60–180 | Low–medium: alpine shrubs | Ridge tarn, falls pool | High: caves, ledges | Medium | Ledges | 600+ from ledges | River source. Lookouts over the plains. Caves give hatchlings cover. The northern wall |
| **Redrock Badlands** (desert) | K–O / 6–12, 21 cells | (+1150, +200) | 10–30, mesas to 80 | Very low: cacti, scrub | 2 oases only | Canyons, mesa shade | High (exposure, thirst) | Mesa tops | 600–800 | Quiet, low-competition shortcut. The oases are guaranteed fights. Its slot canyon is a small-dino highway |
| **Ash Fields** | K–N / 3–5, 7 cells | (+900, −1100) | 30–90 | Almost none | Hot springs, creek source | Low: lava rock spires | High: lava channels, vents | No | 300–500, hazy | The approach to the volcano. Hot springs reward the trip |
| **Emberpeak** (volcano) | L–M / 3–4 | (+1024, −1280) | 90 → 400 | None | None | None | Very high | No | Whole island from the rim | The landmark. Optional rim climb for the view and screenshots. Later: eruption events |
| **Shell Coast** | Ring, widest in the south and east | – | 2–6 | Fish in the shallows, shore critters | None (seawater can't be drunk) | None | Medium (exposed) | Dunes (later) | 500+ | A fast but exposed "highway" around the island. Hatchling nursery N5 |

### 2.3 Elevation and water levels

| Feature | Y |
|---|---|
| Sea, swamp water, river mouth | 0 |
| Lake surface (the river steps down to it in 2–4 stud rapids) | 8 |
| River above the lake (I5–I7), in stepped rapids | 8 → 70 |
| Twin Falls drop | 120 → 70 |
| Ridge tarn | 150 |
| Volcano rim and peak | 340 / 400 |

Stepped rapids keep every water body flat (which Terrain water needs) and read as blocky by design.

---

## 3. Resources, zones and space

### 3.1 Water sources

| ID | Source | Cell | Size | Notes |
|---|---|---|---|---|
| – | Bluevein River | spine | 24–60 wide | Shallow at fords, deep (10–14) elsewhere |
| – | Stillwater Lake | H–I / 8–9 | ~420 × 380 | Hub. Reed beds in the west (cover) vs an open beach in the east (exposed) |
| – | Hotwater Creek | K6 → J7 → lake | 12–20 wide | Runs from the ash fields to the lake |
| – | Fernbrook creek | E4 → D10 → swamp | 10–16 wide | Forest water, so the west isn't dry |
| – | Swamp pools | C–H / 11–15 | many | Murky, but drinkable |
| W1 | Palm Oasis | L8 | 60 × 50 | Open approach from every side |
| W2 | Sinkhole Oasis | N11 | 40 × 40, 20 deep | One ramp in, so it's a trap and a chokepoint |
| W3 | Hot Springs | L5 | 3 pools of 20 × 20 | Proposal: faster injury healing while resting here (game-designer) |
| W4 | Ridge Tarn | H3 | 50 × 40 | Next to nursery N4 |
| W5 | Southmeadow Pond | J12 | 40 × 30 | Covers the southern plains |
| W6 | Fern Pond | B9 | 40 × 30 | Covers the west forest edge, beside the Elder Tree |
| W7 | Rockfoot Pond | K10 | 30 × 30 | At the foot of Lookout Rock: a view plus water is a classic ambush spot |
| – | Nursery springs | N1–N6 | 8 × 8 | Inside the hatchling-only groves |
| – | Sea | ring | – | **Not drinkable** (recommendation). Fish only |

**Water depth sets who can cross:**

| Depth | Who walks it | Who swims it |
|---|---|---|
| 0–3 (fords, shallows) | Everyone, slowed | – |
| 3–8 | Medium and large dinos wade | Hatchlings and small dinos swim (slow, uses stamina) |
| 8–14 (deep river) | Large dinos wade | Everyone else swims |
| > 14 (lake centre, sea) | Nobody | Everyone |

This is the reverse of the land size gates: deep water favours big dinos, and tight gaps favour small ones.

### 3.2 Food: herbivores (plant patches)

A patch is a cluster of 3–6 edible plants. The server tracks bites and regrows it after about 3–5 min (game-designer tunes the numbers). Plants come in **three height tiers** so each size class has its own food:

| Tier | Height | Eaten by | Where |
|---|---|---|---|
| Low (ferns, grass tufts) | ≤ 3 | Hatchlings, small dinos (large ones can, but slowly) | Forest floor, thicket interiors, nurseries |
| Mid (bushes) | 4–10 | Small, medium | Forest edges, plains, swamp |
| High (canopy) | 12–30 | Large and tall herbivores | Forest trees, plains lone trees |

| Biome | Patches (full island) | Mix (low / mid / high) | MVP |
|---|---|---|---|
| Forest | 60 | 40 / 35 / 25 % | 18 |
| Plains | 45 | 20 / 60 / 20 % | 12 |
| Swamp | 30 | 30 / 60 / 10 % | – |
| Highlands | 15 | 50 / 50 / 0 % | – |
| Coast and desert | 16 | 0 / 100 / 0 % | – |
| Ash and volcano | 0 | – | – |
| **Total** | **~166** | | **30** |

### 3.3 Food: carnivores

| Source | Placement | Full island | MVP |
|---|---|---|---|
| NPC prey zones (small critters and NPC herbivore herds) | Forest 6, plains 5 (herds), swamp 4, coast 3, highlands 2, desert 2 | 22 zones | 3 zones |
| Fish spots | River 8, lake 4, swamp 6, coast shallows 4 | 22 | 4 |
| Carcasses | Wherever something dies. They naturally gather at hubs and fords | – | – |

**NPC cap:** 40 server-wide and ≤ 8 per zone (≤ 12 in the MVP). NPCs spawn only 150–500 studs from a player, out of their line of sight, and despawn after 60 s with no player within 700 studs. That keeps the map alive where people are and costs nothing where nobody is.

### 3.4 Danger gradient

| Tier | Zones | Why |
|---|---|---|
| 1 Refuge | Nursery groves, small-only dens, caves' inner tunnels | Geometry keeps adults out (3.6) |
| 2 Low | Deep forest, highland caves, swamp mangrove interiors | Cover and short sightlines |
| 3 Medium | Forest edges, swamp channels, highlands, coast | Mixed cover |
| 4 High | Plains, lake shore, fords, oases | Open, and everyone must come here |
| 5 Hazard | Ash fields, volcano | The environment itself damages you |

There are no hard safe zones apart from hatchling spawn protection (section 4). Safety comes from space, not rules.

### 3.5 Chokepoints

Rule: **every chokepoint has an alternative route that costs at most +30 % travel time**, so camping one is a choice, never a trap.

| ID | Name | Cell | Type | Width | Alternative | Favours |
|---|---|---|---|---|---|---|
| X1 | Falls Ford | I5 | Shallow ford below Twin Falls | 40 | Swim the deep river, or go round the ridge (+400) | Ambushers in the spray and rocks |
| X2 | Ridge Pass | G4 | Gap in the ridge between forest and falls | 50 | The coast path (+500) | Whoever holds the ledges above |
| X3 | Lakehead Ford | I7 | Sandbar where the river enters the lake | 60 | Wade across the lake edge (deep) | Large dinos (they can wade the deep sides) |
| X4 | Outflow Ford | G10 | Gravel ford below the lake | 30 | Swim downstream | Packs (it's narrow) |
| X5 | Mire Causeway | E13 | Raised strip and log crossing through the swamp | 20–30 | Swamp channels (slow mud) | Medium dinos |
| X6 | Ash Bridge | K4 | Rock land-bridge over a lava channel to the rim | 16 | None. The rim is optional, so that's allowed | Nobody: it's a thrill |
| X7 | Redrock Slot | N8 | Slot canyon through the badlands | 12, narrowing to 5 | Around the mesas (+350) | Small dinos: large ones can't fit the 5-stud section |

### 3.6 Size gates, sightlines and hiding spots

**Gate standard** (opening width and height; game-designer must lock the hitboxes to match):

| Opening | Passes | Used for |
|---|---|---|
| 3 | Hatchlings only | Nursery walls, burrows |
| 6 | Small adults, all juveniles | Dens, thickets, slot canyon |
| 10 | Medium and smaller | Swamp roots, cave tunnels |
| ≥ 14 | Everyone | Game trails (16–24), passes, fords |

**Sightlines** (the target length of an unbroken view, and what breaks it):

| Biome | Day | Night | Breakers |
|---|---|---|---|
| Plains | 300–600 | 150 | Rolling hills and a boulder cluster at least every 300 studs. Never a flat sniper field |
| Desert | 600–800 | 200 | Mesas, canyon walls |
| Lake | 400+ | 200 | West reed beds |
| Forest | 60–120 | 40 | Trunks, thickets |
| Swamp | 40–80 | 30 | Fog, mangroves |
| Highland ledges | 600+ | 200 | These are prospect points: you see far, with your back to rock |

Night values assume the day/night system tightens fog. Atmosphere is global, so per-biome fog would be a client-side effect (game-technical-artist).

**Hiding spots for small dinos.** Target: in the forest and swamp, a small-only refuge within 100 studs of any point. Elsewhere, within 250.

| Type | Entrance | Count (full / MVP) | Where |
|---|---|---|---|
| Hollow log | 6 × 6 | 40 / 6 | Forest, swamp edges |
| Root den | 6 × 6, with 2 exits | 25 / 3 | Forest, under big trees |
| Burrow | 3 × 3 (hatchlings only) | 20 / 3 | Forest floor, plains hillsides |
| Rock crevice | 6 wide | 20 / 2 | Highlands, desert, plains boulders |
| Reed bed / tall ferns | No gate. Visual cover only | 15 areas / 2 | Lake west shore, swamp, forest |
| Cave | 14 mouth, 6-wide inner tunnels | 6 / 0 | Highlands, desert mesas |

Every den has at least 2 exits, so a single predator can't wait at the only door. Whether nametags hide in cover is a game-designer call: without it, reed beds don't work.

### 3.7 Landmarks (navigation without a minimap)

| ID | Landmark | Cell | Seen from |
|---|---|---|---|
| M2 | Emberpeak cone | M3 | Everywhere (a streamed low-detail proxy, see 5.3) |
| M1 | Twin Falls | I4 | The north half and the lake |
| M3 | Elder Tree (one giant blocky tree above the canopy) | C7 | The whole forest and the lake |
| M4 | Lookout Rock (plains outcrop, a prospect point) | K9 | The plains |
| M5 | Broken Arch (sandstone) | M7 | The desert and plains |
| M6 | Titan Ribs (a huge ancient skeleton: environmental story, and a visual hint that hunting happens here) | M12 | The southern desert |

Ground colour also identifies each biome: dark green forest, yellow-green plains, orange sand, olive swamp, charcoal ash, grey-blue highlands. Game trails are a lighter ground colour, so the main path through the forest reads at a glance.

---

## 4. Spawn points and hatchling protection

### 4.1 Nurseries (wild spawn)

| ID | Name | Cell | Coordinates | Biome | Suits | Nearest water hub |
|---|---|---|---|---|---|---|
| N1 | Fernhollow | C5 | (−1408, −896) | Forest | All | Fernbrook creek, 512 |
| N2 | Mossbank | F8 | (−640, −128) | Forest/plains edge | All. **MVP nursery** | Lake, 650 |
| N3 | Reedmouth | D12 | (−1152, 896) | Swamp | Carnivores, semi-aquatic | Swamp pools |
| N4 | Cliffnook | G3 | (−384, −1408) | Highland cave | All | Ridge tarn |
| N5 | Dune Grass | K14 | (640, 1408) | South coast | Herbivores | Southmeadow Pond |
| N6 | Redrock Shelf | M10 | (1152, 384) | Desert edge | Desert species (later) | Sinkhole Oasis |

**Placement rules:** each nursery is at least 300 studs from any chokepoint or water hub, has its own spring, and is within 100 studs of forest-grade cover.

### 4.2 Nursery blockout spec

```
Room: Nursery grove (template, ~60 × 60)
  Wall:   ring of trunks or rocks, height ≥ 14, gaps of 3 studs (hatchlings only)
  Exits:  3 exits of 3 studs on different sides, each opening into cover (thicket, reeds or a den)
  Inside: spring pool 8 × 8 · 3–4 low plant patches · 1 grub/bug spawner (food for carnivore hatchlings)
          · 1 raised stump lookout (height 4, ramp) so the hatchling can see out before leaving
  Light:  warm and bright inside, darker canopy outside. The exits sit in contrasting light gaps
  Story:  old eggshell fragments and a worn nest ring: "dinos have hatched here for generations"
```

### 4.3 Protection layers

| Layer | Rule |
|---|---|
| Geometry (main defence) | Only hatchlings fit through 3-stud gaps. Juveniles and up can't enter, so architecture protects hatchlings, not a magic shield |
| Spawn shield | Hatchlings can't be damaged for 60 s after spawning. The shield ends early if they bite, or 10 s after they leave a 20-stud radius around the grove |
| Smart spawn choice | The player picks from 3 offered nurseries that suit their diet. A nursery is greyed out as **Danger** if a sub-adult or adult carnivore has been within 120 studs of it for 30 s |
| Anti-camping | An adult who loiters within 80 studs of a nursery for over 60 s leaves a visible "scent" warning for hatchlings (later) |
| Streaming | The server calls `Player:RequestStreamAroundAsync(nurseryPos)` before placing the hatchling, so nobody spawns into unloaded ground |

### 4.4 Nest spawns (later phase)

Adults lay eggs only on nestable ground: forest clearings, highland ledges, swamp hummocks and coastal dunes. Nests must be ≥ 100 studs from nurseries and ≥ 60 from other nests. A hatchling from a nest spawns there with the same 60 s shield. The parent is the protection.

---

## 5. Blocky world construction

### 5.1 Recommendation: Parts for all land, Terrain only for water

| Option | Look | Performance | Scripting | Verdict |
|---|---|---|---|---|
| **A. Parts in stepped terraces + Terrain water** | Crisp blocky edges, flat colours, wedge slopes like Lego slope bricks | Boxes are the cheapest collision. Part count is managed by merging and streaming | A heightmap goes in and parts come out: deterministic and can be regenerated | **Recommended** |
| B. Smooth Terrain | Rounded, blended, realistic. It fights the Lego look | Cheapest at huge scale | FillBlock works, but edges get smoothed anyway | No: wrong style |
| C. Baked MeshPart chunks (Blender) | Blocky | Best (one mesh per chunk) | Needs an outside pipeline and uploads. Collision fidelity is tricky | Later, only if profiling shows ground parts are the bottleneck |

Why Terrain for water: Roblox Terrain water gives swimming, buoyancy, waves and reflections cheaply. Parts can't swim. Fill it with `FillBlock` in boxes aligned to 4 studs, with banks made of Parts, so the shoreline still reads as blocky.

**Ground rules**
- 16-stud base grid. Merge neighbouring cells of the same height and colour into one big Part ("greedy merge"). This turns ~48k columns into about 4–6k parts island-wide.
- Walkable steps are ≤ 2 studs high (a hatchling must climb them; confirm with the movement prototype). Steeper slopes use WedgeParts at ≤ 35°.
- Cliffs are vertical part stacks ≥ 24 studs high, meaning "nobody climbs this". Test against the large dino's step-up height.
- Use slight colour jitter between neighbouring ground parts (±4 % brightness) instead of grass objects. Optional later: grass tufts scattered client-side within 150 studs of the camera.
- Sea: Terrain water only in a ~300-stud swimmable ring around the island. Beyond it, a flat visual ocean plane (CanCollide, CanQuery and CanTouch off) and an invisible wall at ±2,048, with a current pushing swimmers back.

### 5.2 Part budgets

| Item | Budget |
|---|---|
| Tree | ≤ 3 parts (trunk and 2 canopy blocks), plus collision on the trunk only. Hero trees ≤ 12 |
| Bush / rock / log | ≤ 2 / ≤ 3 / ≤ 2 |
| Den or nursery template | ≤ 25 / ≤ 120 |
| Forest cell (256²) | ≤ 350 (ground 40, ~70 trees, bushes 50, logs, rocks and dens 50) |
| Swamp / highland / desert / plains cell | ≤ 200 / 180 / 120 / 100 |
| Ash / volcano / water / coast cell | ≤ 80 / 150 / 60 / 60 |
| Landmarks in total | ≤ 1,500 |
| **Whole world** | **≤ 32k BaseParts** (estimated ~27k) |
| **Any 768-stud streaming window** | **≤ 9k** (worst case is the forest) |
| **MVP slice** | **≤ 6k** (estimated ~4.7k) |
| Player dino / NPC dino | ≤ 30 / ≤ 15 parts (game-technical-artist owns this) |

**Rules for decorative parts:** Anchored on. CanTouch and CanQuery off unless gameplay needs them. CanCollide off on canopy and decoration. CastShadow off on anything under 6 studs. Material SmoothPlastic or Plastic. No transparency on foliage. Reuse identical sizes so the renderer can instance them.

**Gameplay markers** (plant patches, prey zones, fish spots, drink volumes, nest zones) live **server-side in ServerStorage** as tagged parts or data, not in Workspace. That makes them zero cost for clients and invisible to exploiters.

### 5.3 StreamingEnabled settings (starting point; tune on a real phone)

| Property | Value | Why |
|---|---|---|
| `StreamingEnabled` | true | Required at this size |
| `StreamingMinRadius` | 192 | A large dino's high camera plus a 26 studs/s sprint needs a safe minimum |
| `StreamingTargetRadius` | 768 | Longer than the plains sightline. Roblox lowers it on low-memory devices |
| `StreamOutBehavior` | Opportunistic | Frees memory on mobile |
| `StreamingIntegrityMode` | MinimumRadiusPause | Pause only when the guaranteed area isn't loaded |
| `ModelStreamingMode` per model | **Atomic** on trees, dens and nurseries (they arrive whole). **Persistent** only on the low-detail landmark proxies (≤ 300 parts total). Default for biome chunk folders | |
| `Model.LevelOfDetail` | `StreamingMesh` on landmarks and biome chunk models, so the volcano and the island silhouette stay visible past the radius | Check the current docs for which models this applies to before building |
| Atmosphere | Haze fades the view by ~700–800 studs, which hides the streaming edge | game-technical-artist |
| Code | Client code must expect streamed-out instances: CollectionService tags and `WaitForChild` with timeouts. `RequestStreamAroundAsync` before every spawn or teleport | roblox-systems-scripter |

### 5.4 Mobile targets

| Target | Value |
|---|---|
| Frame rate | 30 fps on a 3–4 GB Android phone, 60 on a recent iPhone |
| Client memory | Under ~1 GB on mobile |
| Lights | ≤ 1 PointLight per 256 cell. Lava is Neon parts with no lights |
| Particles | ≤ 2 ambient emitters per cell. Volcano smoke and ash at low rates |
| Transparency | Water and glass-like effects only. No see-through leaves |
| Camera | Big dinos' cameras will clip forest canopy. Plan for canopy that fades on the client, and test it in the grey-box |
| Touch | No low overhangs on main routes. Every trail ≥ 16 wide, so thumb steering doesn't snag |

---

## 6. MVP map (the prototype slice)

**Slice: cells E6–I10, 1280 × 1280 studs, X −1024…+256, Z −768…+512**, built at the **final coordinates** so the full island grows outwards around it.

```
      E F G H I
   6  --FFPPPP==      forest 7 cells · plains 9 · lake 4 · river 3 · creek 1
   7  FFFFPPPPX3
   8  FFN2PPLLLL      N2 Mossbank nursery · X3 Lakehead Ford · X4 Outflow Ford
   9  FFPPPPLLLL
  10  FFPPX4PPPP
```

| Element | MVP content |
|---|---|
| Biomes | Forest (west) and plains (east), with the lake and river as the hub |
| Spawn | 1 nursery (N2 Mossbank) |
| Water | The whole lake, the river entering at I6 (from a temporary waterfall at the slice edge) and leaving at G10, and Fernbrook at E6 ending in a pond |
| Food | 30 plant patches, 3 prey zones (forest edge, plains, south lakeshore) with ≤ 12 NPCs, 4 fish spots |
| Cover | 1 thicket block, 6 hollow logs, 3 root dens, 3 burrows, 2 crevices, 2 reed beds |
| Chokepoints | X3 and X4 |
| Landmark | One stand-in tall rock or tree in the plains, until Emberpeak exists |
| Boundary | Temporary cliffs (≥ 24) on the north, west and south edges. Deep water past the river on the east. These come out as the island grows |
| Budget | ≤ 6k parts |

Land is about 1.5M studs². That's dense for 30 players (~50k each) but right for 8–15 testers, and it forces the encounters the prototype needs to test.

**How it grows** (matches the concept's phase 3, "Species + map"): add the highlands and falls to the north (the real river source), then the swamp to the south-west (the river mouth), then the desert, ash fields and volcano to the east, and the coast ring last.

---

## 7. Build plan

| Step | Work | Scripted by Claude in Studio | Placed by hand (human or Claude with care) | Exit check |
|---|---|---|---|---|
| 1 Spec | Turn this doc into data: biome grid, heightmap per cell, POI coordinates (a MapSpec module, plus a generator script kept in the repo, for example `tools/worldgen/`) | All of it | – | User approves the map |
| 2 Grey-box ground | Terraces from the heightmap, greedy merge, wedge ramps, cliffs, Terrain water fill, flat grey-box colour per biome, boundary walls. Wrapped in ChangeHistoryService. Output goes to `Workspace.World.Chunks.<Cell>` | Yes | – | Part count ≤ budget. Walkable everywhere a hatchling should be |
| 3 Gameplay markers | Tagged server-side markers for nurseries, patches, prey zones, fish, drink volumes, dens and nest zones | Yes | Nudge any that land badly | Every marker has the right tags |
| 4 Gate templates | Den, log, burrow, thicket and nursery templates with exact gaps. Automated test: push hitbox dummies of each size class through every gate | Yes | – | 100 % of gates pass and block the right classes |
| 5 Automated validation | Reachability flood-fill, max distance to water per cell, chokepoint alternatives within +30 %, sightline raycasts across the plains | Yes | – | All rules in sections 1–4 pass |
| 6 Grey-box playtest | Stopwatch travel times, a new player navigating without a map, nursery safety, ford fights, camera clipping | Timing and heatmap logging scripts | Testers play. Human notes | Times within 20 % of 1.3. Nobody gets lost |
| 7 Iterate | Fix the layout from playtest notes and regenerate | Regeneration | Decisions | **Layout locked: no art before this** |
| 8 Art handoff | Palette, prop library (trees, rocks, bushes as blocky Parts or instanced MeshParts), mark which geometry is gameplay-critical | Can make the props by script or AI mesh generation | game-technical-artist approves the style | Style sheet signed off |
| 9 Dress | Scatter props by rules (density per biome, even spacing, keep trails clear). Ground colour jitter | Bulk scatter | **Hero spots:** landmarks, nursery interiors, chokepoint composition, sightline breakers on the plains, story vignettes (Titan Ribs, shell fragments) | Budgets still met |
| 10 Light and sound | Lighting, Atmosphere, biome sound zones (game-technical-artist) | Settings | Mood tuning by eye | – |
| 11 Performance pass | MicroProfiler, device emulator, a real mid-range phone | Profiling scripts | Device testing | Meets the 5.4 targets |

What needs a human eye: final landmark silhouettes, the composition of each chokepoint and nursery, story props, and the feel of the playtest. Everything repetitive (ground, water, scatter, markers, validation) is scripted, so the layout stays cheap to regenerate until it's locked.

**Handoffs:** game-designer (hitboxes, speeds, thirst and swim rules, nametags in cover), roblox-systems-scripter (generator, tags, streaming-safe client code, NPC spawner), game-technical-artist (palette, props, lighting, fog, mobile limits), roblox-experience-designer (the nursery picker UI and first-session flow).

---

## Decisions for the user

1. **Server size.** (a) 20, (b) **30**, (c) 40. Recommend **30**. The map scales by `640 × √players` if this changes.
2. **Island size.** (a) 3,072 map / 2,600 island, (b) **4,096 map / 3,500 island**, (c) 5,120 map / 4,400 island. Recommend **(b)**: about 3–4.5 min to cross.
3. **How the world is built.** (a) **Parts in stepped terraces plus Terrain water**, (b) Smooth Terrain, (c) baked mesh chunks. Recommend **(a)**: the Lego look, simple box collision, and regenerable by script.
4. **Studs on surfaces.** (a) **Smooth plastic, no studs**, (b) a stud texture on ground tops, (c) studs only on hero props. Recommend **(a)** for performance and readability on phones. game-technical-artist to confirm.
5. **Can dinos drink seawater?** (a) **No**, (b) yes, (c) yes, but it makes you thirsty faster. Recommend **(a)**: it concentrates traffic on fresh water, which creates the encounters.
6. **How hatchlings pick a spawn.** (a) **Choose from 3 offered nurseries**, (b) random, (c) any nursery. Recommend **(a)**, with dangerous nurseries greyed out.
7. **Hard size-gated spaces** (gaps only small dinos fit through). (a) **Yes**, using the 3 / 6 / 10 / 14 standard, (b) no, cover is visual only. Recommend **(a)**. It needs game-designer to lock hitbox widths before the grey-box.
8. **Map edge.** (a) **Swimmable sea ring, then a current and an invisible wall**, (b) cliffs all round. Recommend **(a)**: it reads as an island.
9. **Lava.** (a) Instant death, (b) **heavy damage over time plus being pushed out**. Recommend **(b)**: deaths feel fair on mobile.
10. **MVP slice.** (a) 768 × 768 (lake and forest edge only), (b) **1280 × 1280 (cells E6–I10)**. Recommend **(b)**: generation is scripted, so the bigger slice costs little and tests forest, plains and fords.
11. **Island name** (the game needs an original title; the island name can double as one). (a) Cinderfern Island, (b) Primal Reach, (c) Ashtooth Island. Recommend **(a) Cinderfern**: it mixes the volcano and the forest. Run a name search before committing.
