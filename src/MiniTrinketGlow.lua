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
-- The slot numbers never change, so the frontier patterns that match them are built once
-- rather than concatenated per macro line.
local trinketSlotPatterns = {
	[trinketSlot1] = "%f[%w]" .. trinketSlot1 .. "%f[%W]",
	[trinketSlot2] = "%f[%w]" .. trinketSlot2 .. "%f[%W]",
}
-- The action buttons a scan walks. Resolving the names is most of the cost of a pass that
-- finds nothing, so it is done once.
---@type table[]?
local buttons
-- Action slot -> trinket inventory slot, or false for "not a trinket". Reading a macro is by
-- far the most expensive part of a pass, and the answer only moves when the bars, the macros
-- or the equipped trinkets do, so it is kept until one of those says otherwise.
local actionTrinketSlots = {}
-- Collapses the scan onto the next frame. SPELL_UPDATE_USABLE alone fires many times a second
-- in combat and every one of them asks the same question.
local scanQueued = false
-- LCG keys a glow per frame. The default key is shared, so another addon using it on the same
-- button could stop this one and leave the flag below claiming it is still lit.
local glowKey = "MiniTrinketGlow"
-- Whether each trinket should be glowing this pass. Refilled per pass rather than rebuilt, so
-- a pass allocates nothing.
local trinketReady = {
	[trinketSlot1] = false,
	[trinketSlot2] = false,
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
			--
			-- Matched on word boundaries rather than by looking for a leading space: the last
			-- form runs the slot number straight on from the conditional, so requiring the
			-- space missed it. The trailing boundary is what stops "/use 130" counting as 13.
			local arguments = line:sub(5)

			if arguments:match(trinketSlotPatterns[trinketSlot1]) then
				return trinketSlot1
			end
			if arguments:match(trinketSlotPatterns[trinketSlot2]) then
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
					key = glowKey,
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
			-- Most buttons in a pass are not glowing, so the flag keeps this from calling into
			-- the library once per button to undo nothing.
			if button.MiniTrinketGlow then
				LCG.ProcGlow_Stop(button, glowKey)
				button.MiniTrinketGlow = false
			end
		elseif ActionButton_HideOverlayGlow then
			ActionButton_HideOverlayGlow(button)
		end
	end
end

---The action buttons a pass walks, resolved on first use and kept. The bars are built before
---the addon ever runs and are not torn down afterwards.
local function GetButtons()
	if buttons then
		return buttons
	end

	buttons = {}

	for _, prefix in ipairs(buttonPrefixes) do
		for i = 1, 12 do
			local button = _G[prefix .. i]

			if button then
				buttons[#buttons + 1] = button
			end
		end
	end

	return buttons
end

---Forgets which action slots hold a trinket. Call whenever that answer could have moved: the
---bars changed, a macro was edited, or a different trinket was equipped.
local function InvalidateActionSlots()
	wipe(actionTrinketSlots)
end

local function GetCachedTrinketSlot(action)
	local cached = actionTrinketSlots[action]

	if cached ~= nil then
		return cached or nil
	end

	local slot = GetTrinketSlotForAction(action)

	-- false rather than nil, so a button holding no trinket counts as answered instead of
	-- being re-read - macro parse and all - on every pass.
	actionTrinketSlots[action] = slot or false

	return slot
end

---@return boolean
local function IsTrinketReady(slot)
	local start, duration, usable = GetInventoryItemCooldown("player", slot)

	return usable == 1 and start == 0 and duration == 0
end

local function Run()
	local allowed = (not db.CombatOnly) or UnitAffectingCombat("player") or false
	-- Only two trinkets can ever match, so read their readiness once rather than once per
	-- button pointing at them.
	trinketReady[trinketSlot1] = allowed and IsTrinketReady(trinketSlot1)
	trinketReady[trinketSlot2] = allowed and IsTrinketReady(trinketSlot2)

	local scanned = GetButtons()

	for i = 1, #scanned do
		local button = scanned[i]
		local action = button.action

		local slot = action and GetCachedTrinketSlot(action)

		if slot then
			Glow(button, trinketReady[slot])
		else
			-- An action that stopped pointing at a trinket - unequipped, dragged away, paged
			-- off - still owns whatever glow the last pass gave it.
			Glow(button, false)
		end
	end
end

local function OnScanTick()
	scanQueued = false
	Run()
end

---Runs a scan on the next frame, collapsing however many callers asked for one into one pass.
local function QueueRun()
	if scanQueued then
		return
	end

	scanQueued = true
	C_Timer.After(0, OnScanTick)
end

function addon:Run()
	-- The public entry point is what config changes and tests call, and neither arrives with
	-- an event to invalidate on, so it always re-reads.
	InvalidateActionSlots()
	Run()
end

local function OnEvent(_, event, ...)
	if event == "PLAYER_EQUIPMENT_CHANGED" then
		local slot = ...
		if slot == trinketSlot1 or slot == trinketSlot2 then
			-- A different trinket makes every item button's answer suspect.
			InvalidateActionSlots()
			QueueRun()
		end
	elseif event == "ACTIONBAR_UPDATE_COOLDOWN" then
		local used1, _, duration1 = CheckTrinketUsed(trinketSlot1)
		local used2, _, duration2 = CheckTrinketUsed(trinketSlot2)

		if used1 then
			C_Timer.After(duration1 + 0.1, QueueRun)
		end

		if used2 then
			C_Timer.After(duration2 + 0.1, QueueRun)
		end
	elseif event == "ACTIONBAR_SLOT_CHANGED" then
		-- Carries the slot that changed, or 0 for "all of them". This one arrives in bursts,
		-- so drop just the entry when it names one.
		local slot = ...

		if slot and slot ~= 0 then
			actionTrinketSlots[slot] = nil
		else
			InvalidateActionSlots()
		end

		QueueRun()
	elseif event == "UPDATE_MACROS" or event == "PLAYER_SPECIALIZATION_CHANGED" then
		-- What a macro says, or what the spec put on the bars, has moved.
		InvalidateActionSlots()
		QueueRun()
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- Bars can be rebuilt across a world change, so both caches are suspect.
		buttons = nil
		InvalidateActionSlots()
		QueueRun()
	else
		-- SPELL_UPDATE_USABLE, the combat toggles, and the bar swaps. A page, stance or
		-- vehicle bar moves which slot a button points at, not what any slot holds, and the
		-- cache is keyed on the slot, so those need a pass but no invalidation.
		QueueRun()
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
	eventsFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
	eventsFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
	eventsFrame:RegisterEvent("UPDATE_MACROS")
	eventsFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	eventsFrame:RegisterEvent("SPELL_UPDATE_USABLE")
	eventsFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	eventsFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

mini:WaitForAddonLoad(OnAddonLoaded)
