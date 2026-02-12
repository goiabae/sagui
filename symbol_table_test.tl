
local symbol_table = require("symbol_table")
local testing = require("testing")

local function test_define (t: testing.T)
	local expected = {
		["a"] = symbol_table.Symbol.new("a", symbol_table.GlobalScope, 0),
		["b"] = symbol_table.Symbol.new("b", symbol_table.GlobalScope, 1),
		["c"] = symbol_table.Symbol.new("c", symbol_table.LocalScope, 0),
		["d"] = symbol_table.Symbol.new("d", symbol_table.LocalScope, 1),
		["e"] = symbol_table.Symbol.new("e", symbol_table.LocalScope, 0),
		["f"] = symbol_table.Symbol.new("f", symbol_table.LocalScope, 1),
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

	local first_locau = symbol_table.SymbolTable.new_enclosed(globau)

	local c = first_locau:define("c")
	if c ~= expected["c"] then
		t:error("expected c=%s, got=%s", tostring(expected["c"]), tostring(c))
	end

	local d = first_locau:define("d")
	if d ~= expected["d"] then
		t:error("expected d=%s, got=%s", tostring(expected["d"]), tostring(d))
	end

	local second_locau = symbol_table.SymbolTable.new_enclosed(first_locau)

	local e = second_locau:define("e")
	if e ~= expected["e"] then
		t:error("expected e=%s, got=%s", tostring(expected["e"]), tostring(e))
	end

	local f = second_locau:define("f")
	if f ~= expected["f"] then
		t:error("expected f=%s, got=%s", tostring(expected["f"]), tostring(f))
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

local function test_resolve_local (t: testing.T)
	local globau = symbol_table.SymbolTable.new()
	globau:define("a")
	globau:define("b")

	local locau = symbol_table.SymbolTable.new_enclosed(globau)
	locau:define("c")
	locau:define("d")

	local expected = {
		symbol_table.Symbol.new("a", symbol_table.GlobalScope, 0),
		symbol_table.Symbol.new("b", symbol_table.GlobalScope, 1),
		symbol_table.Symbol.new("c", symbol_table.LocalScope, 0),
		symbol_table.Symbol.new("d", symbol_table.LocalScope, 1),
	}

	for _, sym in ipairs(expected) do
		local result, ok = locau:resolve(sym.name)
		if not ok then
			t:error("name %s not resolvable", sym.name)
		else
			if result ~= sym then
				t:error("expected %s to resolve to %s, got=%s", sym.name, tostring(sym), tostring(result))
			end
		end
	end
end

local function test_resolve_nested_local (t: testing.T)
	local globau = symbol_table.SymbolTable.new()
	globau:define("a")
	globau:define("b")

	local first_locau = symbol_table.SymbolTable.new_enclosed(globau)
	first_locau:define("c")
	first_locau:define("d")

	local second_locau = symbol_table.SymbolTable.new_enclosed(globau)
	second_locau:define("e")
	second_locau:define("f")

	local tests = {
		{
			first_locau,
			{
				symbol_table.Symbol.new("a", symbol_table.GlobalScope, 0),
				symbol_table.Symbol.new("b", symbol_table.GlobalScope, 1),
				symbol_table.Symbol.new("c", symbol_table.LocalScope, 0),
				symbol_table.Symbol.new("d", symbol_table.LocalScope, 1),
			},
		},
		{
			second_locau,
			{
				symbol_table.Symbol.new("a", symbol_table.GlobalScope, 0),
				symbol_table.Symbol.new("b", symbol_table.GlobalScope, 1),
				symbol_table.Symbol.new("e", symbol_table.LocalScope, 0),
				symbol_table.Symbol.new("f", symbol_table.LocalScope, 1),
			},
		},
	}

	for _, tt in ipairs(tests) do
		for _, sym in ipairs(tt[2]) do
			local result, ok = tt[1]:resolve(sym.name)
			if not ok then
				t:error("name %s not resolvable", sym.name)
			else
				if result ~= sym then
					t:error("expected %s to resolve to %s, got=%s", sym.name, tostring(sym), tostring(result))
				end
			end
		end
	end
end

local function fmt_sym (s: symbol_table.Symbol): string
	return string.format("{ name = %s }", s.name)
end

local function test_define_resolve_builtins (t: testing.T)
	local globau = symbol_table.SymbolTable.new()
	local first_locau = symbol_table.SymbolTable.new_enclosed(globau)
	local second_locau = symbol_table.SymbolTable.new_enclosed(first_locau)
	local expected = {
		symbol_table.Symbol.new("a", symbol_table.BuiltinScope, 0),
		symbol_table.Symbol.new("c", symbol_table.BuiltinScope, 1),
		symbol_table.Symbol.new("e", symbol_table.BuiltinScope, 2),
		symbol_table.Symbol.new("f", symbol_table.BuiltinScope, 3),
	}

	for i, v in ipairs(expected) do
		globau:define_builtin(i, v.name)
	end
	for _, tab in ipairs({globau, first_locau, second_locau}) do
		for _, sym in ipairs(expected) do
			local result, ok = tab:resolve(sym.name)
			if not ok then
				t:error("name %s not resolvable", sym.name)
			else
				if result ~= sym then
					t:error("expected %s to resolve to %s, got=%s", sym.name, fmt_sym(sym), fmt_sym(result))
				end
			end
		end
	end
end

return {
	domain = "symbol_table",
	test_cases = {
		{ name = "define", func = test_define },
		{ name = "resolve_global", func = test_resolve_global },
		{ name = "resolve_local", func = test_resolve_local },
		{ name = "resolve_nested_local", func = test_resolve_nested_local },
		{ name = "define_resolve_builtins", func = test_define_resolve_builtins },
	}
}
