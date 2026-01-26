
local ast = require("ast.ast")
local object = require("object")

local record evaluator
	eval: function (ast.Node): object.Object
	eval_program: function (ast.Program): object.Object
	eval_block_statement: function (ast.BlockStatement): object.Object
	eval_statements: function ({ast.Statement}): object.Object
	eval_prefix_expression: function (string, object.Object): object.Object
	eval_bang_operator_expression: function (object.Object): object.Object
	eval_minus_prefix_operator_expression: function (object.Object): object.Object
	eval_infix_expression: function (string, object.Object, object.Object): object.Object
	eval_integer_infix_expression: function (string, object.Object, object.Object): object.Object
	eval_if_expression: function (ast.IfExpression): object.Object

	NULL: object.Null
end

local NULL <const> = object.Null.new()
local TRUE <const> = object.Boolean.new(true)
local FALSE <const> = object.Boolean.new(false)

evaluator.NULL = NULL

local function native_bool_to_boolean_object (input: boolean): object.Boolean
	if input then
		return TRUE
	else
		return FALSE
	end
end

local function new_error (format: string, ...): object.Error
	return object.Error.new(string.format(format, ...))
end

local function is_error (obj: object.Object): boolean
	if obj ~= nil then
		return obj:type() == object.ERROR_OBJ
	else
		return false
	end
end

function evaluator.eval (node: ast.Node): object.Object
	if node is ast.Program then
		return evaluator.eval_program((node as ast.Program))
	elseif node is ast.ExpressionStatement then
		return evaluator.eval((node as ast.ExpressionStatement).expression)
	elseif node is ast.IntegerLiteral then
		return object.Integer.new((node as ast.IntegerLiteral).value)
	elseif node is ast.Boolean then
		return native_bool_to_boolean_object((node as ast.Boolean).value)
	elseif node is ast.PrefixExpression then
		local prefix = node as ast.PrefixExpression
		local right = evaluator.eval(prefix.right)
		if is_error(right) then
			return right
		end
		return evaluator.eval_prefix_expression(prefix.operator, right)
	elseif node is ast.InfixExpression then
		local infix = node as ast.InfixExpression
		local left = evaluator.eval(infix.left)
		if is_error(left) then
			return left
		end
		local right = evaluator.eval(infix.right)
		if is_error(right) then
			return right
		end
		return evaluator.eval_infix_expression(infix.operator, left, right)
	elseif node is ast.BlockStatement then
		return evaluator.eval_block_statement((node as ast.BlockStatement))
	elseif node is ast.IfExpression then
		return evaluator.eval_if_expression((node as ast.IfExpression))
	elseif node is ast.ReturnStatement then
		local val = evaluator.eval((node as ast.ReturnStatement).return_value)
		if is_error(val) then
			return val
		end
		return object.ReturnValue.new(val)
	elseif node is ast.LetStatement then
		local val = evaluator.eval((node as ast.LetStatement).value)
		if is_error(val) then
			return val
		end
	end
	return nil
end

function evaluator.eval_program (program: ast.Program): object.Object
	local result: object.Object
	for _, statement in ipairs(program.statements) do
		result = evaluator.eval(statement)
		if result is object.ReturnValue then
			return (result as object.ReturnValue).value
		elseif result is object.Error then
			return result
		end
	end
	return result
end

function evaluator.eval_block_statement (block: ast.BlockStatement): object.Object
	local result: object.Object
	for _, statement in ipairs(block.statements) do
		result = evaluator.eval(statement)
		if result ~= nil then
			local rt = result:type()
			if rt == object.RETURN_VALUE_OBJ or rt == object.ERROR_OBJ then
				return result
			end
		end
	end
	return result
end

function evaluator.eval_statements (stmts: {ast.Statement}): object.Object
	local result: object.Object
	for _, statement in ipairs(stmts) do
		result = evaluator.eval(statement)
		if result is object.ReturnValue then
			return (result as object.ReturnValue).value
		end
	end
	return result
end

function evaluator.eval_prefix_expression (operator: string, right: object.Object): object.Object
	if operator == "!" then
		return evaluator.eval_bang_operator_expression(right)
	elseif operator == "-" then
		return evaluator.eval_minus_prefix_operator_expression(right)
	else
		return new_error("unknown operator: %s%s", operator, right:type())
	end
end

function evaluator.eval_bang_operator_expression (right: object.Object): object.Object
	if right == TRUE then
		return FALSE
	elseif right == FALSE then
		return TRUE
	elseif right == NULL then
		return TRUE
	else
		return FALSE
	end
end

function evaluator.eval_minus_prefix_operator_expression (right: object.Object): object.Object
	if right:type() ~= object.INTEGER_OBJ then
		return new_error("unknown operator: -%s", right:type())
	else
		local value = (right as object.Integer).value
		return object.Integer.new(-value)
	end
end

function evaluator.eval_infix_expression (operator: string, left: object.Object, right: object.Object): object.Object
	if left:type() == object.INTEGER_OBJ and right:type() == object.INTEGER_OBJ then
		return evaluator.eval_integer_infix_expression(operator, left, right)
	elseif operator == "==" then
		return native_bool_to_boolean_object(left == right)
	elseif operator == "!=" then
		return native_bool_to_boolean_object(left ~= right)
	elseif left:type() ~= right:type() then
		return new_error("type mismatch: %s %s %s", left:type(), operator, right:type())
	else
		return new_error("unknown operator: %s %s %s", left:type(), operator, right:type())
	end
end

function evaluator.eval_integer_infix_expression (operator: string, left: object.Object, right: object.Object): object.Object
	local left_val = (left as object.Integer).value
	local right_val = (right as object.Integer).value
	if operator == "+" then
		return object.Integer.new(left_val + right_val)
	elseif operator == "-" then
		return object.Integer.new(left_val - right_val)
	elseif operator == "*" then
		return object.Integer.new(left_val * right_val)
	elseif operator == "/" then
		return object.Integer.new(math.floor(left_val / right_val))
	elseif operator == "<" then
		return native_bool_to_boolean_object(left_val < right_val)
	elseif operator == ">" then
		return native_bool_to_boolean_object(left_val > right_val)
	elseif operator == "==" then
		return native_bool_to_boolean_object(left_val == right_val)
	elseif operator == "!=" then
		return native_bool_to_boolean_object(left_val ~= right_val)
	else
		return new_error("unknown operator: %s %s %s", left:type(), operator, right:type())
	end
end

local function is_truthy (obj: object.Object): boolean
	if obj == TRUE then
		return true
	elseif obj == FALSE then
		return false
	elseif obj == NULL then
		return false
	else
		return true
	end
end

function evaluator.eval_if_expression (ie: ast.IfExpression): object.Object
	local condition = evaluator.eval(ie.condition)
	if is_error(condition) then
		return condition
	elseif is_truthy(condition) then
		return evaluator.eval(ie.consequence)
	elseif ie.alternative ~= nil then
		return evaluator.eval(ie.alternative)
	else
		return NULL
	end
end

return evaluator
