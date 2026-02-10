
local type SymbolScope = string

local GlobalScope <const>: SymbolScope = "GLOBAL"
local LocalScope <const>: SymbolScope = "LOCAL"

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
	outer: SymbolTable
	store: { string:Symbol }
	num_definitions: integer
	new: function (): SymbolTable
	define: function (self, string): Symbol
	resolve: function (self, string): (Symbol, boolean)
end

function SymbolTable.new (): SymbolTable
	return setmetatable({
		outer = nil,
		store = {},
		num_definitions = 0,
	}, { __index = SymbolTable })
end

function SymbolTable.new_enclosed (outer: SymbolTable): SymbolTable
	local s = SymbolTable.new()
	s.outer = outer
	return s
end

function SymbolTable:define (name: string): Symbol
	local scope = self.outer == nil and GlobalScope or LocalScope
	local symbol: Symbol = Symbol.new(name, scope, self.num_definitions)
	self.store[name] = symbol
	self.num_definitions = self.num_definitions + 1
	return symbol
end

function SymbolTable:resolve (name: string): (Symbol, boolean)
	local obj = self.store[name]
	if obj == nil and self.outer ~= nil then
		return self.outer:resolve(name)
	else
		return obj, obj ~= nil
	end
end

return {
	SymbolScope = SymbolScope,
	GlobalScope = GlobalScope,
	LocalScope = LocalScope,
	Symbol = Symbol,
	SymbolTable = SymbolTable,
}
