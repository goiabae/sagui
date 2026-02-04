
local symbol_table = require("symbol_table")
local testing = require("testing")

local function test_define (t: testing.T)
	local expected = {
		["a"] = symbol_table.Symbol.new("a", symbol_table.GlobalScope, 0),
		["b"] = symbol_table.Symbol.new("b", symbol_table.GlobalScope, 1),
	}
	local globau = symbol_table.SymbolTable.new()
	local a = globau:define("a")
	if a ~= expected["a"] then
		t:error("expected a=%s, got=%s", tostring(expected["a"]), tostring(a))
	end

	local b = globau:define("b")
	if b ~= expected["b"] then
		t:error("expected b=%s, got=%s", tostring(expected["b"]), tostring(b))
	end
end

local function test_resolve_global (t: testing.T)
	local globau = symbol_table.SymbolTable.new()
	globau:define("a")
	globau:define("b")

	local expected = {
		symbol_table.Symbol.new("a", symbol_table.GlobalScope, 0),
		symbol_table.Symbol.new("b", symbol_table.GlobalScope, 1),
	}

	for _, sym in ipairs(expected) do
		local result, ok = globau:resolve(sym.name)
		if not ok then
			t:error("name %s not resolvable", sym.name)
		else
			if result ~= sym then
				t:error("expected %s to resolve to %s, got=%s", sym.name, tostring(sym), tostring(result))
			end
		end
	end
end

return {
	domain = "symbol_table",
	test_cases = {
		{ name = "define", func = test_define },
		{ name = "resolve_global", func = test_resolve_global },
	}
}
