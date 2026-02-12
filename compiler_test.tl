
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
		else -- {code.Instructions}
			local actuali = actual[i]
			if not (actuali is object.CompiledFunction) then
				return string.format("constant %d - not a function: %s", i, type(actual[i]))
			end
			local fn = actuali as object.CompiledFunction
			local err = test_instructions(constant as {code.Instructions}, fn.instructions)
			if err ~= nil then
				return string.format("constant %d - test_instructions failed: %s", i, err)
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

local function test_functions (t: testing.T)
	local tests = {
		{
			input = "fn() { return 5 + 10; }",
			expected_constants = {
				5,
				10,
				{
					code.Instructions.new(code.make(code.OpConstant, 0)),
					code.Instructions.new(code.make(code.OpConstant, 1)),
					code.Instructions.new(code.make(code.OpAdd)),
					code.Instructions.new(code.make(code.OpReturnValue)),
				},
			},
			expected_instructions = {
					code.Instructions.new(code.make(code.OpConstant, 2)),
					code.Instructions.new(code.make(code.OpPop)),
			}
		},
		{
			input = "fn() { 1; 2 }",
			expected_constants = {
				1,
				2,
				{
					code.Instructions.new(code.make(code.OpConstant, 0)),
					code.Instructions.new(code.make(code.OpPop)),
					code.Instructions.new(code.make(code.OpConstant, 1)),
					code.Instructions.new(code.make(code.OpReturnValue)),
				},
			},
			expected_instructions = {
					code.Instructions.new(code.make(code.OpConstant, 2)),
					code.Instructions.new(code.make(code.OpPop)),
			}
		}
	}
	run_compiler_test(t, tests)
end

local function test_functions_without_return_value (t: testing.T)
	local tests = {
		{
			input = "fn() { }",
			expected_constants = {
				{
					code.Instructions.new(code.make(code.OpReturn)),
				},
			},
			expected_instructions = {
					code.Instructions.new(code.make(code.OpConstant, 0)),
					code.Instructions.new(code.make(code.OpPop)),
			}
		}
	}
	run_compiler_test(t, tests)
end

local function expect_last_instruction(t: testing.T, comp: compiler.Compiler, op: code.Opcode)
	local last = comp.scopes[comp.scope_index+1].last_instruction
	if last.opcode ~= op then
		t:error("last_instruction.opcode wrong. got=%s, want=%s", code.opcode_name(last.opcode), code.opcode_name(op))
	end
end

local function expect_scope_index(t: testing.T, comp: compiler.Compiler, n: integer)
	if comp.scope_index ~= n then
		return t:error("scope_index wrong. got=%d, want=%d", comp.scope_index, n)
	end
end

local function test_function_calls (t: testing.T)
	local tests: {CompilerTestCase} = {
		{
			input = "fn() { 24 }();",
			expected_constants = {
				24,
				{
					code.Instructions.new(code.make(code.OpConstant, 0)), -- The literal "24"
					code.Instructions.new(code.make(code.OpReturnValue)),
				},
			},
			expected_instructions = {
					code.Instructions.new(code.make(code.OpConstant, 1)), -- The compiled function
					code.Instructions.new(code.make(code.OpCall, 0)),
					code.Instructions.new(code.make(code.OpPop)),
			}
		},
		{
			input = "let noArg = fn() { 24 }; noArg();",
			expected_constants = {
				24,
				{
					code.Instructions.new(code.make(code.OpConstant, 0)), -- The literal "24"
					code.Instructions.new(code.make(code.OpReturnValue)),
				},
			},
			expected_instructions = {
					code.Instructions.new(code.make(code.OpConstant, 1)), -- The compiled function
					code.Instructions.new(code.make(code.OpSetGlobal, 0)),
					code.Instructions.new(code.make(code.OpGetGlobal, 0)),
					code.Instructions.new(code.make(code.OpCall, 0)),
					code.Instructions.new(code.make(code.OpPop)),
			}
		},
		{
			input = "let oneArg = fn(a) { }; oneArg(24);",
			expected_constants = {
				{
					code.Instructions.new(code.make(code.OpReturn)),
				},
				24,
			},
			expected_instructions = {
					code.Instructions.new(code.make(code.OpConstant, 0)),
					code.Instructions.new(code.make(code.OpSetGlobal, 0)),
					code.Instructions.new(code.make(code.OpGetGlobal, 0)),
					code.Instructions.new(code.make(code.OpConstant, 1)),
					code.Instructions.new(code.make(code.OpCall, 1)),
					code.Instructions.new(code.make(code.OpPop)),
			}
		},
		{
			input = "let manyArg = fn(a, b, c) { }; manyArg(24, 25, 26);",
			expected_constants = {
				{
					code.Instructions.new(code.make(code.OpReturn)),
				},
				24,
				25,
				26,
			},
			expected_instructions = {
					code.Instructions.new(code.make(code.OpConstant, 0)),
					code.Instructions.new(code.make(code.OpSetGlobal, 0)),
					code.Instructions.new(code.make(code.OpGetGlobal, 0)),
					code.Instructions.new(code.make(code.OpConstant, 1)),
					code.Instructions.new(code.make(code.OpConstant, 2)),
					code.Instructions.new(code.make(code.OpConstant, 3)),
					code.Instructions.new(code.make(code.OpCall, 3)),
					code.Instructions.new(code.make(code.OpPop)),
			}
		},
		{
			input = "let oneArg = fn(a) { a }; oneArg(24);",
			expected_constants = {
				{
					code.Instructions.new(code.make(code.OpGetLocal, 0)),
					code.Instructions.new(code.make(code.OpReturnValue)),
				},
				24,
			},
			expected_instructions = {
					code.Instructions.new(code.make(code.OpConstant, 0)),
					code.Instructions.new(code.make(code.OpSetGlobal, 0)),
					code.Instructions.new(code.make(code.OpGetGlobal, 0)),
					code.Instructions.new(code.make(code.OpConstant, 1)),
					code.Instructions.new(code.make(code.OpCall, 1)),
					code.Instructions.new(code.make(code.OpPop)),
			}
		},
		{
			input = [[
        let manyArg = fn(a, b, c) { a; b; c };
        manyArg(24, 25, 26);
      ]],
			expected_constants = {
				{
					code.Instructions.new(code.make(code.OpGetLocal, 0)),
					code.Instructions.new(code.make(code.OpPop)),
					code.Instructions.new(code.make(code.OpGetLocal, 1)),
					code.Instructions.new(code.make(code.OpPop)),
					code.Instructions.new(code.make(code.OpGetLocal, 2)),
					code.Instructions.new(code.make(code.OpReturnValue)),
				},
				24,
				25,
				26,
			},
			expected_instructions = {
					code.Instructions.new(code.make(code.OpConstant, 0)),
					code.Instructions.new(code.make(code.OpSetGlobal, 0)),
					code.Instructions.new(code.make(code.OpGetGlobal, 0)),
					code.Instructions.new(code.make(code.OpConstant, 1)),
					code.Instructions.new(code.make(code.OpConstant, 2)),
					code.Instructions.new(code.make(code.OpConstant, 3)),
					code.Instructions.new(code.make(code.OpCall, 3)),
					code.Instructions.new(code.make(code.OpPop)),
			}
		},
	}
	run_compiler_test(t, tests)
end

local function test_compiler_scopes (t: testing.T)
	local comp = compiler.new()
	expect_scope_index(t, comp, 0)
	local global_symbol_table = comp.symbol_table
	comp:emit(code.OpMul)
	comp:enter_scope()
	expect_scope_index(t, comp, 1)
	comp:emit(code.OpSub)
	if #comp.scopes[comp.scope_index+1].instructions.bytes ~= 1 then
		t:error("instructions length wrong. got=%d", #comp.scopes[comp.scope_index].instructions.bytes)
	end
	expect_last_instruction(t, comp, code.OpSub)
	if comp.symbol_table.outer ~= global_symbol_table then
		t:error("compiler did not enclose symbol_table")
	end
	comp:leave_scope()
	expect_scope_index(t, comp, 0)
	if comp.symbol_table ~= global_symbol_table then
		t:error("compiler did not restore global symbol table")
	end
	if comp.symbol_table.outer ~= nil then
		t:error("compiler modified global symbol table incorrectly")
	end
	comp:emit(code.OpAdd)
	if #comp.scopes[comp.scope_index+1].instructions.bytes ~= 2 then
		t:error("instructions length wrong. got=%d", #comp.scopes[comp.scope_index].instructions.bytes)
	end
	expect_last_instruction(t, comp, code.OpAdd)
	local previous = comp.scopes[comp.scope_index+1].previous_instruction
	if previous.opcode ~= code.OpMul then
		t:error("previous_instruction.opcode wrong. got=%d, want=%d", previous.opcode, code.OpMul)
	end
end

local function test_let_statement_scopes (t: testing.T)
	local tests: {CompilerTestCase} = {
		{
			input = [[
        let num = 55;
        fn() { num }
      ]],
			expected_constants = {
				55,
				{
					code.Instructions.new(code.make(code.OpGetGlobal, 0)),
					code.Instructions.new(code.make(code.OpReturnValue)),
				},
			},
			expected_instructions = {
					code.Instructions.new(code.make(code.OpConstant, 0)),
					code.Instructions.new(code.make(code.OpSetGlobal, 0)),
					code.Instructions.new(code.make(code.OpConstant, 1)),
					code.Instructions.new(code.make(code.OpPop)),
			}
		},
		{
			input = [[
        fn() {
          let  num = 55;
          num
        }
      ]],
			expected_constants = {
				55,
				{
					code.Instructions.new(code.make(code.OpConstant, 0)),
					code.Instructions.new(code.make(code.OpSetLocal, 0)),
					code.Instructions.new(code.make(code.OpGetLocal, 0)),
					code.Instructions.new(code.make(code.OpReturnValue)),
				},
			},
			expected_instructions = {
					code.Instructions.new(code.make(code.OpConstant, 1)),
					code.Instructions.new(code.make(code.OpPop)),
			}
		},
		{
			input = [[
        fn() {
          let a = 55;
          let b = 77;
          a + b
        }
      ]],
			expected_constants = {
				55,
				77,
				{
					code.Instructions.new(code.make(code.OpConstant, 0)),
					code.Instructions.new(code.make(code.OpSetLocal, 0)),
					code.Instructions.new(code.make(code.OpConstant, 1)),
					code.Instructions.new(code.make(code.OpSetLocal, 1)),
					code.Instructions.new(code.make(code.OpGetLocal, 0)),
					code.Instructions.new(code.make(code.OpGetLocal, 1)),
					code.Instructions.new(code.make(code.OpAdd)),
					code.Instructions.new(code.make(code.OpReturnValue)),
				},
			},
			expected_instructions = {
					code.Instructions.new(code.make(code.OpConstant, 2)),
					code.Instructions.new(code.make(code.OpPop)),
			}
		},
	}
	run_compiler_test(t, tests)
end

local function test_builtins (t: testing.T)
	local tests: {CompilerTestCase} = {
		{
			input = [[
        len([]);
        push([], 1);
      ]],
			expected_constants = {
				1,
			},
			expected_instructions = {
					code.Instructions.new(code.make(code.OpGetBuiltin, 0)),
					code.Instructions.new(code.make(code.OpArray, 0)),
					code.Instructions.new(code.make(code.OpCall, 1)),
					code.Instructions.new(code.make(code.OpPop)),
					code.Instructions.new(code.make(code.OpGetBuiltin, 5)),
					code.Instructions.new(code.make(code.OpArray, 0)),
					code.Instructions.new(code.make(code.OpConstant, 0)),
					code.Instructions.new(code.make(code.OpCall, 2)),
					code.Instructions.new(code.make(code.OpPop)),
			}
		},
		{
			input = [[
        fn() { len([]); }
      ]],
			expected_constants = {
				{
					code.Instructions.new(code.make(code.OpGetBuiltin, 0)),
					code.Instructions.new(code.make(code.OpArray, 0)),
					code.Instructions.new(code.make(code.OpCall, 1)),
					code.Instructions.new(code.make(code.OpReturnValue)),
				}
			},
			expected_instructions = {
					code.Instructions.new(code.make(code.OpConstant, 0)),
					code.Instructions.new(code.make(code.OpPop)),
			}
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
		{ name = "functions", func = test_functions },
		{ name = "compiler_scopes", func = test_compiler_scopes },
		{ name = "functions_without_return_value", func = test_functions_without_return_value },
		{ name = "function_calls", func = test_function_calls },
		{ name = "let_statement_scopes", func = test_let_statement_scopes },
		{ name = "builtins", func = test_builtins },
	}
}
