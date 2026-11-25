--!strict
--[[
	Check: argument checkers for client-to-server remotes, used by Lib/Guard.

	A checker is a function (value: any) -> boolean. Every function here is a factory that returns a checker:

		args = { Check.integer(1, 8), Check.boolean(), Check.optional(Check.string(36)) }

	Checkers never throw on bad input: they return false and Guard drops the call. Bad factory arguments (a
	programmer error, found when the remote is registered) do throw.

	Numbers: NaN (x ~= x) and +/-inf are always rejected, because they pass naive range checks and poison maths.

	Pure: no require, no `game`, so it runs under Lune.
]]

export type Checker = (value: any) -> boolean

local Check = {}

-- Checkers made by Check.optional. Weak keys, so unused checkers can be collected.
local optionalCheckers: { [Checker]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function assertRange(min: number, max: number, what: string): ()
	assert(isFiniteNumber(min) and isFiniteNumber(max), what .. ": min and max must be finite numbers")
	assert(min <= max, what .. ": min must be <= max")
end

-- True for a real, finite number (not NaN, not +/-inf).
Check.isFinite = isFiniteNumber

function Check.boolean(): Checker
	return function(value: any): boolean
		return type(value) == "boolean"
	end
end

-- A whole number in [min, max].
function Check.integer(min: number, max: number): Checker
	assertRange(min, max, "Check.integer")
	return function(value: any): boolean
		return isFiniteNumber(value) and value == math.floor(value) and value >= min and value <= max
	end
end

-- Any finite number in [min, max].
function Check.number(min: number, max: number): Checker
	assertRange(min, max, "Check.number")
	return function(value: any): boolean
		return isFiniteNumber(value) and value >= min and value <= max
	end
end

-- A valid UTF-8 string of at most maxLength BYTES (and at least minLength bytes, default 0). Lengths are bytes,
-- not characters: "é" is 2 bytes. Bytes are what cost memory and bandwidth, so that is what the limit protects.
function Check.string(maxLength: number, minLength: number?): Checker
	local min = minLength or 0
	assertRange(min, maxLength, "Check.string")
	return function(value: any): boolean
		return type(value) == "string" and #value >= min and #value <= maxLength and utf8.len(value) ~= nil
	end
end

-- One of the listed values (compared with ==, so strings and numbers work; NaN never matches).
function Check.enum(values: { any }): Checker
	assert(type(values) == "table" and #values > 0, "Check.enum: values must be a non-empty list")
	local allowed: { [any]: boolean } = {}
	for _, value in values do
		allowed[value] = true
	end
	return function(value: any): boolean
		return value ~= nil and allowed[value] == true
	end
end

-- A Vector3 with finite components inside the box [min, max] (both required: positions are always bounded,
-- for example by the map bounds). Bounds must be finite with min <= max on every axis.
function Check.vector3(min: Vector3, max: Vector3): Checker
	assert(typeof(min) == "Vector3" and typeof(max) == "Vector3", "Check.vector3: min and max Vector3 bounds required")
	assertRange(min.X, max.X, "Check.vector3 (X)")
	assertRange(min.Y, max.Y, "Check.vector3 (Y)")
	assertRange(min.Z, max.Z, "Check.vector3 (Z)")
	return function(value: any): boolean
		if typeof(value) ~= "Vector3" then
			return false
		end
		local x, y, z = value.X, value.Y, value.Z
		if not (isFiniteNumber(x) and isFiniteNumber(y) and isFiniteNumber(z)) then
			return false
		end
		return x >= min.X and x <= max.X and y >= min.Y and y <= max.Y and z >= min.Z and z <= max.Z
	end
end

-- An Instance that is a descendant of `ancestor` (not the ancestor itself).
function Check.instanceUnder(ancestor: Instance): Checker
	assert(typeof(ancestor) == "Instance", "Check.instanceUnder: ancestor must be an Instance")
	return function(value: any): boolean
		return typeof(value) == "Instance" and value:IsDescendantOf(ancestor)
	end
end

-- Accepts nil, or whatever `checker` accepts. Guard lets trailing optional arguments be left out.
function Check.optional(checker: Checker): Checker
	assert(type(checker) == "function", "Check.optional: checker must be a function")
	local function optional(value: any): boolean
		return value == nil or checker(value)
	end
	optionalCheckers[optional] = true
	return optional
end

function Check.isOptional(checker: Checker): boolean
	return optionalCheckers[checker] == true
end

return table.freeze(Check)
