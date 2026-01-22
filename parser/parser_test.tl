
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

test_let_statement(testing.new())
test_return_statements(testing.new())
