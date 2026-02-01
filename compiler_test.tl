
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
		return string.format("wrong instructions length.\nwant=%d\ngot=%d", #concatted.bytes, #actual.bytes)
	end
	for i, ins in ipairs(concatted.bytes) do
		if actual.bytes[i] ~= ins then
			return string.format("wrong instruction at %d.\nwant='%s'(%d)\ngot='%s'(%d)", i, concatted:byte_string(), ins, actual:byte_string(), actual.bytes[i])
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
				t.fatal_fail("compiler error: %s", err)
			end
		end
		local bytecode = c:bytecode()
		do
			local err = test_instructions(tt.expected_instructions, bytecode.instructions)
			if err ~= nil then
				t.fatal_fail("test_instructions failed: %s", err)
			end
		end
		do
			local err = test_constants(t, tt.expected_constants, bytecode.constants)
			if err ~= nil then
				t.fatal_fail("test_constants failed: %s", err)
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
			},
		},
	}
	run_compiler_test(t, tests)
end

local t = testing.new()
test_integer_arithmetic(t)
