# Carry-over notes for later tickets

Things found during reviews and QA that belong to a later ticket. Each ticket's lead agent reads its section before starting, and the orchestrator ticks items off when they land.

## T03 DataService
- [ ] Call `Guard.forget(player)` on ProfileReleased. Guard holds players weakly until then (from T01).

## T04 DinoService / death
- [ ] DinoService owns death: `kill` becomes the only death path. Don't trust `Humanoid.Died` from a client-owned character. Today the owning client can trigger a free respawn (a teleport to spawn) by (from T02 review):
  - the Reset button (disable `StarterGui:SetCore("ResetButtonCallback", false)`),
  - `Humanoid:ChangeState(Dead)` (the Dead state replicates from the network owner),
  - deleting its own HumanoidRootPart or Humanoid (deletions of your own character's parts replicate).
- [ ] Spawn via `DataService.ProfileLoaded` + `RequestSpawn` instead of `PlayerAdded`.
- [ ] Replace the default character sounds (`RbxCharacterSounds`, including the death sound) (from T02 QA).
- [ ] The SpawnLocation lookup does a recursive Workspace search on every spawn. Use tagged spawn points (T07).

## T05 Controllers / animation
- [ ] Grow the spike `DinoAnimController` into the shared animator from doc 04 §3: action overlays, and dead dinos stop breathing and swaying.
- [ ] Scale JumpHeight with the growth stage (a hatchling currently jumps 7.2 studs) (from T02).

## T08 Combat
- [ ] Don't trust that `HB_` hitbox parts still exist in a client-owned character: the client can delete them. Build server-side hit volumes from the species data (from T02 review).

## T09 Anti-cheat
- [ ] Install `Guard.setHooks`, and decide whether rate-limit drops count as strikes (laggy clients send bursts) (from T01).
- [ ] Give a grace window after ScaleTo: rescaling lifts the root, and total speed briefly reaches about 18.7 studs/s (from T02).

## T10 Growth
- [ ] Hatchling and Juvenile need the doc 04 head and eye bonus, which needs a rebuild when crossing those stages. T02 uses adult proportions at every stage.
- [ ] ScaleTo on a moving dino can snap the owner back by about speed × ping. Consider applying stage changes only while standing still, or smoothing them (from T02 review).
- [ ] Gameplay stage scales come from `Shared/Species/*` (doc 01: 0.37 / 0.58 / 0.79 / 1.0 for Small). `RigMap.PreviewStageScales` is for previews only.

## Before launch
- [ ] Two-player check in Studio (Test > Clients and Servers): a second player sees the dino animate and rescale. The MCP tools can't start a multi-client test, so the user runs it by hand (from T02 QA).
