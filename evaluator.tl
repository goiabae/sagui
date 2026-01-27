
local ast = require("ast.ast")
local object = require("object")
local environment = require("environment")

local record evaluator
	eval: function (ast.Node, environment.Environment): object.Object
	eval_program: function (ast.Program, environment.Environment): object.Object
	eval_block_statement: function (ast.BlockStatement, environment.Environment): object.Object
	eval_statements: function ({ast.Statement}, environment.Environment): object.Object
	eval_prefix_expression: function (string, object.Object): object.Object
	eval_bang_operator_expression: function (object.Object): object.Object
	eval_minus_prefix_operator_expression: function (object.Object): object.Object
	eval_infix_expression: function (string, object.Object, object.Object): object.Object
	eval_integer_infix_expression: function (string, object.Object, object.Object): object.Object
	eval_string_infix_expression: function (string, object.Object, object.Object): object.Object
	eval_if_expression: function (ast.IfExpression, environment.Environment): object.Object
	eval_identifier: function (ast.Identifier, environment.Environment): object.Object
	eval_expressions: function ({ast.Expression}, environment.Environment): {object.Object}

	NULL: object.Null
end

local NULL <const> = object.Null.new()
local TRUE <const> = object.Boolean.new(true)
local FALSE <const> = object.Boolean.new(false)

evaluator.NULL = NULL

local function new_error (format: string, ...): object.Error
	return object.Error.new(string.format(format, ...))
end

local builtins: { string:object.Builtin } = {
	["len"] = object.Builtin.new(function (...: object.Object): object.Object
		local args = { ... }
		if #args ~= 1 then
			return new_error("wrong number of arguments. got=%d, want=1", #args)
		end
		local fst_arg = args[1]
		if fst_arg is object.String then
			return object.Integer.new(#(fst_arg as object.String).value)
		else
			return new_error("argument to 'len' not supported, got %s", args[1]:type())
		end
	end)
}

local function native_bool_to_boolean_object (input: boolean): object.Boolean
	if input then
		return TRUE
	else
		return FALSE
	end
end

local function is_error (obj: object.Object): boolean
	if obj ~= nil then
		return obj:type() == object.ERROR_OBJ
	else
		return false
	end
end

local function extend_function_env (fn: object.Function, args: {object.Object}): environment.Environment
	local env = environment.new_enclosed_environment(fn.env)
	for param_idx, param in ipairs(fn.parameters) do
		env:set(param.value, args[param_idx])
	end
	return env
end

local function unwrap_return_value (obj: object.Object): object.Object
	if obj is object.ReturnValue then
		return (obj as object.ReturnValue).value
	else
		return obj
	end
end

local function apply_function (fn: object.Object, args: {object.Object}): object.Object
	if fn is object.Builtin then
		return (fn as object.Builtin).fn(table.unpack(args))
	elseif fn is object.Function then
		local func = fn as object.Function
		local extended_env = extend_function_env(func, args)
		local evaluated = evaluator.eval(func.body, extended_env)
		return unwrap_return_value(evaluated)
	else
		return new_error("not a function: %s", fn:type())
	end
end

function evaluator.eval (node: ast.Node, env: environment.Environment): object.Object
	if node is ast.Program then
		return evaluator.eval_program((node as ast.Program), env)
	elseif node is ast.ExpressionStatement then
		return evaluator.eval((node as ast.ExpressionStatement).expression, env)
	elseif node is ast.IntegerLiteral then
		return object.Integer.new((node as ast.IntegerLiteral).value)
	elseif node is ast.Boolean then
		return native_bool_to_boolean_object((node as ast.Boolean).value)
	elseif node is ast.PrefixExpression then
		local prefix = node as ast.PrefixExpression
		local right = evaluator.eval(prefix.right, env)
		if is_error(right) then
			return right
		end
		return evaluator.eval_prefix_expression(prefix.operator, right)
	elseif node is ast.InfixExpression then
		local infix = node as ast.InfixExpression
		local left = evaluator.eval(infix.left, env)
		if is_error(left) then
			return left
		end
		local right = evaluator.eval(infix.right, env)
		if is_error(right) then
			return right
		end
		return evaluator.eval_infix_expression(infix.operator, left, right)
	elseif node is ast.BlockStatement then
		return evaluator.eval_block_statement((node as ast.BlockStatement), env)
	elseif node is ast.IfExpression then
		return evaluator.eval_if_expression((node as ast.IfExpression), env)
	elseif node is ast.ReturnStatement then
		local val = evaluator.eval((node as ast.ReturnStatement).return_value, env)
		if is_error(val) then
			return val
		end
		return object.ReturnValue.new(val)
	elseif node is ast.LetStatement then
		local let_stmt = node as ast.LetStatement
		local val = evaluator.eval(let_stmt.value, env)
		if is_error(val) then
			return val
		end
		env:set(let_stmt.name.value, val)
	elseif node is ast.Identifier then
		return evaluator.eval_identifier((node as ast.Identifier), env)
	elseif node is ast.FunctionLiteral then
		local lit = node as ast.FunctionLiteral
		local params = lit.parameters
		local body = lit.body
		return object.Function.new(params, body, env)
	elseif node is ast.CallExpression then
		local ce = node as ast.CallExpression
		local func = evaluator.eval(ce.func, env)
		if is_error(func) then
			return func
		end
		local args = evaluator.eval_expressions(ce.arguments, env)
		if #args == 1 and is_error(args[1]) then
			return args[1]
		end
		return apply_function(func, args)
	elseif node is ast.StringLiteral then
		return object.String.new((node as ast.StringLiteral).value)
	end
	return nil
end

function evaluator.eval_identifier (node: ast.Identifier, env: environment.Environment): object.Object
	do
		local val, ok = env:get(node.value)
		if ok then
			return val
		end
	end
	if builtins[node.value] ~= nil then
		return builtins[node.value]
	end
	return new_error("identifier not found: " .. node.value)
end

function evaluator.eval_program (program: ast.Program, env: environment.Environment): object.Object
	local result: object.Object
	for _, statement in ipairs(program.statements) do
		result = evaluator.eval(statement, env)
		if result and result is object.ReturnValue then
			return (result as object.ReturnValue).value
		elseif result and result is object.Error then
			return result
		end
	end
	return result
end

function evaluator.eval_block_statement (block: ast.BlockStatement, env: environment.Environment): object.Object
	local result: object.Object
	for _, statement in ipairs(block.statements) do
		result = evaluator.eval(statement, env)
		if result ~= nil then
			local rt = result:type()
			if rt == object.RETURN_VALUE_OBJ or rt == object.ERROR_OBJ then
				return result
			end
		end
	end
	return result
end

function evaluator.eval_statements (stmts: {ast.Statement}, env: environment.Environment): object.Object
	local result: object.Object
	for _, statement in ipairs(stmts) do
		result = evaluator.eval(statement, env)
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
	elseif left:type() == object.STRING_OBJ and right:type() == object.STRING_OBJ then
		return evaluator.eval_string_infix_expression(operator, left, right)
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

function evaluator.eval_string_infix_expression (operator: string, left: object.Object, right: object.Object): object.Object
	if operator ~= "+" then
		return new_error("unknown operator: %s %s %s", left:type(), operator, right:type())
	end
	local left_val = (left as object.String).value
	local right_val = (right as object.String).value
	return object.String.new(left_val .. right_val)
end

function evaluator.eval_expressions (exps: {ast.Expression}, env: environment.Environment): {object.Object}
	local result = {}
	for _, e in ipairs(exps) do
		local evaluated = evaluator.eval(e, env)
		if is_error(evaluated) then
			return {evaluated}
		end
		table.insert(result, evaluated)
	end
	return result
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

function evaluator.eval_if_expression (ie: ast.IfExpression, env: environment.Environment): object.Object
	local condition = evaluator.eval(ie.condition, env)
	if is_error(condition) then
		return condition
	elseif is_truthy(condition) then
		return evaluator.eval(ie.consequence, env)
	elseif ie.alternative ~= nil then
		return evaluator.eval(ie.alternative, env)
	else
		return NULL
	end
end

return evaluator
