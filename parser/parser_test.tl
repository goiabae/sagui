
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
			t.error("il not ast.IntegerLiteral. got=%s", type(il))
			return false
		end
		local integ = il as ast.IntegerLiteral
		if integ.value ~= value then
			t.error("integ.value not %d. got=%d", value, integ.value)
			return false
		end
		if integ:token_literal() ~= tostring(value) then
			t.error("integ:token_literal() not %d. got=%d", tostring(value), integ:token_literal())
			return false
		end
		return true
	end
end

local function identifier_checker (value: string): check_node_fn
	return function (t: testing.T, exp: ast.Expression): boolean
		if not (exp is ast.Identifier) then
			t.error("exp not ast.Identifier. got=%s", type(exp))
			return false
		end
		local ident = exp as ast.Identifier
		if ident.value ~= value then
			t.error("ident.value not %s. got=%s", value, ident.value)
			return false
		end
		if ident:token_literal() ~= value then
			t.error("ident:token_literal() not %s. got=%s", value, ident:token_literal())
			return false
		end
		return true
	end
end

local function literal_checker (value: string | integer): check_node_fn
	if type(value) == "string" then
		return integer_literal_checker(value as integer)
	elseif type(value) == "number" then
		return identifier_checker(value as string)
	end
end

local function infix_expression_checker (operator: string, left_ck: check_node_fn, right_ck: check_node_fn): check_node_fn
	return function (t: testing.T, exp: ast.Expression): boolean
		if not (exp is ast.InfixExpression) then
			t.error("exp is not ast.InfixExpression. got=%s", type(exp))
			return false
		end
		local op_exp = exp as ast.InfixExpression
		if not left_ck(t, op_exp.left) then
			return false
		end
		if op_exp.operator ~= operator then
			t.error("exp.operator is not '%s'. got='%s'", operator, op_exp.operator)
			return false
		end
		if not right_ck(t, op_exp.right) then
			return false
		end
		return true
	end
end

local function expression_statement_checker (exp_ck: check_node_fn): check_node_fn
	return function (t: testing.T, stmt: ast.Statement): boolean
		local a = stmt
		if not (a is ast.ExpressionStatement) then
			t.fatal_fail("stmt is not ast.ExpressionStatement")
		end
		return exp_ck(t, (stmt as ast.ExpressionStatement).expression)
	end
end

local function if_expression_checker (cond_ck: check_node_fn, cons_ck: check_node_fn, alt_ck: check_node_fn): check_node_fn
	return function (t: testing.T, node: ast.Node): boolean
		if not (node is ast.IfExpression) then
			t.fatal_fail("node not a ast.Ifexpression")
		end
		local if_exp = node as ast.IfExpression
		if if_exp.condition == nil then
			t.fatal_fail("if expression condition was nil")
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
			t.fatal_fail("block has not enough statements. got=%d", #blk.statements)
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
			t.error("il not ast.Boolean. got=%s", type(il))
			return false
		end
		local integ = il as ast.Boolean
		if integ.value ~= value then
			t.error("integ.value not %d. got=%d", value, integ.value)
			return false
		end
		if integ:token_literal() ~= tostring(value) then
			t.error("integ:token_literal() not %d. got=%d", tostring(value), integ:token_literal())
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
			t.fatal_fail("program has not enough statements. got=%d", #prog.statements)
		end
		for i, ck in ipairs(cks) do
			if not ck(t, prog.statements[i]) then
				return false
			end
		end
		return true
	end
end

local function function_literal_checker (params: {string}, body_ck: check_node_fn): check_node_fn
	return function (t: testing.T, node: ast.Node): boolean
		if not node then
			t.fatal_fail("node was nil")
		end
		if not (node is ast.FunctionLiteral) then
			t.error("node not ast.Functionliteral. got=%s", type(node))
			return false
		end
		local func = node as ast.FunctionLiteral
		if #func.parameters ~= #params then
			t.error("function literal has not %d parameters. got=%d", #params, #func.parameters)
		end
		for i, p in ipairs(params) do
			if not identifier_checker(p)(t, func.parameters[i]) then
				return false
			end
		end
		return body_ck(t, func.body)
	end
end

do
	local token = require("token")
	local t = testing.new()

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
		t.error("il not ast.IntegerLiteral. got=%s", type(il))
		return false
	end
	local integ = il as ast.IntegerLiteral
	if integ.value ~= value then
		t.error("integ.value not %d. got=%d", value, integ.value)
		return false
	end
	if integ:token_literal() ~= tostring(value) then
		t.error("integ:token_literal() not %d. got=%d", tostring(value), integ:token_literal())
		return false
	end
	return true
end

local function test_identifier (t: testing.T, exp: ast.Expression, value: string): boolean
	if not (exp is ast.Identifier) then
		t.error("exp not ast.Identifier. got=%s", type(exp))
		return false
	end
	local ident = exp as ast.Identifier
	if ident.value ~= value then
		t.error("ident.value not %s. got=%s", value, ident.value)
		return false
	end
	if ident:token_literal() ~= value then
		t.error("ident:token_literal() not %s. got=%s", value, ident:token_literal())
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
	t.error("type of exp not handled. got=%s", type(exp))
	return false
end

local function check_infix_expression (t: testing.T, exp: ast.Expression, left: any, operator: string, right: any): boolean
	if not (exp is ast.InfixExpression) then
		t.error("exp is not ast.InfixExpression. got=%s", type(exp))
		return false
	end
	local op_exp = exp as ast.InfixExpression
	if not test_literal_expression(t, op_exp.left, left) then
		return false
	end
	if op_exp.operator ~= operator then
		t.error("exp.operator is not '%s'. got='%s'", operator, op_exp.operator)
		return false
	end
	if not test_literal_expression(t, op_exp.right, right) then
		return false
	end
	return true
end

local function check_prefix_expression (t: testing.T, exp: ast.Expression, operator: string, right: any): boolean
	if not (exp is ast.PrefixExpression) then
		t.error("exp is not ast.PrefixExpression. got=%s", type(exp))
		return false
	end
	local op_exp = exp as ast.PrefixExpression
	if op_exp.operator ~= operator then
		t.error("exp.operator is not '%s'. got='%s'", operator, op_exp.operator)
		return false
	end
	if not test_literal_expression(t, op_exp.right, right) then
		return false
	end
	return true
end

do
	local token = require("token")
	local t = testing.new()
	local a = ast.IntegerLiteral.new({ type = token.INT, literal = "5" }, 5)
	local b = ast.PrefixExpression.new({ type = token.BANG, literal = "!" }, "!", a)
	assert(check_prefix_expression(t, b, "!", 5))
end

local function check_let_statement (t: testing.T, s: ast.Statement, name: string): boolean
	if s:token_literal() ~= "let" then
		t.error("s:token_literal() not 'let'. got='%s'", s:token_literal())
		return false
	end
	if not (s is ast.LetStatement) then
		t.error("s not ast.LetStatement")
		return false
	end
	local let_stmt = s as ast.LetStatement
	if let_stmt.name.value ~= name then
		t.error("let_stmt.name.value not '%s'. got='%s'", name, let_stmt.name.value)
		return false
	end
	if let_stmt.name:token_literal() ~= name then
		t.error("let_stmt.name:token_literal() not '%s'. got='%s'", name, let_stmt.name:token_literal())
		return false
	end
	return true
end

local function check_parser_errors(t: testing.T, p: parser.Parser)
	local errors = p:get_errors()
	if #errors == 0 then
		return
	end
	t.error("parser has %d errors", #errors)
	for _, msg in ipairs(errors) do
		t.error("parser error: '%s'", msg)
	end
	t.fail_now()
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
		t.fatal_fail("parse_program() returned nil")
	end
	if #program.statements ~= 3 then
		t.fatal_fail("program.statements does not contain 3 statements: %d", #program.statements)
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
	if #program.statements ~= 3 then
		t.fatal_fail("program.statements does not contain 3 statements: %d", #program.statements)
	end
	for _, stmt in ipairs(program.statements) do
		if not (stmt is ast.ReturnStatement) then
			t.error("stmt not ast.Returnstatement")
		else
			local return_stmt = stmt as ast.ReturnStatement
			if return_stmt:token_literal() ~= "return" then
				t.error("return_stmt:token_literal() not 'return'. got='%s'", return_stmt:token_literal())
			end
		end
	end
end

local function test_identifier_expression (t: testing.T)
	local input = "foobar;"
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	if #program.statements ~= 1 then
		t.fatal_fail("program has not enough statements. got=%d", #program.statements)
	end
	local a = program.statements[1]
	if not (a is ast.ExpressionStatement) then
		t.fatal_fail("program.statements[1] is not ast.ExpressionStatement")
	end
	local stmt = program.statements[1] as ast.ExpressionStatement
	local b = stmt.expression
	if not (b is ast.Identifier) then
		t.fatal_fail("exp not ast.Identifier.")
	end
	local ident = stmt.expression as ast.Identifier
	if ident.value ~= "foobar" then
		t.error("ident.value not %s. got=%s", "foobar", ident.value)
	end
	if ident:token_literal() ~= "foobar" then
		t.error("ident:token_literal() not %s. got=%s", "foobar", ident:token_literal())
	end
	t.ok()
end

local function test_parsing_integer_literal (t: testing.T)
	local input = "5;"
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	if #program.statements ~= 1 then
		t.fatal_fail("program has not enough statements. got=%d", #program.statements)
	end
	local a = program.statements[1]
	if not (a is ast.ExpressionStatement) then
		t.fatal_fail("program.statements[1] is not ast.ExpressionStatement")
	end
	local stmt = program.statements[1] as ast.ExpressionStatement
	local b = stmt.expression
	if not (b is ast.IntegerLiteral) then
		t.fatal_fail("exp not ast.IntegerLiteral. got=%s", type(b))
	end
	local literal = stmt.expression as ast.IntegerLiteral
	if literal.value ~= 5 then
		t.error("literal.value not %d. got=%d", 5, literal.value)
	end
	if literal:token_literal() ~= "5" then
		t.error("literal:token_literal() not %s. got=%s", "5", literal:token_literal())
	end
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
			t.fatal_fail("program does not contain %d statements. got=%d", 1, #program.statements)
		end
		local a = program.statements[1]
		if not (a is ast.ExpressionStatement) then
			t.fatal_fail("program.statements[1] is not ast.ExpressionStatement")
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
			t.fatal_fail("program does not contain %d statements. got=%d", 1, #program.statements)
		end
		local a = program.statements[1]
		if not (a is ast.ExpressionStatement) then
			t.fatal_fail("program.statements[1] is not ast.ExpressionStatement")
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
			t.error("expected='%s', got='%s'", expected, actual)
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
	local input = "fn(x, y) { x + y; }"
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()
	check_parser_errors(t, p)
	local ck = program_checker {
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
	ck(t, program)
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

local t = testing.new()
test_parsing_let_statement(t)
test_return_statements(t)
test_identifier_expression(t)
test_parsing_integer_literal(t)
test_parsing_prefix_expressions(t)
test_parsing_infix_expression(t)
test_operator_precedence_parsing(t)
test_parsing_boolean_literal(t)
test_if_expression(t)
test_if_else_expression(t)
test_function_literal_parsing(t)
test_function_parameter_parsing(t)
