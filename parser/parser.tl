
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

	peek_precedence: function (self): integer
	cur_precedence: function (self): integer

	parse_program: function(self): ast.Program
	parse_statement: function(self): ast.Statement
	parse_let_statement: function(self): ast.LetStatement
	parse_return_statement: function(self): ast.ReturnStatement
	parse_expression_statement: function(self): ast.ExpressionStatement
	parse_expression: function (self, integer): ast.Expression
	parse_identifier: function (self): ast.Expression
	parse_integer_literal: function (self): ast.Expression
	parse_prefix_expression: function (self): ast.Expression
	parse_infix_expression: function (self, ast.Expression): ast.Expression
	parse_boolean: function (self): ast.Expression
	parse_grouped_expression: function (self): ast.Expression
	parse_if_expression: function (self): ast.Expression
	parse_block_statement: function (self): ast.BlockStatement
	parse_function_literal: function (self): ast.Expression
	parse_function_parameters: function (self): {ast.Identifier}
	parse_call_expression: function (self, ast.Expression): ast.Expression
	parse_call_arguments: function (self): {ast.Expression}

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

local precedences <const>: { token.TokenType:integer } = {
	[token.EQ] = EQUALS,
	[token.NOT_EQ] = EQUALS,
	[token.LT] = LESSGREATER,
	[token.GT] = LESSGREATER,
	[token.PLUS] = SUM,
	[token.MINUS] = SUM,
	[token.SLASH] = PRODUCT,
	[token.ASTERISK] = PRODUCT,
	[token.LPAREN] = CALL,
}

function Parser:peek_precedence(): integer
	local p = precedences[self.peek_token.type]
	if p then
		return p
	end
	return LOWEST
end

function Parser:cur_precedence(): integer
	local p = precedences[self.cur_token.type]
	if p then
		return p
	end
	return LOWEST
end

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
	stmt.return_value = self:parse_expression(LOWEST)
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
	while not self:peek_token_is(token.SEMICOLON) and precedence < self:peek_precedence() do
		local infix = self.infix_parse_fns[self.peek_token.type]
		if infix == nil then
			return left_exp
		end
		self:next_token()
		left_exp = infix(self, left_exp)
	end
	return left_exp
end

function Parser:parse_identifier (): ast.Expression
	return ast.Identifier.new(self.cur_token, self.cur_token.literal)
end

function Parser:parse_integer_literal (): ast.Expression
	local lit = ast.IntegerLiteral.new(self.cur_token, nil)
	assert(lit is ast.IntegerLiteral)
	assert(lit.kind == "integer_literal")
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

function Parser:parse_infix_expression (left: ast.Expression): ast.Expression
	local expression = ast.InfixExpression.new(self.cur_token, left, self.cur_token.literal, nil)
	local precedence = self:cur_precedence()
	self:next_token()
	expression.right = self:parse_expression(precedence)
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
	self:next_token()
	stmt.value = self:parse_expression(LOWEST)
	while not self:cur_token_is(token.SEMICOLON) do
		self:next_token()
	end
	return stmt
end

function Parser:parse_boolean (): ast.Expression
	if self:cur_token_is(token.TRUE) then
		return ast.Boolean.new(self.cur_token, true)
	elseif self:cur_token_is(token.FALSE) then
		return ast.Boolean.new(self.cur_token, false)
	else
		return nil
	end
end

function Parser:parse_grouped_expression (): ast.Expression
	self:next_token()
	local exp = self:parse_expression(LOWEST)
	if not self:expect_peek(token.RPAREN) then
		return nil
	end
	return exp
end

function Parser:parse_if_expression (): ast.Expression
	local expression = ast.IfExpression.new(self.cur_token, nil, nil, nil)
	if not self:expect_peek(token.LPAREN) then
		return nil
	end
	self:next_token()
	expression.condition = self:parse_expression(LOWEST)
	if not self:expect_peek(token.RPAREN) then
		return nil
	end
	if not self:expect_peek(token.LBRACE) then
		return nil
	end
	expression.consequence = self:parse_block_statement()
	if self:peek_token_is(token.ELSE) then
		self:next_token()
		if not self:expect_peek(token.LBRACE) then
			return nil
		end
		expression.alternative = self:parse_block_statement()
	end
	return expression
end

function Parser:parse_block_statement (): ast.BlockStatement
	local block = ast.BlockStatement.new(self.cur_token, {})
	self:next_token()
	while not self:cur_token_is(token.RBRACE) and not self:cur_token_is(token.EOF) do
		local stmt = self:parse_statement()
		if stmt ~= nil then
			table.insert(block.statements, stmt)
		end
		self:next_token()
	end
	return block
end

function Parser:parse_function_literal (): ast.Expression
	local lit = ast.FunctionLiteral.new(self.cur_token, nil, nil)
	if not self:expect_peek(token.LPAREN) then
		return nil
	end
	lit.parameters = self:parse_function_parameters()
	assert(lit.parameters ~= nil)
	if not lit.parameters then
		return nil
	end
	if not self:expect_peek(token.LBRACE) then
		return nil
	end
	lit.body = self:parse_block_statement()
	return lit
end

function Parser:parse_function_parameters (): {ast.Identifier}
	local identifiers = {}
	if self:peek_token_is(token.RPAREN) then
		self:next_token()
		return identifiers
	end
	self:next_token()
	do
		local ident = ast.Identifier.new(self.cur_token, self.cur_token.literal)
		table.insert(identifiers, ident)
	end
	while self:peek_token_is(token.COMMA) do
		self:next_token()
		self:next_token()
		local ident = ast.Identifier.new(self.cur_token, self.cur_token.literal)
		table.insert(identifiers, ident)
	end
	if not self:expect_peek(token.RPAREN) then
		return nil
	end
	return identifiers
end

function Parser:parse_call_expression (func: ast.Expression): ast.Expression
	local exp = ast.CallExpression.new(self.cur_token, func, nil)
	exp.arguments = self:parse_call_arguments()
	return exp
end

function Parser:parse_call_arguments (): {ast.Expression}
	local args = {}
	if self:peek_token_is(token.RPAREN) then
		self:next_token()
		return args
	end
	self:next_token()
	table.insert(args, self:parse_expression(LOWEST))
	while self:peek_token_is(token.COMMA) do
		self:next_token()
		self:next_token()
		table.insert(args, self:parse_expression(LOWEST))
	end
	if not self:expect_peek(token.RPAREN) then
		return nil
	end
	return args
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
	p:register_prefix(token.TRUE, p.parse_boolean)
	p:register_prefix(token.FALSE, p.parse_boolean)
	p:register_prefix(token.LPAREN, p.parse_grouped_expression)
	p:register_prefix(token.IF, p.parse_if_expression)
	p:register_prefix(token.FUNCTION, p.parse_function_literal)

	p:register_infix(token.PLUS, p.parse_infix_expression)
	p:register_infix(token.MINUS, p.parse_infix_expression)
	p:register_infix(token.SLASH, p.parse_infix_expression)
	p:register_infix(token.ASTERISK, p.parse_infix_expression)
	p:register_infix(token.EQ, p.parse_infix_expression)
	p:register_infix(token.NOT_EQ, p.parse_infix_expression)
	p:register_infix(token.LT, p.parse_infix_expression)
	p:register_infix(token.GT, p.parse_infix_expression)
	p:register_infix(token.LPAREN, p.parse_call_expression)
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
