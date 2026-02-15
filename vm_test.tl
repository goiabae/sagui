
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
		if actual ~= object.NULL then
			t:error("object is not Null: %s", type(actual))
		end
	elseif expected is object.Error then
		if not (actual is object.Error) then
			t:error("object is not Error")
			return
		end
		local errobj = actual as object.Error
		if errobj.message ~= (expected as object.Error).message then
			t:error("wrong error message. expected '%s', got='%s'", (expected as object.Error).message, errobj.message)
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
		-- for i, constant in ipairs(comp:bytecode().constants) do
		-- 	print(string.format("CONSTANT %d %s:", i, constant))
		-- 	if constant is object.CompiledFunction then
		-- 		local fn = constant as object.CompiledFunction
		-- 		print(string.format(" Instruction:\n%s", fn.instructions:string()))
		-- 	elseif constant is object.Integer then
		-- 		local int = constant as object.Integer
		-- 		print(string.format(" Value: %d\n", int.value))
		-- 	end
		-- 	print()
		-- end
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
		{ input = "if (1 > 2) { 10 }", expected = object.NULL },
		{ input = "if (false) { 10 }", expected = object.NULL },
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
		{ input = "[][0]", expected = object.NULL },
		{ input = "[1, 2, 3][99]", expected = object.NULL },
		{ input = "[1][-1]", expected = object.NULL },
		{ input = "{1: 1, 2: 2}[1]", expected = 1 },
		{ input = "{1: 1, 2: 2}[2]", expected = 2 },
		{ input = "{1: 1}[0]", expected = object.NULL },
		{ input = "{}[0]", expected = object.NULL },
	}
	run_vm_tests(t, tests)
end

local function test_calling_functions_without_arguments (t: testing.T)
	local tests: {VMTestCase} = {
		{ input = "let fivePlusTen = fn() { 5 + 10; }; fivePlusTen();", expected = 15 },
		{
			input = [[
        let one = fn() { 1; };
        let two = fn() { 2; };
        one() + two()
      ]],
			expected = 3
		},
		{
			input = [[
        let a = fn() { 1 };
        let b = fn() { a() + 1 };
        let c = fn() { b() + 1 };
        c();
      ]],
			expected = 3
		},
	}
	run_vm_tests(t, tests)
end

local function test_functions_with_return_statement (t: testing.T)
	local tests: {VMTestCase} = {
		{
			input = [[
        let earlyExit = fn() { return 99; 100; };
        earlyExit();
      ]],
			expected = 99
		},
		{
			input = [[
        let earlyExit = fn() { return 99; return 100; };
        earlyExit();
      ]],
			expected = 99
		},
	}
	run_vm_tests(t, tests)
end

local function test_functions_without_return_value (t: testing.T)
	local tests: {VMTestCase} = {
		{
			input = [[
        let noReturn = fn() { };
        noReturn();
      ]],
			expected = object.NULL
		},
		{
			input = [[
        let noReturn = fn() { };
        let noReturnTwo = fn() { noReturn(); };
        noReturn();
        noReturnTwo();
      ]],
			expected = object.NULL
		},
	}
	run_vm_tests(t, tests)
end

local function test_first_class_functions (t: testing.T)
	local tests: {VMTestCase} = {
		{
			input = [[
        let returnsOneReturner = fn() {
          let returnsOne = fn() { 1; };
          returnsOne;
        };
        returnsOneReturner()();
      ]],
			expected = 1
		},
	}
	run_vm_tests(t, tests)
end

local function test_calling_functions_with_bindings (t: testing.T)
	local tests: {VMTestCase} = {
		{
			input = [[
        let one = fn() { let one = 1; one };
        one();
      ]],
			expected = 1
		},
		{
			input = [[
        let oneAndTwo = fn() { let one = 1; let two = 2; one + two; };
        oneAndTwo();
      ]],
			expected = 3
		},
		{
			input = [[
        let oneAndTwo = fn() { let one = 1; let two = 2; one + two; };
        let threeAndFour = fn() { let three = 3; let four = 4; three + four; };
        oneAndTwo() + threeAndFour();
      ]],
			expected = 10
		},
		{
			input = [[
        let firstFoobar = fn() { let foobar = 50; foobar; };
        let secondFoobar = fn() { let foobar = 100; foobar; };
        firstFoobar() + secondFoobar();
      ]],
			expected = 150
		},
		{
			input = [[
        let globalSeed = 50;
        let minusOne = fn() { let num = 1; globalSeed - num; };
        let minusTwo = fn() { let num = 2; globalSeed - num; };
        minusOne() + minusTwo();
      ]],
			expected = 97
		},
	}
	run_vm_tests(t, tests)
end

local function test_calling_functions_with_arguments_and_bindings (t: testing.T)
	local tests: {VMTestCase} = {
		{
			input = [[
        let identity = fn(a) { a; };
        identity(4);
      ]],
			expected = 4
		},
		{
			input = [[
        let sum = fn(a, b) { a + b; };
        sum(1, 2);
      ]],
			expected = 3
		},
		{
			input = [[
        let sum = fn(a, b) { let c = a + b; c; };
        sum(1, 2);
      ]],
			expected = 3
		},
		{
			input = [[
        let sum = fn(a, b) { let c = a + b; c; };
        sum(1, 2) + sum(3, 4);
      ]],
			expected = 10
		},
		{
			input = [[
        let sum = fn(a, b) { let c = a + b; c; };
        let outer = fn() { sum(1, 2) + sum(3, 4); };
        outer();
      ]],
			expected = 10
		},
		{
			input = [[
        let globalNum = 10;
        let sum = fn(a, b) { let c = a + b; c + globalNum; };
        let outer = fn() { sum(1, 2) + sum(3, 4) + globalNum; };
        outer() + globalNum;
      ]],
			expected = 50
		},
	}
	run_vm_tests(t, tests)
end

local function test_calling_functions_with_wrong_arguments (t: testing.T)
	local tests: {VMTestCase} = {
		{
			input = "fn() { 1; }(1);",
			expected = "wrong number of arguments: want=0, got=1",
		},
		{
			input = "fn(a) { a; }();",
			expected = "wrong number of arguments: want=1, got=0",
		},
		{
			input = "fn(a, b) { a + b; }(1);",
			expected = "wrong number of arguments: want=2, got=1",
		},
	}
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
			if err == nil then
				t:fatal_fail("expected VM error but resulted in none.")
			end
			if err ~= tt.expected then
				t:fatal_fail("wrong VM error: want='%s', got='%s'", tt.expected, err)
			end
		end
	end
end

local function test_calling_functions_with_wrong_arguments2 (t: testing.T)
	local tests: {VMTestCase} = {
		{
			input = 'len("")',
			expected = 0,
		},
		{
			input = 'len("four")',
			expected = 4,
		},
		{
			input = 'len("hello world")',
			expected = 11,
		},
		{
			input = 'len(1)',
			expected = object.Error.new("argument to 'len' not supported, got INTEGER"),
		},
		{
			input = 'len("one", "two")',
			expected = object.Error.new("wrong number of arguments. got=2, want=1"),
		},
		{
			input = 'len([1, 2, 3])',
			expected = 3,
		},
		{ input = 'len([])', expected = 0},
		{ input = 'puts("hello", "world!")', expected = object.NULL},
		{ input = 'first([1, 2, 3])', expected = 1},
		{ input = 'first([])', expected = object.NULL},
		{ input = 'first(1)', expected = object.Error.new("argument to 'first' must be ARRAY, got INTEGER"), },
		{ input = 'last([1, 2, 3])', expected = 3},
		{ input = 'last([])', expected = object.NULL },
		{ input = 'last(1)', expected = object.Error.new("argument to 'last' must be ARRAY, got INTEGER") },
		{ input = 'rest([1, 2, 3])', expected = { 2, 3 } },
		{ input = 'rest([])', expected = object.NULL },
		{ input = 'push([], 1)', expected = { 1 }},
		{ input = 'push(1, 1)', expected = object.Error.new("argument to 'push' must be ARRAY, got INTEGER") },
	}
	run_vm_tests(t, tests)
end

local function test_closures (t: testing.T)
	local tests: {VMTestCase} = {
		{
			input = [[
        let newClosure = fn(a) {
          fn() { a; };
        };
        let closure = newClosure(99);
        closure();
      ]],
			expected = 99,
		},
		{
			input = [[
        let newAdder = fn(a, b) {
          fn(c) { a + b + c; };
        };
        let adder = newAdder(1, 2);
        adder(8);
      ]],
			expected = 11,
		},
		{
			input = [[
        let newAdder = fn(a, b) {
          let c = a + b;
          fn(d) { c + d; };
        };
        let adder = newAdder(1, 2);
        adder(8);
      ]],
			expected = 11,
		},
		{
			input = [[
        let newAdderOuter = fn(a, b) {
          let c = a + b;
          fn(d) {
            let e = d + c;
            fn(f) { e + f; };
          };
        };
        let newAdderInner = newAdderOuter(1, 2);
        let adder = newAdderInner(3);
        adder(8);
      ]],
			expected = 14,
		},
		{
			input = [[
        let a = 1;
        let newAdderOuter = fn(b) {
          fn(c) {
            fn(d) {
              a + b + c + d;
            };
          };
        };
        let newAdderInner = newAdderOuter(2);
        let adder = newAdderInner(3);
        adder(8);
      ]],
			expected = 14,
		},
		{
			input = [[
        let newClosure = fn(a, b) {
          let one = fn() { a; };
          let two = fn() { b; };
          fn() { one() + two(); };
        };
        let closure = newClosure(9, 90);
        closure();
      ]],
			expected = 99,
		},
	}
	run_vm_tests(t, tests)
end

local function test_recursive_functions (t: testing.T)
	local tests: {VMTestCase} = {
		{
			input = [[
        let countDown = fn(x) {
          if (x == 0) {
            return 0;
          } else {
            countDown(x - 1);
          }
        };
        countDown(1);
      ]],
			expected = 0,
		},
		{
			input = [[
        let countDown = fn(x) {
          if (x == 0) {
            return 0;
          } else {
            countDown(x - 1);
          }
        };
        let wrapper = fn() {
          countDown(1);
        };
        wrapper();
      ]],
			expected = 0,
		},
		{
			input = [[
        let wrapper = fn() {
          let countDown = fn(x) {
            if (x == 0) {
              return 0;
            } else {
              countDown(x - 1);
            }
          };
          countDown(1);
        };
        wrapper();
      ]],
			expected = 0,
		},
	}
	run_vm_tests(t, tests)
end

local function test_recursive_fibonacci (t: testing.T)
	local tests: {VMTestCase} = {
		{
			input = [[
        let fibonacci = fn(x) {
          if (x == 0) {
            return 0;
          } else {
            if (x == 1) {
              return 1;
            } else {
              fibonacci(x - 1) + fibonacci(x - 2);
            }
          }
        };
        fibonacci(15);
      ]],
			expected = 610,
		},
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
		{ name = "calling_functions_without_arguments", func = test_calling_functions_without_arguments },
		{ name = "functions_with_return_statement", func = test_functions_with_return_statement },
		{ name = "functions_without_return_value", func = test_functions_without_return_value },
		{ name = "first_class_functions", func = test_first_class_functions },
		{ name = "calling_functions_with_bindings", func = test_calling_functions_with_bindings },
		{ name = "calling_functions_with_arguments_and_bindings", func = test_calling_functions_with_arguments_and_bindings },
		{ name = "calling_functions_with_wrong_arguments", func = test_calling_functions_with_wrong_arguments },
		{ name = "calling_functions_with_wrong_arguments2", func = test_calling_functions_with_wrong_arguments2 },
		{ name = "closures", func = test_closures },
		{ name = "recursive_functions", func = test_recursive_functions },
		{ name = "recursive_fibonacci", func = test_recursive_fibonacci },
	}
}
