
local code = require("code")
local object = require("object")
local ast = require("ast.ast")
local symbol_table = require("symbol_table")

local record compiler
	record Bytecode
		instructions: code.Instructions
		constants: {object.Object}
	end
	record EmittedInstruction
		opcode: code.Opcode
		position: integer
	end
	record CompilationScope
		instructions: code.Instructions
		last_instruction: EmittedInstruction
		previous_instruction: EmittedInstruction
	end
	record Compiler
		instructions: code.Instructions
		constants: {object.Object}
		last_instruction: EmittedInstruction
		previous_instruction: EmittedInstruction
		compile: function (self, ast.Node): string
		bytecode: function (self): Bytecode
		add_constant: function (self, object.Object): integer
		emit: function (self, code.Opcode, ...: integer): integer
		add_instruction: function (self, {code.byte}): integer
		symbol_table: symbol_table.SymbolTable
		scopes: {CompilationScope}
		scope_index: integer
		current_instructions: function (self): code.Instructions
		enter_scope: function (self)
		leave_scope: function (self): code.Instructions
	end
	new: function (): Compiler
	new_with_state: function (symbol_table.SymbolTable, {object.Object}): Compiler
end

function compiler.Compiler:enter_scope ()
	local scope = {
		instructions = code.Instructions.new(),
		last_instruction = nil,
		previous_instruction = nil,
	} as compiler.CompilationScope
	table.insert(self.scopes, scope)
	self.scope_index = self.scope_index + 1
	self.symbol_table = symbol_table.SymbolTable.new_enclosed(self.symbol_table)
end

function compiler.Compiler:leave_scope (): code.Instructions
	local instructions = self:current_instructions()
	table.remove(self.scopes) -- pop last
	self.scope_index = self.scope_index - 1
	self.symbol_table = self.symbol_table.outer
	return instructions
end

function compiler.Compiler:current_instructions (): code.Instructions
	return self.scopes[self.scope_index+1].instructions
end

function compiler.Compiler:replace_instruction (pos: integer, new_instruction: {code.byte})
	for i = 0, #new_instruction - 1 do
		self.scopes[self.scope_index+1].instructions.bytes[pos+i] = new_instruction[i+1]
	end
end

function compiler.Compiler:change_operand(op_pos: integer, operand: integer)
	local op = self:current_instructions().bytes[op_pos] as code.Opcode
	local new_instruction = code.make(op, operand)
	self:replace_instruction(op_pos, new_instruction)
end

function compiler.Compiler:add_instruction (ins: {code.byte}): integer
	local pos_new_instruction = #self:current_instructions().bytes + 1
	self:current_instructions():append_bytes(ins)
	return pos_new_instruction
end

function compiler.Compiler:set_last_instruction (op: code.Opcode, pos: integer)
	local previous = self.scopes[self.scope_index+1].last_instruction
	local last: compiler.EmittedInstruction = { opcode = op, position = pos }
	self.scopes[self.scope_index+1].previous_instruction = previous
	self.scopes[self.scope_index+1].last_instruction = last
end

function compiler.Compiler:emit (op: code.Opcode, ...: integer): integer
	local ins = code.make(op, ...)
	local pos = self:add_instruction(ins)
	self:set_last_instruction(op, pos)
	return pos
end

function compiler.Compiler:last_instruction_is (op: code.Opcode): boolean
	if #self:current_instructions().bytes == 0 then
		return false
	else
		return self.scopes[self.scope_index+1].last_instruction.opcode == op
	end
end

function compiler.Compiler:remove_last_pop ()
	self.scopes[self.scope_index+1].instructions = self.scopes[self.scope_index+1].instructions:drop_bytes(1)
	assert(self.scopes[self.scope_index+1].instructions ~= nil)
	self.scopes[self.scope_index+1].last_instruction = self.scopes[self.scope_index+1].previous_instruction
end

function compiler.Compiler:replace_last_pop_with_return ()
	local last_pos = self.scopes[self.scope_index + 1].last_instruction.position
	self:replace_instruction(last_pos, code.make(code.OpReturnValue))
	self.scopes[self.scope_index + 1].last_instruction.opcode = code.OpReturnValue
end

function compiler.Compiler:compile (node: ast.Node): string
	if node is ast.Program then
		for _, s in ipairs((node as ast.Program).statements) do
			local err = self:compile(s)
			if err ~= nil then
				return err
			end
		end
	elseif node is ast.ExpressionStatement then
		local err = self:compile((node as ast.ExpressionStatement).expression)
		if err ~= nil then
			return err
		end
		self:emit(code.OpPop)
	elseif node is ast.InfixExpression then
		local infix = node as ast.InfixExpression

		if infix.operator == '<' then
			local err = self:compile(infix.right)
			if err ~= nil then
				return err
			end
			err = self:compile(infix.left)
			if err ~= nil then
				return err
			end
			self:emit(code.OpGreaterThan)
			return nil
		end

		local err = self:compile(infix.left)
		if err ~= nil then
			return err
		end
		err = self:compile(infix.right)
		if err ~= nil then
			return err
		end
		if infix.operator == "+" then
			self:emit(code.OpAdd)
		elseif infix.operator == '-' then
			self:emit(code.OpSub)
		elseif infix.operator == '*' then
			self:emit(code.OpMul)
		elseif infix.operator == '/' then
			self:emit(code.OpDiv)
		elseif infix.operator == '>' then
			self:emit(code.OpGreaterThan)
		elseif infix.operator == '==' then
			self:emit(code.OpEqual)
		elseif infix.operator == '!=' then
			self:emit(code.OpNotEqual)
		else
			return string.format("unknown operator %s", infix.operator)
		end
	elseif node is ast.IntegerLiteral then
		local integer = object.Integer.new(node.value)
		self:emit(code.OpConstant, self:add_constant(integer))
	elseif node is ast.Boolean then
		local bool = node as ast.Boolean
		if bool.value then
			self:emit(code.OpTrue)
		else
			self:emit(code.OpFalse)
		end
	elseif node is ast.PrefixExpression then
		local prefix = node as ast.PrefixExpression
		local err = self:compile(prefix.right)
		if err ~= nil then
			return err
		end
		if prefix.operator == "!" then
			self:emit(code.OpBang)
		elseif prefix.operator == "-" then
			self:emit(code.OpMinus)
		else
			return string.format("unknown operator %s", prefix.operator)
		end
	elseif node is ast.IfExpression then
		local if_exp = node as ast.IfExpression
		local err: string
		err = self:compile(if_exp.condition)
		if err ~= nil then
			return err
		end
		local jump_not_truthy_pos = self:emit(code.OpJumpNotTruthy, 9999)
		err = self:compile(if_exp.consequence)
		if err ~= nil then
			return err
		end
		if self:last_instruction_is(code.OpPop) then
			self:remove_last_pop()
		end
		local jump_pos = self:emit(code.OpJump, 9999)
		local after_consequence_pos = #self:current_instructions().bytes
		self:change_operand(jump_not_truthy_pos, after_consequence_pos)
		if if_exp.alternative == nil then
			self:emit(code.OpNull)
		else
			err = self:compile(if_exp.alternative)
			if err ~= nil then
				return err
			end
			if self:last_instruction_is(code.OpPop) then
				self:remove_last_pop()
			end
		end
		local after_alternative_pos = #self:current_instructions().bytes
		self:change_operand(jump_pos, after_alternative_pos)
	elseif node is ast.BlockStatement then
		local blk = node as ast.BlockStatement
		for _, s in ipairs(blk.statements) do
			local err = self:compile(s)
			if err ~= nil then
				return err
			end
		end
	elseif node is ast.LetStatement then
		local let_stmt = node as ast.LetStatement
		local err = self:compile(let_stmt.value)
		if err ~= nil then
			return err
		end
		local symbol = self.symbol_table:define(let_stmt.name.value)
		if symbol.scope == symbol_table.GlobalScope then
			self:emit(code.OpSetGlobal, symbol.index)
		else
			self:emit(code.OpSetLocal, symbol.index)
		end
	elseif node is ast.Identifier then
		local ident = node as ast.Identifier
		local symbol, ok = self.symbol_table:resolve(ident.value)
		if not ok then
			return string.format("undefined variable %s", ident.value)
		end
		if symbol.scope == symbol_table.GlobalScope then
			self:emit(code.OpGetGlobal, symbol.index)
		else
			self:emit(code.OpGetLocal, symbol.index)
		end
	elseif node is ast.StringLiteral then
		local str = object.String.new((node as ast.StringLiteral).value)
		self:emit(code.OpConstant, self:add_constant(str))
	elseif node is ast.ArrayLiteral then
		local arr_lit = node as ast.ArrayLiteral
		for _, el in ipairs(arr_lit.elements) do
			local err = self:compile(el)
			if err ~= nil then
				return err
			end
		end
		self:emit(code.OpArray, #arr_lit.elements)
	elseif node is ast.HashLiteral then
		local hash = node as ast.HashLiteral
		local keys: {ast.Expression} = {}
		for k, _ in pairs(hash.pairs) do
			table.insert(keys, k)
		end
		table.sort(keys, function (ki: ast.Expression, kj: ast.Expression): boolean
			return ki:string() < kj:string()
		end)
		for _, k in ipairs(keys) do
			local err = self:compile(k)
			if err ~= nil then
				return err
			end
			err = self:compile(hash.pairs[k])
			if err ~= nil then
				return err
			end
		end
		self:emit(code.OpHash, hash.pair_count * 2)
	elseif node is ast.IndexExpression then
		local index_exp = node as ast.IndexExpression
		local err = self:compile(index_exp.left)
		if err ~= nil then
			return err
		end
		err = self:compile(index_exp.index)
		if err ~= nil then
			return err
		end
		self:emit(code.OpIndex)
	elseif node is ast.FunctionLiteral then
		local func_lit = node as ast.FunctionLiteral
		self:enter_scope()
		for _, p in ipairs(func_lit.parameters) do
			self.symbol_table:define(p.value)
		end
		local err = self:compile(func_lit.body)
		if err ~= nil then
			return err
		end
		if self:last_instruction_is(code.OpPop) then
			self:replace_last_pop_with_return()
		end
		if not self:last_instruction_is(code.OpReturnValue) then
			self:emit(code.OpReturn)
		end
		local num_locals = self.symbol_table.num_definitions
		local instructions = self:leave_scope()
		local compiled_fn = object.CompiledFunction.new(instructions, num_locals, #func_lit.parameters)
		self:emit(code.OpConstant, self:add_constant(compiled_fn))
	elseif node is ast.ReturnStatement then
		local ret = node as ast.ReturnStatement
		local err = self:compile(ret.return_value)
		if err ~= nil then
			return err
		end
		self:emit(code.OpReturnValue)
	elseif node is ast.CallExpression then
		local call = node as ast.CallExpression
		local err = self:compile(call.func)
		if err ~= nil then
			return err
		end
		for _, a in ipairs(call.arguments) do
			err = self:compile(a)
			if err ~= nil then
				return err
			end
		end
		self:emit(code.OpCall, #call.arguments)
	end
	return nil
end

-- adds to constants and returns index
function compiler.Compiler:add_constant (obj: object.Object): integer
	table.insert(self.constants, obj)
	return #self.constants - 1
end

function compiler.Compiler:bytecode (): compiler.Bytecode
	return {
		instructions = self:current_instructions(),
		constants = self.constants,
	}
end

function compiler.new (): compiler.Compiler
	return setmetatable({
		constants = {},
		symbol_table = symbol_table.SymbolTable.new(),
		scopes = {
			{
				instructions = code.Instructions.new(),
				last_instruction = nil,
				previous_instruction = nil,
			} as compiler.CompilationScope
		},
		scope_index = 0,
	} as compiler.Compiler, { __index = compiler.Compiler })
end

function compiler.new_with_state (s: symbol_table.SymbolTable, constants: {object.Object}): compiler.Compiler
	local c = compiler.new()
	c.symbol_table = s
	c.constants = constants
	return c
end

return compiler
