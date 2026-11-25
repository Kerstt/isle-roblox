# 04 - Art and Technical Art

Owner: technical art. Status: draft for user review, 2026-11-26.
Scope: dino look, rig standard, animation, cosmetics hook-up, VFX and lighting, mobile budgets, build pipeline.
Depends on: species list and growth numbers from the game-design docs (the stage scales below are a proposal until those land).

**MVP** in this doc = what the Prototype and Core loop phases need: 1 playable species (the raptor-type), 1 AI prey species, the rig standard, procedural animation, the basic VFX, a day and a night lighting state. Everything else is marked **Later**.

---

## 1. Art style guide: "brick-built dinos"

### 1.1 Pillars
| Pillar | Rule |
|---|---|
| Chunky | Every dino is built from big, readable blocks. No smooth organic curves, no sculpted meshes on the body. |
| Brick grid | All authored part dimensions and offsets are multiples of **0.5 stud** at adult scale. This gives the toy-brick feel and keeps builds consistent. |
| One signature | Each species has exactly one oversized signature feature in its Accent color (frill, sail, crest, plates, club, sickle claw). It is the thing you recognise first. |
| Toy plastic vs real world | Dinos are clean SmoothPlastic; the world uses textured materials (Grass, Rock, Sand, Wood, Slate). Dinos pop off the background like toys on a diorama. |
| Readable before pretty | Silhouette, size and diet color must read on a phone at 150 studs. Details that only read up close are optional and get hidden at distance. |

### 1.2 Original style signatures (our look, not anyone else's)
These five traits are applied to every species so the game has its own identity. They were chosen without reference to any existing blocky dino game; any new species must be checked side by side against competitor games before approval, and redesigned if it reads as a copy.

| Trait | Spec |
|---|---|
| Stepped taper | Necks and tails are segment chains where each segment is **15-20% smaller** than the previous one, with a visible step (no wedges smoothing the joins). |
| Two-tone split | Primary color on top, Secondary (belly) color below. The split line sits at **60% of each bone's height** on every bone, so the line runs cleanly nose to tail. |
| Square eyes | Eye = square block in Eye color, with a dark pupil block. **Carnivores:** vertical bar pupil (0.5 x 1 ratio), eyes angled forward. **Herbivores:** square pupil (1 x 1), eyes on the side of the head. Diet reads from the face alone. |
| Plate feet | Feet are wide flat plates (1.5x the leg width) with 3 wedge toes in the Detail color (claws). |
| Tooth row | Teeth are a single row of small Detail-colored wedges per jaw side, not individual cones. Herbivores get a flat beak block instead. |

Legal note: describe the style as "brick-built" or "blocky" in store text. Never use the word LEGO, a studded LEGO-style top, minifigure shapes or LEGO colors by name.

### 1.3 Shape language
| Shape | Use | Avoid |
|---|---|---|
| Block | Main masses (torso, hips, head, thighs) | Thin slabs under 0.5 stud thick, except decal carriers |
| Wedge | Snout taper, claws, teeth, spikes, sail edges, toe tips | Using wedges to round off the stepped tail and neck |
| CornerWedge | Horn tips, frill corners, cheek points | More than 4 per dino |
| Cylinder | Only for tube crests and the sauropod neck (Later) | Legs (they lose the brick look) |
| Ball | Not used on dinos | Eyes, joints |

Carnivore masses lean forward with angular, wedge-heavy heads (threat). Herbivore masses are boxier and level, with rounder overall bulk and blunt heads (sturdy). Sizes go from heavy at the hips to light at the tail tip.

### 1.4 Proportions per size class (adult, authored scale = 1.0)
Reference: a default Roblox avatar is about 5 studs tall.

| Class | Example archetypes | Adult length | Hip/shoulder height | Head length (% of body length, excluding tail) | Leg thickness | Notes |
|---|---|---|---|---|---|---|
| Small | Raptor-type, small fast herbivore | 8-10 studs | 3.5-4.5 | 35% | thigh 1.5, shin 1 | Big head and feet, lean body. Cute-leaning at hatchling, sharp at adult. |
| Medium | Crested biped herbivore, dome-head, twin-crest carnivore | 14-18 | 6-8 | 30% | thigh 2.5, shin 1.5 | Balanced. Signature feature can be large. |
| Large | Big biped carnivore, frilled quad, plated quad, sail-back | 26-34 | 11-15 | 28% | thigh 4-5, shin 3 | Very heavy legs, thick tail base (equal to hip height x 0.6). |
| Huge (Later) | Sauropod, boss | 50-70 | 18-24 | 12% | 6+ | Separate budget and camera work. Not in MVP. |

Exaggeration rules (all classes): heads 1.3x realistic size; legs 1.2x thicker than realistic; tails 0.85x realistic length (saves parts and helps camera); bipedal arms stay tiny but chunky (minimum 0.5 x 0.5 stud blocks).

Growth-stage proportions: hatchlings get **+25% head and +40% eye size** relative to body (applied at build time, see 2.5). Juveniles get +10% head. Sub-adults and adults use base proportions.

### 1.5 Color system
**Paint zones** (every visual part belongs to exactly one zone; skins recolor by zone):

| Zone | Covers | Share of visible surface |
|---|---|---|
| Primary | Back, flanks, top of head, top of tail | about 55% |
| Secondary | Belly, throat, underside of tail, inner legs | about 25% |
| Accent | Signature feature, plus optional 1-2 trim parts | about 10% |
| Detail | Teeth, claws, beak, horns | about 5% |
| Eye / Pupil | Eye blocks and pupils | about 2% |
| Pattern (Later) | Hidden pattern bricks that skins can turn on (3.3) | 0% by default |

**Contrast rules:** Primary vs Secondary at least 20 points apart in lightness (L*). Accent saturation at least 60%. Pupil is always the darkest color on the dino.

**Diet coding (readability rule):** predators and prey must be told apart at distance.

| Diet | Primary range | Accent range | Eye |
|---|---|---|---|
| Carnivore | Darker, desaturated (charcoal, deep olive, rust, slate) | Warm and hot: Blood Red, Ember Orange, Bone | Amber or yellow eye, bar pupil |
| Herbivore | Mid to light, earthy or cool (moss, sand, teal, stone) | Cool or sunny: Sun Yellow, Teal, Sky Blue, Cream | Dark brown eye, square pupil |
| Omnivore / fish-eater (Later) | Mid values, blue-gray or olive | Orange plus teal pairing | Amber, square pupil |

Default (free) skins are picked from the species' home biome palette, so a dino is naturally camouflaged in its home biome. Paid skins may break camouflage (that is part of the look-at-me appeal, not a stat).

**Project palette (original swatches; build from these only):**

| Group | Swatches (name, hex) |
|---|---|
| Neutrals | Bone #E8DCC0, Belly Cream #F2EDE3, Eye White #F4F1EA, Pupil Black #1E1E22, Claw Gray #4A4744 |
| Carnivore accents | Blood Red #B23A2E, Ember Orange #E0672B, Rust #8C4A2F |
| Herbivore accents | Sun Yellow #E8B931, Teal #2F9C95, Sky Blue #5BA4CF |
| Forest | Moss #3E6B35, Leaf #8DA34A, Bark #5C4630 |
| Swamp | Olive #4F5B2E, Murk Teal #3B5A55, Reed #7A6E45 |
| Desert | Sand #C9A26B, Terracotta #B8613A, Dust #8A6A4A |
| Volcano | Basalt #3A3533, Ash #5A4A45, Ember #C2452D |
| River / coast | Slate Blue #4C6E7F, Pebble #8FA9A8, Shell #D9CFB4 |

Keep it at these ~30 swatches until launch. A limited palette is what makes a toy line look like a set.

### 1.6 Materials
| Material | Where | Why |
|---|---|---|
| **SmoothPlastic** | Default for every dino zone | Cleanest toy read, exact color reproduction for skins, no texture memory, cheapest to render. |
| Plastic | Not used on dinos | Its fine grain reads as noise at dino scale and blurs the clean-toy vs textured-world contrast. Fine on world props. |
| Neon | Eye shine and glowing skins only; max 4 parts and about 2% of surface | Full-bright and blooms. Too much destroys night readability and looks cheap. |
| CrackedLava, Basalt, Slate, Ice, ForceField | Skin variants only (Later), on Accent or Primary zones | Gives premium skins a different material read without textures. ForceField is animated and fine on mobile in small amounts. |
| Glass, partial Transparency | Never on dinos | Transparency sorting and overdraw on mobile; reads badly. |
| MaterialVariant (custom textured materials) | Later, premium skins only | Works on plain Parts, but needs uploaded textures. Test how Part color tints it before committing. |

Other part settings: Reflectance 0. **CastShadow on** for bone parts 1 stud or larger; **off** for teeth, claws, pupils, eyes and pattern bricks (saves shadow-map cost with no visible loss).

SurfaceAppearance only works on MeshParts, so it is not part of this style. It would only matter if we later convert dinos to meshes (not recommended, see 7).

### 1.7 Reading silhouettes at distance
| Range (studs) | What must read | How |
|---|---|---|
| Near, under 40 | Everything: teeth, pupils, claws, patterns, accessories | Full detail |
| Mid, 40-150 | Species (by signature shape), diet (Accent warmth), growth stage (size) | Main masses + signature + Accent color |
| Far, 150-400 | Posture (biped vs quad), size, movement | Silhouette only. Client hides Detail-zone and pattern parts (see 6.4). |
| Beyond streaming radius | Nothing | Not rendered |

Silhouette acceptance test (per species, before sign-off):
1. Render the adult as a pure black shape against white from the side, front and 3/4 at 50, 150 and 300 studs on a phone-sized viewport.
2. Every species must be identifiable by shape alone at 150 studs when lined up with the others.
3. At most **8 main masses** (head, neck, torso, hips, tail, legs, signature). If removing detail parts changes what the dino is, the signature is too small.
4. Two species of the same size class and posture must differ in signature placement (head vs back vs tail).

---

## 2. Dino rig standard

### 2.1 Construction rules
- Built from plain **Parts** (Block, Wedge, CornerWedge). No MeshParts on the body in MVP.
- **Bone parts** are the main visible block of each segment (the head block, the thigh block). Decoration parts (teeth, eye blocks, toes, spikes) are parented **inside** their bone part and joined with a WeldConstraint. This keeps "everything that moves with the head" in one place.
- Bones are joined to each other with **Motor6D**. Bone parts sit flat under the Model, not nested in each other.
- Facing and axes: the Model faces **-Z** (Roblox LookVector), +Y is up. Every bone part is authored axis-aligned with its Front face forward and Top face up, so decal faces mean the same thing on every species (Top = back, Bottom = belly, Left/Right = flanks, Front = face).
- Rest pose (identity Motor6D.Transform) is a neutral standing pose: legs straight down, tail level, head level.
- Joint pivots sit at anatomical pivot points (top center of a leg segment, back center of a head). C0 and C1 are set so the pivot CFrame is shared: `C0 = parent.CFrame:ToObjectSpace(pivot)`, `C1 = child.CFrame:ToObjectSpace(pivot)`.

### 2.2 Standard joint hierarchy
One hierarchy for bipeds and quadrupeds. Bipeds use the Fore chain as tiny arms.

```
HumanoidRootPart            (invisible root and collider; Model.PrimaryPart)
└─ Hips                     (pelvis)
   ├─ Torso                 (chest)
   │  ├─ Neck1 ─ Neck2* ─ Neck3* ─ Neck4* ─ Head ─ Jaw
   │  ├─ ForeUpper_L ─ ForeLower_L* ─ ForeFoot_L*
   │  └─ ForeUpper_R ─ ForeLower_R* ─ ForeFoot_R*
   ├─ Tail1 ─ Tail2 ─ Tail3 ─ Tail4* ─ Tail5* ─ Tail6*
   ├─ HindUpper_L ─ HindLower_L ─ HindFoot_L
   └─ HindUpper_R ─ HindLower_R ─ HindFoot_R
* optional
```

| Bone | Parent | Biped | Quadruped | Notes |
|---|---|---|---|---|
| HumanoidRootPart | none | required | required | Named for Humanoid compatibility even if the systems doc picks a custom controller. Transparency 1. |
| Hips | HumanoidRootPart | required | required | Joint `J_Hips` drives body bob and lean. |
| Torso | Hips | required | required | |
| Neck1 | Torso | required | required | Neck2-4 optional (long necks, Later sauropod). |
| Head | last Neck | required | required | |
| Jaw | Head | required | required | Bite and roar; herbivores still need it for eat. |
| Tail1-3 | Hips / previous | required | required | Minimum 3 segments for a readable sway. |
| Tail4-6 | previous | optional | optional | Large class uses 5-6. |
| HindUpper/Lower/Foot _L/_R | Hips chain | required | required | |
| ForeUpper_L/R | Torso | required | required | Biped tiny arm. |
| ForeLower, ForeFoot _L/_R | Fore chain | optional | required | |

Bone count: biped minimum 17, quadruped minimum 21, maximum 28.

### 2.3 Naming conventions (code contract)
| Thing | Convention | Example |
|---|---|---|
| Bone part | Role name from 2.2, `_L` / `_R` suffix for sides | `HindUpper_L` |
| Motor6D | `J_<ChildBone>`, parented **inside the child bone** (same placement as Roblox R15) | `Head.J_Head` (Part0 = Neck1, Part1 = Head) |
| Decoration part | `D_<Description>`, inside its bone | `Head.D_Tooth_L1` |
| Hitbox part | `HB_<Region>`, flat under the Model | `HB_Head` |
| Cosmetic socket | Attachment `S_<Socket>` on the listed bone | `Head.S_HeadTop` |
| VFX socket | Attachment `FX_<Name>` | `HindFoot_L.FX_Foot_L` |
| Paint zone | Attribute `Zone` (string) on every visible part | `Zone = "Primary"` |
| Model attributes | `Species`, `SizeClass`, `Locomotion` ("Biped"/"Quadruped"), `Diet`, `RigVersion` (number) | `RigVersion = 1` |

Code finds joints through one shared module (proposed `src/shared/Dino/RigMap.luau`) that lists required and optional bones and returns a typed table: `rig.Joints.Head`, `rig.Bones.Tail3`, `rig.Sockets.HeadTop`. Missing optional bones return nil and the animator skips them. Missing required bones are a validator failure (7.3).

### 2.4 Physics flags
| Part type | CanCollide | CanQuery | CanTouch | Massless | Notes |
|---|---|---|---|---|---|
| HumanoidRootPart | true | true | false | false | The only collider, unless the systems doc adds one body collider for large class. |
| Bone and decoration parts | false | false | false | true | Pure visuals: no physics, no raycast hits, no touch events. Big CPU saving. |
| Hitbox parts | false | true | false | true | Collision group `DinoHitbox`. Transparency 1. |

### 2.5 Growth stages: ScaleTo, not per-stage models
**Recommendation: one rig per species, scaled with `Model:ScaleTo()`, with hatchling and juvenile proportion bonuses baked in when the rig is built.**

| Option | Pros | Cons |
|---|---|---|
| **ScaleTo on one rig (recommended)** | One build and one set of cosmetic sockets per species; ScaleTo also scales Motor6D offsets, welds, attachments and (per Roblox docs) effect sizes; supports smooth growth inside a stage; procedural animation is mostly rotations, which do not need scaling | Proportions are uniform unless we add build-time bonuses |
| Separate model per stage | Full control of baby proportions | 4x build, review and cosmetic-fit work per species; swaps pop visually; sockets must match across 4 models |

How it works:
1. The rig builder takes `(species, stage)`. For Hatchling and Juvenile it enlarges Head and eye parts by the bonus in 1.4 and moves the neck joint to match. Sub-adult and Adult use the base build. Bone names and sockets are identical in all stages.
2. The server then calls `model:ScaleTo(stageScale)`. A stage change rebuilds only when crossing Hatchling→Juvenile or Juvenile→Sub-adult (proportion change); otherwise it is a ScaleTo call (smooth growth within a stage is possible if the growth doc wants it).
3. Values that ScaleTo does not cover are reset from data per stage: Humanoid HipHeight (if a Humanoid is used), walk speed, camera distance, procedural stride length (multiplied by `model:GetScale()`).
4. Verify in the prototype: emitter and trail scaling, and HipHeight behaviour under ScaleTo. Where it falls short, code multiplies by `GetScale()`.

Proposed stage scales (relative to adult; game design owns the final numbers):

| Stage | Small | Medium | Large |
|---|---|---|---|
| Hatchling | 0.30 | 0.20 | 0.12 |
| Juvenile | 0.50 | 0.40 | 0.30 |
| Sub-adult | 0.75 | 0.70 | 0.65 |
| Adult | 1.00 | 1.00 | 1.00 |

A Large hatchling comes out about 1.5-2 studs tall, the same size band as other hatchlings, so all hatchlings share nests and hiding spots fairly.

### 2.6 Hitboxes (separate from visuals)
| Hitbox | Welded to | Size | Purpose |
|---|---|---|---|
| HB_Head | Head | 1.2x head block | Head hits (bonus damage if combat wants it) |
| HB_Body | Torso | Covers Hips + Torso | Main body hits |
| HB_Tail | Tail1 | Covers Tail1-3 | Tail hits |
| HB_Neck (optional) | Neck1 | Long necks only | |

- Attack volumes are **not parts**: combat code builds the bite query from `S_Mouth` world CFrame plus a reach value from species data, using `GetPartBoundsInBox` with OverlapParams limited to the `DinoHitbox` group.
- Important: procedural animation runs on clients only (section 3), so **the server sees every dino in rest pose**. Hitboxes follow the rest pose plus root movement. This is intentional: hit detection is deterministic and not affected by animation frames. Hitboxes are sized a little generous to cover the animated range.
- Hitboxes scale with ScaleTo automatically, so growth changes hit size with no extra code.

### 2.7 Part and instance budget per dino
| Class | Visual parts (bones + decoration) | Hitboxes | Attachments (sockets + FX) | Total instances (all, incl. joints, welds, Humanoid) |
|---|---|---|---|---|
| Small | 25-40 | 3 | 16-20 | 140 max |
| Medium | 35-55 | 3-4 | 18-22 | 180 max |
| Large | 45-70 | 3-4 | 20-24 | 220 max |
| AI prey / ambient | 15-25 | 2 | 6 | 80 max |
| Equipped cosmetics (any dino) | +12 parts max | none | uses sockets | +30 instances max |

Hard cap: **80 visual parts** on any player dino including cosmetics.

---

## 3. Animation approach

### 3.1 Comparison
| | Keyframe (Animation Editor, uploaded) | **Procedural (code drives Motor6D.Transform)** |
|---|---|---|
| Who makes it | Someone keys poses in the Animation Editor; each clip must be published as a Roblox asset owned by the experience owner | Claude writes it in Luau; no assets, no uploads |
| Cost for many species | 9 clips x 8 species = 72 clips to key and publish, and every rig change can break them | One shared animator plus a small parameter table per species |
| Growth scaling | Clip translations need to follow model scale (Roblox scales them with ScaleTo, but must be verified per clip) | Mostly rotations; translations multiplied by `GetScale()` |
| Responsiveness | Fixed clips, blends between them | Reacts to real speed, turn rate, slope and stamina; foot timing drives dust VFX exactly |
| Quality ceiling | Highest for hand-crafted hero moves (roars, emotes) | Good for gaits and simple actions; weaker for complex acting |
| Network | Played animations replicate | Nothing replicates; each client animates dinos it can see from replicated state (speed, action) |
| Can Claude do it without the user animating? | Partly: Claude can create KeyframeSequences by script, but authoring blind is slow and the user still has to publish every clip | **Yes, fully** |

**Recommendation: procedural animation for MVP and for all species' core set.** Add keyframed clips Later only for hero moments (emotes, signature roars), when someone is available to key and publish them. The Roblox Studio MCP also lists a `generate_animation` tool; it is worth a 1-hour test on a dino rig, but it is likely aimed at humanoid avatars, so the plan does not depend on it.

### 3.2 How the procedural animator works (design level)
- Client controller (proposed `src/client/Controllers/DinoAnimController.luau`) animates every visible dino rig, including the local player's.
- Inputs per dino, read from replicated attributes the server sets: `Speed` (from root velocity), `Action` (Idle, Bite, Special, Eat, Drink, Rest, Hurt, Dead) and `ActionTime` (server timestamp, so all clients start the action in sync).
- Each frame (RunService.PreSimulation), it writes `Motor6D.Transform` for each joint from a few layered signals:
  1. Gait cycle: phase advances by speed / stride length. Legs swing as sine curves with per-gait offsets (biped alternate; quadruped walk = diagonal pairs offset by 0.25, run = bound).
  2. Body: hips bob twice per cycle, torso counter-rotates, head stabilises toward the look direction.
  3. Tail: a delayed sine wave down Tail1-6 (each segment lags the previous one), plus turn-based sway.
  4. Action overlay: short curve-driven poses (bite = head lunge + jaw open/snap) blended on top with a 0.1 s ease.
- Per-species parameters live in data (proposed `src/shared/Dino/AnimProfiles.luau`): stride length, cadence, leg lift, hip bob, tail amplitude, neck lunge distance, jaw angle, posture lean. A new species usually needs only this table.
- Footfall events from the gait phase fire the dust VFX and footstep sounds at exact contact.
- Performance LOD: see 6.4. Use `--!native` on the animator module.

### 3.3 Minimum animation set per species
| Animation | Procedural method | Duration / loop | MVP? |
|---|---|---|---|
| Idle | Breathing as a small torso pitch rock (rotation only, no part resizing), slow tail sway, random head glance every 3-6 s | loop | Yes |
| Walk | Gait cycle, walk params | loop, speed-driven | Yes |
| Run | Gait cycle, run params (longer stride, more lean, quad switches to bound) | loop, speed-driven | Yes |
| Bite | Head lunge forward + down, jaw open 0.15 s, snap shut, recover | 0.45 s | Yes |
| Special | Per species: roar = head up + jaw wide + body shake; charge = head down lean; tail swipe = hips yaw + tail whip | 0.6-1.2 s | Yes for MVP species |
| Eat / drink | Neck and head down to ground, jaw chew loop (drink = smaller jaw motion, head lower) | loop while active | Yes |
| Rest | Legs fold (upper and lower legs rotate), hips drop via root offset, head down, slow breathing | enter 0.8 s, loop | Yes |
| Hurt | 0.2 s flinch: torso and head jerk away from hit direction | 0.3 s, overlay | Yes |
| Death | Topple onto side (root-relative roll on Hips), legs stiffen, jaw open, then hold for carcass | 1.2 s, then static | Yes |
| Jump / fall, swim | Gait variants | loop | Later (swim when water gameplay lands) |
| Emotes (sit, dance, roar variants) | Keyframed or procedural | | Later (shop) |

Death pose stays as the carcass visual. The carcass is the same model with hitboxes swapped for an eat-interaction volume (systems doc decides the swap).

---

## 4. Cosmetics: how they attach

The contract that keeps cosmetics working across all species and all growth stages: **cosmetics never reference species-specific part names.** They only use paint zones, sockets and bone roles, which every rig has.

### 4.1 Skins (recolors)
| Tier | How | MVP? |
|---|---|---|
| Zone recolor | A skin is a data entry: `{Primary, Secondary, Accent, Detail, Eye, Pupil}` colors plus optional material per zone. Applying it loops the model's parts and sets Color and Material from each part's `Zone` attribute. Works on every species and stage because every rig is zoned. | Yes (one default skin per species; shop skins come in the Shop phase) |
| Pattern bricks | Each species rig includes hidden `Zone = "Pattern"` bricks (thin bands on tail, back and flanks; 6-10 parts). A pattern skin (stripes, bands, spots) turns a named subset visible and colors them. Fully brick-built, no textures, no uploads. | Later |
| Texture overlays | Tileable pattern images (camo, galaxy) as Texture instances on the Top/Left/Right faces of the 6-8 largest Primary parts. Needs uploaded images. | Later |
| Material skins | Zone material overrides (Lava = CrackedLava Accent + Neon cracks, Crystal = ForceField Accent). | Later |
| Scars and markings | Decals on fixed bone faces (Head Left/Right, Torso Left/Right) using the shared axis convention in 2.1. | Later |

Skins never change part count except pattern bricks, which are already in the rig.

### 4.2 Accessories
- Each rig has the standard sockets below. Each socket carries an attribute `SocketScale` (number) so one accessory fits a small head and a large head. Species authors set it when building the rig.
- An accessory is a Model with a root part `Handle` containing an Attachment named the same as its target socket (e.g. `S_HeadTop`). Equip: clone, `accessory:ScaleTo(socket.SocketScale * dino:GetScale())`, align the Handle attachment to the socket, weld Handle to the socket's bone, parent under the dino model. Later dino ScaleTo calls then scale it automatically with growth.
- Optional per-species fit offsets: `FitOffsets = { [Species] = CFrame }` on the accessory data for small corrections. An accessory may list `Excludes = {"Sauropod"}` when it can't fit.
- Accessory visuals: CanCollide/CanQuery/CanTouch false, Massless, all parts zoned `Accessory` (never recolored by skins), max 12 parts.

| Socket | Bone | Slot | Used for |
|---|---|---|---|
| S_HeadTop | Head | Head | Hats, horn caps, crowns |
| S_Face | Head | Face | Glasses, masks, glowing-eye overlays |
| S_Eye_L / S_Eye_R | Head | Face | Eye glow, eye VFX |
| S_Mouth | Jaw | (combat, VFX) | Bite origin, roar effect, held items |
| S_Neck | Neck1 | Neck | Collars, bandanas |
| S_Back | Torso | Back | Spikes, packs |
| S_Saddle | Torso (top, middle) | Back | Saddles (shares slot with S_Back) |
| S_TailTip | last Tail | Tail | Tail rings, tail flames |
| S_Chest | Torso (front) | (VFX) | Auras, roar shockwave origin |

### 4.3 Effects (particles, trails, beams)
| Socket | Bone | Used for |
|---|---|---|
| FX_Foot_L / FX_Foot_R (+ FX_ForeFoot_L/R on quads) | HindFoot / ForeFoot | Footstep dust, cosmetic footstep effects (fired by gait footfalls) |
| FX_Trail_A / FX_Trail_B | Tail3 and last Tail (two points) | Trail cosmetics (fire trail, glitter) |
| FX_Body | Torso center | Auras, bleed drips, heal sparkle |
| FX_Mouth | Jaw tip | Bite impact, roar breath, eat chunks |

- Aura effects use a ParticleEmitter parented to the Torso part with `Shape = Box` and `ShapeStyle = Surface`, so the aura automatically matches each species' body size and growth.
- Cosmetic effects are created and run **on each client**, from an equipped-effect ID the server replicates as an attribute. The server never simulates particles.
- All effect sizes multiply by `dino:GetScale()` if ScaleTo does not already scale them (verify, 2.5).

### 4.4 Compatibility rules (checked by the validator)
1. Every rig has every required bone, zone attribute on every visible part, and every socket in 4.2 and 4.3 with `SocketScale` set.
2. Cosmetics reference only zones, sockets and the bone roles in 2.2.
3. Each new cosmetic is fit-tested on every species at Hatchling and Adult (automated screenshot grid, see 7.2).

---

## 5. VFX and lighting

### 5.1 VFX style
Particles match the brick look: **square particles** (a plain white square texture, tinted), hard-edged, short-lived, no soft smoky blobs. Squash the squares with Size curves instead of using many particles.

Texture needs (one small atlas or 3-4 tiny images, 64x64): white square, square outline (for shockwaves), square with a crack (impact), droplet square. These need uploading once (see 7.4).

### 5.2 MVP VFX list
| Effect | Trigger | Build | Budget (per instance) |
|---|---|---|---|
| Bite hit | Server confirms a hit; clients play it at the hit point | Burst `Emit(8)`: white and Blood Red squares, 0.25 s life, speed 8-12, plus a 0.1 s white flash square. Victim gets a light camera shake (0.15 s, small) on their own client. | 10 particles, 0.3 s |
| Bleed | Victim has the bleed status | Emitter on FX_Body, dark red squares falling with gravity; Rate = 2 / 4 / 8 for light / medium / heavy bleed; Large class 1.5x size, not more particles | 4-16 alive |
| Footstep dust | Gait footfall (Medium and Large always; Small only when running) | `Emit(3)` sand-colored squares, low and slow, 0.6 s life; color picks from the ground material (sand, dirt, ash) | 3-6 alive per dino |
| Sprint / landing dust | Running start, landing | `Emit(6)` ring burst at feet | 6 |
| Water splash | Root enters water or runs in shallow water | `Emit(10)` white-blue squares upward on entry; small ripple ring (flat square outline, grows and fades) every footfall in water | 10 burst, 2 ripples alive |
| Drinking ripples | Drink action | Ripple ring at S_Mouth every 0.8 s | 2 alive |
| Eat chunks | Eat action on carcass | `Emit(2)` meat-red squares from FX_Mouth per chew | 4 alive |
| Death | Death | `Emit(12)` dust squares at the body on topple | 12 |
| Growth up | Stage change | Brief bright square burst around FX_Body + a scale "pop" (0.2 s overshoot to 1.05x) | 16 |
| Night lighting | Clock | See 5.3 | |

Later: roar shockwave (expanding square-outline beam ring, cosmetic color), species special effects, rain, ash fall near volcano, fireflies in forest at night, meteor event, heal/rest sparkle, cosmetic auras and trails.

All combat VFX are cosmetic and client-side; the server only sends "hit at position X, type Y".

### 5.3 Lighting and post-processing
Global settings:
| Setting | Value | Why |
|---|---|---|
| Lighting.Technology | ShadowMap | Crisp sun shadows show off the blocky shapes; Roblox automatically falls back to cheaper lighting on low graphics quality. Future is too costly on mobile for our needs. |
| Atmosphere | On (values per time of day below) | Distance haze sells scale, and also hides the streaming edge. |
| Sky | Custom flat-colored skybox (Later); default sky for MVP | |
| Bloom | Intensity 0.35, Size 24, Threshold 1.4 | Only Neon eyes and bright skins glow; the toy colors stay clean. |
| ColorCorrection | Saturation +0.10, Contrast +0.05 (day) | Pushes the toy palette slightly. |
| SunRays | Intensity 0.05, Spread 0.6 | Subtle, day only. |
| DepthOfField | Off in gameplay | Hurts readability on phones. Photo mode only (Later). |

Time-of-day states (client LightingController tweens between them over 20-40 s; the server owns the clock and replicates it, because night danger is gameplay):

| State | ClockTime | Brightness | Ambient | OutdoorAmbient | Atmosphere Density / Haze / Color | ColorCorrection Tint | Feel |
|---|---|---|---|---|---|---|---|
| Dawn | 6.0 | 1.8 | #3C3A44 | #8A7A88 | 0.32 / 1.5 / #E7B9A2 | #FFE9DC | Pink-gold, long shadows |
| Day | 12.0 | 2.6 | #4A4A4A | #8C8C8C | 0.28 / 1.0 / #C7D6E2 | #FFFFFF | Bright, clean, high color |
| Dusk | 18.0 | 1.6 | #3A3440 | #7A6070 | 0.35 / 2.0 / #E59A6A | #FFE0C8 | Warm orange, warning that night is coming |
| Night | 0.0 | 0.6 | #20263A | #3A4766 | 0.40 / 2.5 / #2A3550 | #C8D4FF, Saturation -0.15 | Blue moonlight, darker but readable |

Night readability rules (mobile screens are dim and often used outdoors):
- Never pitch black: a dino silhouette must be visible against terrain at 60 studs at night on minimum phone brightness.
- The local player's own dino gets a client-only soft PointLight (Range 14 x stage scale, Brightness 0.5, cool white). Others' dinos get no lights (budget). A "night vision" mutation (Later) can raise this.
- Neon eye shine only on dinos within 40 studs (client LOD): it hints "something is watching you" without revealing predators across the map. (Decision 9.)
- Water gets a slight moon specular from the default water settings; no extra lights.

---

## 6. Mobile performance budgets

Target: **30 fps on a low-end phone (about 3 GB RAM, 2019-class)**, 60 fps on mid phones and PC. Server: 30 players + AI.

### 6.1 Scene budgets (what one client sees at once)
| Item | Budget (mobile) | PC | Notes |
|---|---|---|---|
| Player dinos | 30 total, about 15 streamed in near a player | 30 | StreamingEnabled decides what is present |
| AI dinos server-wide | 40 cap (MVP 20) | same | Systems/AI doc owns the cap; rigs at the AI budget in 2.7 |
| Dino visual parts on the client | 2,500 max | 4,000 | 15 x 60 + 25 x 20 + cosmetics, with headroom |
| Dino instances total on the server | about 10,000 (30 x 220 + 40 x 80) | | |
| Whole-place parts streamed in on the client | 25,000 max | 40,000 | Map doc should plan terrain + props inside this |
| Distinct materials on dinos | 1 (SmoothPlastic) + Neon | | Fewer materials, better batching |
| Particles alive on screen | 300 max | 1,000 | Combat bursts use `Emit()`, never long high-Rate emitters |
| Particles per dino (status + cosmetic) | 25 max | 60 | |
| Cosmetic effects running | own dino + 6 nearest within 80 studs | own + 15 | Others show their dino but no effect until in range |
| Trails / Beams on screen | 6 | 20 | |
| Dynamic lights | 2 (own dino light + 1 event) | 8 | |
| Transparent parts on dinos | 0 | 0 | |

### 6.2 Frame-time budget (client, low-end phone, 33 ms frame)
| System | Budget |
|---|---|
| Procedural animation (all dinos) | 1.5 ms |
| VFX simulation and render | 1.5 ms |
| Lighting / shadows | 4 ms |
| Everything else (map render, UI, scripts, physics) | rest |

### 6.3 Memory
Keep client memory under about 1 GB on the low-end target (check in the Developer Console). Brick-built dinos use almost no texture memory, which is a major advantage of this style. The texture budget goes to the world and UI.

### 6.4 Client LOD rules (cheap, because they are local only)
| Distance from camera | Animation rate | Details | Effects |
|---|---|---|---|
| Under 60 studs | Every frame | All | All |
| 60-150 | 30 Hz | All | Status effects yes, cosmetic effects only within 80 |
| 150-300 | 10 Hz, tail and jaw frozen | Detail and Pattern zones hidden (`LocalTransparencyModifier = 1`) | None |
| Over 300 | Frozen | Hidden details | None |

Also scale particle Rate down by the player's graphics quality level (read from UserGameSettings on the client).

### 6.5 How we measure
Before each phase sign-off: spawn 30 player-class dinos (mix of classes, with cosmetics) and 40 AI in a test place, run on the lowest available phone, and capture MicroProfiler frames. Record before/after numbers in this doc. Any system over its budget gets fixed before new content is added.

---

## 7. Production pipeline

### 7.1 Build method: script-built Parts from a data spec
| Method | Verdict |
|---|---|
| **Script-built Parts from a Luau spec (recommended)** | Each species is a data module listing bones, decorations, zones, sockets and hitboxes. A shared builder turns it into a rig. It is versioned in git through Rojo, diffable, rebuildable at any time, guaranteed to meet the rig standard, and Claude can do it entirely through code and Studio previews. |
| Hand-built in Studio | Possible for the user, but slow and inconsistent; breaks naming and sockets unless validated. Fine for small tweaks, followed by an export back to the spec. |
| `generate_mesh` (AI meshes) | Not for dino bodies: organic sculpted results break the brick look, come unrigged, with inconsistent proportions between species and no paint zones. Good for props (rocks, nests, eggs, bones, trees) and maybe accessory shapes. `segment_mesh` and `generate_procedural_model` are worth testing for props too. |
| Convert to MeshParts later | Not recommended: loses per-zone recolors (skins) and adds upload work, for a small part-count gain. |

Proposed files (to be created by the scripting work, not by this doc):
- `src/shared/Dino/RigMap.luau`: bone, socket and zone names (the contract).
- `src/shared/Dino/RigSpecs/<Species>.luau`: one spec per species.
- `src/shared/Dino/RigBuilder.luau`: builds `(species, stage)` into a Model.
- `src/shared/Dino/AnimProfiles.luau`: per-species animation parameters.
- `src/shared/Dino/Skins.luau`: zone color sets.
- `src/tests/RigValidator.spec.luau`: validates every species x stage.

Templates are built once at server start (one per species x stage band) and cloned on spawn.

### 7.2 Per-species workflow (what Claude does)
| Step | Who | Output |
|---|---|---|
| 1. Species card | Game design | Size class, diet, locomotion, signature feature, special move |
| 2. Visual brief | Claude (tech art) | Silhouette description, palette picks, part list, socket placement |
| 3. Rig spec | Claude | `RigSpecs/<Species>.luau` |
| 4. Preview build | Claude, in Studio edit mode via `execute_luau` (inside a ChangeHistory recording, in a dedicated `ArtPreview` folder) | Rig in the place for review |
| 5. Look review | Claude | `screen_capture` from side, front and 3/4, next to an avatar; black silhouette test at 50 / 150 / 300 studs |
| 6. Validator | Claude | Test passes: names, zones, sockets, flags, budgets, 0.5-stud grid |
| 7. Animation profile | Claude | `AnimProfiles` entry; play-test with `start_stop_play`, `video_capture` of idle, walk, run, every action |
| 8. Stage lineup | Claude | All 4 stages side by side with an avatar for scale |
| 9. Cosmetic fit grid | Claude | Every accessory and skin on Hatchling and Adult, captured |
| 10. Perf check | Claude | 30 + 40 spawn test, MicroProfiler numbers |
| 11. Approval | **User** | Yes / change list |

Estimated effort: about 1 working session per species after the first (the first species also builds the builder, animator and validator, about 3-4 sessions).

### 7.3 Validator checks (automatic, blocks a species from shipping)
Required bones present and correctly parented; Motor6D names and placement; every visible part has a valid `Zone`; all sockets present with `SocketScale`; physics flags per 2.4; part and instance counts within 2.7; dimensions on the 0.5-stud grid at adult scale; no transparency or Glass on visuals; hitboxes in the `DinoHitbox` group.

### 7.4 What the user does by hand
| Task | When | Why Claude can't |
|---|---|---|
| Approve the style on the first species (screenshots) | Prototype | Taste call |
| Upload the 3-4 particle textures (or set up an Open Cloud API key in Studio so the upload can be scripted; the user creates and enters the key themselves) | Prototype | Asset uploads need the owner's account and credentials |
| Play on a real phone and report feel, readability and frame rate | Each phase | Claude can only use the Studio Device Simulator, which does not show real phone performance |
| Save and publish the place | When asked | Publishing is the user's call |
| Key and publish any hero keyframe animations (if wanted) | Later | Needs hand animation and publishing |
| Final icon and thumbnails sign-off | Launch | Branding call |

### 7.5 Title ideas (art touches branding)
Brickjaw Island, Primal Bricks, Blockasaur Isle, Fossil Blocks: Survive. All need a Roblox and trademark search before use.

---

## 8. MVP vs Later summary
| Area | MVP | Later |
|---|---|---|
| Species art | Raptor-type (Small carnivore, biped) + 1 Small herbivore AI prey | 6-8 species, Huge class, mythic skins |
| Rig | Full standard, builder, validator, ScaleTo growth | Long-neck support (Neck2-4), boss rigs |
| Animation | Procedural: full 9-animation set | Keyframed emotes and hero roars, swim, jump |
| Skins | Zone recolors (default skin per species) | Pattern bricks, textures, material skins, scars |
| Accessories / effects | Sockets in every rig (no items yet) | Shop items |
| VFX | Bite hit, bleed, dust, splash, ripples, eat, death, growth | Roar shockwave, specials, weather, ambient life |
| Lighting | Day + Night states, ShadowMap, Atmosphere, Bloom | Dawn/Dusk polish, custom sky, weather lighting |

---

## Decisions for the user

1. **How dinos are built**
   - A: Script-built Parts from a Luau spec in git (Claude builds and maintains them). **Recommended.**
   - B: Hand-built in Studio by you.
   - C: AI-generated meshes (`generate_mesh`).
   Recommendation: A. It is the only option that keeps every species on the rig standard and lets Claude do the work.

2. **Animation method**
   - A: Procedural (code-driven Motor6D) for everything. **Recommended for MVP.**
   - B: Animation Editor clips uploaded per species.
   - C: Procedural now, keyframed hero emotes later.
   Recommendation: A now, moving to C when the shop needs emotes. No hand animation needed from you.

3. **Growth scaling**
   - A: One rig per species + `Model:ScaleTo`, with baby head/eye bonuses at build time. **Recommended.**
   - B: Separate hand-made model per stage.
   Recommendation: A (a quarter of the work, and cosmetics fit every stage automatically).

4. **Stage scale numbers** (table in 2.5)
   - A: Accept the proposed scales.
   - B: Let the growth design doc set them and art follows.
   Recommendation: B, using 2.5 as the starting point.

5. **Body material**
   - A: SmoothPlastic everywhere. **Recommended.**
   - B: Plastic (slight grain).
   Recommendation: A, for the clean toy read and exact skin colors.

6. **Skin patterns at launch**
   - A: Zone recolors and material skins only, no uploads.
   - B: Add pattern bricks (stripes, bands) built into every rig.
   - C: Add texture overlays (camo, galaxy), which need uploaded images.
   Recommendation: A for MVP, B in the Shop phase, C only for premium items after launch.

7. **Diet color coding** (predators warm accents and darker bodies, herbivores cool or sunny accents)
   - A: Enforce it for default skins; paid skins are free to break it. **Recommended.**
   - B: Enforce it for all skins.
   - C: No coding.
   Recommendation: A. Readability for free players, freedom for cosmetics.

8. **How dark night gets**
   - A: Readable night (blue moonlight, silhouettes visible at 60 studs, own-dino light). **Recommended.**
   - B: Very dark night; players rely on their own light and eye shine.
   Recommendation: A. Very dark nights are unplayable on many phones.

9. **Eye shine at night**
   - A: Neon eye shine visible only within 40 studs, all dinos. **Recommended.**
   - B: No eye shine.
   - C: Carnivores only (scarier, but gives prey a free warning).
   Recommendation: A.

10. **Particle textures**
    - A: Upload 3-4 small square textures once (needs you, about 10 minutes). **Recommended.**
    - B: Use only Roblox's built-in particle texture (no uploads, but soft round particles that clash with the brick look).
    Recommendation: A.

11. **Player dino controller** (for the systems doc; affects the rig root)
    - A: Humanoid with a custom rig (simplest movement and replication; root stays `HumanoidRootPart`).
    - B: Custom physics controller.
    Recommendation: A for MVP. The rig standard works with either, so this is the systems scripter's call.
