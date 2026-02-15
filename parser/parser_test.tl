
local testing = require("testing")
local ast = require("ast.ast")
local lexer = require("lexer.lexer")
local parser = require("parser.parser")

local type check_node_fn = function (testing.T, ast.Node): boolean

local function anything_checker (): check_node_fn
	return function (_: testing.T, _: ast.Node): boolean
		return true
	end
end

local function integer_literal_checker (value: integer): check_node_fn
	return function (t: testing.T, il: ast.Expression): boolean
		if not (il is ast.IntegerLiteral) then
			t:error("il not ast.IntegerLiteral. got=%s", type(il))
			return false
		end
		local integ = il as ast.IntegerLiteral
		if integ.value ~= value then
			t:error("integ.value not %d. got=%d", value, integ.value)
			return false
		end
		if integ:token_literal() ~= tostring(value) then
			t:error("integ:token_literal() not %d. got=%d", tostring(value), integ:token_literal())
			return false
		end
		return true
	end
end


local function string_literal_checker (value: string): check_node_fn
	return function (t: testing.T, il: ast.Expression): boolean
		if not (il is ast.StringLiteral) then
			t:error("il not ast.StringLiteral. got=%s", type(il))
			return false
		end
		local integ = il as ast.StringLiteral
		if integ.value ~= value then
			t:error("integ.value not '%s'. got='%s'", value, integ.value)
			return false
		end
		if integ:token_literal() ~= value then
			t:error("integ:token_literal() not '%s'. got='%s'", value, integ:token_literal())
			return false
		end
		return true
	end
end

local function identifier_checker (value: string): check_node_fn
	return function (t: testing.T, exp: ast.Expression): boolean
		if not (exp is ast.Identifier) then
			t:error("exp not ast.Identifier. got=%s", type(exp))
			return false
		end
		local ident = exp as ast.Identifier
		if ident.value ~= value then
			t:error("ident.value not %s. got=%s", value, ident.value)
			return false
		end
		if ident:token_literal() ~= value then
			t:error("ident:token_literal() not %s. got=%s", value, ident:token_literal())
			return false
		end
		return true
	end
end

local function literal_checker (value: string | integer): check_node_fn
	if type(value) == "integer" then
		return integer_literal_checker(value as integer)
	elseif type(value) == "string" then
		return identifier_checker(value as string)
	end
end

local function infix_expression_checker (operator: string, left_ck: check_node_fn, right_ck: check_node_fn): check_node_fn
	return function (t: testing.T, exp: ast.Expression): boolean
		if not (exp is ast.InfixExpression) then
			t:error("exp is not ast.InfixExpression. got=%s", type(exp))
			return false
		end
		local op_exp = exp as ast.InfixExpression
		if not left_ck(t, op_exp.left) then
			return false
		end
		if op_exp.operator ~= operator then
			t:error("exp.operator is not '%s'. got='%s'", operator, op_exp.operator)
			return false
		end
		if not right_ck(t, op_exp.right) then
			return false
		end
		return true
	end
end

local function index_expression_checker (arr_ck: check_node_fn, idx_ck: check_node_fn): check_node_fn
	return function (t: testing.T, node: ast.Node): boolean
		if not (node is ast.IndexExpression) then
			t:error("exp is not ast.IndexExpression. got=%s", type(node))
			return false
		end
		local index_exp = node as ast.IndexExpression
		if not arr_ck(t, index_exp.left) then
			return false
		end
		if not idx_ck(t, index_exp.index) then
			return false
		end
		return true
	end
end

local function expression_statement_checker (exp_ck: check_node_fn): check_node_fn
	return function (t: testing.T, stmt: ast.Statement): boolean
		local a = stmt
		if not (a is ast.ExpressionStatement) then
			t:fatal_fail("stmt is not ast.ExpressionStatement")
		end
		return exp_ck(t, (stmt as ast.ExpressionStatement).expression)
	end
end

local function if_expression_checker (cond_ck: check_node_fn, cons_ck: check_node_fn, alt_ck: check_node_fn): check_node_fn
	return function (t: testing.T, node: ast.Node): boolean
		if not (node is ast.IfExpression) then
			t:fatal_fail("node not a ast.Ifexpression")
		end
		local if_exp = node as ast.IfExpression
		if if_exp.condition == nil then
			t:fatal_fail("if expression condition was nil")
		end
		return cond_ck(t, if_exp.condition)
			and (if_exp.consequence and cons_ck(t, if_exp.consequence))
			and (alt_ck and alt_ck(t, if_exp.alternative) or if_exp.alternative == nil)
	end
end

local function block_statement_checker (cks: { check_node_fn }): check_node_fn
	return function (t: testing.T, node: ast.Node): boolean
		if not (node is ast.BlockStatement) then
			return false
		end
		local blk = node as ast.BlockStatement
		if #blk.statements ~= #cks then
			t:fatal_fail("block has not enough statements. got=%d", #blk.statements)
		end
		for i, ck in ipairs(cks) do
			if not ck(t, blk.statements[i]) then
				return false
			end
		end
		return true
	end
end

local function boolean_literal_checker (value: boolean): check_node_fn
	return function (t: testing.T, il: ast.Expression): boolean
		if not (il is ast.Boolean) then
			t:error("il not ast.Boolean. got=%s", type(il))
			return false
		end
		local integ = il as ast.Boolean
		if integ.value ~= value then
			t:error("integ.value not %d. got=%d", value, integ.value)
			return false
		end
		if integ:token_literal() ~= tostring(value) then
			t:error("integ:token_literal() not %d. got=%d", tostring(value), integ:token_literal())
			return false
		end
		return true
	end
end

local function program_checker (cks: { check_node_fn }): check_node_fn
	return function (t: testing.T, node: ast.Node): boolean
		if not (node is ast.Program) then
			return false
		end
		local prog = node as ast.Program
		if #prog.statements ~= #cks then
			t:fatal_fail("program has not enough statements. got=%d", #prog.statements)
		end
		for i, ck in ipairs(cks) do
			if not ck(t, prog.statements[i]) then
				return false
			end
		end
		return true
	end
end

local function function_literal_checker (params: {string}, body_ck: check_node_fn, name?: string): check_node_fn
	return function (t: testing.T, node: ast.Node): boolean
		if not node then
			t:fatal_fail("node was nil")
		end
		if not (node is ast.FunctionLiteral) then
			t:error("node not ast.Functionliteral. got=%s", type(node))
			return false
		end
		local func = node as ast.FunctionLiteral
		if name ~= nil then
			if func.name == nil then
				t:error("recursive function literal not given name.")
			else
				if func.name ~= name then
					t:error("recursive function literal with wrong name. want='%s', got='%s'", name, func.name)
				end
			end
		end
		if #func.parameters ~= #params then
			t:error("function literal has not %d parameters. got=%d", #params, #func.parameters)
		end
		for i, p in ipairs(params) do
			if not identifier_checker(p)(t, func.parameters[i]) then
				return false
			end
		end
		return body_ck(t, func.body)
	end
end

local function array_literal_checker (cks: {check_node_fn}): check_node_fn
	return function (t: testing.T, node: ast.Node): boolean
		if not node then
			t:fatal_fail("node was nil")
		end
		if not (node is ast.ArrayLiteral) then
			t:error("node not ast.ArrayLiteral. got=%s", type(node))
			return false
		end
		local arr = node as ast.ArrayLiteral
		if #arr.elements ~= #cks then
			t:error("array literal has not %d elements. got=%d", #cks, #arr.elements)
		end
		for i, e in ipairs(arr.elements) do
			if not cks[i](t, e) then
				return false
			end
		end
		return true
	end
end

local function hash_literal_checker (cks: { string:check_node_fn }): check_node_fn
	return function (t: testing.T, node: ast.Node): boolean
		if not node then
			t:fatal_fail("node was nil")
		end
		if not (node is ast.HashLiteral) then
			t:error("node not ast.HashLiteral. got=%s", type(node))
			return false
		end
		local hash = node as ast.HashLiteral
		for k, v in pairs(hash.pairs) do
			if cks[k:string()] == nil then
				t:error("hash has unexpected key %s", k:string())
				return false
			else
				if not cks[k:string()](t, v) then
					return false
				end
			end
		end
		return true
	end
end

local function return_statement_checker (exp_ck: check_node_fn): check_node_fn
	return function (t: testing.T, node: ast.Node): boolean
		if not node then
			t:fatal_fail("node was nil")
		end
		if not (node is ast.ReturnStatement) then
			t:error("node not ast.Returnstatement. got=%s", type(node))
			return false
		end
		local ret = node as ast.ReturnStatement
		return exp_ck(t, ret.return_value)
	end
end

local function call_expression_checker (func_ck: check_node_fn, cks: { check_node_fn }): check_node_fn
	return function (t: testing.T, node: ast.Node): boolean
		if not (node is ast.CallExpression) then
			t:error("node not ast.CallExpression. got=%s", type(node))
			return false
		end
		local call = node as ast.CallExpression
		if not func_ck(t, call.func) then
			return false
		end
		if #call.arguments ~= #cks then
			t:error("call expression has not %d arguments. got=%d", #cks, #call.arguments)
			return false
		end
		for i, a in ipairs(call.arguments) do
			if not cks[i](t, a) then
				return false
			end
		end
		return true
	end
end

local function let_statement_checker (name: string, value_ck: check_node_fn): check_node_fn
	return function (t: testing.T, node: ast.Node): boolean
		if node:token_literal() ~= "let" then
			t:error("s:token_literal() not 'let'. got='%s'", node:token_literal())
			return false
		end
		if not (node is ast.LetStatement) then
			t:error("s not ast.LetStatement")
			return false
		end
		local let_stmt = node as ast.LetStatement
		if let_stmt.name.value ~= name then
			t:error("let_stmt.name.value not '%s'. got='%s'", name, let_stmt.name.value)
			return false
		end
		if let_stmt.name:token_literal() ~= name then
			t:error("let_stmt.name:token_literal() not '%s'. got='%s'", name, let_stmt.name:token_literal())
			return false
		end
		if not value_ck(t, let_stmt.value) then
			return false
		end
		return true
	end
end

do
	local token = require("token")
	local t = testing.T.new()

	do
		local node = ast.IntegerLiteral.new({ type = token.INT, literal = "5" }, 5)
		local ck = integer_literal_checker(5)
		assert(ck(t, node))
	end

	do
		local node = ast.ExpressionStatement.new(
			{ type = token.FALSE, literal = "false" },
			ast.Boolean.new(
				{ type = token.FALSE, literal = "false" },
				false
			)
		)
		local ck = expression_statement_checker(
			boolean_literal_checker(false)
		)
		assert(ck(t, node))
	end

	do
		local node = ast.Boolean.new({ type = token.FALSE, literal = "false" }, false)
		local ck = boolean_literal_checker(false)
		assert(ck(t, node))
	end

	do
		local node = ast.Identifier.new({ type = token.IDENT, literal = "x" }, "x")
		local ck = identifier_checker("x")
		assert(ck(t, node))
	end

	do
		local node = ast.Identifier.new({ type = token.IDENT, literal = "x" }, "x")
		local ck = literal_checker("x")
		assert(ck(t, node))
	end

	do
		local node = ast.InfixExpression.new(
			{ type = token.PLUS, literal = "+" },
			ast.IntegerLiteral.new({ type = token.INT, literal = "5" }, 5),
			"+",
			ast.InfixExpression.new(
				{ type = token.ASTERISK, literal = "*" },
				ast.IntegerLiteral.new({ type = token.INT, literal = "15"}, 15),
				"*",
				ast.IntegerLiteral.new({ type = token.INT, literal = "10" }, 10)
			)
		)
		local ck = infix_expression_checker(
			"+",
			integer_literal_checker(5),
			infix_expression_checker("*", integer_literal_checker(15), integer_literal_checker(10))
		)
		assert(ck(t, node))
	end

	do
		local node = ast.InfixExpression.new(
			{ type = token.LT, literal = "<" },
			ast.Identifier.new({ type = token.IDENT, literal = "x" }, "x"),
			"<",
			ast.Identifier.new({ type = token.IDENT, literal = "y" }, "y")
		)
		local ck = infix_expression_checker(
			"<",
			identifier_checker("x"),
			identifier_checker("y")
		)
		assert(ck(t, node))
	end
end

local function check_integer_literal (t: testing.T, il: ast.Expression, value: integer): boolean
	if not (il is ast.IntegerLiteral) then
		t:error("il not ast.IntegerLiteral. got=%s", type(il))
		return false
	end
	local integ = il as ast.IntegerLiteral
	if integ.value ~= value then
		t:error("integ.value not %d. got=%d", value, integ.value)
		return false
	end
	if integ:token_literal() ~= tostring(value) then
		t:error("integ:token_literal() not %d. got=%d", tostring(value), integ:token_literal())
		return false
	end
	return true
end

local function test_identifier (t: testing.T, exp: ast.Expression, value: string): boolean
	if not (exp is ast.Identifier) then
		t:error("exp not ast.Identifier. got=%s", type(exp))
		return false
	end
	local ident = exp as ast.Identifier
	if ident.value ~= value then
		t:error("ident.value not %s. got=%s", value, ident.value)
		return false
	end
	if ident:token_literal() ~= value then
		t:error("ident:token_literal() not %s. got=%s", value, ident:token_literal())
		return false
	end
	return true
end

local function test_boolean_literal (t: testing.T, exp: ast.Expression, value: boolean): boolean
	return boolean_literal_checker(value)(t, exp)
end

local function test_literal_expression (t: testing.T, exp: ast.Expression, expected: any): boolean
	if type(expected) == "number" then
		return check_integer_literal(t, exp, expected as integer)
	elseif type(expected) == "string" then
		return test_identifier(t, exp, expected as string)
	elseif type(expected) == "boolean" then
		return test_boolean_literal(t, exp, expected as boolean)
	end
	t:error("type of exp not handled. got=%s", type(exp))
	return false
end

local function check_infix_expression (t: testing.T, exp: ast.Expression, left: any, operator: string, right: any): boolean
	if not (exp is ast.InfixExpression) then
		t:error("exp is not ast.InfixExpression. got=%s", type(exp))
		return false
	end
	local op_exp = exp as ast.InfixExpression
	if not test_literal_expression(t, op_exp.left, left) then
		return false
	end
	if op_exp.operator ~= operator then
		t:error("exp.operator is not '%s'. got='%s'", operator, op_exp.operator)
		return false
	end
	if not test_literal_expression(t, op_exp.right, right) then
		return false
	end
	return true
end

local function check_prefix_expression (t: testing.T, exp: ast.Expression, operator: string, right: any): boolean
	if not (exp is ast.PrefixExpression) then
		t:error("exp is not ast.PrefixExpression. got=%s", type(exp))
		return false
	end
	local op_exp = exp as ast.PrefixExpression
	if op_exp.operator ~= operator then
		t:error("exp.operator is not '%s'. got='%s'", operator, op_exp.operator)
		return false
	end
	if not test_literal_expression(t, op_exp.right, right) then
		return false
	end
	return true
end

do
	local token = require("token")
	local t = testing.T.new()
	local a = ast.IntegerLiteral.new({ type = token.INT, literal = "5" }, 5)
	local b = ast.PrefixExpression.new({ type = token.BANG, literal = "!" }, "!", a)
	assert(check_prefix_expression(t, b, "!", 5))
end

local function check_let_statement (t: testing.T, s: ast.Statement, name: string): boolean
	if s:token_literal() ~= "let" then
		t:error("s:token_literal() not 'let'. got='%s'", s:token_literal())
		return false
	end
	if not (s is ast.LetStatement) then
		t:error("s not ast.LetStatement")
		return false
	end
	local let_stmt = s as ast.LetStatement
	if let_stmt.name.value ~= name then
		t:error("let_stmt.name.value not '%s'. got='%s'", name, let_stmt.name.value)
		return false
	end
	if let_stmt.name:token_literal() ~= name then
		t:error("let_stmt.name:token_literal() not '%s'. got='%s'", name, let_stmt.name:token_literal())
		return false
	end
	return true
end

local function check_parser_errors(t: testing.T, p: parser.Parser)
	local errors = p:get_errors()
	if #errors == 0 then
		return
	end
	for _, msg in ipairs(errors) do
		t:error("parser error: '%s'", msg)
	end
	t:fatal_fail("parser has %d errors", #errors)
end

local function test_parsing_let_statement (t: testing.T)
	local input = [[
    let x = 5;
    let y = 10;
    let foobar = 838383;
  ]]
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	if program == nil then
		t:fatal_fail("parse_program() returned nil")
	end
	if #program.statements ~= 3 then
		t:fatal_fail("program.statements does not contain 3 statements: %d", #program.statements)
	end
	local tests: {string} = {
		"x",
		"y",
		"foobar",
	}
	for i, expected_identifier in ipairs(tests) do
		local stmt = program.statements[i]
		if not check_let_statement(t, stmt, expected_identifier) then
			return
		end
	end
end

local function test_return_statements (t: testing.T)
	local input = [[
    return 5;
    return 10;
    return 993322;
  ]]
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	local ck = program_checker {
		return_statement_checker(integer_literal_checker(5)),
		return_statement_checker(integer_literal_checker(10)),
		return_statement_checker(integer_literal_checker(993322)),
	}
	ck(t, program)
end

local function test_identifier_expression (t: testing.T)
	local input = "foobar;"
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	local ck = program_checker {
		expression_statement_checker(
			identifier_checker("foobar")
		)
	}
	ck(t, program)
end

local function test_parsing_integer_literal (t: testing.T)
	local input = "5;"
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	local ck = program_checker {
		expression_statement_checker(
			integer_literal_checker(5)
		)
	}
	ck(t, program)
end

local function test_parsing_prefix_expressions (t: testing.T)
	local prefix_tests: { { string, string, any } } = {
		{"!5;", "!", 5},
		{"-15;", "-", 15},
		{"!true;", "!", true},
		{"!false;", "!", false},
	}
	for _, tt in ipairs(prefix_tests) do
		local input = tt[1]
		local operator = tt[2]
		local integer_value = tt[3]
		local l = lexer.new(input)
		local p = parser.new(l)
		local program = p:parse_program()
		check_parser_errors(t, p)
		if #program.statements ~= 1 then
			t:fatal_fail("program does not contain %d statements. got=%d", 1, #program.statements)
		end
		local a = program.statements[1]
		if not (a is ast.ExpressionStatement) then
			t:fatal_fail("program.statements[1] is not ast.ExpressionStatement")
		end
		local stmt = program.statements[1] as ast.ExpressionStatement
		check_prefix_expression(t, stmt.expression, operator, integer_value)
	end
end

local function test_parsing_infix_expression (t: testing.T)
	local infix_tests: { { string, any, string, any } } = {
		{"5 + 5;", 5, "+", 5},
		{"5 - 5;", 5, "-", 5},
		{"5 * 5;", 5, "*", 5},
		{"5 / 5;", 5, "/", 5},
		{"5 > 5;", 5, ">", 5},
		{"5 < 5;", 5, "<", 5},
		{"5 == 5;", 5, "==", 5},
		{"5 != 5;", 5, "!=", 5},
		{"true == true", true, "==", true},
		{"true != false", true, "!=", false},
		{"false == false", false, "==", false},
	}
	for _, tt in ipairs(infix_tests) do
		local input = tt[1]
		local left_value = tt[2]
		local operator = tt[3]
		local right_value = tt[4]

		local l = lexer.new(input)
		local p = parser.new(l)
		local program = p:parse_program()
		check_parser_errors(t, p)
		if #program.statements ~= 1 then
			t:fatal_fail("program does not contain %d statements. got=%d", 1, #program.statements)
		end
		local a = program.statements[1]
		if not (a is ast.ExpressionStatement) then
			t:fatal_fail("program.statements[1] is not ast.ExpressionStatement")
		end
		local stmt = program.statements[1] as ast.ExpressionStatement
		check_infix_expression(t, stmt.expression, left_value, operator, right_value)
	end
end

local function test_operator_precedence_parsing (t: testing.T)
	local tests = {
		{ "-a * b", "((-a) * b)" },
		{ "!-a", "(!(-a))" },
		{ "a + b + c", "((a + b) + c)" },
		{ "a + b - c", "((a + b) - c)" },
		{ "a * b * c", "((a * b) * c)" },
		{ "a * b / c", "((a * b) / c)" },
		{ "a + b / c", "(a + (b / c))" },
		{ "a + b * c + d / e - f", "(((a + (b * c)) + (d / e)) - f)" },
		{ "3 + 4; -5 * 5", "(3 + 4)((-5) * 5)" },
		{ "5 > 4 == 3 < 4", "((5 > 4) == (3 < 4))" },
		{ "5 < 4 != 3 > 4", "((5 < 4) != (3 > 4))" },
		{ "3 + 4 * 5 == 3 * 1 + 4 * 5", "((3 + (4 * 5)) == ((3 * 1) + (4 * 5)))" },
		{ "true", "true" },
		{ "false", "false" },
		{ "3 > 5 == false", "((3 > 5) == false)" },
		{ "3 < 5 == true", "((3 < 5) == true)" },
		{ "1 + (2 + 3) + 4", "((1 + (2 + 3)) + 4)" },
		{ "(5 + 5) * 2", "((5 + 5) * 2)" },
		{ "2 / (5 + 5)", "(2 / (5 + 5))" },
		{ "-(5 + 5)", "(-(5 + 5))" },
		{ "!(true == true)", "(!(true == true))" },
		{ "a + add(b * c) + d", "((a + add((b * c))) + d)" },
		{ "add(a, b, 1, 2 * 3, 4 + 5, add(6, 7 * 8))", "add(a, b, 1, (2 * 3), (4 + 5), add(6, (7 * 8)))" },
		{ "add(a + b + c * d / f + g)", "add((((a + b) + ((c * d) / f)) + g))" },
		{ "a * [1, 2, 3, 4][b * c] * d", "((a * ([1, 2, 3, 4][(b * c)])) * d)" },
		{ "add(a * b[2], b[1], 2 * [1, 2][1])", "add((a * (b[2])), (b[1]), (2 * ([1, 2][1])))" },
	}
	for _, tt in ipairs(tests) do
		local input = tt[1]
		local expected = tt[2]

		local l = lexer.new(input)
		local p = parser.new(l)
		local program = p:parse_program()
		check_parser_errors(t, p)
		local actual = program:string()
		if actual ~= expected then
			t:error("expected='%s', got='%s'", expected, actual)
		end
	end
end

local function test_parsing_boolean_literal (t: testing.T)
	local input = [[
    true;
    false;
  ]]
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	program_checker({ (expression_statement_checker(boolean_literal_checker(true))), (expression_statement_checker(boolean_literal_checker(false))) })(t, program)
end

local function test_if_expression (t: testing.T)
	local input = "if (x < y) { x }"
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	local ck = program_checker {
		expression_statement_checker(
			if_expression_checker(
				infix_expression_checker(
					"<",
					identifier_checker("x"),
					identifier_checker("y")
				),
				block_statement_checker {
					expression_statement_checker(identifier_checker("x"))
				},
				nil
			)
		)
	}
	ck(t, program)
end

local function test_if_else_expression (t: testing.T)
	local input = "if (x < y) { x } else { y }"
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	local ck = program_checker {
		expression_statement_checker(
			if_expression_checker(
				infix_expression_checker(
					"<",
					identifier_checker("x"),
					identifier_checker("y")
				),
				block_statement_checker {
					expression_statement_checker(identifier_checker("x"))
				},
				block_statement_checker {
					expression_statement_checker(identifier_checker("y"))
				}
			)
		)
	}
	ck(t, program)
end

local function test_function_literal_parsing (t: testing.T)
	local tests: {{string, check_node_fn}} = {
		{
			"fn(x, y) { x + y; }",
			program_checker {
				expression_statement_checker(
					function_literal_checker({ "x", "y" },
						block_statement_checker {
							expression_statement_checker(
								infix_expression_checker(
									"+",
									identifier_checker("x"),
									identifier_checker("y")
								)
							)
						}
					)
				)
			}
		},
		{
			"fn() {}",
			program_checker {
				expression_statement_checker(
					function_literal_checker({},
						block_statement_checker {}
					)
				)
			}
		},
		{
			"fn() { return 3; }",
			program_checker {
				expression_statement_checker(
					function_literal_checker({},
						block_statement_checker {
							return_statement_checker(integer_literal_checker(3))
						}
					)
				)
			}
		},
		{
			"fn(x) { return x + 3; }",
			program_checker {
				expression_statement_checker(
					function_literal_checker({ "x" },
						block_statement_checker {
							return_statement_checker(
								infix_expression_checker(
									"+",
									identifier_checker("x"),
									integer_literal_checker(3)
								)
							)
						}
					)
				)
			}
		},
		{
			"fn(x) { return x + 3; }",
			program_checker {
				expression_statement_checker(
					function_literal_checker({ "x" },
						block_statement_checker {
							return_statement_checker(
								infix_expression_checker(
									"+",
									identifier_checker("x"),
									integer_literal_checker(3)
								)
							)
						}
					)
				)
			}
		},
		{
			"fn() { return 5 + 10; }",
			program_checker {
				expression_statement_checker(
					function_literal_checker({},
						block_statement_checker {
							return_statement_checker(
								infix_expression_checker(
									"+",
									integer_literal_checker(5),
									integer_literal_checker(10)
								)
							)
						}
					)
				)
			}
		},
	}
	for _, tt in ipairs(tests) do
		local input = tt[1]
		local ck = tt[2]
		local l = lexer.new(input)
		local p = parser.new(l)
		local program = p:parse_program()
		check_parser_errors(t, p)
		ck(t, program)
	end
end

local function test_function_parameter_parsing (t: testing.T)
	local tests: {{string,{string}}} = {
		{"fn() {};", {}},
		{"fn(x) {};", {"x"}},
		{"fn(x, y, z) {};", {"x", "y", "z"}},
	}
	for _, tt in ipairs(tests) do
		local l = lexer.new(tt[1])
		local p = parser.new(l)
		local program = p:parse_program()
		check_parser_errors(t, p)
		local ck = program_checker {
			expression_statement_checker(
				function_literal_checker(tt[2], anything_checker())
			)
		}
		ck(t, program)
	end
end

local function test_call_expression_parsing (t: testing.T)
	local input = "add(1, 2 * 3, 4 + 5);"
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	local ck = program_checker {
		expression_statement_checker(
			call_expression_checker(
				identifier_checker("add"),
				{
					integer_literal_checker(1),
					infix_expression_checker(
						"*",
						integer_literal_checker(2),
						integer_literal_checker(3)
					),
					infix_expression_checker(
						"+",
						integer_literal_checker(4),
						integer_literal_checker(5)
					),
				}
			)
		)
	}
	ck(t, program)
end

local function test_let_statement (t: testing.T)
	local tests: {{string, check_node_fn}} = {
		{"let x = 5;", program_checker { let_statement_checker("x", integer_literal_checker(5)) } },
		{"let y = true;", program_checker { let_statement_checker("y", boolean_literal_checker(true)) } },
		{"let foobar = y;", program_checker { let_statement_checker("foobar", identifier_checker("y")) } },
	}
	for _, tt in ipairs(tests) do
		local input = tt[1]
		local ck = tt[2]
		local l = lexer.new(input)
		local p = parser.new(l)
		local program = p:parse_program()
		check_parser_errors(t, p)
		ck(t, program)
	end
end

local function test_string_literal_expression (t: testing.T)
	local input = '"hello world";'
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	local ck = program_checker {
		expression_statement_checker(
			string_literal_checker("hello world")
		)
	}
	ck(t, program)
end

local function test_parsing_array_literals (t: testing.T)
	local input = '[1, 2 * 2, 3 + 3];'
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	local ck = program_checker {
		expression_statement_checker(
			array_literal_checker {
				integer_literal_checker(1),
				infix_expression_checker(
					"*",
					integer_literal_checker(2),
					integer_literal_checker(2)
				),
				infix_expression_checker(
					"+",
					integer_literal_checker(3),
					integer_literal_checker(3)
				)
			}
		)
	}
	ck(t, program)
end

local function test_parsing_index_expressions (t: testing.T)
	local input = 'myArray[1 + 1]'
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	local ck = program_checker {
		expression_statement_checker(
			index_expression_checker(
				identifier_checker("myArray"),
				infix_expression_checker(
					"+",
					integer_literal_checker(1),
					integer_literal_checker(1)
				)
			)
		)
	}
	ck(t, program)
end

local function test_parsing_hash_literals_string_keys (t: testing.T)
	local input = '{"one": 1, "two": 2, "three": 3}'
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	local ck = program_checker {
		expression_statement_checker(
			hash_literal_checker {
				['one'] = integer_literal_checker(1),
				['two'] = integer_literal_checker(2),
				['three'] = integer_literal_checker(3),
			}
		)
	}
	ck(t, program)
end

local function test_parsing_empty_hash_literal (t: testing.T)
	local input = '{}'
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	local ck = program_checker {
		expression_statement_checker(
			hash_literal_checker {}
		)
	}
	ck(t, program)
end

local function test_parsing_hash_literals_with_expressions (t: testing.T)
	local input = '{"one": 0 + 1, "two": 10 - 8, "three": 15 / 5}'
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	local ck = program_checker {
		expression_statement_checker(
			hash_literal_checker {
				['one'] = infix_expression_checker("+", integer_literal_checker(0), integer_literal_checker(1)),
				['two'] = infix_expression_checker("-", integer_literal_checker(10), integer_literal_checker(8)),
				['three'] = infix_expression_checker("/", integer_literal_checker(15), integer_literal_checker(5)),
			}
		)
	}
	ck(t, program)
end

local function test_function_literal_with_name (t: testing.T)
	local input = 'let myFunction = fn() { };'
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	local ck = program_checker {
		let_statement_checker("myFunction", function_literal_checker({}, anything_checker(), "myFunction"))
	}
	ck(t, program)
end

return {
	domain = "parser",
	test_cases = {
		{ name = "parsing_let_statement", func = test_parsing_let_statement },
		{ name = "return_statements", func = test_return_statements },
		{ name = "identifier_expression", func = test_identifier_expression },
		{ name = "parsing_integer_literal", func = test_parsing_integer_literal },
		{ name = "parsing_prefix_expressions", func = test_parsing_prefix_expressions },
		{ name = "parsing_infix_expression", func = test_parsing_infix_expression },
		{ name = "operator_precedence_parsing", func = test_operator_precedence_parsing },
		{ name = "parsing_boolean_literal", func = test_parsing_boolean_literal },
		{ name = "if_expression", func = test_if_expression },
		{ name = "if_else_expression", func = test_if_else_expression },
		{ name = "function_literal_parsing", func = test_function_literal_parsing },
		{ name = "function_parameter_parsing", func = test_function_parameter_parsing },
		{ name = "call_expression_parsing", func = test_call_expression_parsing },
		{ name = "let_statement", func = test_let_statement },
		{ name = "string_literal_expression", func = test_string_literal_expression },
		{ name = "parsing_array_literals", func = test_parsing_array_literals },
		{ name = "parsing_index_expressions", func = test_parsing_index_expressions },
		{ name = "parsing_hash_literals_string_keys", func = test_parsing_hash_literals_string_keys },
		{ name = "parsing_empty_hash_literal", func = test_parsing_empty_hash_literal },
		{ name = "parsing_hash_literals_with_expressions", func = test_parsing_hash_literals_with_expressions },
		{ name = "function_literal_with_name", func = test_function_literal_with_name },
	}
}
