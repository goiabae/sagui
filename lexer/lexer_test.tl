
local lexer = require("lexer.lexer")
local testing = require("testing")
local token = require("token")

local function test_next_token (t: testing.T)
	local input = "=+(){},;"
	local tests: {token.Token} = {
		{ type = token.ASSIGN, literal = "=" },
		{ type = token.PLUS, literal = "+" },
		{ type = token.LPAREN, literal = "(" },
		{ type = token.RPAREN, literal = ")" },
		{ type = token.LBRACE, literal = "{" },
		{ type = token.RBRACE, literal = "}" },
		{ type = token.COMMA, literal = "," },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.EOF, literal = "" },
	}
	local l = lexer.new(input)
	for i, expected in ipairs(tests) do
		local tok = l:next_token()
		if not tok then
			t.fatal_fail("tests[%d] - token was nil", i)
			return
		end
		if tok.type ~= expected.type then
			t.fatal_fail("tests[%d] - tokentype wrong. expected=%q, got=%q",
                i, expected.type, tok.type)
		end
		if tok.literal ~= expected.literal then
			t.fatal_fail("tests[%d] - literal wrong. expected=%q, got=%q",
                i, expected.literal, tok.literal)
		end
	end
end

local function test_next_token2 (t: testing.T)
	local input = [[
    let five = 5;
    let ten = 10;
    let add = fn(x, y) {
      x + y;
    };
    let result = add(five, ten);
  ]]
	local tests: {token.Token} = {
		{ type = token.LET, literal = "let" },
		{ type = token.IDENT, literal = "five" },
		{ type = token.ASSIGN, literal = "=" },
		{ type = token.INT, literal = "5" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.LET, literal = "let" },
		{ type = token.IDENT, literal = "ten" },
		{ type = token.ASSIGN, literal = "=" },
		{ type = token.INT, literal = "10" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.LET, literal = "let" },
		{ type = token.IDENT, literal = "add" },
		{ type = token.ASSIGN, literal = "=" },
		{ type = token.FUNCTION, literal = "fn" },
		{ type = token.LPAREN, literal = "(" },
		{ type = token.IDENT, literal = "x" },
		{ type = token.COMMA, literal = "," },
		{ type = token.IDENT, literal = "y" },
		{ type = token.RPAREN, literal = ")" },
		{ type = token.LBRACE, literal = "{" },
		{ type = token.IDENT, literal = "x" },
		{ type = token.PLUS, literal = "+" },
		{ type = token.IDENT, literal = "y" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.RBRACE, literal = "}" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.LET, literal = "let" },
		{ type = token.IDENT, literal = "result" },
		{ type = token.ASSIGN, literal = "=" },
		{ type = token.IDENT, literal = "add" },
		{ type = token.LPAREN, literal = "(" },
		{ type = token.IDENT, literal = "five" },
		{ type = token.COMMA, literal = "," },
		{ type = token.IDENT, literal = "ten" },
		{ type = token.RPAREN, literal = ")" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.EOF, literal = "" },
	}
	local l = lexer.new(input)
	for i, expected in ipairs(tests) do
		local tok = l:next_token()
		if not tok then
			t.fatal_fail("tests[%d] - token was nil", i)
			return
		end
		if tok.type ~= expected.type then
			t.fatal_fail("tests[%d] - tokentype wrong. expected=%q, got=%q",
                i, expected.type, tok.type)
		end
		if tok.literal ~= expected.literal then
			t.fatal_fail("tests[%d] - literal wrong. expected=%q, got=%q",
                i, expected.literal, tok.literal)
		end
	end
end

local function test_next_token3 (t: testing.T)
	local input = [[
    let five = 5;
    let ten = 10;
    let add = fn(x, y) {
      x + y;
    };
    let result = add(five, ten);
    !-/*5;
    5 < 10 > 5;
  ]]
	local tests: {token.Token} = {
		{ type = token.LET, literal = "let" },
		{ type = token.IDENT, literal = "five" },
		{ type = token.ASSIGN, literal = "=" },
		{ type = token.INT, literal = "5" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.LET, literal = "let" },
		{ type = token.IDENT, literal = "ten" },
		{ type = token.ASSIGN, literal = "=" },
		{ type = token.INT, literal = "10" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.LET, literal = "let" },
		{ type = token.IDENT, literal = "add" },
		{ type = token.ASSIGN, literal = "=" },
		{ type = token.FUNCTION, literal = "fn" },
		{ type = token.LPAREN, literal = "(" },
		{ type = token.IDENT, literal = "x" },
		{ type = token.COMMA, literal = "," },
		{ type = token.IDENT, literal = "y" },
		{ type = token.RPAREN, literal = ")" },
		{ type = token.LBRACE, literal = "{" },
		{ type = token.IDENT, literal = "x" },
		{ type = token.PLUS, literal = "+" },
		{ type = token.IDENT, literal = "y" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.RBRACE, literal = "}" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.LET, literal = "let" },
		{ type = token.IDENT, literal = "result" },
		{ type = token.ASSIGN, literal = "=" },
		{ type = token.IDENT, literal = "add" },
		{ type = token.LPAREN, literal = "(" },
		{ type = token.IDENT, literal = "five" },
		{ type = token.COMMA, literal = "," },
		{ type = token.IDENT, literal = "ten" },
		{ type = token.RPAREN, literal = ")" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.BANG, literal = "!" },
		{ type = token.MINUS, literal = "-" },
		{ type = token.SLASH, literal = "/" },
		{ type = token.ASTERISK, literal = "*" },
		{ type = token.INT, literal = "5" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.INT, literal = "5" },
		{ type = token.LT, literal = "<" },
		{ type = token.INT, literal = "10" },
		{ type = token.GT, literal = ">" },
		{ type = token.INT, literal = "5" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.EOF, literal = "" },
	}
	local l = lexer.new(input)
	for i, expected in ipairs(tests) do
		local tok = l:next_token()
		if not tok then
			t.fatal_fail("tests[%d] - token was nil", i)
			return
		end
		if tok.type ~= expected.type then
			t.fatal_fail("tests[%d] - tokentype wrong. expected=%q, got=%q",
                i, expected.type, tok.type)
		end
		if tok.literal ~= expected.literal then
			t.fatal_fail("tests[%d] - literal wrong. expected=%q, got=%q",
                i, expected.literal, tok.literal)
		end
	end
end

local function test_next_token4 (t: testing.T)
	local input = [[
    let five = 5;
    let ten = 10;
    let add = fn(x, y) {
      x + y;
    };
    let result = add(five, ten);
    !-/*5;
    5 < 10 > 5;
    if (5 < 10) {
      return true;
    } else {
      return false;
    }
  ]]
	local tests: {token.Token} = {
		{ type = token.LET, literal = "let" },
		{ type = token.IDENT, literal = "five" },
		{ type = token.ASSIGN, literal = "=" },
		{ type = token.INT, literal = "5" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.LET, literal = "let" },
		{ type = token.IDENT, literal = "ten" },
		{ type = token.ASSIGN, literal = "=" },
		{ type = token.INT, literal = "10" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.LET, literal = "let" },
		{ type = token.IDENT, literal = "add" },
		{ type = token.ASSIGN, literal = "=" },
		{ type = token.FUNCTION, literal = "fn" },
		{ type = token.LPAREN, literal = "(" },
		{ type = token.IDENT, literal = "x" },
		{ type = token.COMMA, literal = "," },
		{ type = token.IDENT, literal = "y" },
		{ type = token.RPAREN, literal = ")" },
		{ type = token.LBRACE, literal = "{" },
		{ type = token.IDENT, literal = "x" },
		{ type = token.PLUS, literal = "+" },
		{ type = token.IDENT, literal = "y" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.RBRACE, literal = "}" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.LET, literal = "let" },
		{ type = token.IDENT, literal = "result" },
		{ type = token.ASSIGN, literal = "=" },
		{ type = token.IDENT, literal = "add" },
		{ type = token.LPAREN, literal = "(" },
		{ type = token.IDENT, literal = "five" },
		{ type = token.COMMA, literal = "," },
		{ type = token.IDENT, literal = "ten" },
		{ type = token.RPAREN, literal = ")" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.BANG, literal = "!" },
		{ type = token.MINUS, literal = "-" },
		{ type = token.SLASH, literal = "/" },
		{ type = token.ASTERISK, literal = "*" },
		{ type = token.INT, literal = "5" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.INT, literal = "5" },
		{ type = token.LT, literal = "<" },
		{ type = token.INT, literal = "10" },
		{ type = token.GT, literal = ">" },
		{ type = token.INT, literal = "5" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.IF, literal = "if" },
		{ type = token.LPAREN, literal = "(" },
		{ type = token.INT, literal = "5" },
		{ type = token.LT, literal = "<" },
		{ type = token.INT, literal = "10" },
		{ type = token.RPAREN, literal = ")" },
		{ type = token.LBRACE, literal = "{" },
		{ type = token.RETURN, literal = "return" },
		{ type = token.TRUE, literal = "true" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.RBRACE, literal = "}" },
		{ type = token.ELSE, literal = "else" },
		{ type = token.LBRACE, literal = "{" },
		{ type = token.RETURN, literal = "return" },
		{ type = token.FALSE, literal = "false" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.RBRACE, literal = "}" },
		{ type = token.EOF, literal = "" },
	}
	local l = lexer.new(input)
	for i, expected in ipairs(tests) do
		local tok = l:next_token()
		if not tok then
			t.fatal_fail("tests[%d] - token was nil", i)
			return
		end
		if tok.type ~= expected.type then
			t.fatal_fail("tests[%d] - tokentype wrong. expected=%q, got=%q",
                i, expected.type, tok.type)
		end
		if tok.literal ~= expected.literal then
			t.fatal_fail("tests[%d] - literal wrong. expected=%q, got=%q",
                i, expected.literal, tok.literal)
		end
	end
end

local function test_next_token5 (t: testing.T)
	local input = [[
    let five = 5;
    let ten = 10;
    let add = fn(x, y) {
      x + y;
    };
    let result = add(five, ten);
    !-/*5;
    5 < 10 > 5;
    if (5 < 10) {
      return true;
    } else {
      return false;
    }
    10 == 10;
    10 != 9;
    "foobar"
    "foo bar"
    [1, 2];
    {"foo": "bar"}
  ]]
	local tests: {token.Token} = {
		{ type = token.LET, literal = "let" },
		{ type = token.IDENT, literal = "five" },
		{ type = token.ASSIGN, literal = "=" },
		{ type = token.INT, literal = "5" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.LET, literal = "let" },
		{ type = token.IDENT, literal = "ten" },
		{ type = token.ASSIGN, literal = "=" },
		{ type = token.INT, literal = "10" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.LET, literal = "let" },
		{ type = token.IDENT, literal = "add" },
		{ type = token.ASSIGN, literal = "=" },
		{ type = token.FUNCTION, literal = "fn" },
		{ type = token.LPAREN, literal = "(" },
		{ type = token.IDENT, literal = "x" },
		{ type = token.COMMA, literal = "," },
		{ type = token.IDENT, literal = "y" },
		{ type = token.RPAREN, literal = ")" },
		{ type = token.LBRACE, literal = "{" },
		{ type = token.IDENT, literal = "x" },
		{ type = token.PLUS, literal = "+" },
		{ type = token.IDENT, literal = "y" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.RBRACE, literal = "}" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.LET, literal = "let" },
		{ type = token.IDENT, literal = "result" },
		{ type = token.ASSIGN, literal = "=" },
		{ type = token.IDENT, literal = "add" },
		{ type = token.LPAREN, literal = "(" },
		{ type = token.IDENT, literal = "five" },
		{ type = token.COMMA, literal = "," },
		{ type = token.IDENT, literal = "ten" },
		{ type = token.RPAREN, literal = ")" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.BANG, literal = "!" },
		{ type = token.MINUS, literal = "-" },
		{ type = token.SLASH, literal = "/" },
		{ type = token.ASTERISK, literal = "*" },
		{ type = token.INT, literal = "5" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.INT, literal = "5" },
		{ type = token.LT, literal = "<" },
		{ type = token.INT, literal = "10" },
		{ type = token.GT, literal = ">" },
		{ type = token.INT, literal = "5" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.IF, literal = "if" },
		{ type = token.LPAREN, literal = "(" },
		{ type = token.INT, literal = "5" },
		{ type = token.LT, literal = "<" },
		{ type = token.INT, literal = "10" },
		{ type = token.RPAREN, literal = ")" },
		{ type = token.LBRACE, literal = "{" },
		{ type = token.RETURN, literal = "return" },
		{ type = token.TRUE, literal = "true" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.RBRACE, literal = "}" },
		{ type = token.ELSE, literal = "else" },
		{ type = token.LBRACE, literal = "{" },
		{ type = token.RETURN, literal = "return" },
		{ type = token.FALSE, literal = "false" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.RBRACE, literal = "}" },
		{ type = token.INT, literal = "10" },
		{ type = token.EQ, literal = "==" },
		{ type = token.INT, literal = "10" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.INT, literal = "10" },
		{ type = token.NOT_EQ, literal = "!=" },
		{ type = token.INT, literal = "9" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.STRING, literal = "foobar" },
		{ type = token.STRING, literal = "foo bar" },
		{ type = token.LBRACKET, literal = "[" },
		{ type = token.INT, literal = "1" },
		{ type = token.COMMA, literal = "," },
		{ type = token.INT, literal = "2" },
		{ type = token.RBRACKET, literal = "]" },
		{ type = token.SEMICOLON, literal = ";" },
		{ type = token.LBRACE, literal = "{" },
		{ type = token.STRING, literal = "foo" },
		{ type = token.COLON, literal = ":" },
		{ type = token.STRING, literal = "bar" },
		{ type = token.RBRACE, literal = "}" },
		{ type = token.EOF, literal = "" },
	}
	local l = lexer.new(input)
	for i, expected in ipairs(tests) do
		local tok = l:next_token()
		if not tok then
			t.fatal_fail("tests[%d] - token was nil", i)
			return
		end
		if tok.type ~= expected.type then
			t.fatal_fail("tests[%d] - tokentype wrong. expected=%q, got=%q",
                i, expected.type, tok.type)
		end
		if tok.literal ~= expected.literal then
			t.fatal_fail("tests[%d] - literal wrong. expected=%q, got=%q",
                i, expected.literal, tok.literal)
		end
	end
end

test_next_token(testing.new())
test_next_token2(testing.new())
test_next_token3(testing.new())
test_next_token4(testing.new())
test_next_token5(testing.new())
