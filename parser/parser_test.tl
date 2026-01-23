
local testing = require("testing")
local ast = require("ast.ast")
local lexer = require("lexer.lexer")
local parser = require("parser.parser")

local function test_let_statement2 (t: testing.T, s: ast.Statement, name: string): boolean
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

local function test_let_statement (t: testing.T)
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
		if not test_let_statement2(t, stmt, expected_identifier) then
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

local function test_integer_literal (t: testing.T)
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

local function test_integer_literal2 (t: testing.T, il: ast.Expression, value: integer): boolean
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

local function test_parsing_prefix_expressions (t: testing.T)
	local prefix_tests = {
		{"!5;", "!", 5},
		{"-15;", "-", 15},
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
		local b = stmt.expression
		if not (b is ast.PrefixExpression) then
			t.fatal_fail("stmt not ast.PrefixExpression. got=%s", type(b))
		end
		local exp = stmt.expression as ast.PrefixExpression
		if exp.operator ~= operator then
			t.fatal_fail("exp.operator is not '%s'. got=%s", operator, exp.operator)
		end
		if not test_integer_literal2(t, exp.right, integer_value) then
			return
		end
	end
end

local function test_parsing_infix_expression (t: testing.T)
	local infix_tests = {
		{"5 + 5;", 5, "+", 5},
		{"5 - 5;", 5, "-", 5},
		{"5 * 5;", 5, "*", 5},
		{"5 / 5;", 5, "/", 5},
		{"5 > 5;", 5, ">", 5},
		{"5 < 5;", 5, "<", 5},
		{"5 == 5;", 5, "==", 5},
		{"5 != 5;", 5, "!=", 5},
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
		local b = stmt.expression
		if not (b is ast.InfixExpression) then
			t.fatal_fail("stmt not ast.InfixExpression. got=%s", type(b))
		end
		local exp = stmt.expression as ast.InfixExpression
		if not test_integer_literal2(t, exp.left, left_value) then
			return
		end
		if exp.operator ~= operator then
			t.fatal_fail("exp.operator is not '%s'. got=%s", operator, exp.operator)
		end
		if not test_integer_literal2(t, exp.right, right_value) then
			return
		end
	end
end

test_let_statement(testing.new())
test_return_statements(testing.new())
test_identifier_expression(testing.new())
test_integer_literal(testing.new())
test_parsing_prefix_expressions(testing.new())
test_parsing_infix_expression(testing.new())
