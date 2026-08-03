-- Working out which trinket an action button uses is the whole job. An item button is easy -
-- match the item id against what is equipped - but a macro has to be read, and macro text is
-- hand written in a dozen shapes: extra spaces, conditionals, upper case, comments, several
-- lines of which only one matters.
--
-- Getting it wrong is quiet. Nothing errors; the button simply never glows, or a button that
-- has nothing to do with trinkets glows whenever a trinket comes off cooldown.

local fw = require("TestFramework")
local Env = require("Env")

fw.describe("MiniTrinketGlow - trinket detection", function()
	local env

	fw.before_each(function()
		env = Env.Build()
		env.Equip(Env.TrinketSlot1, 111111)
		env.Equip(Env.TrinketSlot2, 222222)
	end)

	-- Item buttons

	fw.it("matches an item button against the equipped trinket", function()
		env.UseItem(111111)

		fw.truthy(env.RunAndCheckGlow(), "the equipped trinket in slot one")
	end)

	fw.it("ignores an item button holding something that is not equipped", function()
		env.UseItem(999999)

		fw.falsy(env.RunAndCheckGlow(), "a healthstone is not a trinket")
	end)

	-- Macro shapes

	fw.it("reads the plain form", function()
		env.UseMacro("/use 13")

		fw.truthy(env.RunAndCheckGlow(), "/use 13")
	end)

	fw.it("reads the second trinket slot", function()
		env.UseMacro("/use 14")

		fw.truthy(env.RunAndCheckGlow(), "/use 14")
	end)

	fw.it("tolerates runs of whitespace", function()
		env.UseMacro("/use    13")

		fw.truthy(env.RunAndCheckGlow(), "collapsed whitespace")
	end)

	fw.it("tolerates leading whitespace on the line", function()
		env.UseMacro("   /use 13")

		fw.truthy(env.RunAndCheckGlow(), "indented macro line")
	end)

	fw.it("reads through a conditional", function()
		env.UseMacro("/use [combat] 13")

		fw.truthy(env.RunAndCheckGlow(), "/use [combat] 13")
	end)

	fw.it("is case insensitive", function()
		env.UseMacro("/USE 13")

		fw.truthy(env.RunAndCheckGlow(), "upper case macro")
	end)

	fw.it("finds the trinket line among several", function()
		env.UseMacro("#showtooltip\n/cast Ice Block\n/use 13")

		fw.truthy(env.RunAndCheckGlow(), "multi-line macro")
	end)

	fw.it("ignores a macro that uses no trinket slot", function()
		env.UseMacro("#showtooltip\n/cast Frostbolt")

		fw.falsy(env.RunAndCheckGlow(), "no /use line")
	end)

	fw.it("ignores a slot number on a command that is not /use", function()
		env.UseMacro("/cast 13")

		fw.falsy(env.RunAndCheckGlow(), "/cast is not /use")
	end)

	fw.it("ignores an empty or missing macro body", function()
		env.UseMacro("")
		fw.falsy(env.RunAndCheckGlow(), "empty body")

		env.UseMacro(nil)
		fw.falsy(env.RunAndCheckGlow(), "no body")
	end)

	-- Known gap
	--
	-- The parser looks for the slot number preceded by a space, so a conditional written
	-- flush against the number is missed. The macro is valid and the addon's own comment
	-- lists it as a supported shape, so this is a defect rather than a decision - marked
	-- expected-to-fail so the marker disappears the moment it is fixed.

	fw.xfail("reads a conditional written flush against the slot number", function()
		env.UseMacro("/use [mod:shift,@player]13")

		fw.truthy(env.RunAndCheckGlow(), "/use [mod:shift,@player]13")
	end)

	-- Cooldown and combat gating

	fw.it("does not glow a trinket that is on cooldown", function()
		env.UseMacro("/use 13")
		env.OnCooldown[Env.TrinketSlot1] = true

		fw.falsy(env.RunAndCheckGlow(), "trinket on cooldown")
	end)

	fw.it("holds the glow back out of combat when asked to", function()
		env.UseMacro("/use 13")
		env.InCombat = false

		fw.falsy(env.RunAndCheckGlow(), "combat only, out of combat")

		env.InCombat = true

		fw.truthy(env.RunAndCheckGlow(), "combat only, in combat")
	end)
end)
