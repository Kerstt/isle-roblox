--!strict
--[[
	CollisionGroups: PhysicsService collision group names, so server and client code never drift apart.
	Every value equals its key (a spec checks this). DinoService registers them at server start.

	| Group      | Parts                                   | Rule (doc 05 section 2.2, doc 04 section 2.4)        |
	|------------|-----------------------------------------|------------------------------------------------------|
	| Dino       | Every dino's HumanoidRootPart (collider) | Dino x Dino off (fling exploit, jitter; Decision 4)  |
	| DinoHitbox | HB_ hitbox parts (CanCollide off)        | Query-only; must equal RigMap.HitboxCollisionGroup    |

	Later: NPC (Dino x NPC off), World (anti-cheat noclip raycasts).
]]

local CollisionGroups = table.freeze({
	Dino = "Dino",
	DinoHitbox = "DinoHitbox",
})

return CollisionGroups
