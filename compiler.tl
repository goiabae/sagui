
local code = require("code")
local object = require("object")
local ast = require("ast.ast")

local record compiler
	record Bytecode
		instructions: code.Instructions
		constants: {object.Object}
	end
	record Compiler
		instructions: code.Instructions
		constants: {object.Object}
		compile: function (self, ast.Node): string
		bytecode: function (self): Bytecode
		add_constant: function (self, object.Object): integer
		emit: function (self, code.Opcode, ...: integer): integer
		add_instruction: function (self, {code.byte}): integer
	end
	new: function (): Compiler
end

function compiler.Compiler:add_instruction (ins: {code.byte}): integer
	local pos_new_instruction = #self.instructions.bytes + 1
	self.instructions:append_bytes(ins)
	return pos_new_instruction
end

function compiler.Compiler:emit (op: code.Opcode, ...: integer): integer
	local ins = code.make(op, ...)
	local pos = self:add_instruction(ins)
	return pos
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
	}, { __index = compiler.Compiler })
end

return compiler
