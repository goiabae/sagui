
local vm = require("vm")
local ast = require("ast.ast")
local lexer = require("lexer.lexer")
local object = require("object")
local parser = require("parser.parser")
local compiler = require("compiler")
local testing = require("testing")

local function parse (input: string): ast.Program
	local l = lexer.new(input)
	local p = parser.new(l)
	return p:parse_program()
end

local record Error
	message: string
end

local record Map <K, V>
	where self.kind == "map"
	kind: string
	map: { K: V }
	len: integer
	new: function ({ K:V }): Map<K, V>
end

local map_mt: metatable<Map> = {}

function Map.new <K, V> (init: { K:V }): Map<K, V>
	local pair_count = 0
	for _, _ in pairs(init) do
		pair_count = pair_count + 1
	end
	return setmetatable({
		kind = "map",
		map = init,
		len = pair_count,
	} as Map<K, V>, map_mt)
end

local function test_integer_object (expected: integer, actual: object.Object): Error
	if actual == nil then
		return { message = "object was nil" }
	end
	if not (actual is object.Integer) then
		return { message = string.format("object is not Integer. got=%s", type(actual)) }
	end
	local result = actual as object.Integer
	if result.value ~= expected then
		return { message = string.format("object has wrong value. got=%d, want=%d", result.value, expected) }
	end
	return nil
end

local function test_boolean_object (expected: boolean, actual: object.Object): Error
	local function f (v: boolean): string return v and "true" or "false" end
	if actual == nil then
		return { message = "object was nil" }
	end
	if not (actual is object.Boolean) then
		return { message = string.format("object is not Boolean. got=%s", type(actual)) }
	end
	local result = actual as object.Boolean
	if result.value ~= expected then
		return { message = string.format("object has wrong value. got=%s, want=%s", f(result.value), f(expected)) }
	end
	return nil
end

local function test_string_object (expected: string, actual: object.Object): Error
	if not (actual is object.String) then
		return { message = string.format("object is not String. got=%s", type(actual)) }
	end
	local result = actual as object.String
	if result.value ~= expected then
		return { message = string.format("object has wrong value. got='%s', want='%s'", result.value, expected) }
	end
	return nil
end

local function test_intarray_object (expected: {integer}, actual: object.Object): Error
	if not (actual is object.Array) then
		return { message = string.format("object not Array: %s", type(actual)) }
	end
	local array = actual as object.Array
	if #array.elements ~= #(expected as {integer}) then
		return { message = "wrong num of elements" }
	end
	for i, expected_elem in ipairs(expected) do
		local err = test_integer_object(expected_elem, array.elements[i])
		if err ~= nil then
			return { message = string.format("test_integer_object failed: %s", err.message) }
		end
	end
end

local function test_expected_object (t: testing.T, expected: any, actual: object.Object)
	if type(expected) == "number" then
		local err = test_integer_object(expected as integer, actual)
		if err ~= nil then
			t:error("test_integer_object failed: %s", err.message)
		end
	elseif type(expected) == "boolean" then
		local err = test_boolean_object(expected as boolean, actual)
		if err ~= nil then
			t:error("test_boolean_object failed: %s", err.message)
		end
	elseif type(expected) == "string" then
		local err = test_string_object(expected as string, actual)
		if err ~= nil then
			t:error("test_string_object failed: %s", err.message)
		end
	elseif expected is object.Null then
		if actual ~= vm.Null then
			t:error("object is not Null: %s", type(actual))
		end
	elseif expected is Map<integer, integer> then
		local expd = expected as Map<integer, integer>
		if not (actual is object.Hash) then
			t:error("object is not Hash. got=%s", type(actual))
			return
		end
		local hash = actual as object.Hash
		if hash.pair_count ~= expd.len then
			t:error("hash has wrong number of Pairs. want=%s, got=%d", expd.len, hash.pair_count)
			return
		end
		for expected_key, expected_value in pairs(expd.map) do
			local pair_ = hash.pairs[expected_key]
			if pair_ == nil then
				t:error("no pair for given key in Pairs")
			end
			local err = test_integer_object(expected_value, pair_.value)
			if err ~= nil then
				t:error("test_integer_object failed: %s", err)
			end
		end
	else
		if actual is object.Array then
			local err = test_intarray_object(expected as {integer}, actual)
			if err ~= nil then
				t:error("test_intarray_object failed: %s", err.message)
			end
		elseif actual is object.Hash then
			local expd = expected as { integer:integer }
			local hash = actual as object.Hash
			-- if
		end
	end
end

local record VMTestCase
	input: string
	expected: any
end

local function run_vm_tests (t: testing.T, tests: {VMTestCase})
	for _, tt in ipairs(tests) do
		local program = parse(tt.input)
		local comp = compiler.new()
		do
			local err = comp:compile(program)
			if err ~= nil then
				t:fatal_fail("copiler error: %s", err)
			end
		end
		local vm_ = vm.new(comp:bytecode())
		do
			local err = vm_:run()
			if err ~= nil then
				t:fatal_fail("vm error: %s", err)
			end
		end
		local stack_elem = vm_:last_popped_stack_elem()
		test_expected_object(t, tt.expected, stack_elem)
	end
end

local function test_integer_arithmetic (t: testing.T)
	local tests = {
		{ input = "1", expected = 1 },
		{ input = "2", expected = 2 },
		{ input = "1 + 2", expected = 3 },
		{ input = "1 - 2", expected = -1 },
		{ input = "1 * 2", expected = 2 },
		{ input = "4 / 2", expected = 2 },
		{ input = "50 / 2 * 2 + 10 - 5", expected = 55 },
		{ input = "5 + 5 + 5 + 5 - 10", expected = 10 },
		{ input = "2 * 2 * 2 * 2 * 2", expected = 32 },
		{ input = "5 * 2 + 10", expected = 20 },
		{ input = "5 + 2 * 10", expected = 25 },
		{ input = "5 * (2 + 10)", expected = 60 },
		{ input = "-5", expected = -5 },
		{ input = "-10", expected = -10 },
		{ input = "-50 + 100 + -50", expected = 0 },
		{ input = "(5 + 10 * 2 + 15 / 3) * 2 + -10", expected = 50 },
	}
	run_vm_tests(t, tests)
end

local function test_boolean_expressions (t: testing.T)
	local tests = {
		{ input = "true", expected = true },
		{ input = "false", expected = false },
		{ input = "1 < 2", expected = true },
		{ input = "1 > 2", expected = false },
		{ input = "1 < 1", expected = false },
		{ input = "1 > 1", expected = false },
		{ input = "1 == 1", expected = true },
		{ input = "1 != 1", expected = false },
		{ input = "1 == 2", expected = false },
		{ input = "1 != 2", expected = true },
		{ input = "true == true", expected = true },
		{ input = "false == false", expected = true },
		{ input = "true == false", expected = false },
		{ input = "true != false", expected = true },
		{ input = "false != true", expected = true },
		{ input = "(1 < 2) == true", expected = true },
		{ input = "(1 < 2) == false", expected = false },
		{ input = "(1 > 2) == true", expected = false },
		{ input = "(1 > 2) == false", expected = true },
		{ input = "!true", expected = false },
		{ input = "!false", expected = true },
		{ input = "!5", expected = false },
		{ input = "!!true", expected = true },
		{ input = "!!false", expected = false },
		{ input = "!!5", expected = true },
		{ input = "!(if (false) { 5; })", expected = true },
	}
	run_vm_tests(t, tests)
end

local function test_conditionals (t: testing.T)
	local tests: {VMTestCase} = {
		{ input = "if (true) { 10 }", expected = 10 },
		{ input = "if (true) { 10 } else { 20 }", expected = 10 },
		{ input = "if (false) { 10 } else { 20 } ", expected = 20 },
		{ input = "if (1) { 10 }", expected = 10 },
		{ input = "if (1 < 2) { 10 }", expected = 10 },
		{ input = "if (1 < 2) { 10 } else { 20 }", expected = 10 },
		{ input = "if (1 > 2) { 10 } else { 20 }", expected = 20 },
		{ input = "if (1 > 2) { 10 }", expected = vm.Null },
		{ input = "if (false) { 10 }", expected = vm.Null },
		{ input = "if ((if (false) { 10 })) { 10 } else { 20 }", expected = 20 },
	}
	run_vm_tests(t, tests)
end

local function test_global_let_statement (t: testing.T)
	local tests: {VMTestCase} = {
		{ input = "let one = 1; one", expected = 1 },
		{ input = "let one = 1; let two = 2; one + two", expected = 3 },
		{ input = "let one = 1; let two = one + one; one + two", expected = 3 },
	}
	run_vm_tests(t, tests)
end

local function test_string_expressions (t: testing.T)
	local tests: {VMTestCase} = {
		{ input = '"monkey"', expected = "monkey" },
		{ input = '"mon" + "key"', expected = "monkey" },
		{ input = '"mon" + "key" + "banana"', expected = "monkeybanana" },
	}
	run_vm_tests(t, tests)
end

local function test_array_literals (t: testing.T)
	local tests: {VMTestCase} = {
		{ input = '[]', expected = {} },
		{ input = '[1, 2, 3]', expected = {1, 2, 3} },
		{ input = '[1 + 2, 3 * 4, 5 + 6]', expected = {3, 12, 11} },
	}
	run_vm_tests(t, tests)
end

local function test_hash_literals (t: testing.T)
	local tests: {VMTestCase} = {
		{ input = '{}', expected = Map.new {} },
		{
			input = '{1: 2, 2: 3}',
			expected = Map.new {
				[object.Integer.new(1):hash_key().value] = 2,
				[object.Integer.new(2):hash_key().value] = 3,
			}
		},
		{
			input = '{1 + 1: 2 * 2, 3 + 3: 4 * 4}',
			expected = Map.new {
				[object.Integer.new(2):hash_key().value] = 4,
				[object.Integer.new(6):hash_key().value] = 16,
			}
		},
	}
	run_vm_tests(t, tests)
end

local function test_index_expressions (t: testing.T)
	local tests: {VMTestCase} = {
		{ input = "[1, 2, 3][1]", expected = 2 },
		{ input = "[1, 2, 3][0 + 2]", expected = 3 },
		{ input = "[[1, 1, 1]][0][0]", expected = 1 },
		{ input = "[][0]", expected = vm.Null },
		{ input = "[1, 2, 3][99]", expected = vm.Null },
		{ input = "[1][-1]", expected = vm.Null },
		{ input = "{1: 1, 2: 2}[1]", expected = 1 },
		{ input = "{1: 1, 2: 2}[2]", expected = 2 },
		{ input = "{1: 1}[0]", expected = vm.Null },
		{ input = "{}[0]", expected = vm.Null },
	}
	run_vm_tests(t, tests)
end

return {
	domain = "vm",
	test_cases = {
		{ name = "integer_arithmetic", func = test_integer_arithmetic },
		{ name = "boolean_expressions", func = test_boolean_expressions },
		{ name = "conditionals", func = test_conditionals },
		{ name = "global_let_statement", func = test_global_let_statement },
		{ name = "string_expressions", func = test_string_expressions },
		{ name = "array_literals", func = test_array_literals },
		{ name = "hash_literals", func = test_hash_literals },
		{ name = "index_expressions", func = test_index_expressions },
	}
}
