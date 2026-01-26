local type ObjectType = string

local INTEGER_OBJ <const> = "INTEGER"
local BOOLEAN_OBJ <const> = "BOOLEAN"
local NULL_OBJ <const> = "NULL"
local RETURN_VALUE_OBJ <const> = "RETURN_VALUE"
local ERROR_OBJ <const> = "ERROR"

local interface Object
	type: function (self): ObjectType
	inspect: function (self): string
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

local object <const> = {
	Object = Object,
	ObjectType = ObjectType,

	Integer = Integer,
	Boolean = Boolean,
	Null = Null,
	ReturnValue = ReturnValue,
	Error = Error,

	INTEGER_OBJ = INTEGER_OBJ,
	BOOLEAN_OBJ = BOOLEAN_OBJ,
	NULL_OBJ = NULL_OBJ,
	RETURN_VALUE_OBJ = RETURN_VALUE_OBJ,
	ERROR_OBJ = ERROR_OBJ,
}

return object
