local _, addon = ...
---@type MiniFramework
local mini = addon.Framework
local eventsFrame
local trinketSlot1 = INVSLOT_TRINKET1 or 13
local trinketSlot2 = INVSLOT_TRINKET2 or 14
local buttonPrefixes = {
	"ActionButton",
	"MultiBarBottomLeftButton",
	"MultiBarBottomRightButton",
	"MultiBarRightButton",
	"MultiBarLeftButton",
	"MultiBar5Button",
	"MultiBar6Button",
	"MultiBar7Button",
}
local LCG = LibStub and LibStub("LibCustomGlow-1.0", false)
local lastTrinketStart = {
	[trinketSlot1] = 0,
	[trinketSlot2] = 0,
}
---@type Db
local db

local function GetEquippedTrinketItemID(slot)
	return GetInventoryItemID("player", slot)
end

local function ParseMacroForTrinketSlot(body)
	if not body or body == "" then
		return nil
	end

	for line in body:gmatch("[^\r\n]+") do
		line = line:lower()
		-- collapse whitespace
		line = line:gsub("%s+", " "):gsub("^%s+", "")

		if line:sub(1, 4) == "/use" then
			-- /use 13
			-- /use    13
			-- /use [combat] 13
			-- /use [mod:shift,@player]14
			if line:find(" " .. trinketSlot1, 5, true) then
				return trinketSlot1
			end
			if line:find(" " .. trinketSlot2, 5, true) then
				return trinketSlot2
			end
		end
	end

	return nil
end

local function GetMacroBodyFromAction(action)
	-- GetActionText returns the macro name when the action is a macro
	local macroName = GetActionText(action)

	if not macroName or macroName == "" then
		return nil
	end

	local macroIndex = GetMacroIndexByName(macroName)

	if not macroIndex or macroIndex == 0 then
		return nil
	end

	local _, _, body = GetMacroInfo(macroIndex)
	return body
end

local function GetTrinketSlotForAction(action)
	local actionType, id = GetActionInfo(action)

	if actionType == "item" and id then
		local t1 = GetEquippedTrinketItemID(trinketSlot1)
		local t2 = GetEquippedTrinketItemID(trinketSlot2)

		if t1 and id == t1 then
			return trinketSlot1
		end

		if t2 and id == t2 then
			return trinketSlot2
		end

		return nil
	end

	if actionType == "macro" then
		local body = GetMacroBodyFromAction(action)
		return ParseMacroForTrinketSlot(body)
	end

	return nil
end

local function CheckTrinketUsed(slot)
	local start, duration, enable = GetInventoryItemCooldown("player", slot)

	if enable ~= 1 then
		return false
	end

	if duration and duration > 0 and start and start > 0 then
		if start ~= lastTrinketStart[slot] then
			-- cooldown changed; if it just started, count it as "used"
			lastTrinketStart[slot] = start
			return true, start, duration
		end
	end

	return false
end

local function Glow(button, enable)
	if enable then
		if LCG then
			if not button.MiniTrinketGlow then
				LCG.ProcGlow_Start(button, {
					color = nil,
					startAnim = true,
					duration = 1,
					xOffset = 0,
					yOffset = 0,
					key = "",
				})
				button.MiniTrinketGlow = true
			end
		else
			if ActionButton_ShowOverlayGlow then
				ActionButton_ShowOverlayGlow(button)
			end
		end
	else
		if LCG then
			LCG.ProcGlow_Stop(button)
			button.MiniTrinketGlow = false
		elseif ActionButton_HideOverlayGlow then
			ActionButton_HideOverlayGlow(button)
		end
	end
end

local function Run()
	for _, prefix in ipairs(buttonPrefixes) do
		for i = 1, 12 do
			local button = _G[prefix .. i]

			if button and button.action then
				local slot = GetTrinketSlotForAction(button.action)

				if slot then
					local start, duration, usable = GetInventoryItemCooldown("player", slot)
					local onCD = usable == 1 and start > 0 and duration > 0
					local inCombat = UnitAffectingCombat("player")
					local onlyCombat = db.CombatOnly
					local glow = not onCD and (not onlyCombat or inCombat)

					Glow(button, glow)
				end
			end
		end
	end
end

function addon:Run()
	Run()
end

local function OnEvent(_, event, ...)
	if event == "PLAYER_EQUIPMENT_CHANGED" then
		local slot = ...
		if slot == trinketSlot1 or slot == trinketSlot2 then
			Run()
		end
	elseif event == "ACTIONBAR_UPDATE_COOLDOWN" then
		local used1, _, duration1 = CheckTrinketUsed(trinketSlot1)
		local used2, _, duration2 = CheckTrinketUsed(trinketSlot2)

		if used1 then
			C_Timer.After(duration1 + 0.1, Run)
		end

		if used2 then
			C_Timer.After(duration2 + 0.1, Run)
		end
	else
		addon:Run()
	end
end

local function OnAddonLoaded()
	addon.Config:Init()

	db = mini:GetSavedVars()

	eventsFrame = CreateFrame("Frame")
	eventsFrame:SetScript("OnEvent", OnEvent)
	eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventsFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	eventsFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
	eventsFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	eventsFrame:RegisterEvent("SPELL_UPDATE_USABLE")
	eventsFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	eventsFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

mini:WaitForAddonLoad(OnAddonLoaded)
