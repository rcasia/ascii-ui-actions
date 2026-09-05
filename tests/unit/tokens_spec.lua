local tokens = require("ascii-ui-actions.ui.tokens")
local eq = require("tests.assertions").eq

describe("ui.tokens", function()
	it("maps run state to a palette entry", function()
		eq("✓", tokens.state(tokens.state_for({ status = "completed", conclusion = "success" })).glyph)
		eq("✗", tokens.state(tokens.state_for({ status = "completed", conclusion = "failure" })).glyph)
		eq("●", tokens.state(tokens.state_for({ status = "in_progress" })).glyph)
		eq("○", tokens.state(tokens.state_for({ status = "queued" })).glyph)
	end)

	it("uses theme highlight groups, never hex", function()
		for key, entry in pairs(tokens.states) do
			assert(not (entry.highlight or ""):find("#"), key .. " must not use hex")
		end
	end)

	it("raises clearly on unknown states", function()
		local ok, err = pcall(tokens.state, "exploded")
		assert(not ok, "unknown state must raise")
		assert(tostring(err):find("unknown state", 1, true))
	end)
end)
