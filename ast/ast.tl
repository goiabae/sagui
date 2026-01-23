
local token = require("token")

local interface Node
  token_literal: function(self): string
	string: function(self): string
end

local interface Statement is Node
  statement_node: function(self)
end

local interface Expression is Node
  expression_node: function(self)
end

local record Program is Node
	statements: {Statement}
end

function Program:token_literal(): string
	if #self.statements > 0 then
		return self.statements[1]:token_literal()
	else
		return ""
	end
end

function Program:string(): string
	local out = ""
	for _, s in ipairs(self.statements) do
		out = out .. s:string()
	end
	return out
end

function Program.new(stmts: {Statement}): Program
	return setmetatable({
		statements = stmts,
	}, { __index = Program })
end

local record Identifier is Expression
	token: token.Token
	value: string
end

function Identifier:expression_node() end
function Identifier:token_literal(): string return self.token.literal end
function Identifier.new(tk: token.Token, value: string): Identifier
	return setmetatable({
		token = tk,
		value = value,
	}, { __index = Identifier })
end

function Identifier:string(): string
	return self.value
end

local record IntegerLiteral is Expression
	token: token.Token
	value: integer
end

function IntegerLiteral:expression_node() end
function IntegerLiteral:token_literal(): string return self.token.literal end
function IntegerLiteral.new(tk: token.Token, value: integer): IntegerLiteral
	return setmetatable({
		token = tk,
		value = value,
	}, { __index = IntegerLiteral })
end

function IntegerLiteral:string(): string
	return tostring(self.value)
end

local record PrefixExpression is Expression
	token: token.Token
	operator: string
	right: Expression
end

function PrefixExpression:expression_node() end
function PrefixExpression:token_literal(): string return self.token.literal end
function PrefixExpression.new(tk: token.Token, operator: string, right: Expression): PrefixExpression
	return setmetatable({
		token = tk,
		operator = operator,
		right = right,
	}, { __index = PrefixExpression })
end

function PrefixExpression:string(): string
	return "(" .. self.operator .. self.right:string() .. ")"
end

local record LetStatement is Statement
	token: token.Token
	name: Identifier
	value: Expression
end

function LetStatement:statement_node() end
function LetStatement:token_literal(): string return self.token.literal end
function LetStatement.new(tk: token.Token, name: Identifier, value: Expression): LetStatement
	return setmetatable({
		token = tk,
		name = name,
		value = value,
	}, { __index = LetStatement })
end

function LetStatement:string(): string
	local out = ""
	out = out .. self:token_literal() .. " "
	out = out .. self.name:string()
	out = out .. " = "
	if self.value ~= nil then
		out = out .. self.value:string()
	end
	out = out .. ";"
	return out
end

local record ReturnStatement is Statement
	token: token.Token
	return_value: Expression
end

function ReturnStatement:statement_node() end
function ReturnStatement:token_literal(): string return self.token.literal end
function ReturnStatement.new(tk: token.Token, return_value: Expression): ReturnStatement
	return setmetatable({
		token = tk,
		return_value = return_value,
	}, { __index = ReturnStatement })
end

function ReturnStatement:string(): string
	local out = ""
	out = out .. self:token_literal() .. " "
	if self.return_value ~= nil then
		out = out .. self.return_value:string()
	end
	out = out .. ";"
	return out
end

local record ExpressionStatement is Statement
	token: token.Token
	expression: Expression
end

function ExpressionStatement:statement_node() end
function ExpressionStatement:token_literal(): string return self.token.literal end
function ExpressionStatement.new(tk: token.Token, expression: Expression): ExpressionStatement
	return setmetatable({
		token = tk,
		expression = expression,
	}, { __index = ExpressionStatement })
end

function ExpressionStatement:string(): string
	if self.expression ~= nil then
		return self.expression:string()
	end
	return ""
end

local ast <const> = {
	Node = Node,

	Statement = Statement,
	LetStatement = LetStatement,
	ReturnStatement = ReturnStatement,
	ExpressionStatement = ExpressionStatement,

	Expression = Expression,
	Identifier = Identifier,
	IntegerLiteral = IntegerLiteral,
	PrefixExpression = PrefixExpression,

	Program = Program,
}

return ast
