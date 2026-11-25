--!strict
--[[
	Growth: pure growth-stage helpers shared by server (truth) and clients (UI, camera).

	Pure (doc 05 section 8.1): no require, no `game`, no Instances. Species data is passed in.
	T02 adds the stage lookup the spike needs; T10 adds progress, thresholds and stat interpolation here.
]]

local Growth = {}

Growth.StageCount = 4
Growth.StageNames = table.freeze({ "Hatchling", "Juvenile", "Sub-adult", "Adult" })

-- True for a whole-number stage index 1..4 (rejects NaN, infinities, fractions and non-numbers).
function Growth.isStage(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= 1 and value <= Growth.StageCount
end

-- The stage entry for `stage` from a species' stage list, or nil when the index is not a valid stage
-- or the list does not have it. Generic, so it returns whatever stage type the caller passes in.
function Growth.stageAt<T>(stages: { T }, stage: any): T?
	if not Growth.isStage(stage) then
		return nil
	end
	return stages[stage]
end

return table.freeze(Growth)
