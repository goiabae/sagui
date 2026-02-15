
local ast = require("ast.ast")
local environment = require("environment")
local objecti = require("objecti")
local code = require("code")
local symbol_table = require("symbol_table")

local type ObjectType = objecti.ObjectType
local type Object = objecti.Object

local INTEGER_OBJ <const> = "INTEGER"
local BOOLEAN_OBJ <const> = "BOOLEAN"
local NULL_OBJ <const> = "NULL"
local RETURN_VALUE_OBJ <const> = "RETURN_VALUE"
local ERROR_OBJ <const> = "ERROR"
local FUNCTION_OBJ <const> = "FUNCTION"
local STRING_OBJ <const> = "STRING"
local BUILTIN_OBJ <const> = "BUILTIN"
local ARRAY_OBJ <const> = "ARRAY"
local HASH_OBJ <const> = "HASH"
local COMPILED_FUNCTION_OBJ <const> = "COMPILED_FUNCTION_OBJ"
local CLOSURE_OBJ <const> = "CLOSURE"

local type BuiltinFunction = function (...: Object): Object

local record HashKey
	type: ObjectType
	value: integer
end

function HashKey.new (type_: ObjectType, value: integer): HashKey
	return setmetatable({
		type = type_,
		value = value,
	}, {
		__index = HashKey,
		__eq = function (a: HashKey, b: HashKey): boolean
			return a.value == b.value
		end
	})
end

local record Integer is Object
	where self.kind == "INTEGER"
	kind: string
	value: integer
end

function Integer:inspect (): string
	return string.format("%d", self.value)
end

function Integer:type (): ObjectType
	return INTEGER_OBJ
end

function Integer.new (value: integer): Integer
	return setmetatable({
		kind = INTEGER_OBJ,
		value = value,
	}, { __index = Integer })
end

function Integer:hash_key (): HashKey
	return HashKey.new(self:type(), self.value)
end

local record Boolean is Object
	where self.kind == "BOOLEAN"
	kind: string
	value: boolean
end

function Boolean:inspect (): string
	return self.value and "true" or "false"
end

function Boolean:type (): ObjectType
	return BOOLEAN_OBJ
end

function Boolean.new (value: boolean): Boolean
	return setmetatable({
		kind = BOOLEAN_OBJ,
		value = value,
	}, { __index = Boolean })
end

function Boolean:hash_key (): HashKey
	local value: integer
	if self.value then
		value = 1
	else
		value = 0
	end
	return HashKey.new(self:type(), value)
end

local record Null is Object
	where self.kind == "NULL"
	kind: string
end
function Null:inspect (): string return "null" end
function Null:type (): ObjectType return NULL_OBJ end
function Null.new (): Null return setmetatable({ kind = NULL_OBJ }, { __index = Null }) end

local record ReturnValue is Object
	where self.kind == "RETURN_VALUE"
	kind: string
	value: Object
end

function ReturnValue:inspect (): string return self.value:inspect() end
function ReturnValue:type (): ObjectType return RETURN_VALUE_OBJ end
function ReturnValue.new (value: Object): ReturnValue
	return setmetatable({
		kind = RETURN_VALUE_OBJ,
		value = value,
	}, { __index = ReturnValue })
end

local record Error is Object
	where self.kind == "ERROR"
	kind: string
	message: string
end

function Error:inspect (): string return "ERROR: " .. self.message end
function Error:type (): ObjectType return ERROR_OBJ end
function Error.new (message: string): Error
	return setmetatable({
		kind = ERROR_OBJ,
		message = message,
	}, { __index = Error })
end

local record Function is Object
	where self.kind == "FUNCTION"
	kind: string
	parameters: {ast.Identifier}
	body: ast.BlockStatement
	env: environment.Environment
end

function Function:type (): ObjectType return FUNCTION_OBJ end
function Function:inspect (): string
	local params = {}
	for _, p in ipairs(self.parameters) do
		table.insert(params, p:string())
	end
	return "fn" .. "(" .. table.concat(params, ", ") .. ") {\n" .. self.body:string() .. "\n}"
end
function Function.new (parameters: {ast.Identifier}, body: ast.BlockStatement, env: environment.Environment): Function
	return setmetatable({
		kind = FUNCTION_OBJ,
		parameters = parameters,
		body = body,
		env = env,
	}, { __index = Function })
end

local record String is Object
	where self.kind == "STRING"
	kind: string
	value: string
end

function String:type (): ObjectType return STRING_OBJ end
function String:inspect (): string return self.value end
function String.new (value: string): String
	return setmetatable({
		kind = STRING_OBJ,
		value = value,
	}, { __index = String })
end

local function hash (str: string): integer
	local h = 5381
	for c in string.gmatch(str, ".") do
		h = math.fmod(((h << 5) + h) + string.byte(c), 2147483648)
	end
	return h
end

function String:hash_key (): HashKey
	local h = hash(self.value)
	return HashKey.new(self:type(), h)
end

local record Builtin is Object
	where self.kind == "BUILTIN"
	kind: string
	fn: BuiltinFunction
end

function Builtin:type (): ObjectType return BUILTIN_OBJ end
function Builtin:inspect (): string return "builtin_function" end
function Builtin.new (fn: BuiltinFunction): Builtin
	return setmetatable({
		kind = BUILTIN_OBJ,
		fn = fn,
	}, { __index = Builtin })
end

local record Array is Object
	where self.kind == "ARRAY"
	kind: string
	elements: {Object}
end

function Array:type (): ObjectType return ARRAY_OBJ end
function Array:inspect (): string
	local elements = {}
	for _, e in ipairs(self.elements) do
		table.insert(elements, e:inspect())
	end
	return "[" .. table.concat(elements, ", ") .. "]"
end
function Array.new (elements: {Object}): Array
	return setmetatable({
		kind = ARRAY_OBJ,
		elements = elements,
	}, { __index = Array })
end

local record HashPair
	key: Object
	value: Object
end

local record Hash is Object
	where self.kind == "HASH"
	kind: string
	pairs: { integer:HashPair }
	pair_count: integer
end

function Hash:type (): ObjectType return HASH_OBJ end
function Hash:inspect (): string
	local pairs_ = {}
	for _, pair_ in pairs(self.pairs) do
		table.insert(pairs_, string.format("%s: %s", pair_.key:inspect(), pair_.value:inspect()))
	end
	return "{" .. table.concat(pairs_, ", ") .. "}"
end
function Hash.new (pairs_: { integer:HashPair }, pair_count: integer): Hash
	return setmetatable({
		kind = HASH_OBJ,
		pairs = pairs_,
		pair_count = pair_count,
	}, { __index = Hash })
end

local interface Hashable
	where self.hash_key ~= nil
	hash_key: function (self): HashKey
end

local record CompiledFunction is Object
	where self.kind == "COMPILED_FUNCTION_OBJ"
	kind: string
	instructions: code.Instructions
	num_locals: integer
	num_parameters: integer
end

function CompiledFunction:type (): ObjectType return COMPILED_FUNCTION_OBJ end
function CompiledFunction:inspect (): string
	return string.format("CompiledFunction")
end
function CompiledFunction.new (instructions: code.Instructions, num_locals: integer, num_parameters: integer): CompiledFunction
	return setmetatable({
		kind = COMPILED_FUNCTION_OBJ,
		instructions = instructions,
		num_locals = num_locals,
		num_parameters = num_parameters,
	}, { __index = CompiledFunction })
end

local record Closure is Object
	where self.kind == "CLOSURE"
	kind: string
	fn: CompiledFunction
	free: {Object}
end

function Closure:type (): ObjectType return CLOSURE_OBJ end
function Closure:inspect (): string
	return string.format("Closure")
end
function Closure.new (fn: CompiledFunction, free: {Object}): Closure
	return setmetatable({
		kind = CLOSURE_OBJ,
		fn = fn,
		free = free,
	}, { __index = Closure })
end


local function new_error (format: string, ...): Error
	return Error.new(string.format(format, ...))
end

local NULL <const> = Null.new()
local TRUE <const> = Boolean.new(true)
local FALSE <const> = Boolean.new(false)

local builtins: {{string, Builtin}} = {
	{
		"len",
		Builtin.new(function (...: Object): Object
			-- print("executing len")
			local args = { ... }
			if #args ~= 1 then
				return new_error("wrong number of arguments. got=%d, want=1", #args)
			end
			local fst_arg = args[1]
			if fst_arg is String then
				return Integer.new(#(fst_arg as String).value)
			elseif fst_arg is Array then
				return Integer.new(#(fst_arg as Array).elements)
			else
				return new_error("argument to 'len' not supported, got %s", args[1]:type())
			end
		end)
	},
	{
		"first",
		Builtin.new(function (...: Object): Object
			-- print("executing first")
			local args = { ... }
			if #args ~= 1 then
				return new_error("wrong number of arguments. got=%d, want=1", #args)
			end
			if args[1]:type() ~= ARRAY_OBJ then
				return new_error("argument to 'first' must be ARRAY, got %s", args[1]:type())
			end
			local arr = args[1] as Array
			if #arr.elements > 0 then
				return arr.elements[1]
			else
				return NULL
			end
		end)
	},
	{
		"last",
		Builtin.new(function (...: Object): Object
			-- print("executing last")
			local args = { ... }
			if #args ~= 1 then
				return new_error("wrong number of arguments. got=%d, want=1", #args)
			end
			if args[1]:type() ~= ARRAY_OBJ then
				return new_error("argument to 'last' must be ARRAY, got %s", args[1]:type())
			end
			local arr = args[1] as Array
			local length = #arr.elements
			if length > 0 then
				return arr.elements[length]
			else
				return NULL
			end
		end)
	},
	{
		"rest",
		Builtin.new(function (...: Object): Object
			--print("executing rest")
			local args = { ... }
			if #args ~= 1 then
				return new_error("wrong number of arguments. got=%d, want=1", #args)
			end
			if args[1]:type() ~= ARRAY_OBJ then
				return new_error("argument to 'rest' must be ARRAY, got %s", args[1]:type())
			end
			local arr = args[1] as Array
			local length = #arr.elements
			if length > 0 then
				local new_elements = {}
				for i = 2, length do
					table.insert(new_elements, arr.elements[i])
				end
				return Array.new(new_elements)
			else
				return NULL
			end
		end)
	},
	{
		"puts",
		Builtin.new(function (...: Object): Object
			--print("executing puts")
			local args = { ... }
			for i = 1, #args do
				local a = args[i]
				print(a:inspect())
			end
			return NULL
		end)
	},
	{
		"push",
		Builtin.new(function (...: Object): Object
			--print("executing push")
			local args = { ... }
			if #args ~= 2 then
				return new_error("wrong number of arguments. got=%d, want=2", #args)
			end
			if args[1]:type() ~= ARRAY_OBJ then
				return new_error("argument to 'push' must be ARRAY, got %s", args[1]:type())
			end
			local arr = args[1] as Array
			local length = #arr.elements
			local new_elements = {}
			for i = 1, length do
				table.insert(new_elements, arr.elements[i])
			end
			table.insert(new_elements, args[2])
			symbol_table.Symbol.new("a", symbol_table.BuiltinScope, 0)
			return Array.new(new_elements)
		end)
	},
}

local function get_builtin_by_name (name: string): Builtin | nil
	for _, def in ipairs(builtins) do
		if def[1] == name then
			return def[2]
		end
	end
	return nil
end

local object <const> = {
	Object = Object,
	ObjectType = ObjectType,

	Integer = Integer,
	Boolean = Boolean,
	Null = Null,
	ReturnValue = ReturnValue,
	Error = Error,
	Function = Function,
	String = String,
	Builtin = Builtin,
	Array = Array,
	Hash = Hash,
	HashKey = HashKey,
	Hashable = Hashable,
	CompiledFunction = CompiledFunction,
	Closure = Closure,

	INTEGER_OBJ = INTEGER_OBJ,
	BOOLEAN_OBJ = BOOLEAN_OBJ,
	NULL_OBJ = NULL_OBJ,
	RETURN_VALUE_OBJ = RETURN_VALUE_OBJ,
	ERROR_OBJ = ERROR_OBJ,
	FUNCTION_OBJ = FUNCTION_OBJ,
	STRING_OBJ = STRING_OBJ,
	BUILTIN_OBJ = BUILTIN_OBJ,
	ARRAY_OBJ = ARRAY_OBJ,
	HASH_OBJ = HASH_OBJ,
	COMPILED_FUNCTION_OBJ = COMPILED_FUNCTION_OBJ,
	CLOSURE_OBJ = CLOSURE_OBJ,

	builtins = builtins,
	get_builtin_by_name = get_builtin_by_name,
	NULL = NULL,
	TRUE = TRUE,
	FALSE = FALSE,
}

return object
