# 05 Technical architecture

Reads with: `AGENT_BRIEF.md`, `00-concept.md`, `02-experience-and-monetization.md`. Gameplay numbers (drain rates, growth times, damage) belong to the game design and economy docs; numbers here are engineering budgets and defaults marked *(tune)*.

Scope: how the code is organised and how the server stays in charge. It fits the existing scaffold: `src/shared/Loader.luau` (direct children only, name-sorted, every `Init` in turn, then every `Start` in its own thread), `Config.luau`, the two thin `Main` bootstraps and the Rojo mapping in `default.project.json`.

**MVP** = Prototype + Core loop phases from the concept (one species, movement, needs, bite, growth, carcasses, AI prey, saving). Everything else is **later**.

---

## 1. Module map

### 1.1 Folder layout

```
src/shared/            -> ReplicatedStorage.Shared   (required on demand, never run by the Loader)
  Config.luau            existing; add tunables (tick rates, caps, grace windows)
  Loader.luau            existing
  Net.luau               remote names, classes, lazy create (server) / lazy resolve (client)
  Signal.luau            ~50-line typed signal (no dependency)
  Types.luau             exported types: SpeciesDef, StageDef, AttackDef, LifeState
  Tags.luau, Attributes.luau   string constants for CollectionService tags and attribute names
  Species/               init.luau (registry + validation) + one file per species (Raptor.luau, ...)
  Wildlife/              NPC species data (Prey, Stalker, ...)
  Logic/                 PURE modules: no require, no game, no Instances (see section 8)
    Needs.luau  Growth.luau  Damage.luau  Hitbox.luau  Movement.luau  Stamina.luau
src/modules/           -> ServerStorage.Modules      (Loader runs direct children)
  <Name>Service.luau     one per system, or <Name>Service/init.luau with private helper children
  Lib/                   Folder, so the Loader skips it: server-only libraries
    Guard.luau  Check.luau  RateLimiter.luau  Scheduler.luau  Targets.luau  ProfileStore.luau (vendored)
src/client/Controllers/ -> StarterPlayerScripts.Client.Controllers (Loader runs direct children)
  <Name>Controller.luau  (helpers nested the same way)
src/tests/             -> ServerStorage.Tests        (never run by the Loader; see section 8)
```

`Lib/` works because `Loader` only collects `ModuleScript` children; a Folder is ignored, and a service written as `Foo/init.luau` becomes one ModuleScript whose children are skipped.

### 1.2 Server services (`src/modules`)

Layer = dependency rank. A module may `require` only modules in a lower layer (L0 = libs). Upward communication goes through signals owned by the lower module.

| Service | L | Responsibility | Requires | Init does | Start does | Phase |
|---|---|---|---|---|---|---|
| DataService | 1 | ProfileStore sessions, schema v1, migrations, coins and slot mutators, purchase-id log. Owns the player lifecycle: emits `ProfileLoaded`, `BeforeRelease`, `ProfileReleased`. | Lib/ProfileStore, Lib/Scheduler | Opens the store (mock in Studio) | Connects `PlayerAdded` + loops existing players, `PlayerRemoving`, `BindToClose` | MVP |
| WorldService | 1 | Runtime folders (`workspace.Dinos`, `Wildlife`, `Carcasses`), tagged world points (water, plants, spawns, Nursery zones), zone queries (`isInNursery(pos)`), map bounds | - | Creates folders (idempotent) | Indexes tagged instances, watches tag add/remove | MVP |
| AnalyticsService | 1 | Thin wrapper over Roblox `AnalyticsService` (funnels, economy, custom events from doc 02 section 6); no-ops in Studio | - | - | - | MVP (light) |
| DinoService | 2 | Owns each player's **LifeState** (species, slot, growth, health, needs, flags). Spawns the dino character, applies stage stats and scale, the single place where death happens. Mirrors state to attributes. Emits `Spawned`, `StageChanged`, `Died`. Remote: `RequestSpawn`, `ReturnToMenu`. | DataService, WorldService, Species, Lib/Targets, Lib/Guard | Sets `Players.CharacterAutoLoads = false`; subscribes to `ProfileLoaded`, `BeforeRelease`; registers remotes | Starts 15 s life-mirror loop | MVP |
| NeedsService | 3 | Hunger, thirst, stamina, health regen, bleed ticks; sprint state. Remotes: `SetSprint`, `SetRest`. Exposes `trySpendStamina`. | DinoService, Logic/Needs, Logic/Stamina, Lib/Scheduler | Subscribes to `Spawned`; registers remotes | 1 Hz needs tick, 5 Hz stamina tick | MVP |
| GrowthService | 3 | Growth progress per tick, stage thresholds, calls `DinoService.setStage` | DinoService, Logic/Growth | Subscribes to `Spawned` | 1 Hz growth tick | MVP |
| CarcassService | 3 | Turns deaths into carcass models with a meat pool; decay timer; cap | DinoService, WorldService | Subscribes to `DinoService.Died` | Decay loop (0.2 Hz) | MVP |
| AntiCheatService | 3 | Movement sampling (speed, teleport, air time), rubber-band, violation log, kick threshold. Also receives `Guard` strike reports. | DinoService, Logic/Movement, Lib/Scheduler | Subscribes to `Spawned`/`Died` | 5 Hz staggered sampler | MVP |
| CombatService | 4 | Attack requests, cooldowns, windup, hit resolution with rewind, damage via `Targets`, combat tag, spawn shield and Nursery modifiers. Remote: `Attack`. | DinoService, NeedsService, WorldService, Logic/Damage, Logic/Hitbox, Lib/Targets | Registers remote | Starts 20 Hz position history sampler | MVP |
| FeedingService | 4 | Eat and drink: server-created ProximityPrompts on tagged sources and carcasses, range and diet checks, feeding channel ticks. Remote: `StopFeeding`. | DinoService, NeedsService, CarcassService, WorldService | Registers remote | Creates prompts on indexed sources; 2 Hz feeding tick | MVP |
| WildlifeService | 5 | NPC population manager, AI state machines, sleeping, NPC damage and death (calls `CarcassService.spawnFrom`) | WorldService, CarcassService, Wildlife, Lib/Targets, Lib/Scheduler | - | Spawns populations, 5 Hz AI tick | MVP |
| GroupService | 3 | Herds/packs: invites, membership, caps, herd TextChannel, map pings | DinoService | Registers remotes | - | Later (doc 02 wants it early; see Decision 12) |
| RewardService | 2 | Daily Forage calendar, Survival Journal one-time rewards | DataService | Subscribes to `ProfileLoaded` | - | Later (first after MVP) |
| DayNightService | 1 | Server clock, `Lighting.ClockTime` replication, night flag for AI | - | - | Clock loop | Later |
| WeatherService | 1 | Weather state machine, attributes for client VFX | - | - | Weather loop | Later |
| NestService | 4 | Nest sites, eggs, herd nest respawn | DinoService, GroupService, DataService | Registers remotes | - | Later |
| PolicyGateService | 1 | Caches `PolicyService:GetPolicyInfoForPlayerAsync` per player; fail closed | - | - | Fetch on join | Later (needed before any shop) |
| ShopService | 3 | Coin purchases, equips, rotation, ownership checks | DataService, PolicyGateService, Catalog | Registers remotes | Rotation timer | Later |
| ReceiptService | 2 | Single `ProcessReceipt`; idempotent via purchase-id log in the profile; game pass checks | DataService | Sets `MarketplaceService.ProcessReceipt` | - | Later |
| LeaderboardService | 3 | `leaderstats` (longest life), weekly `OrderedDataStore` boards | DataService, DinoService | - | Flush loop (60 s) | Later |
| AdminService | 6 | Whitelisted mod tools: kick, spectate, view violations, set NPC density | many | Registers remotes | - | Later |
| EventService | 5 | Boss dino, meteor/volcano events | WildlifeService, WorldService | - | Event scheduler | Later |

### 1.3 Client controllers (`src/client/Controllers`)

| Controller | Responsibility | Requires | Init | Start | Phase |
|---|---|---|---|---|---|
| InputController | One input layer for keyboard, touch and gamepad via `ContextActionService`; touch buttons (Bite, Sprint, Call, Eat/Drink); emits intent signals | - | Creates signals | Binds actions | MVP |
| CharacterController | On every `CharacterAdded`: disables `Dead`/`Climbing` states, sprint prediction (local `WalkSpeed`), plays species animations through the Animator, re-binds after growth rescale | InputController, Species | Subscribes to intents | Hooks `CharacterAdded` (+ current character) | MVP |
| CameraController | Follow camera offset and zoom scaled by growth stage; mobile-friendly | - | - | Watches character `Stage` attribute | MVP |
| SpawnMenuController | Slot list and species pick, `RequestSpawn`, death screen (cause, tip, Respawn) | Net | - | Listens to `LifeEvent` | MVP |
| HudController | Health, hunger, thirst, stamina, growth bars from attributes | Attributes | - | Builds HUD, binds attribute signals | MVP |
| CombatController | Bite input to `Attack`, local windup animation, cooldown display, hit confirm | InputController, Net | Subscribes to intents | Listens to `AttackResult` | MVP |
| FxController | Plays cosmetic effects from the `Fx` unreliable remote (hit flash, roar, footsteps), with a per-frame cap | Net | - | Listens to `Fx` | MVP |
| NotificationController | Toasts from `Notify` | Net | - | Listens to `Notify` | MVP |
| HerdController, MapController | Herd menu, invites, map and pings | Net | - | - | Later |
| ShopController, InventoryController | Shop tabs, ViewportFrame preview, equip | Net | - | - | Later |
| SettingsController, JournalController | Settings, Survival Journal, Daily Forage | Net | - | - | Later |

### 1.4 Shared modules (`src/shared`)

| Module | Responsibility | Phase |
|---|---|---|
| Config | Global tunables (tick rates, caps, grace windows, `UseLiveDataInStudio`) | exists |
| Loader | Lifecycle runner | exists |
| Net | Remote registry (section 4) | MVP |
| Signal | Typed signal for module-to-module events | MVP |
| Types | Shared exported types | MVP |
| Tags, Attributes | Name constants so server and client never drift | MVP |
| Species | Per-species data: stage stats, attacks, diet, rig name, animation ids; `Species.validate()` | MVP |
| Wildlife | NPC data: stats, behaviour params, meat value | MVP |
| Logic/Needs, Growth, Damage, Hitbox, Movement, Stamina | Pure formulas used by server (truth) and client (prediction, UI ETAs) | MVP |
| Catalog | Cosmetics and species prices, rotation pools | Later |
| Products | Game pass and developer product ids | Later |

Server-only pure logic (anti-cheat thresholds, migrations) lives as nested children of its service, e.g. `src/modules/AntiCheatService/Scoring.luau`, `src/modules/DataService/Migrations.luau`, so clients cannot read it.

### 1.5 require vs registry, and Init-order rules

**Use plain `require`, not a registry.** `require` is cached, so `require(script.Parent.DinoService)` returns the same table the Loader started. It keeps `--!strict` types flowing between modules (a string-keyed registry returns `any`), works with editor autocomplete, and costs nothing. A registry only helps with cycles and test injection; we avoid cycles with layers and test pure logic without services.

Init order is alphabetical (AnalyticsService, AntiCheatService, CarcassService, CombatService, DataService, DinoService, ...), so it is **unrelated to dependencies**. These rules make order irrelevant:

| Rule | Why |
|---|---|
| 1. Signals and per-player tables are created at the **top level** of the owning module (no yields). | They exist as soon as the module is required, which is before any `Init`. |
| 2. `Init` only builds own state, registers remotes (`Net` creates lazily) and **connects** to other modules' signals. Never call another service's function that reads state set up in that service's `Init`. Never yield. | Connecting to a signal is safe in any order; calling into an un-initialised service is the classic bug. |
| 3. Anything that **fires** events or touches players happens in `Start` or later. | Every `Init` has finished before the first `Start`, so every subscriber is connected. |
| 4. Only DataService listens to `Players.PlayerAdded`/`PlayerRemoving`. In `Start` it connects **and** loops `Players:GetPlayers()`. Others react to its signals. | One lifecycle source; covers players who joined before `Start` (always true in Studio Play Solo). |
| 5. No circular requires. Lower layers expose functions; higher layers call down or subscribe down. Cross-cutting lookups (who is damageable) go through L0 libs such as `Lib/Targets`. | Luau errors on recursive require. |
| 6. Per-player state is cleared on `DataService.ProfileReleased`, never on a separate `PlayerRemoving` connection. | No races between services on leave. |

Skeleton every service follows:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Needs = require(ReplicatedStorage.Shared.Logic.Needs)
local Scheduler = require(script.Parent.Lib.Scheduler)
local DinoService = require(script.Parent.DinoService)

local NeedsService = {}
local sprinting: { [Player]: boolean } = {} -- rule 1: top-level state

function NeedsService:Init()
	DinoService.Spawned:Connect(function(player: Player) -- rule 2: connect only
		sprinting[player] = false
	end)
end

function NeedsService:Start()
	Scheduler.everyPlayer(1, "Needs", function(player: Player, dt: number) -- rule 3
		local life = DinoService.getLife(player)
		if life then
			Needs.tick(life, DinoService.speciesStage(life), dt)
		end
	end)
end

return NeedsService
```

---

## 2. Player as dino

### 2.1 Options

| | A. Humanoid rig (custom model as `player.Character`) | B. Humanoid + `ControllerManager` (physics character controller) | C. Fully custom physics controller (no Humanoid) |
|---|---|---|---|
| Movement, jump, swim, slopes | Built in | Built in, tunable per controller (ground, air, swim) | All hand-written |
| Mobile thumbstick, gamepad, camera | Default PlayerModule works unchanged | PlayerModule input must be fed to `ControllerManager.MovingDirection` | Write own controls and camera |
| Quadruped feel (turn rate, accel) | Weak: instant turning, Humanoid "biped" feel | Good: turn speed, acceleration, ground sensors | Full control |
| Replication | Client-owned physics, engine replicates | Same | Same (or custom snapshots) |
| Animation replication | Animator on Humanoid, client-played anims replicate | Same | Animator under an AnimationController |
| Build cost | ~1 day | ~3-4 days | 2+ weeks |
| Anti-cheat | Outcome checks (2.4) | Same | Same unless fully server-simulated |

**Recommendation for MVP: A.** Same rig upgrades to B later without remodelling if heavy species feel wrong (the rig and Humanoid stay; only the movement driver changes). Note: Roblox has been rolling out a server-authority mode with client prediction for characters. Check its status when T09 starts; if it is generally available, a half-day spike could remove most movement exploits.

### 2.2 Rig and spawn (option A)

| Item | Spec |
|---|---|
| Auto-spawn | `Players.CharacterAutoLoads = false` (set in the place file and again in `DinoService:Init`). No Roblox avatar is ever loaded. |
| Rig source | One template Model per species in `ReplicatedStorage.Assets.Rigs` (Studio-built, next to Rojo's `Shared`, so it is safe; client needs it for spawn-menu and shop previews). |
| Collision | Only `HumanoidRootPart` collides: one box sized per stage. All visual blocks are `Massless`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, joined with `Motor6D`. |
| Humanoid | `HipHeight` from stage data; `BreakJointsOnDeath = false`; `RequiresNeck = false`; `DisplayDistanceType = None`; Climbing disabled. `Health`/`MaxHealth` fixed at 100 and **never used** (2.3). |
| Spawn flow | `RequestSpawn(slotIndex)` validated → `player:RequestStreamAroundAsync(spawnPos)` → clone rig → apply cosmetics → set stage scale → `PivotTo(spawnPos)` → parent to `workspace.Dinos` → `player.Character = model` → `AntiCheat` grace 3 s → `Spawned` fires. |
| Growth | Stage change rescales **in place** with `Model:ScaleTo(stage.scale)`, then sets `HipHeight`, root size and `WalkSpeed` from data, lifts the model by the height delta, grants 2 s anti-cheat grace. No character swap, so the camera, Animator and ownership stay. Spike T02 must confirm `ScaleTo` keeps Motor6Ds and network ownership. Fallback: one template per stage and swap. |
| Collisions between dinos | Collision groups: `Dino` x `Dino` off and `Dino` x `NPC` off in MVP. Client-owned assemblies colliding with each other is the main fling exploit and causes jitter. See Decision 4. |

### 2.3 Health and death live on the server

The Humanoid only moves the dino. The engine's death path is client-influenced (the owner runs the Humanoid state machine), so:

- Health is a field in the server's `LifeState`, mirrored to the character as attributes `Health`/`MaxHealth`.
- `CharacterController` disables `HumanoidStateType.Dead` locally; the server never lowers `Humanoid.Health`.
- `DinoService.kill(player, cause, killer?)` is the only death path: it clears the slot's life, fires `Died`, ragdolls or tips the model (cosmetic), and `CarcassService` replaces it with a carcass.
- Falling out of the world (`FallenPartsDestroyHeight`) or a removed character counts as death with cause `"Fell"`.

### 2.4 Movement replication, ownership and anti-cheat

The player's client owns its character's physics (engine default, do not change). Positions replicate to the server and on to other clients with interpolation; no custom replication in MVP. Everything else (NPCs, carcasses, props) is server-owned or anchored: `SetNetworkOwner(nil)` on NPC roots, and no unanchored world props.

Because the client owns movement, a cheater can move however they like **locally**. The server can't stop that from happening, only detect the result and undo it:

| Check (AntiCheatService, 5 Hz, staggered across frames) | Rule *(tune)* | Action |
|---|---|---|
| Speed | Horizontal distance per sample vs `Movement.maxSpeed(life) * 1.25 + 4` studs/s. Excess feeds a leaky bucket (leak 6 studs/s, trip at 12 studs). | Trip: `PivotTo(lastValid)`, zero velocity, +1 violation |
| Teleport | One sample moves > 60 studs | Rubber-band immediately, +2 violations |
| Air time | No ground within `HipHeight + 6` studs (server raycast down) for > 3 s while height is not falling; exempt when root is in terrain water (`ReadVoxels` on one voxel) | Rubber-band to last grounded position |
| Noclip | Raycast between consecutive samples against `World` collision group | Log only in MVP |
| Grace | Spawn, `ScaleTo`, server teleports, knockback grant 1-3 s of no checks | - |
| Escalation | Violations decay 1 per 20 s. 10 within a minute: kick with a neutral message, log to analytics. | Week 1 of playtests: **log only**, then enforce (Decision 10) |

`WalkSpeed` hacks are invisible to the server (the client can change it locally), which is why every check is outcome-based. `lastValid` is the last sample that passed all checks.

---

## 3. Server authority: ticks, combat, cooldowns

### 3.1 Tick rates

All loops run from one `Lib/Scheduler` Heartbeat connection that spreads per-player work across frames and wraps each job in `debug.profilebegin(name)`.

| Job | Rate | Notes |
|---|---|---|
| Needs (hunger, thirst, regen, bleed) | 1 Hz per player, staggered | Pure `Needs.tick(state, stats, dt)` |
| Growth | 1 Hz per player | Progresses only while fed and watered above thresholds (design doc) |
| Stamina | 5 Hz | Client predicts for the bar; server is truth and pushes `Stamina` attribute |
| Anti-cheat sampler | 5 Hz | Staggered |
| Combat position history | 20 Hz | Ring buffer of root CFrames, 0.5 s per entity |
| Feeding channel | 2 Hz | Stops when the player moves > 2 studs, attacks or takes damage |
| Wildlife AI | 5 Hz near players, 1 Hz at 150-300 studs, asleep beyond | Section 6 |
| Carcass decay | 0.2 Hz | |
| Life mirror into profile | every 15 s + on stage change + on death | Section 5 |
| Attribute replication | On change only, quantised to integers | Avoids attribute spam |

### 3.2 Hit detection

| Approach | Responsive | Exploit surface | Cost | Verdict |
|---|---|---|---|---|
| Server `GetPartsInPart` with a hitbox part | Laggy for the attacker | Low | Geometry query per attack; hits visual parts; cannot rewind | No |
| Client claims "I hit X", server validates distance/angle/cooldown | Best | Reach within tolerance, target picking | Cheap | Later fallback if feel tests fail |
| **Server resolves with math + rewind** | Good | Low | Very cheap | **MVP** |

MVP pipeline for `Attack(attackIndex)`:

1. `Guard` checks (section 4.3), then CombatService checks: alive, not stunned, attack exists for species and stage, cooldown elapsed (accept `>= cooldown - 0.1 s` for jitter, never queue), `NeedsService.trySpendStamina`.
2. Set cooldown, set attacker combat tag, end spawn shield. Fire `Fx` (attack start) to nearby players except the attacker (who already plays it locally).
3. `task.delay(attack.windup)`. Re-check attacker alive.
4. Broad phase: entities within `attack.range + 15` studs of the attacker root (iterate the `Targets` list, ≤ 70 entities, or `GetPartBoundsInRadius` against a `Hurtbox` collision group if counts grow).
5. Rewind: for each candidate, take its root CFrame from history at `now - clamp(attackerPing/2 + 0.1, 0, 0.2)` (`player:GetNetworkPing()`). Cap 200 ms so lag-switching does not buy reach.
6. Narrow phase: `Hitbox.overlaps(attackBoxCFrame, attackBoxSize, targetCFrame, targetHalfSize)`, an oriented-box test in pure Luau (unit-tested). Attack box = attacker root CFrame times `attack.offset`, size times stage scale, +10% leniency.
7. For each hit: `Damage.compute(attack, attackerStage, victimStage, modifiers)` where modifiers include Nursery and spawn-shield rules from doc 02. Apply via `Targets.get(model).applyDamage(amount, source)`; set victim combat tag; bleed if the attack has it.
8. `AttackResult` to attacker (hit count), `Fx` hit to nearby players.

### 3.3 Cooldowns, combat tag, rate limits

| Item | Rule |
|---|---|
| Cooldowns | Server table `lastUse[player][attackIndex] = os.clock()`. The client shows its own timer from the same species data but never decides. |
| Combat tag | `lastCombatAt` set on dealing or taking damage. 10 s for UI (shop hidden, doc 02); `Config.CombatLogSeconds` (30 s *(tune)*) for the logout rule; blocks `ReturnToMenu`, `SetRest` and slot switching. |
| Remote rate limits | Token bucket per player per remote, defined with each remote (4.2). Over-limit calls are dropped silently. |
| Strikes | Malformed payloads or over-limit calls add strikes; > 30 strikes in 60 s: log + kick. Never throw on bad input (log spam is a DoS vector). |

---

## 4. Remotes

### 4.1 Created from code

Rojo deletes Studio-made children of its mapped folders, so remotes are created by code in a separate folder, `ReplicatedStorage.Remotes`, next to `Shared`.

- `Shared/Net.luau` holds one frozen table: name → class (`RemoteEvent`, `UnreliableRemoteEvent`, `RemoteFunction`).
- Server: the first call to `Net.server(name)` creates the folder and **all** remotes at once (idempotent), so there is no "RemotesService must Init first" ordering bug and clients always see a complete set.
- Client: `Net.client(name)` resolves lazily with `WaitForChild` on first use, warns after 30 s. Controllers use remotes in `Start`, never at require time (the Loader requires one module at a time).
- Never `RemoteFunction:InvokeClient`. Client-to-server `RemoteFunction` is allowed only for request/response menus (spawn, later purchase), with handlers that never yield on the client.

### 4.2 Remote list

Client → server:

| Remote | Class | Payload | Limit (burst / per s) | Server validation | Phase |
|---|---|---|---|---|---|
| RequestSpawn | RemoteFunction | `(slotIndex: number) -> (ok: boolean, reason: string?)` | 2 / 0.5 | Profile loaded; not alive; integer 1..unlocked slots; slot not on cooldown; 5 s after death | MVP |
| ReturnToMenu | RemoteEvent | `()` | 1 / 0.2 | Alive; not combat-tagged; in a Nursery if switching slots (doc 02) | MVP |
| SetSprint | RemoteEvent | `(on: boolean)` | 10 / 5 | Boolean; alive; stamina > 0 to enable | MVP |
| SetRest | RemoteEvent | `(on: boolean)` | 4 / 1 | Boolean; alive; not combat-tagged | MVP |
| Attack | RemoteEvent | `(attackIndex: number)` | 6 / 4 | Integer 1..#attacks for species+stage; section 3.2 | MVP |
| Vocal | RemoteEvent | `(callIndex: number)` | 3 / 0.5 | Integer 1..#calls; cooldown | MVP |
| StopFeeding | RemoteEvent | `()` | 4 / 2 | Alive | MVP |
| *(Eat, Drink)* | ProximityPrompt `Triggered` (server event) | engine-supplied prompt | 4 / 2 | Prompt is one the server created on a tagged source/carcass; re-check distance ≤ prompt range + 4; diet; not full; carcass has meat | MVP |
| HerdInvite | RemoteEvent | `(targetUserId: number)` | 3 / 0.2 | Integer; target in server; not blocked; cap | Later |
| HerdRespond | RemoteEvent | `(inviteId: string, accept: boolean)` | 3 / 0.5 | String ≤ 36 chars, known pending invite for this player | Later |
| HerdLeave / HerdKick | RemoteEvent | `()` / `(userId: number)` | 2 / 0.2 | Membership, leader for kick | Later |
| MapPing | RemoteEvent | `(pingType: number, position: Vector3)` | 3 / 0.3 | Enum 1..5; finite vector inside map bounds | Later |
| ClaimDaily | RemoteEvent | `()` | 1 / 0.1 | Server date vs last claim | Later |
| BuyWithCoins | RemoteFunction | `(itemId: string) -> (ok, reason?)` | 2 / 0.5 | Catalog item; not owned; balance; not combat-tagged | Later |
| Equip | RemoteEvent | `(speciesId: string, slot: string, itemId: string?)` | 5 / 1 | Enum slot; owned item; species valid | Later |
| SaveSettings | RemoteEvent | `(settings: { [string]: any })` | 2 / 0.2 | Whitelisted keys, type and range per key, ≤ 20 keys | Later |
| LayEgg / ChooseNest | RemoteEvent | `()` / `(nestId: string)` | 1 / 0.1 | Adult; nest rules | Later |

Server → client:

| Remote | Class | Payload | Sent to |
|---|---|---|---|
| ProfileSync | RemoteEvent | `{ coins: number, slots: {SlotSummary}, ownedSpecies: {string}, settings: {...} }` | Owner, on load and on change |
| LifeEvent | RemoteEvent | `("Spawned" | "StageChanged" | "Died", data)`; Died: `{ cause: string, killerName: string?, lifeSeconds: number, coins: number }` | Owner |
| AttackResult | RemoteEvent | `(attackIndex: number, hits: number)` | Attacker |
| Notify | RemoteEvent | `(key: string, args: {any}?)` | Owner |
| Fx | UnreliableRemoteEvent | `(fxId: number, source: Instance?, position: Vector3?, value: number?)` (< 900 bytes) | Players within 200 studs |

Live state is **attributes**, not remotes:

| Where | Attributes | Who reads |
|---|---|---|
| Character model | `Species`, `Stage`, `Health`, `MaxHealth`, `Bleeding`, `Shielded`, `HerdId` | Everyone (nameplates, health bars) |
| Player | `Hunger`, `Thirst`, `Stamina`, `Growth`, `CombatTagged` | Owner HUD (visible to all, harmless) |

### 4.3 Validation strategy

Every client-to-server remote is connected through one wrapper, so no handler can skip checks:

```lua
--!strict
-- src/modules/Lib/Guard.luau (sketch)
Guard.on("Attack", {
	limit = { burst = 6, perSecond = 4 },
	args = { Check.integer(1, 8) }, -- exact count: select("#", ...) must equal #args
	gate = DinoService.getLife, -- drop unless this returns non-nil (live dino); passed in, so Guard (L0) requires nothing
}, function(player: Player, life: LifeState, attackIndex: number)
	CombatService.handleAttack(player, life, attackIndex)
end)
```

| Layer | Checks |
|---|---|
| Guard (generic) | Token bucket; exact argument count; per-arg checker; `gate(player)` must return non-nil (`DinoService.getLife` for in-life remotes, `DataService.getProfile` for menu remotes) and its result is passed to the handler |
| `Check` library | `boolean`, `integer(min,max)`, `number(min,max)` rejecting NaN (`x ~= x`) and ±inf, `string(maxLen)`, `enum(set)`, `vector3(bounds)` with finite components, `instanceUnder(folder)` |
| Handler (domain) | Ownership (slot, item, carcass in range), state (alive, cooldown, stamina, combat tag), game rules |

Failures increment strikes (3.3) and return nothing. Tests cover every `Check` function and Guard's arg-count rule.

---

## 5. Data

### 5.1 Library

**ProfileStore** (loleris, successor to ProfileService): session locking, auto-save, `BindToClose` handling, `Reconcile` against a template, a mock store for Studio. Vendor one pinned file at `src/modules/Lib/ProfileStore.luau` with its licence header and version in a comment (section 9). Confirm exact API names against the pinned version's docs when implementing T03.

| Setting | Value |
|---|---|
| Store name | `PlayerData` (data-version lives inside the profile, not in the store name) |
| Key | `"Player_" .. userId` |
| Studio | Mock store unless `Config.UseLiveDataInStudio` is true (Decision 11) |
| Session start | `StartSessionAsync(key, { Cancel = player left })`; on success `AddUserId(userId)` (GDPR erasure), migrate, then `Reconcile` |
| Session end | `OnSessionEnd` → kick if still in game ("Data session ended, please rejoin") |
| Auto-save | ProfileStore's own periodic save; we only keep `profile.Data` current |
| Private servers | Progression writes skipped when owner changed growth speed or PvP (doc 02 Decision 6). Later. |

### 5.2 Save schema v1

Matches doc 02's saved slots (3 free, +3 pass; death resets that slot to a hatchling; equips save per species).

```lua
--!strict
export type SlotLife = {
	speciesId: string,
	growth: number,      -- 0..1 across all stages
	health: number,      -- fraction 0..1, rescaled to stage max on spawn
	hunger: number,      -- 0..1
	thirst: number,      -- 0..1
	bleeding: boolean,
	bornAt: number,      -- os.time(), for "longest life"
	lifeSeconds: number, -- alive time only
}

export type ProfileData = {
	_version: number,                 -- 1
	coins: number,                    -- integer >= 0 (Fossil Coins)
	ownedSpecies: { [string]: true }, -- starter species granted by Reconcile/migration
	slots: { SlotLife | false },      -- index = slot; false = empty; length = unlocked slots
	lastSlot: number,
	cosmetics: {
		owned: { [string]: true },
		equipped: { [string]: { skin: string?, accessories: { string }, effect: string? } }, -- per speciesId
	},
	settings: { hints: boolean, musicVolume: number, sfxVolume: number, cameraShake: boolean },
	stats: { playSeconds: number, deaths: number, kills: number, longestLife: number, adultsReached: number },
	rewards: { dailyDay: number, lastDailyClaim: number, journal: { [string]: true } },
	purchases: { [string]: number },  -- PurchaseId -> os.time(); trimmed to newest 100
	createdAt: number,
	lastSeen: number,
}
```

### 5.3 What persists

| Data | After death | After leaving |
|---|---|---|
| Coins, owned species, cosmetics, settings, stats, rewards | Kept | Kept |
| Slot life (species, growth, needs, health, bleeding) | **Slot reset** (`false`, respawn as hatchling) | Kept, unless combat-logged (below) |
| Position | No | No in MVP: respawn at a Nursery for that species (Decision 3) |
| Stamina, cooldowns, combat tag, sprint, feeding | No | No |
| Herd membership | No | No |
| Nest and eggs | Later design | Later design |

Write rules:

- The slot life is mirrored into `profile.Data.slots[i]` every 15 s, on stage change, and immediately cleared on death. Shutdown order with ProfileStore's own `BindToClose` then does not matter.
- `BeforeRelease(player)` fires synchronously in DataService's `PlayerRemoving` handler before `EndSession`; DinoService writes the final snapshot there (no yields allowed).
- **Combat logging**: if the player leaves while `now - lastCombatAt < CombatLogSeconds`, the slot is written as `false` (dino lost) and the next join shows "Your dino was lost: you left during a fight." Server shutdown never applies this penalty. (Decision 2)
- Coins change only through `DataService.addCoins(player, amount, reason)`: integer, clamped ≥ 0, logged with `AnalyticsService` economy event and ending balance.

### 5.4 Migrations

| Rule | Detail |
|---|---|
| Version field | `_version` integer, `CURRENT_VERSION` in `DataService/Migrations.luau` |
| Order on load | 1. version check, 2. run `Migrations[v]` for each `v` from `_version` to `CURRENT - 1`, 3. `Reconcile()` adds new keys from the template |
| Migration functions | Pure `(data) -> data`, one per step, never edited after release; renames and restructures go here, plain additions only need the template |
| Newer than code | `_version > CURRENT` (an old server during an update): end the session without migrating and kick "Server is updating, rejoin". Prevents an old server writing old-shape data. |
| Tests | Each migration gets a fixture test: v(n) sample in, v(n+1) shape out (section 8) |

---

## 6. AI wildlife

| Topic | MVP design |
|---|---|
| Simulation | Server only. Each NPC: blocky Model, single collider root, `Humanoid` for movement (`MoveTo`), `SetNetworkOwner(nil)`, `ModelStreamingMode = Atomic`. |
| Brain | Small state machine per species from `Wildlife` data: `Idle → Wander → Graze → Drink → Flee`; predators (doc 02's onboarding "Stalker") add `Stalk → Chase → Attack → GiveUp`. |
| Navigation | Steering, not pathfinding: wander targets picked inside the NPC's home zone, 3 forward raycasts for obstacle avoidance, flee = run away from threat with the same avoidance. `PathfindingService` only for rare long trips, later, max 2 computes per second server-wide. |
| Population | `WildlifeService` keeps a target count per zone (`WorldService` zones). Spawns happen 120-300 studs from the nearest player and out of their line of sight. |
| Caps *(tune)* | 40 active NPCs per server, 8 per zone, 30 carcasses (oldest despawns first) |
| Sleeping | Every 2 s, a grid check (64-stud cells) finds NPCs with no player within 300 studs. Asleep NPCs are **despawned to a data record** (species, zone, health) and re-materialised when a player comes within range. Between 150 and 300 studs: 1 Hz brain, no avoidance raycasts. |
| Damage | Each NPC registers with `Lib/Targets`; CombatService treats it like a dino. Death → `CarcassService.spawnFrom(model, meat)`. |
| Budget | AI ≤ 1.5 ms per frame at cap (MicroProfiler label `Wildlife`) |
| Later | Parallel Luau (Actors) for brains if the budget is exceeded; custom snapshot replication via `UnreliableRemoteEvent` for 100+ NPCs; herding behaviour; boss AI. |

---

## 7. Performance

### 7.1 Streaming settings (place file, set by the user or the scripter in Studio)

| Property | Value | Why |
|---|---|---|
| `Workspace.StreamingEnabled` | true | Big island, mobile memory |
| `StreamingMinRadius` | 128 | Fast and large dinos need nearby terrain loaded |
| `StreamingTargetRadius` | 768 *(tune)* | Roblox lowers it on low-memory devices |
| `StreamOutBehavior` | Opportunistic | Frees memory on mobile |
| `StreamingIntegrityMode` | MinimumRadiusPause | Pauses the player instead of letting them fall through unloaded ground after spawn |
| Dino rigs, NPCs, carcasses | `ModelStreamingMode = Atomic` | Never half a dino |
| Map landmarks used by the map UI | `Persistent` (few) | Always available |

### 7.2 Client code rules under streaming

| Rule | Example |
|---|---|
| Never assume a workspace instance exists | No `workspace.Map.River.Water` paths in client code |
| Discover world things by tag | `CollectionService:GetTagged(Tags.WaterSource)` + `GetInstanceAddedSignal` / `GetInstanceRemovedSignal` |
| `WaitForChild` only for own character parts and `ReplicatedStorage`, always with a timeout | `character:WaitForChild("HumanoidRootPart", 10)` |
| Handle stream-out | Effects attached to a model clean up on `Destroying` / tag removed |
| Server prepares streaming before moving a player | `player:RequestStreamAroundAsync(pos)` before spawn and teleports |
| Server sees everything | Server code may index workspace directly |

### 7.3 Budgets *(tune with game-technical-artist)*

| Item | Budget |
|---|---|
| Player dino rig | ≤ 25 parts, 1 collider, ≤ 2 ParticleEmitters (cosmetic effects) |
| NPC rig | ≤ 12 parts |
| Carcass | ≤ 6 parts (separate simple model) |
| Map | Terrain for ground and water; ≤ 25k BaseParts in Workspace at MVP; decor anchored, `CanCollide/CanQuery/CanTouch = false`, `CastShadow = false` on small decor |
| Players per server | 30 (Decision 8) |
| Active NPCs | 40 |
| Server scripts per frame at full load | ≤ 4 ms (Needs 0.2, AntiCheat 0.3, Combat spikes 0.5, Wildlife 1.5, rest 1.5) |
| Client scripts per frame (low-end phone) | ≤ 2 ms |
| Remote traffic | Attributes on change only; `Fx` unreliable and distance-filtered; no per-frame remotes |

Measure with the MicroProfiler (labels from `Scheduler`) and the Developer Console's server stats in a 2-client Studio test plus 40 NPCs.

---

## 8. Testing

### 8.1 What is unit-tested

Pure modules have **no `require`, no `game`, no Instances**; data (species stats, config) is passed in as arguments. That makes them testable both in Studio and outside Roblox.

| Module | Tests |
|---|---|
| Logic/Needs | Drain per second, regen only when fed/watered, bleed, clamps at 0 and 1 |
| Logic/Growth | Stage for progress, no growth when starving, time to adult from data |
| Logic/Damage | Stage scaling, Nursery and shield modifiers, never negative |
| Logic/Hitbox | OBB overlap cases (inside, edge, rotated, behind) |
| Logic/Movement | Max speed per stage and sprint; leaky bucket trip points (`AntiCheatService/Scoring`) |
| Lib/Check, Lib/RateLimiter | Every checker incl. NaN/inf; bucket refill math with an injected clock |
| DataService/Migrations | Fixture in, expected shape out, per version |
| Species data | Every species has 4 stages, positive stats, attack indexes valid (`Species.validate`) |

### 8.2 Harness

A dependency-free `src/tests/TestKit.luau` (~100 lines: `describe`, `it`, `expect(x).toBe/toEqual/toBeNear/toThrow`). Spec files `src/tests/<Name>.spec.luau` return a function and load the module under test by a logical name, so the same spec runs in two places:

```lua
--!strict
return function(t)
	local Growth = t.load("Shared/Logic/Growth")
	t.describe("Growth.stageFor", function()
		t.it("is hatchling below the first threshold", function()
			t.expect(Growth.stageFor(0.1, { 0.25, 0.5, 0.75 })).toBe(1)
		end)
	end)
end
```

| Runner | How `t.load` resolves | How to run |
|---|---|---|
| Studio | `"Shared/..."` → `ReplicatedStorage.Shared...`, `"Modules/..."` → `ServerStorage.Modules...` | `require(game.ServerStorage.Tests.RunAll)()` from the command bar or the Roblox_Studio MCP `execute_luau`; prints pass/fail |
| Lune (CI and local) | `"Shared/..."` → `src/shared/...` file path (`init.luau` aware) | `lune run scripts/test` (runner lives outside `src/`, so Rojo never syncs it) |

`Vector3`/`CFrame` are not Lune globals: the Lune runner injects them from `@lune/roblox`. If a datatype method the Hitbox math needs is missing there, that module keeps its math in plain numbers.

Integration checks stay manual for MVP: Studio play-test (2 clients) through the MCP tools, read console, run the exploit checklist (send garbage to every remote with a test LocalScript in Studio only).

### 8.3 CI

| Step | Status |
|---|---|
| StyLua check, Selene lint, Rojo build | Exists |
| `lune run scripts/test` | Add in T01 (Lune pinned in `rokit.toml`) |
| `luau-lsp analyze` with `rojo sourcemap` and Roblox type definitions (`--!strict` type check) | Add after MVP; catches type errors the build does not |
| In-engine tests via Open Cloud Luau Execution on a test place | Later, optional: needs an API key secret, and secrets are not available to fork PRs on this public repo |

---

## 9. Third-party libraries

| Library | Need | Recommendation |
|---|---|---|
| ProfileStore | Session locking and safe saves are hard to get right | **Vendor** one pinned file in `src/modules/Lib/` (licence header kept) |
| Signal (e.g. GoodSignal / sleitnick Signal) | Module events | **Write our own** ~50 lines in `Shared/Signal.luau` (typed, no deferred-event surprises) |
| Promise | Async chains | **Skip**: `task.spawn/defer/delay` plus `pcall` cover our cases |
| Jest-Lua | Test framework | **Skip for MVP**: TestKit + Lune are enough; revisit if tests grow past ~200 cases |
| Matter/ECS, Knit, networking libs | Frameworks | **Skip**: the Loader plus `Net`/`Guard` already cover it, and frameworks add lifecycle rules that conflict with the Loader |

**Stay dependency-free (no Wally) for the MVP.** If Wally is adopted later:

| Change | Detail |
|---|---|
| `wally.toml` | `[dependencies]` (shared) and `[server-dependencies]` |
| `rokit.toml` | add `UpliftGames/wally` and `JohnnyMorganz/wally-package-types` (restores strict types through Wally's link modules) |
| `default.project.json` | Under `ReplicatedStorage`: `"Packages": { "$path": "Packages" }`. Under `ServerStorage`: `"ServerPackages": { "$path": "ServerPackages" }`. Both sit next to the existing mapped folders, not inside them. |
| Workflow | `wally install` then `rojo sourcemap default.project.json -o sourcemap.json` then `wally-package-types --sourcemap sourcemap.json Packages/`; `sync.cmd` runs `wally install` first |
| CI | Same install steps before build and tests; `Packages/` and `ServerPackages/` gitignored |
| Lint | StyLua and Selene already scan only `src`, so packages are not linted |

---

## 10. MVP build order (tickets)

Owner is `roblox-systems-scripter` unless noted. Each ticket ends with: Rojo build passes, `stylua`/`selene` clean, tests pass, Studio play-test with console clean, and a short exploit review of any new remote.

### Prototype (week 1)

| # | Ticket | Done when |
|---|---|---|
| T01 | Foundations: `Signal`, `Net`, `Types`, `Tags`, `Attributes`, `Lib/Check`, `Lib/RateLimiter`, `Lib/Guard`, `Lib/Scheduler`, `Lib/Targets`, `TestKit`, Studio `RunAll`, Lune runner, CI test step | Specs for Check/RateLimiter pass in Studio and CI; a dummy remote rejects bad args and floods |
| T02 | Spike: Raptor rig (blocky, Humanoid, single collider, Motor6D visuals), `CharacterAutoLoads` off, `ScaleTo` at 4 stage sizes; verify ownership after scale, mobile thumbstick, camera. Rig art: `game-technical-artist`. | Written result: ScaleTo in place works or fall back to per-stage templates |
| T03 | DataService: vendored ProfileStore, mock in Studio, schema v1, migration scaffold + tests, `ProfileLoaded/BeforeRelease/ProfileReleased`, `addCoins` | Join/leave/rejoin keeps data in live-data test; migration specs pass |
| T04 | `Species` (Raptor), `Logic/Movement`, DinoService: `RequestSpawn`, LifeState, attributes, `kill`, carcass-less death, respawn; SpawnMenuController minimal | Spawn, die (debug command), respawn as hatchling |
| T05 | InputController (keyboard/touch/gamepad), CharacterController (states, animations), CameraController | Playable on PC and Studio's phone emulator |
| T06 | `Logic/Needs`, `Logic/Stamina`, NeedsService (`SetSprint`, `SetRest`), HudController | Bars drain and regen; starving kills; sprint drains stamina server-side |
| T07 | WorldService, FeedingService with ProximityPrompts on tagged water and plant sources. Test terrain with a river and plants: `game-level-designer` | Drink and graze refill needs; prompts rejected out of range |
| T08 | `Logic/Damage`, `Logic/Hitbox`, CombatService (bite, cooldown, rewind, combat tag), CombatController, FxController; dummy target NPC | Two-client bite works at 150 ms simulated latency; cooldown spam rejected |
| T09 | AntiCheatService (speed, teleport, air time; log-only mode switch) | Speed and teleport exploits from a Studio test script are detected; no false positives in 20 min normal play |

### Core loop (weeks 2-3)

| # | Ticket | Done when |
|---|---|---|
| T10 | `Logic/Growth`, GrowthService, stage rescale and stat curves, `LifeEvent StageChanged` | Hatchling → Adult at debug speed with correct size and stats |
| T11 | CarcassService: death → carcass, meat pool, decay, cap; carnivore eating via FeedingService | Kill → carcass → eat → meat runs out → carcass gone |
| T12 | `Wildlife` data, WildlifeService: one prey species, state machine, steering, populations, sleeping, NPC damage → carcass | 40 NPCs within AI budget; NPCs sleep when nobody is near |
| T13 | Slot persistence: mirror life to slot, restore on spawn, combat-log rule, death clears slot, coins for survival time and stages, death screen | Grow, leave, rejoin: same growth; leave mid-fight: dino lost |
| T14 | Exploit and performance pass: every remote fuzzed, MicroProfiler at 2 clients + 40 NPCs, streaming on phone emulator; `code-reviewer`, then `qa-tester` | All budgets in 7.3 met; zero accepted malformed payloads |

### First after MVP (ordered)

PolicyGateService → RewardService (Daily Forage) → GroupService + herd chat + map pings → DayNightService → species 2-8 + biomes → Stalker onboarding predator → ShopService + ReceiptService → LeaderboardService → AdminService → NestService.

---

## Decisions for the user

1. **Character technology.** (a) Humanoid rig as `player.Character`; (b) Humanoid + ControllerManager; (c) custom physics controller. **Recommend (a)** for MVP, with (b) as the upgrade path for heavy species. It's the same rig either way.
2. **Logging out during a fight.** (a) Slot is lost if you leave within 30 s of combat; (b) no penalty; (c) the dino stays in the world for 30 s after you leave (more work). **Recommend (a)**: simple, and it stops players escaping death by leaving.
3. **Save position between sessions.** (a) No, respawn at a Nursery for your species; (b) save position. **Recommend (a)** for MVP: no spawning inside enemies or in map areas that changed.
4. **Collisions in MVP.** (a) Dinos pass through other dinos and NPCs; (b) full collisions. **Recommend (a)**: it removes the fling exploit and jitter. Revisit body-blocking later with server-side pushback.
5. **Hit detection.** (a) Server resolves hits with math and ≤ 200 ms rewind; (b) client claims hits, server validates. **Recommend (a)**, with (b) kept as a fallback if playtests feel laggy.
6. **Dependencies.** (a) No Wally; vendor ProfileStore and write a tiny Signal; (b) adopt Wally now. **Recommend (a)** for MVP.
7. **Testing.** (a) In-house TestKit run in Studio and in CI through Lune; (b) Jest-Lua via Wally; (c) Studio-only manual tests. **Recommend (a).**
8. **Server size.** (a) 30; (b) 20; (c) 50. **Recommend (a)**: lively enough for herds and hunting, fits the NPC and script budgets on mobile.
9. **Active NPC cap.** (a) 40; (b) 25; (c) 80 with custom replication (later work). **Recommend (a).**
10. **Anti-cheat enforcement.** (a) Log only during week-1 playtests, then rubber-band, with kicks only for repeat offenders; (b) enforce from day one. **Recommend (a)** to tune thresholds without punishing real players.
11. **Data in Studio.** (a) Mock store by default, live data only with `Config.UseLiveDataInStudio`; (b) always live (needs Studio API access on). **Recommend (a)**: play-tests can't corrupt real saves.
12. **Herds in MVP.** Doc 02 lists basic herds, herd chat and pings as MVP, but the concept puts them after the core loop. (a) First feature after the core loop; (b) inside MVP. **Recommend (a)** to keep the MVP to systems one person can test alone.
