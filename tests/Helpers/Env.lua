-- Loads MiniTrinketGlow into a mocked client with one action button whose contents the tests
-- control, so the macro parser can be driven end to end.
--
-- The addon glows an action button when the trinket behind it is off cooldown. Working out
-- which trinket slot a button refers to is the interesting part: an item button is matched by
-- item id, but a macro has to be read, and macro text is written by hand in a dozen shapes.

local harness = require("AddonHarness")

local M = {}

-- The button under test. Every prefix the addon scans behaves the same way; asserting on one
-- keeps the tests about the parser rather than about the scan.
M.ButtonName = "ActionButton1"
M.Action = 1
M.MacroName = "TrinketMacro"
M.TrinketSlot1 = 13
M.TrinketSlot2 = 14

---@return table env
function M.Build()
	_G.MiniTrinketGlowDB = nil

	local context = harness.Load("MiniTrinketGlow")

	local env = {
		Addon = context.Addon,
		Context = context,
		-- What the action slot under test holds. Everything else is empty.
		ActionType = nil,
		ActionItemId = nil,
		MacroBody = nil,
		-- Equipped trinket item ids by inventory slot.
		Equipped = {},
		-- Inventory slots currently on cooldown.
		OnCooldown = {},
		InCombat = false,
	}

	_G.GetActionInfo = function(action)
		if action ~= M.Action or not env.ActionType then
			return nil
		end

		return env.ActionType, env.ActionItemId
	end

	_G.GetActionText = function(action)
		if action ~= M.Action or env.ActionType ~= "macro" then
			return nil
		end

		return M.MacroName
	end

	_G.GetMacroIndexByName = function(name)
		return name == M.MacroName and 1 or 0
	end

	_G.GetMacroInfo = function(index)
		if index ~= 1 then
			return nil
		end

		return M.MacroName, nil, env.MacroBody
	end

	_G.GetInventoryItemID = function(_, slot)
		return env.Equipped[slot]
	end

	_G.GetInventoryItemCooldown = function(_, slot)
		if env.OnCooldown[slot] then
			return 1000, 120, 1
		end

		-- start 0, duration 0, enabled: the trinket is ready.
		return 0, 0, 1
	end

	_G.UnitAffectingCombat = function()
		return env.InCombat
	end

	harness.Login(context)

	env.Button = _G[M.ButtonName]

	-- Controls

	---Puts a macro on the button under test.
	function env.UseMacro(body)
		env.ActionType = "macro"
		env.MacroBody = body
	end

	---Puts an item on the button under test.
	function env.UseItem(itemId)
		env.ActionType = "item"
		env.ActionItemId = itemId
	end

	function env.Equip(slot, itemId)
		env.Equipped[slot] = itemId
	end

	---Runs one pass of the addon and reports whether the button ended up glowing.
	---@return boolean
	function env.RunAndCheckGlow()
		env.Button.MiniTrinketGlow = nil
		env.Addon:Run()

		return env.Button.MiniTrinketGlow == true
	end

	-- Glowing is gated on being in combat by default, which would mask every parser result.
	env.InCombat = true

	return env
end

return M
