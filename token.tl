
local type TokenType = string
local record Token
	 type: TokenType
	 literal: string
end

local ILLEGAL <const> = "ILLEGAL"
local EOF <const> = "EOF"
local IDENT <const> = "IDENT"
local INT <const> = "INT"
local ASSIGN <const> = "ASSIGN"
local PLUS <const> = "+"
local MINUS <const> = "-"
local BANG <const> = "!"
local ASTERISK <const> = "*"
local SLASH <const> = "/"
local LT <const> = "<"
local GT <const> = ">"
local COMMA <const> = "COMMA"
local SEMICOLON <const> = "SEMICOLON"
local LPAREN <const> = "LPAREN"
local RPAREN <const> = "RPAREN"
local LBRACE <const> = "LBRACE"
local RBRACE <const> = "RBRACE"
local LBRACKET <const> = "["
local RBRACKET <const> = "]"
local EQ <const> = "=="
local NOT_EQ <const> = "!="
local STRING <const> = "STRING"

local FUNCTION <const> = "FUNCTION"
local LET <const> = "LET"
local TRUE <const> = "TRUE"
local FALSE <const> = "FALSE"
local IF <const> = "IF"
local ELSE <const> = "ELSE"
local RETURN <const> = "RETURN"

local keywords: { string:TokenType } = {
	["fn"] = FUNCTION,
	["let"] = LET,
	["true"] = TRUE,
	["false"] = FALSE,
	["if"] = IF,
	["else"] = ELSE,
	["return"] = RETURN,
}

local function lookup_ident (ident: string): TokenType
	return keywords[ident] or IDENT
end

local token <const> = {
	TokenType = TokenType,
	Token = Token,

	lookup_ident = lookup_ident,

	ILLEGAL = ILLEGAL,
	EOF = EOF,
	IDENT = IDENT,
	INT = INT,
	ASSIGN = ASSIGN,
	PLUS = PLUS,
	MINUS = MINUS,
	BANG = BANG,
	ASTERISK = ASTERISK,
	SLASH = SLASH,
	LT = LT,
	GT = GT,
	COMMA = COMMA,
	SEMICOLON = SEMICOLON,
	LPAREN = LPAREN,
	RPAREN = RPAREN,
	LBRACE = LBRACE,
	RBRACE = RBRACE,
	LBRACKET = LBRACKET,
	RBRACKET = RBRACKET,
	EQ = EQ,
	NOT_EQ = NOT_EQ,
	STRING = STRING,

	FUNCTION = FUNCTION,
	LET = LET,
	TRUE = TRUE,
	FALSE = FALSE,
	IF = IF,
	ELSE = ELSE,
	RETURN = RETURN,
}

return token
