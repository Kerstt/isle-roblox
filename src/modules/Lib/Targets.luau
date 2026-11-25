--!strict
--[[
	Targets: the registry of everything that can take damage (player dinos, NPCs, test dummies).

	It sits in layer 0 so CombatService can damage an NPC without requiring WildlifeService, and WildlifeService
	can find dinos without requiring CombatService (doc 05 section 1.5, rule 5). Owners register a model with
	callbacks; the combat code only ever talks to the Target.

		Targets.register(model, {
			kind = "NPC",
			getRoot = function() return model.PrimaryPart end,
			applyDamage = function(amount: number, source: any?) ... end,
		})
		local target = Targets.get(model) -- or Targets.findFromPart(hitPart)

	A model that is an Instance unregisters itself when it is destroyed. register returns an unregister function.
	Owners must either Destroy the model or call that function when the target goes away (death, despawn,
	sleeping NPCs): parenting a model to nil does NOT unregister it, and plain-table models never auto-unregister.
	Pure: no require, no `game`, so it runs under Lune (specs use plain tables as models).
]]

export type Kind = "Dino" | "NPC" | "Dummy"

export type Target = {
	kind: Kind,
	player: Player?, -- the owning player, for player dinos
	getRoot: () -> BasePart?,
	applyDamage: (amount: number, source: any?) -> (),
}

type Entry = { model: any, target: Target, connection: RBXScriptConnection? }

local Targets = {}

local entries: { [any]: Entry } = {}
local order: { any } = {} -- models in registration order, for stable iteration

function Targets.unregister(model: any): ()
	local entry = entries[model]
	if entry == nil then
		return
	end
	entries[model] = nil
	local index = table.find(order, model)
	if index then
		table.remove(order, index)
	end
	if entry.connection then
		entry.connection:Disconnect()
	end
end

function Targets.register(model: any, target: Target): () -> ()
	assert(model ~= nil, "Targets.register: model is required")
	assert(type(target) == "table", "Targets.register: target must be a table")
	assert(type(target.kind) == "string", "Targets.register: target.kind is required")
	assert(type(target.getRoot) == "function", "Targets.register: target.getRoot is required")
	assert(type(target.applyDamage) == "function", "Targets.register: target.applyDamage is required")

	Targets.unregister(model) -- registering again replaces the old entry
	local entry: Entry = { model = model, target = target, connection = nil }
	if typeof(model) == "Instance" then
		entry.connection = model.Destroying:Connect(function()
			Targets.unregister(model)
		end)
	end
	entries[model] = entry
	table.insert(order, model)

	return function()
		if entries[model] == entry then
			Targets.unregister(model)
		end
	end
end

function Targets.get(model: any): Target?
	local entry = entries[model]
	return if entry then entry.target else nil
end

-- The target that owns `instance`: the instance itself or its nearest registered ancestor.
function Targets.findFromPart(instance: any): (Target?, any)
	local node = instance
	while node ~= nil do
		local entry = entries[node]
		if entry then
			return entry.target, node
		end
		node = node.Parent
	end
	return nil, nil
end

function Targets.count(): number
	return #order
end

-- A snapshot list of { model, target } pairs in registration order; safe to change the registry while iterating.
function Targets.list(): { { model: any, target: Target } }
	local result = table.create(#order)
	for _, model in order do
		table.insert(result, { model = model, target = entries[model].target })
	end
	return result
end

return table.freeze(Targets)
