
local evaluator = require("evaluator")
local lexer = require("lexer.lexer")
local object = require("object")
local parser = require("parser.parser")
local testing = require("testing")

local function test_eval (input: string): object.Object
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	assert(program ~= nil)
	return evaluator.eval(program)
end

local function test_integer_object (t: testing.T, obj: object.Object, expected: integer): boolean
	if not obj then
		t.error("object was nil")
		return false
	end
	if not (obj is object.Integer) then
		t.error("object is not Integer. got=%s", type(obj))
		return false
	end
	local result = obj as object.Integer
	if result.value ~= expected then
		t.error("object has wrong value. got=%d, want=%d", result.value, expected)
		return false
	end
	return true
end

local function test_eval_integer_expression (t: testing.T)
	local tests = {
		{"5", 5},
		{"10", 10},
		{"-5", -5},
		{"-10", -10},
		{"5 + 5 + 5 + 5 - 10", 10},
		{"2 * 2 * 2 * 2 * 2", 32},
		{"-50 + 100 + -50", 0},
		{"5 * 2 + 10", 20},
		{"5 + 2 * 10", 25},
		{"20 + 2 * -10", 0},
		{"50 / 2 * 2 + 10", 60},
		{"2 * (5 + 10)", 30},
		{"3 * 3 * 3 + 10", 37},
		{"3 * (3 * 3) + 10", 37},
		{"(5 + 10 * 2 + 15 / 3) * 2 + -10", 50},
	}
	for _, tt in ipairs(tests) do
		local evaluated = test_eval(tt[1])
		test_integer_object(t, evaluated, tt[2])
	end
end

local function test_boolean_object (t: testing.T, obj: object.Object, expected: boolean): boolean
	if not obj then
		t.error("object was nil")
		return false
	end
	if not (obj is object.Boolean) then
		t.error("object is not Boolean. got=%s", type(obj))
		return false
	end
	local result = obj as object.Boolean
	if result.value ~= expected then
		t.error("object has wrong value. got=%s, want=%t", result.value and "true" or "false", expected and "true" or "false")
		return false
	end
	return true
end

local function test_eval_boolean_expression (t: testing.T)
	local tests = {
		{"true", true},
		{"false", false},
		{"1 < 2", true},
		{"1 > 2", false},
		{"1 < 1", false},
		{"1 > 1", false},
		{"1 == 1", true},
		{"1 != 1", false},
		{"1 == 2", false},
		{"1 != 2", true},
		{"true == true", true},
		{"false == false", true},
		{"true == false", false},
		{"true != false", true},
		{"false != true", true},
		{"(1 < 2) == true", true},
		{"(1 < 2) == false", false},
		{"(1 > 2) == true", false},
		{"(1 > 2) == false", true},
	}
	for _, tt in ipairs(tests) do
		local evaluated = test_eval(tt[1])
		test_boolean_object(t, evaluated, tt[2])
	end
end

local function test_bang_operator (t: testing.T)
	local tests = {
		{"!true", false},
		{"!false", true},
		{"!5", false},
		{"!!true", true},
		{"!!false", false},
		{"!!5", true},
	}
	for _, tt in ipairs(tests) do
		local evaluated = test_eval(tt[1])
		test_boolean_object(t, evaluated, tt[2])
	end
end

local function test_null_object (t: testing.T, obj: object.Object): boolean
	if obj ~= evaluator.NULL then
		t.error("object is not NULL. got=%s", type(obj))
		return false
	end
	return true
end

local function test_if_else_expressions (t: testing.T)
	local tests = {
		{"if (true) { 10 }", 10},
		{"if (false) { 10 }", nil},
		{"if (1) { 10 }", 10},
		{"if (1 < 2) { 10 }", 10},
		{"if (1 > 2) { 10 }", nil},
		{"if (1 > 2) { 10 } else { 20 }", 20},
		{"if (1 < 2) { 10 } else { 20 }", 10},
	}
	for _, tt in ipairs(tests) do
		local evaluated = test_eval(tt[1])
		if tt[2] == nil then
			test_null_object(t, evaluated)
		else
			test_integer_object(t, evaluated, tt[2])
		end
	end
end

local function test_return_statements (t: testing.T)
	local tests = {
		{"return 10;", 10},
		{"return 10; 9;", 10},
		{"return 2 * 5; 9;", 10},
		{"9; return 2 * 5; 9;", 10},
		{
			[[
         if (10 > 1) {
           if (10 > 1) {
             return 10;
           }
           return 1;
         }
      ]],
			10,
		},
	}
	for _, tt in ipairs(tests) do
		local evaluated = test_eval(tt[1])
		test_integer_object(t, evaluated, tt[2])
	end
end

local function test_error_handling (t: testing.T)
	local tests = {
		{
			"5 + true;",
			"type mismatch: INTEGER + BOOLEAN",
		},
		{
			"5 + true; 5;",
			"type mismatch: INTEGER + BOOLEAN",
		},
		{
			"-true",
			"unknown operator: -BOOLEAN",
		},
		{
			"true + false;",    "unknown operator: BOOLEAN + BOOLEAN",
		},
		{
			"5; true + false; 5",
			"unknown operator: BOOLEAN + BOOLEAN",
		},
		{
			"if (10 > 1) { true + false; }",
			"unknown operator: BOOLEAN + BOOLEAN",
		},
		{
			[[
        if (10 > 1) {
          if (10 > 1) {
            return true + false;
          }
          return 1;
        }
      ]],
			"unknown operator: BOOLEAN + BOOLEAN",
		},
		{
			"foobar",
			"identifier not found: foobar",
		},
	}
	for _, tt in ipairs(tests) do
		local evaluated = test_eval(tt[1])
		if not evaluated then
			t.error("error object was nil")
		elseif not (evaluated is object.Error) then
			t.error("no error object returned. got=%s", evaluated:type())
		else
			local err_obj = evaluated as object.Error
			if err_obj.message ~= tt[2] then
				t.error("wrong error message. expected='%s', got='%s'", tt[2], err_obj.message)
			end
		end
	end
end

local function test_let_statement (t: testing.T)
	local tests = {
		{"let a = 5; a;", 5},
		{"let a = 5 * 5; a;", 25},
		{"let a = 5; let b = a; b;", 5},
		{"let a = 5; let b = a; let c = a + b + 5; c;", 15},
	}
	for _, tt in ipairs(tests) do
		test_integer_object(t, test_eval(tt[1]), tt[2])
	end
end

local t = testing.new()
test_eval_integer_expression(t)
test_eval_boolean_expression(t)
test_bang_operator(t)
test_if_else_expressions(t)
test_return_statements(t)
test_error_handling(t)
