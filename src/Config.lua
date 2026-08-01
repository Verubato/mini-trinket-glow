local addonName, addon = ...
---@type MiniFramework
local mini = addon.Framework
local verticalSpacing = 20
local db
---@class Db
local dbDefaults = {
	CombatOnly = true,
}
local M = {}
addon.Config = M

function M:Init()
	db = mini:GetSavedVars(dbDefaults)

	local panel = CreateFrame("Frame")
	panel.name = addonName

	local category = mini:AddCategory(panel)

	if not category then
		return
	end

	local header = mini:PanelHeader({
		Parent = panel,
		Description = "Glow trinkets on your action bars when they're off cooldown.",
		Gap = 8,
	})

	local combatOnlyChk = mini:Checkbox({
		Parent = panel,
		LabelText = "Combat only",
		Tooltip = "Only glow when in combat.",
		GetValue = function()
			return db.CombatOnly
		end,
		SetValue = function(enabled)
			db.CombatOnly = enabled
            addon:Run()
		end,
	})

	combatOnlyChk:SetPoint("TOPLEFT", header.Anchor, "BOTTOMLEFT", 0, -verticalSpacing)

	SLASH_MINITRINKETGLOW1 = "/minitrinketglow"
	SLASH_MINITRINKETGLOW2 = "/minitg"
	SLASH_MINITRINKETGLOW3 = "/mtg"

	mini:RegisterSlashCommand(category, panel)
end
