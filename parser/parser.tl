
local ast = require("ast.ast")
local lexer = require("lexer.lexer")
local token = require("token")

local record Parser
	l: lexer.Lexer
	cur_token: token.Token
	peek_token: token.Token
	errors: {string}

	get_errors: function(self): {string}

	cur_token_is: function(self, token.TokenType): boolean
	peek_token_is: function(self, token.TokenType): boolean
	expect_peek: function(self, token.TokenType): boolean
	next_token: function(self)
	peek_error: function(self, token.TokenType)

	parse_program: function(self): ast.Program
	parse_statement: function(self): ast.Statement
	parse_let_statement: function(self): ast.LetStatement
	parse_return_statement: function(self): ast.ReturnStatement
end

function Parser:cur_token_is(t: token.TokenType): boolean
	return self.cur_token.type == t
end

function Parser:peek_token_is(t: token.TokenType): boolean
	return self.peek_token.type == t
end

function Parser:expect_peek(t: token.TokenType): boolean
	if self:peek_token_is(t) then
		self:next_token()
		return true
	else
		self:peek_error(t)
		return false
	end
end

function Parser:next_token()
	self.cur_token = self.peek_token
	self.peek_token = self.l:next_token()
end

function Parser:parse_return_statement(): ast.ReturnStatement
	local stmt = ast.ReturnStatement.new(self.cur_token, nil)
	self:next_token()
	while not self:cur_token_is(token.SEMICOLON) do
		self:next_token()
	end
	return stmt
end

function Parser:parse_statement(): ast.Statement
	if self.cur_token.type == token.LET then
		return self:parse_let_statement()
	elseif self.cur_token.type == token.RETURN then
		return self:parse_return_statement()
	else
		return nil
	end
end

function Parser:parse_program(): ast.Program
	local program = ast.Program.new({})
	while not self:cur_token_is(token.EOF) do
		local stmt = self:parse_statement()
		if stmt ~= nil then
			table.insert(program.statements, stmt)
		end
		self:next_token()
	end
	return program
end

function Parser:parse_let_statement(): ast.LetStatement
	local stmt = ast.LetStatement.new(self.cur_token, nil, nil)
	if not self:expect_peek(token.IDENT) then
		return nil
	end
	stmt.name = ast.Identifier.new(self.cur_token, self.cur_token.literal)
	if not self:expect_peek(token.ASSIGN) then
		return nil
	end
	while not self:cur_token_is(token.SEMICOLON) do
		self:next_token()
	end
	return stmt
end

local function new (l: lexer.Lexer): Parser
	local p: Parser = setmetatable({
		l = l,
		cur_token = nil,
		peek_token = nil,
		errors = {},
	}, { __index = Parser })
	p:next_token()
	p:next_token()
	return p
end

function Parser:get_errors(): {string}
	return self.errors
end

function Parser:peek_error(t: token.TokenType)
	local msg = string.format("expected next token to be %s, got=%s", t, self.peek_token.type)
	table.insert(self.errors, msg)
end

local parser <const> = {
	Parser = Parser,
	new = new,
}

return parser
