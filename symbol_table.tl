
local type SymbolScope = string

local GlobalScope <const>: SymbolScope = "GLOBAL"

local record Symbol
	name: string
	scope: SymbolScope
	index: integer
	__tostring: function (self): string
	__eq: function (self, Symbol): boolean
	new: function (string, SymbolScope, integer): Symbol
end

function Symbol:__tostring (): string
	return string.format("{ name = %s, scope = %s, index = %d }", self.name, self.scope as string, self.index)
end

function Symbol.__eq (a: Symbol, b: Symbol): boolean
	return a.name == b.name
		and a.scope == b.scope
		and a.index == b.index
end

function Symbol.new (name: string, scope: SymbolScope, index: integer): Symbol
	return setmetatable({
		name = name,
		scope = scope,
		index = index,
	}, {
		__index = Symbol,
		__eq = function (a: Symbol, b: Symbol): boolean
			return a.name == b.name
				and a.scope == b.scope
				and a.index == b.index
		end,
		__tostring = function (self: Symbol): string
			return string.format("{ name = %s, scope = %s, index = %d }", self.name, self.scope as string, self.index)
		end,
	})
end

local record SymbolTable
	store: { string:Symbol }
	num_definitions: integer
	new: function (): SymbolTable
	define: function (self, string): Symbol
	resolve: function (self, string): (Symbol, boolean)
end

function SymbolTable.new (): SymbolTable
	return setmetatable({
		store = {},
		num_definitions = 0,
	}, { __index = SymbolTable })
end

function SymbolTable:define (name: string): Symbol
	local symbol: Symbol = Symbol.new(name, GlobalScope, self.num_definitions)
	self.store[name] = symbol
	self.num_definitions = self.num_definitions + 1
	return symbol
end

function SymbolTable:resolve (name: string): (Symbol, boolean)
	local obj = self.store[name]
	return obj, obj ~= nil
end

return {
	SymbolScope = SymbolScope,
	GlobalScope = GlobalScope,
	Symbol = Symbol,
	SymbolTable = SymbolTable,
}
