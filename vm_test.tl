
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

local function test_expected_object (t: testing.T, expected: any, actual: object.Object)
	if type(expected) == "number" then
		local err = test_integer_object(expected as integer, actual)
		if err ~= nil then
			t.error("test_integer_object failed: %s", err.message)
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
				t.fatal_fail("copiler error: %s", err)
			end
		end
		local vm_ = vm.new(comp:bytecode())
		do
			local err = vm_:run()
			if err ~= nil then
				t.fatal_fail("vm error: %s", err)
			end
		end
		local stack_elem = vm_:stack_top()
		test_expected_object(t, tt.expected, stack_elem)
	end
end

local function test_integer_arithmetic (t: testing.T)
	local tests = {
		{ input = "1", expected = 1 },
		{ input = "2", expected = 2 },
		{ input = "1 + 2", expected = 3 }, -- FIXME
	}
	run_vm_tests(t, tests)
end

local t = testing.new()
test_integer_arithmetic(t)
