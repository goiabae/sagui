
local compiler = require("compiler")
local code = require("code")
local testing = require("testing")
local lexer = require("lexer.lexer")
local parser = require("parser.parser")
local ast = require("ast.ast")
local object = require("object")

local record CompilerTestCase
	input: string
	expected_constants: {any}
	expected_instructions: {code.Instructions}
end

local function parse (input: string): ast.Program
	local l = lexer.new(input)
	local p = parser.new(l)
	return p:parse_program()
end

local function concat_instructions (s: {code.Instructions}): code.Instructions
	local out = code.Instructions.new()
	for _, ins in ipairs(s) do
		for _, i in ipairs(ins.bytes) do
			table.insert(out.bytes, i)
		end
	end
	return out
end

local function test_instructions (expected: {code.Instructions}, actual: code.Instructions): string
	local concatted = concat_instructions(expected)
	if actual.bytes == nil then
		error("actual.bytes was nil")
	end
	if #actual.bytes ~= #concatted.bytes then
		return string.format("wrong instructions length.\nwant=(%d)\n%s\ngot=(%d)\n%s", #concatted.bytes, concatted:string(), #actual.bytes, actual:string())
	end
	for i, ins in ipairs(concatted.bytes) do
		if actual.bytes[i] ~= ins then
			return string.format("wrong instruction at %d.\nwant='%s'(%d)\ngot='%s'(%d)", i, concatted:string(), ins, actual:string(), actual.bytes[i])
		end
	end
	return nil
end

local function test_integer_object (expected: integer, actual: object.Object): string
	if not (actual is object.Integer) then
		return string.format("object is not Integer. got=%s", type(actual))
	end
	local result = actual as object.Integer
	if result.value ~= expected then
		return string.format("object has wrong value. got=%d, want=%d", result.value, expected)
	end
	return nil
end

local function test_string_object (expected: string, actual: object.Object): string
	if not (actual is object.String) then
		return string.format("object is not String. got=%s", type(actual))
	end
	local result = actual as object.String
	if result.value ~= expected then
		return string.format("object has wrong value. got='%s', want='%s'", result.value, expected)
	end
	return nil
end

local function test_constants (t: testing.T, expected: {any}, actual: {object.Object}): string
	local _ = t
	if #expected ~= #actual then
		return string.format("wrong number of constants. got=%d, want=%d", #actual, #expected)
	end
	for i, constant in ipairs(expected) do
		if type(constant) == "number" then
			local err = test_integer_object(constant as integer, actual[i])
			if err ~= nil then
				return string.format("constant %d - test_integer_object failed: %s", i, err)
			end
		elseif type(constant) == "string" then
			local err = test_string_object(constant as string, actual[i])
			if err ~= nil then
				return string.format("constant %d - test_string_object failed: %s", i, err)
			end
		end
	end
	return nil
end

local function run_compiler_test (t: testing.T, tests: {CompilerTestCase})
	for _, tt in ipairs(tests) do
		local program = parse(tt.input)
		local c = compiler.new()
		do
			local err = c:compile(program)
			if err ~= nil then
				print(string.format("compiler error: %s", err))
				t:fatal_fail("compiler error: %s", err)
			end
		end
		local bytecode = c:bytecode()
		do
			local err = test_instructions(tt.expected_instructions, bytecode.instructions)
			if err ~= nil then
				t:fatal_fail("test_instructions failed: %s", err)
			end
		end
		do
			local err = test_constants(t, tt.expected_constants, bytecode.constants)
			if err ~= nil then
				t:fatal_fail("test_constants failed: %s", err)
			end
		end
	end
end

-- local function each <T, U>(xs: {T}, f: function (T): U): {U}
-- 	local acc = {}
-- 	for i = 1, #xs do table.insert(acc, f(xs[i])); end
-- 	return acc
-- end

-- local function format_bytes <T>(xs: {T}): string
-- 	return table.concat(each(xs, function (x: T): string return string.format("%02x", x as integer) end), " ")
-- end

local function test_integer_arithmetic (t: testing.T)
	local tests: {CompilerTestCase} = {
		{
			input = "1 + 2",
			expected_constants = {1, 2},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpConstant, 1)),
				code.Instructions.new(code.make(code.OpAdd)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = "1; 2",
			expected_constants = {1, 2},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpPop)),
				code.Instructions.new(code.make(code.OpConstant, 1)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = "1 - 2",
			expected_constants = {1, 2},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpConstant, 1)),
				code.Instructions.new(code.make(code.OpSub)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = "1 * 2",
			expected_constants = {1, 2},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpConstant, 1)),
				code.Instructions.new(code.make(code.OpMul)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = "2 / 1",
			expected_constants = {2, 1},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpConstant, 1)),
				code.Instructions.new(code.make(code.OpDiv)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = "-1",
			expected_constants = {1},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpMinus)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
	}
	run_compiler_test(t, tests)
end

local function test_boolean_expressions (t: testing.T)
	local tests = {
		{
			input = "true",
			expected_constants = {},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpTrue)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = "false",
			expected_constants = {},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpFalse)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = "1 > 2",
			expected_constants = {1, 2},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpConstant, 1)),
				code.Instructions.new(code.make(code.OpGreaterThan)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = "1 < 2",
			expected_constants = {2, 1},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpConstant, 1)),
				code.Instructions.new(code.make(code.OpGreaterThan)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = "1 == 2",
			expected_constants = {1, 2},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpConstant, 1)),
				code.Instructions.new(code.make(code.OpEqual)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = "1 != 2",
			expected_constants = {1, 2},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpConstant, 1)),
				code.Instructions.new(code.make(code.OpNotEqual)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = "true == false",
			expected_constants = {},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpTrue)),
				code.Instructions.new(code.make(code.OpFalse)),
				code.Instructions.new(code.make(code.OpEqual)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = "true != false",
			expected_constants = {},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpTrue)),
				code.Instructions.new(code.make(code.OpFalse)),
				code.Instructions.new(code.make(code.OpNotEqual)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = "!true",
			expected_constants = {},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpTrue)),
				code.Instructions.new(code.make(code.OpBang)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
	}
	run_compiler_test(t, tests)
end

local function test_conditionals (t: testing.T)
	local tests = {
		{
			input = "if (true) { 10 }; 3333;",
			expected_constants = {10, 3333},
			expected_instructions = {
				-- 0000
				code.Instructions.new(code.make(code.OpTrue)),
				-- 0001
				code.Instructions.new(code.make(code.OpJumpNotTruthy, 10)),
				-- 0004
				code.Instructions.new(code.make(code.OpConstant, 0)),
				-- 0007
				code.Instructions.new(code.make(code.OpJump, 11)),
				-- 0010
				code.Instructions.new(code.make(code.OpNull)),
				-- 0011
				code.Instructions.new(code.make(code.OpPop)),
				-- 0012
				code.Instructions.new(code.make(code.OpConstant, 1)),
				-- 0015
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = "if (true) { 10 } else { 20 }; 3333;",
			expected_constants = {10, 20, 3333},
			expected_instructions = {
				-- 0000
				code.Instructions.new(code.make(code.OpTrue)),
				-- 0001
				code.Instructions.new(code.make(code.OpJumpNotTruthy, 10)),
				-- 0004
				code.Instructions.new(code.make(code.OpConstant, 0)),
				-- 0007
				code.Instructions.new(code.make(code.OpJump, 13)),
				-- 0010
				code.Instructions.new(code.make(code.OpConstant, 1)),
				-- 0013
				code.Instructions.new(code.make(code.OpPop)),
				-- 0014
				code.Instructions.new(code.make(code.OpConstant, 2)),
				-- 0017
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
	}
	run_compiler_test(t, tests)
end

local function test_global_let_statement (t: testing.T)
	local tests = {
		{
			input = "let one = 1; let two = 2;",
			expected_constants = {1, 2},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpSetGlobal, 0)),
				code.Instructions.new(code.make(code.OpConstant, 1)),
				code.Instructions.new(code.make(code.OpSetGlobal, 1)),
			},
		},
		{
			input = "let one = 1; one;",
			expected_constants = {1},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpSetGlobal, 0)),
				code.Instructions.new(code.make(code.OpGetGlobal, 0)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = "let one = 1; let two = one; two;",
			expected_constants = {1},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpSetGlobal, 0)),
				code.Instructions.new(code.make(code.OpGetGlobal, 0)),
				code.Instructions.new(code.make(code.OpSetGlobal, 1)),
				code.Instructions.new(code.make(code.OpGetGlobal, 1)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
	}
	run_compiler_test(t, tests)
end

local function test_string_expressions (t: testing.T)
	local tests = {
		{
			input = '"monkey"',
			expected_constants = {"monkey"},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = '"mon" + "key"',
			expected_constants = {"mon", "key"},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpConstant, 1)),
				code.Instructions.new(code.make(code.OpAdd)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
	}
	run_compiler_test(t, tests)
end

local function test_array_literals (t: testing.T)
	local tests = {
		{
			input = '[]',
			expected_constants = {},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpArray, 0)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = '[1, 2, 3]',
			expected_constants = {1, 2, 3},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpConstant, 1)),
				code.Instructions.new(code.make(code.OpConstant, 2)),
				code.Instructions.new(code.make(code.OpArray, 3)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = '[1 + 2, 3 - 4, 5 * 6]',
			expected_constants = {1, 2, 3, 4, 5, 6},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpConstant, 1)),
				code.Instructions.new(code.make(code.OpAdd)),

				code.Instructions.new(code.make(code.OpConstant, 2)),
				code.Instructions.new(code.make(code.OpConstant, 3)),
				code.Instructions.new(code.make(code.OpSub)),

				code.Instructions.new(code.make(code.OpConstant, 4)),
				code.Instructions.new(code.make(code.OpConstant, 5)),
				code.Instructions.new(code.make(code.OpMul)),

				code.Instructions.new(code.make(code.OpArray, 3)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
	}
	run_compiler_test(t, tests)
end

local function test_hash_literals (t: testing.T)
	local tests = {
		{
			input = '{}',
			expected_constants = {},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpHash, 0)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = '{1: 2, 3: 4, 5: 6}',
			expected_constants = {1, 2, 3, 4, 5, 6},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpConstant, 1)),
				code.Instructions.new(code.make(code.OpConstant, 2)),
				code.Instructions.new(code.make(code.OpConstant, 3)),
				code.Instructions.new(code.make(code.OpConstant, 4)),
				code.Instructions.new(code.make(code.OpConstant, 5)),
				code.Instructions.new(code.make(code.OpHash, 6)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = '{1: 2 + 3, 4: 5 * 6}',
			expected_constants = {1, 2, 3, 4, 5, 6},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpConstant, 1)),
				code.Instructions.new(code.make(code.OpConstant, 2)),
				code.Instructions.new(code.make(code.OpAdd)),

				code.Instructions.new(code.make(code.OpConstant, 3)),
				code.Instructions.new(code.make(code.OpConstant, 4)),
				code.Instructions.new(code.make(code.OpConstant, 5)),
				code.Instructions.new(code.make(code.OpMul)),

				code.Instructions.new(code.make(code.OpHash, 4)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
	}
	run_compiler_test(t, tests)
end

local function test_index_expressions (t: testing.T)
	local tests = {
		{
			input = '[1, 2, 3][1 + 1]',
			expected_constants = {1, 2, 3, 1, 1},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpConstant, 1)),
				code.Instructions.new(code.make(code.OpConstant, 2)),
				code.Instructions.new(code.make(code.OpArray, 3)),
				code.Instructions.new(code.make(code.OpConstant, 3)),
				code.Instructions.new(code.make(code.OpConstant, 4)),
				code.Instructions.new(code.make(code.OpAdd)),
				code.Instructions.new(code.make(code.OpIndex)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
		{
			input = '{1: 2}[2 - 1]',
			expected_constants = {1, 2, 2, 1},
			expected_instructions = {
				code.Instructions.new(code.make(code.OpConstant, 0)),
				code.Instructions.new(code.make(code.OpConstant, 1)),
				code.Instructions.new(code.make(code.OpHash, 2)),
				code.Instructions.new(code.make(code.OpConstant, 2)),
				code.Instructions.new(code.make(code.OpConstant, 3)),
				code.Instructions.new(code.make(code.OpSub)),
				code.Instructions.new(code.make(code.OpIndex)),
				code.Instructions.new(code.make(code.OpPop)),
			},
		},
	}
	run_compiler_test(t, tests)
end

return {
	domain = "compiler",
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
