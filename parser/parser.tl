
local ast = require("ast.ast")
local lexer = require("lexer.lexer")
local token = require("token")

-- `any' means Parser
local type prefix_parse_fn = function (any): ast.Expression
local type infix_parse_fn = function (any, ast.Expression): ast.Expression

local record Parser
	l: lexer.Lexer
	cur_token: token.Token
	peek_token: token.Token
	errors: {string}
	prefix_parse_fns: { token.TokenType:prefix_parse_fn }
	infix_parse_fns: { token.TokenType:infix_parse_fn }

	get_errors: function(self): {string}
	no_prefix_parse_fn_error: function (self, token.TokenType)

	cur_token_is: function(self, token.TokenType): boolean
	peek_token_is: function(self, token.TokenType): boolean
	expect_peek: function(self, token.TokenType): boolean
	next_token: function(self)
	peek_error: function(self, token.TokenType)

	parse_program: function(self): ast.Program
	parse_statement: function(self): ast.Statement
	parse_let_statement: function(self): ast.LetStatement
	parse_return_statement: function(self): ast.ReturnStatement
	parse_expression_statement: function(self): ast.ExpressionStatement
	parse_expression: function (self, integer): ast.Expression
	parse_identifier: function (self): ast.Expression
	parse_integer_literal: function (self): ast.Expression
	parse_prefix_expression: function (self): ast.Expression

	register_prefix: function (self, token.TokenType, prefix_parse_fn)
	register_infix: function (self, token.TokenType, infix_parse_fn)
end

local LOWEST <const> = 1
local EQUALS <const> = 2
local LESSGREATER <const> = 3
local SUM <const> = 4
local PRODUCT <const> = 5
local PREFIX <const> = 6
local CALL <const> = 7

function Parser:register_prefix (token_type: token.TokenType, fn: prefix_parse_fn)
	self.prefix_parse_fns[token_type] = fn
end

function Parser:register_infix (token_type: token.TokenType, fn: infix_parse_fn)
	self.infix_parse_fns[token_type] = fn
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

function Parser:parse_expression_statement(): ast.ExpressionStatement
	local stmt = ast.ExpressionStatement.new(self.cur_token, self:parse_expression(LOWEST))
	if self:peek_token_is(token.SEMICOLON) then
		self:next_token()
	end
	return stmt
end

function Parser:no_prefix_parse_fn_error (t: token.TokenType)
	local msg = string.format("no prefix parse function for %s found", t)
	table.insert(self.errors, msg)
end

function Parser:parse_expression (precedence: integer): ast.Expression
	local prefix = self.prefix_parse_fns[self.cur_token.type]
	if prefix == nil then
		self:no_prefix_parse_fn_error(self.cur_token.type)
		return nil
	end
	local left_exp = prefix(self)
	return left_exp
end

function Parser:parse_identifier (): ast.Expression
	return ast.Identifier.new(self.cur_token, self.cur_token.literal)
end

function Parser:parse_integer_literal (): ast.Expression
	local lit = ast.IntegerLiteral.new(self.cur_token, nil)
	local value = tonumber(self.cur_token.literal)
	if value == nil then
		local msg = string.format("could not parse '%s' as integer", self.cur_token.literal)
		table.insert(self.errors, msg)
		return nil
	end
	lit.value = math.floor(value)
	return lit
end

function Parser:parse_prefix_expression (): ast.Expression
	local expression = ast.PrefixExpression.new(self.cur_token, self.cur_token.literal, nil)
	self:next_token()
	expression.right = self:parse_expression(PREFIX)
	return expression
end

function Parser:parse_statement(): ast.Statement
	if self.cur_token.type == token.LET then
		return self:parse_let_statement()
	elseif self.cur_token.type == token.RETURN then
		return self:parse_return_statement()
	else
		return self:parse_expression_statement()
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
		prefix_parse_fns = {},
		infix_parse_fns = {},
	}, { __index = Parser })
	p:next_token()
	p:next_token()
	p:register_prefix(token.IDENT, p.parse_identifier)
	p:register_prefix(token.INT, p.parse_integer_literal)
	p:register_prefix(token.BANG, p.parse_prefix_expression)
	p:register_prefix(token.MINUS, p.parse_prefix_expression)
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
