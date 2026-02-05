
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
	end
	new: function (): Compiler
	new_with_state: function (symbol_table.SymbolTable, {object.Object}): Compiler
end

function compiler.Compiler:replace_instruction (pos: integer, new_instruction: {code.byte})
	for i = 0, #new_instruction - 1 do
		self.instructions.bytes[pos+i] = new_instruction[i+1]
	end
end

function compiler.Compiler:change_operand(op_pos: integer, operand: integer)
	local op = self.instructions.bytes[op_pos] as code.Opcode
	local new_instruction = code.make(op, operand)
	self:replace_instruction(op_pos, new_instruction)
end

function compiler.Compiler:add_instruction (ins: {code.byte}): integer
	local pos_new_instruction = #self.instructions.bytes + 1
	self.instructions:append_bytes(ins)
	return pos_new_instruction
end

function compiler.Compiler:set_last_instruction (op: code.Opcode, pos: integer)
	local previous = self.last_instruction
	local last: compiler.EmittedInstruction = { opcode = op, position = pos }
	self.previous_instruction = previous
	self.last_instruction = last
end

function compiler.Compiler:emit (op: code.Opcode, ...: integer): integer
	local ins = code.make(op, ...)
	local pos = self:add_instruction(ins)
	self:set_last_instruction(op, pos)
	return pos
end

function compiler.Compiler:last_instruction_is_pop (): boolean
	return self.last_instruction.opcode == code.OpPop
end

function compiler.Compiler:remove_last_pop ()
	self.instructions = self.instructions:drop_bytes(1)
	assert(self.instructions ~= nil)
	self.last_instruction = self.previous_instruction
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
		if self:last_instruction_is_pop() then
			self:remove_last_pop()
		end
		local jump_pos = self:emit(code.OpJump, 9999)
		local after_consequence_pos = #self.instructions.bytes
		self:change_operand(jump_not_truthy_pos, after_consequence_pos)
		if if_exp.alternative == nil then
			self:emit(code.OpNull)
		else
			err = self:compile(if_exp.alternative)
			if err ~= nil then
				return err
			end
			if self:last_instruction_is_pop() then
				self:remove_last_pop()
			end
		end
		local after_alternative_pos = #self.instructions.bytes
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
		self:emit(code.OpSetGlobal, symbol.index)
	elseif node is ast.Identifier then
		local ident = node as ast.Identifier
		local symbol, ok = self.symbol_table:resolve(ident.value)
		if not ok then
			return string.format("undefined variable %s", ident.value)
		end
		self:emit(code.OpGetGlobal, symbol.index)
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
		instructions = self.instructions,
		constants = self.constants,
	}
end

function compiler.new (): compiler.Compiler
	return setmetatable({
		instructions = code.Instructions.new(),
		constants = {},
		last_instruction = {},
		previous_instruction = {},
		symbol_table = symbol_table.SymbolTable.new(),
	}, { __index = compiler.Compiler })
end

function compiler.new_with_state (s: symbol_table.SymbolTable, constants: {object.Object}): compiler.Compiler
	return setmetatable({
		instructions = code.Instructions.new(),
		constants = constants,
		last_instruction = {},
		previous_instruction = {},
		symbol_table = s,
	}, { __index = compiler.Compiler })
end

return compiler
