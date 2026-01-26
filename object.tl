
local ast = require("ast.ast")
local environment = require("environment")
local objecti = require("objecti")

local type ObjectType = objecti.ObjectType
local type Object = objecti.Object

local INTEGER_OBJ <const> = "INTEGER"
local BOOLEAN_OBJ <const> = "BOOLEAN"
local NULL_OBJ <const> = "NULL"
local RETURN_VALUE_OBJ <const> = "RETURN_VALUE"
local ERROR_OBJ <const> = "ERROR"
local FUNCTION_OBJ <const> = "FUNCTION"

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

local object <const> = {
	Object = Object,
	ObjectType = ObjectType,

	Integer = Integer,
	Boolean = Boolean,
	Null = Null,
	ReturnValue = ReturnValue,
	Error = Error,
	Function = Function,

	INTEGER_OBJ = INTEGER_OBJ,
	BOOLEAN_OBJ = BOOLEAN_OBJ,
	NULL_OBJ = NULL_OBJ,
	RETURN_VALUE_OBJ = RETURN_VALUE_OBJ,
	ERROR_OBJ = ERROR_OBJ,
	FUNCTION_OBJ = FUNCTION_OBJ,
}

return object
