--!strict
--[[
	Palette: the project's original colour swatches (doc 04 section 1.5). Rig specs and skins name swatches from
	this table only, so the whole roster reads as one set. Values are hex strings, not Color3, so the module stays
	pure (it loads under Lune too); builders convert with Color3.fromHex.

	Keep it at about 30 swatches until launch. Add a swatch here (and to doc 04) before any spec uses it.
]]

local Palette = table.freeze({
	-- Neutrals
	Bone = "#E8DCC0",
	BellyCream = "#F2EDE3",
	EyeWhite = "#F4F1EA",
	PupilBlack = "#1E1E22",
	ClawGray = "#4A4744",
	-- Carnivore accents
	BloodRed = "#B23A2E",
	EmberOrange = "#E0672B",
	Rust = "#8C4A2F",
	-- Herbivore accents
	SunYellow = "#E8B931",
	Teal = "#2F9C95",
	SkyBlue = "#5BA4CF",
	-- Forest
	Moss = "#3E6B35",
	Leaf = "#8DA34A",
	Bark = "#5C4630",
	-- Swamp
	Olive = "#4F5B2E",
	MurkTeal = "#3B5A55",
	Reed = "#7A6E45",
	-- Desert
	Sand = "#C9A26B",
	Terracotta = "#B8613A",
	Dust = "#8A6A4A",
	-- Volcano
	Basalt = "#3A3533",
	Ash = "#5A4A45",
	Ember = "#C2452D",
	-- River / coast
	SlateBlue = "#4C6E7F",
	Pebble = "#8FA9A8",
	Shell = "#D9CFB4",
})

return Palette
