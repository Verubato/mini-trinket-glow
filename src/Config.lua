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

	local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 0, -verticalSpacing)
	title:SetText(string.format("%s - %s", addonName, version))

	local description = panel:CreateFontString(nil, "ARTWORK", "GameFontWhite")
	description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	description:SetText("Glow trinkets on your action bars when they're off cooldown.")

	local combatOnlyChk = mini:CreateSettingCheckbox({
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

	combatOnlyChk:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -verticalSpacing)

	SLASH_MINITRINKETGLOW1 = "/minitrinketglow"
	SLASH_MINITRINKETGLOW2 = "/minitg"
	SLASH_MINITRINKETGLOW3 = "/mtg"

	mini:RegisterSlashCommand(category, panel)
end
