
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
	eval_index_expression: function (object.Object, object.Object): object.Object
	eval_hash_literal: function (ast.HashLiteral, environment.Environment): object.Object
	eval_hash_index_expression: function (object.Object, object.Object): object.Object

	NULL: object.Null
	TRUE: object.Boolean
	FALSE: object.Boolean
end

local NULL <const> = object.Null.new()
local TRUE <const> = object.Boolean.new(true)
local FALSE <const> = object.Boolean.new(false)

evaluator.NULL = NULL
evaluator.TRUE = TRUE
evaluator.FALSE = FALSE

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
		elseif fst_arg is object.Array then
			return object.Integer.new(#(fst_arg as object.Array).elements)
		else
			return new_error("argument to 'len' not supported, got %s", args[1]:type())
		end
	end),
	["first"] = object.Builtin.new(function (...: object.Object): object.Object
		local args = { ... }
		if #args ~= 1 then
			return new_error("wrong number of arguments. got=%d, want=1", #args)
		end
		if args[1]:type() ~= object.ARRAY_OBJ then
			return new_error("argument to 'first' must be ARRAY, got %s", args[1]:type())
		end
		local arr = args[1] as object.Array
		if #arr.elements > 0 then
			return arr.elements[1]
		else
			return NULL
		end
	end),
	["last"] = object.Builtin.new(function (...: object.Object): object.Object
		local args = { ... }
		if #args ~= 1 then
			return new_error("wrong number of arguments. got=%d, want=1", #args)
		end
		if args[1]:type() ~= object.ARRAY_OBJ then
			return new_error("argument to 'last' must be ARRAY, got %s", args[1]:type())
		end
		local arr = args[1] as object.Array
		local length = #arr.elements
		if length > 0 then
			return arr.elements[length]
		else
			return NULL
		end
	end),
	["rest"] = object.Builtin.new(function (...: object.Object): object.Object
		local args = { ... }
		if #args ~= 1 then
			return new_error("wrong number of arguments. got=%d, want=1", #args)
		end
		if args[1]:type() ~= object.ARRAY_OBJ then
			return new_error("argument to 'rest' must be ARRAY, got %s", args[1]:type())
		end
		local arr = args[1] as object.Array
		local length = #arr.elements
		if length > 0 then
			local new_elements = {}
			for i = 2, length do
				table.insert(new_elements, arr.elements[i])
			end
			return object.Array.new(new_elements)
		else
			return NULL
		end
	end),
	["push"] = object.Builtin.new(function (...: object.Object): object.Object
		local args = { ... }
		if #args ~= 2 then
			return new_error("wrong number of arguments. got=%d, want=2", #args)
		end
		if args[1]:type() ~= object.ARRAY_OBJ then
			return new_error("argument to 'push' must be ARRAY, got %s", args[1]:type())
		end
		local arr = args[1] as object.Array
		local length = #arr.elements
		local new_elements = {}
		for i = 1, length do
			table.insert(new_elements, arr.elements[i])
		end
		table.insert(new_elements, args[2])
		return object.Array.new(new_elements)
	end),
	["puts"] = object.Builtin.new(function (...: object.Object): object.Object
		local args = { ... }
		for i = 1, #args do
			local a = args[i]
			print(a:inspect())
		end
		return NULL
	end),
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
	elseif node is ast.ArrayLiteral then
		local elements = evaluator.eval_expressions((node as ast.ArrayLiteral).elements, env)
		if #elements == 1 and is_error(elements[1]) then
			return elements[1]
		end
		return object.Array.new(elements)
	elseif node is ast.IndexExpression then
		local ie = node as ast.IndexExpression
		local left = evaluator.eval(ie.left, env)
		if is_error(left) then
			return left
		end
		local index = evaluator.eval(ie.index, env)
		if is_error(index) then
			return index
		end
		return evaluator.eval_index_expression(left, index)
	elseif node is ast.HashLiteral then
		return evaluator.eval_hash_literal(node, env)
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

function evaluator.eval_array_index_expression (array: object.Object, index: object.Object): object.Object
	local array_object = array as object.Array
	local idx = (index as object.Integer).value
	local max = #array_object.elements - 1
	if idx < 0 or idx > max then
		return NULL
	else
		return array_object.elements[idx+1]
	end
end

function evaluator.eval_index_expression (left: object.Object, index: object.Object): object.Object
	if left:type() == object.ARRAY_OBJ and index:type() == object.INTEGER_OBJ then
		return evaluator.eval_array_index_expression(left, index)
	elseif left:type() == object.HASH_OBJ then
		return evaluator.eval_hash_index_expression(left, index)
	else
		return new_error("index operator not supported: %s", left:type())
	end
end

function evaluator.eval_hash_index_expression (hash: object.Object, index: object.Object): object.Object
	local hash_object = hash as object.Hash
	local key = index as object.Hashable
	if key.hash_key == nil then
		return new_error("unusable as hash key: %s", index:type())
	end
	local pair = hash_object.pairs[key:hash_key().value]
	if pair == nil then
		return NULL
	end
	return pair.value
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

function evaluator.eval_hash_literal (node: ast.HashLiteral, env: environment.Environment): object.Object
	local pairs_ = {}
	for kn, vn in pairs(node.pairs) do
		local key = evaluator.eval(kn, env)
		if is_error(key) then
			return key
		end
		if (key as object.Hashable).hash_key == nil then
			return new_error("unusable as hash key: %s", key:type())
		end
		local hash_key = key as object.Hashable
		local value = evaluator.eval(vn, env)
		if is_error(value) then
			return value
		end
		local hashed = hash_key:hash_key()
		pairs_[hashed.value] = { key = key, value = value }
	end
	return object.Hash.new(pairs_)
end

return evaluator
