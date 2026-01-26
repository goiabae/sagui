
local token = require("token")

local enum NodeType
	"program"
	"expression_statement"
	"identifier"
	"integer_literal"
	"boolean"
	"prefix_expression"
	"infix_expression"
	"block_statement"
	"if_expression"
	"return_statement"
	"let_statement"
end

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
	where self.kind == "program"
	kind: NodeType
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
		kind = "program",
		statements = stmts,
	}, { __index = Program })
end

local record Identifier is Expression
	where self.kind == "identifier"
	kind: NodeType
	token: token.Token
	value: string
end

function Identifier:expression_node() end
function Identifier:token_literal(): string return self.token.literal end
function Identifier.new(tk: token.Token, value: string): Identifier
	return setmetatable({
		kind = "identifier",
		token = tk,
		value = value,
	}, { __index = Identifier })
end

function Identifier:string(): string
	return self.value
end

local record IntegerLiteral is Expression
	where self.kind == "integer_literal"
	kind: NodeType
	token: token.Token
	value: integer
end

function IntegerLiteral:expression_node() end
function IntegerLiteral:token_literal(): string return self.token.literal end
function IntegerLiteral.new(tk: token.Token, value: integer): IntegerLiteral
	return setmetatable({
		kind = "integer_literal",
		token = tk,
		value = value,
	}, { __index = IntegerLiteral })
end

function IntegerLiteral:string(): string
	return tostring(self.value)
end

local record PrefixExpression is Expression
	where self.kind == "prefix_expression"
	kind: NodeType
	token: token.Token
	operator: string
	right: Expression
end

function PrefixExpression:expression_node() end
function PrefixExpression:token_literal(): string return self.token.literal end
function PrefixExpression.new(tk: token.Token, operator: string, right: Expression): PrefixExpression
	return setmetatable({
		kind = "prefix_expression",
		token = tk,
		operator = operator,
		right = right,
	}, { __index = PrefixExpression })
end

function PrefixExpression:string(): string
	return "(" .. self.operator .. self.right:string() .. ")"
end

local record InfixExpression is Expression
	where self.kind == "infix_expression"
	kind: NodeType
	token: token.Token
	left: Expression
	operator: string
	right: Expression
end

function InfixExpression:expression_node() end
function InfixExpression:token_literal(): string return self.token.literal end
function InfixExpression.new(tk: token.Token, left: Expression, operator: string, right: Expression): InfixExpression
	return setmetatable({
		kind = "infix_expression",
		token = tk,
		left = left,
		operator = operator,
		right = right,
	}, { __index = InfixExpression })
end

function InfixExpression:string(): string
	return "(" .. self.left:string() .. " " .. self.operator .. " " .. self.right:string() .. ")"
end

local record LetStatement is Statement
	where self.kind == "let_statement"
	kind: NodeType
	token: token.Token
	name: Identifier
	value: Expression
end

function LetStatement:statement_node() end
function LetStatement:token_literal(): string return self.token.literal end
function LetStatement.new(tk: token.Token, name: Identifier, value: Expression): LetStatement
	return setmetatable({
		kind = "let_statement",
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
	where self.kind == "return_statement"
	kind: NodeType
	token: token.Token
	return_value: Expression
end

function ReturnStatement:statement_node() end
function ReturnStatement:token_literal(): string return self.token.literal end
function ReturnStatement.new(tk: token.Token, return_value: Expression): ReturnStatement
	return setmetatable({
		kind = "return_statement",
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
	where self.kind == "expression_statement"
	kind: NodeType
	token: token.Token
	expression: Expression
end

function ExpressionStatement:statement_node() end
function ExpressionStatement:token_literal(): string return self.token.literal end
function ExpressionStatement.new(tk: token.Token, expression: Expression): ExpressionStatement
	return setmetatable({
		kind = "expression_statement",
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

local record Boolean is Expression
	where self.kind == "boolean"
	kind: NodeType
	token: token.Token
	value: boolean
end

function Boolean:expression_node() end
function Boolean:token_literal(): string return self.token.literal end
function Boolean.new(tk: token.Token, value: boolean): Boolean
	return setmetatable({
		kind = "boolean",
		token = tk,
		value = value,
	}, { __index = Boolean })
end

function Boolean:string(): string
	return self.token.literal
end

local record BlockStatement is Statement
	where self.kind == "block_statement"
	kind: NodeType
	token: token.Token
	statements: {Statement}
end

function BlockStatement:statement_node() end
function BlockStatement:token_literal(): string return self.token.literal end
function BlockStatement.new(tk: token.Token, statements: {Statement}): BlockStatement
	return setmetatable({
		kind = "block_statement",
		token = tk,
		statements = statements,
	}, { __index = BlockStatement })
end

function BlockStatement:string(): string
	local out = ""
	for _, s in ipairs(self.statements) do
		out = out .. s:string()
	end
	return out
end

local record IfExpression is Expression
	where self.kind == "if_expression"
	kind: NodeType
	token: token.Token
	condition: Expression
	consequence: BlockStatement
	alternative: BlockStatement
end

function IfExpression:expression_node() end
function IfExpression:token_literal(): string return self.token.literal end
function IfExpression.new(tk: token.Token, condition: Expression, consequence: BlockStatement, alternative: BlockStatement): IfExpression
	return setmetatable({
		kind = "if_expression",
		token = tk,
		condition = condition,
		consequence = consequence,
		alternative = alternative,
	}, { __index = IfExpression })
end

function IfExpression:string(): string
	local out = ""
	out = out .. "if" .. self.condition:string() .. " " .. self.consequence:string()
	if self.alternative ~= nil then
		out = out .. "else " .. self.alternative:string()
	end
	return out
end

local record FunctionLiteral is Expression
	token: token.Token
	parameters: {Identifier}
	body: BlockStatement
end

function FunctionLiteral:expression_node() end
function FunctionLiteral:token_literal(): string return self.token.literal end
function FunctionLiteral.new(tk: token.Token, parameters: {Identifier}, body: BlockStatement): FunctionLiteral
	return setmetatable({
		token = tk,
		parameters = parameters,
		body = body,
	}, { __index = FunctionLiteral })
end

function FunctionLiteral:string(): string
	local params = {}
	for _, p in ipairs(self.parameters) do
		table.insert(params, p:string())
	end
	return self:token_literal() .. "(" .. table.concat(params, ", ") .. ") " .. self.body:string()
end

local record CallExpression is Expression
	token: token.Token
	func: Expression
	arguments: {Expression}
end

function CallExpression:expression_node() end
function CallExpression:token_literal(): string return self.token.literal end
function CallExpression.new(tk: token.Token, func: Expression, arguments: {Expression}): CallExpression
	return setmetatable({
		token = tk,
		func = func,
		arguments = arguments,
	}, { __index = CallExpression })
end

function CallExpression:string(): string
	local args = {}
	for _, a in ipairs(self.arguments) do
		table.insert(args, a:string())
	end
	return self.func:string() ..  "(" .. table.concat(args, ", ") .. ")"
end

local ast <const> = {
	Node = Node,

	Statement = Statement,
	LetStatement = LetStatement,
	ReturnStatement = ReturnStatement,
	ExpressionStatement = ExpressionStatement,
	BlockStatement = BlockStatement,

	Expression = Expression,
	Identifier = Identifier,
	IntegerLiteral = IntegerLiteral,
	PrefixExpression = PrefixExpression,
	InfixExpression = InfixExpression,
	Boolean = Boolean,
	IfExpression = IfExpression,
	FunctionLiteral = FunctionLiteral,
	CallExpression = CallExpression,

	Program = Program,
}

return ast
