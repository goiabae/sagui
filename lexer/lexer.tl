
local token = require("token")

local type byte = string

local record Lexer
	input: string
	position: integer
	read_position: integer
	ch: byte
end

function Lexer:read_char(): byte
	if self.read_position > #self.input then
		self.ch = nil
	else
		self.ch = self.input:sub(self.read_position, self.read_position)
	end
	self.position = self.read_position
	self.read_position = self.read_position + 1
end

function Lexer:peek_char(): byte
	if self.read_position > #self.input then
		return nil
	else
		return self.input:sub(self.read_position, self.read_position)
	end
end

local function new_token (token_type: token.TokenType, ch: byte): token.Token
	return { type = token_type, literal = ch }
end

local function is_letter(c: string): boolean
	return string.match(c, "%a") ~= nil
end

local function is_digit(c: string): boolean
	return string.match(c, "%d") ~= nil
end

function Lexer:read_identifier(): string
	local position = self.position
	while self.ch and is_letter(self.ch) do
		self:read_char()
	end
	return self.input:sub(position, self.position-1)
end

function Lexer:read_number(): string
	local position = self.position
	while self.ch and is_digit(self.ch) do
		self:read_char()
	end
	return self.input:sub(position, self.position-1)
end

function Lexer:skip_whitespace()
	while self.ch == ' ' or self.ch == '\t' or self.ch == '\n' or self.ch == '\r' do
		self:read_char()
	end
end

function Lexer:read_string(): string
	local position = self.position + 1
	while true do
		self:read_char()
		if self.ch == '"' or self.ch == nil then
			break
		end
	end
	return self.input:sub(position, self.position-1)
end

function Lexer:next_token(): token.Token
	local tok: token.Token
	self:skip_whitespace()
	if self.ch == "=" then
		if self:peek_char() == "=" then
			local ch = self.ch
			self:read_char()
			local literal = ch .. self.ch
			tok = new_token(token.EQ, literal)
		else
			tok = new_token(token.ASSIGN, self.ch)
		end
	elseif self.ch == "+" then
		tok = new_token(token.PLUS, self.ch)
	elseif self.ch == "-" then
		tok = new_token(token.MINUS, self.ch)
	elseif self.ch == "!" then
		if self:peek_char() == "=" then
			local ch = self.ch
			self:read_char()
			local literal = ch .. self.ch
			tok = new_token(token.NOT_EQ, literal)
		else
			tok = new_token(token.BANG, self.ch)
		end
	elseif self.ch == "/" then
		tok = new_token(token.SLASH, self.ch)
	elseif self.ch == "*" then
		tok = new_token(token.ASTERISK, self.ch)
	elseif self.ch == "<" then
		tok = new_token(token.LT, self.ch)
	elseif self.ch == ">" then
		tok = new_token(token.GT, self.ch)
	elseif self.ch == ";" then
		tok = new_token(token.SEMICOLON, self.ch)
	elseif self.ch == "(" then
		tok = new_token(token.LPAREN, self.ch)
	elseif self.ch == ")" then
		tok = new_token(token.RPAREN, self.ch)
	elseif self.ch == "," then
		tok = new_token(token.COMMA, self.ch)
	elseif self.ch == "+" then
		tok = new_token(token.PLUS, self.ch)
	elseif self.ch == "{" then
		tok = new_token(token.LBRACE, self.ch)
	elseif self.ch == "}" then
		tok = new_token(token.RBRACE, self.ch)
	elseif self.ch == '"' then
		tok = new_token(token.STRING, self:read_string())
	elseif self.ch == nil then
		tok = new_token(token.EOF, "")
	else
		if is_letter(self.ch) then
			local ident = self:read_identifier()
			tok = new_token(token.lookup_ident(ident), ident)
			return tok
		elseif is_digit(self.ch) then
			tok = new_token(token.INT, self:read_number())
			return tok
		else
			tok = new_token(token.ILLEGAL, self.ch)
		end
	end
	self:read_char()
	return tok
end

local function new (input: string): Lexer
	local l: Lexer = setmetatable({
		input = input,
		position = 1,
		read_position = 1,
		ch = nil,
	}, { __index = Lexer })
	l:read_char()
	return l
end

local lexer <const> = {
	Lexer = Lexer,
	new = new,
}

return lexer
