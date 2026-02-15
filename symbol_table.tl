
local type SymbolScope = string

local GlobalScope <const>: SymbolScope = "GLOBAL"
local LocalScope <const>: SymbolScope = "LOCAL"
local BuiltinScope <const>: SymbolScope = "BUILTIN"
local FreeScope <const>: SymbolScope = "FREE"
local FunctionScope <const>: SymbolScope = "FUNCTION"

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
		--and a.scope == b.scope
		--and a.index == b.index
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
				--and a.scope == b.scope
				--and a.index == b.index
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
	free_symbols: {Symbol}
	new: function (): SymbolTable
	define: function (self, string): Symbol
	resolve: function (self, string): (Symbol, boolean)
	define_builtin: function (self, integer, string): Symbol
	define_free: function (self, Symbol): Symbol
end

function SymbolTable:define_free (original: Symbol): Symbol
	table.insert(self.free_symbols, original)
	local symbol = Symbol.new(original.name, FreeScope, #self.free_symbols - 1)
	self.store[original.name] = symbol
	return symbol
end

function SymbolTable.new (): SymbolTable
	return setmetatable({
		outer = nil,
		store = {},
		num_definitions = 0,
		free_symbols = {},
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
	local obj: Symbol
	local ok: boolean

	obj, ok = self.store[name], self.store[name] ~= nil

	if ok then
		return obj, ok
	else
		if self.outer == nil then
			return nil, false
		else
			obj, ok = self.outer:resolve(name)
			if not ok then
				return obj, ok
			else
				if obj.scope == GlobalScope or obj.scope == BuiltinScope then
					return obj, ok
				else
					local free = self:define_free(obj)
					return free, true
				end
			end
		end
	end

	-- local obj, ok = self.store[name], self.store[name] == nil
	-- if (not ok) and self.outer ~= nil then
	-- 	obj, ok = self.outer:resolve(name)
	-- 	if not ok then
	-- 		return obj, ok
	-- 	end
	-- 	if obj.scope == GlobalScope or obj.scope == BuiltinScope then
	-- 		return obj, ok
	-- 	end
	-- 	local free = self:define_free(obj)
	-- 	return free, true
	-- else
	-- 	return obj, ok
	-- end
end

function SymbolTable:define_builtin (index: integer, name: string): Symbol
	local symbol = Symbol.new(name, BuiltinScope, index)
	self.store[name] = symbol
	return symbol
end

function SymbolTable:define_function_name (name: string): Symbol
	local symbol = Symbol.new(name, FunctionScope, 0)
	self.store[name] = symbol
	return symbol
end

return {
	SymbolScope = SymbolScope,
	GlobalScope = GlobalScope,
	LocalScope = LocalScope,
	BuiltinScope = BuiltinScope,
	Symbol = Symbol,
	SymbolTable = SymbolTable,
	FreeScope = FreeScope,
	FunctionScope = FunctionScope,
}
