
local code = require("code")
local compiler = require("compiler")
local object = require("object")

local stack_size <const> = 2048

local True <const> = object.Boolean.new(true)
local False <const> = object.Boolean.new(false)
local Null <const> = object.Null.new()

local function native_bool_to_boolean_object (input: boolean): object.Boolean
	if input then
		return True
	else
		return False
	end
end

local record vm
	record VM
		constants: {object.Object}
		instructions: code.Instructions
		stack: {object.Object}
		sp: integer
		stack_top: function (self): object.Object
		run: function (self): string
		push: function (self, object.Object): string
		pop: function (self): object.Object
		last_popped_stack_elem: function (self): object.Object
		execute_binary_operation: function (self, code.Opcode): string
		execute_binary_integer_operation: function (self, code.Opcode, object.Object, object.Object): string
	end
	new: function (compiler.Bytecode): VM
	Null: object.Null
end

vm.Null = Null

function vm.VM:last_popped_stack_elem (): object.Object
	return self.stack[self.sp+1]
end

function vm.VM:stack_top (): object.Object
	if self.sp == 0 then
		return nil
	end
	return self.stack[self.sp-1+1]
end

function vm.VM:execute_binary_integer_operation (op: code.Opcode, left: object.Object, right: object.Object): string
	local left_value = (left as object.Integer).value
	local right_value = (right as object.Integer).value
	local result: integer
	if op == code.OpAdd then
		result = left_value + right_value
	elseif op == code.OpSub then
		result = left_value - right_value
	elseif op == code.OpMul then
		result = left_value * right_value
	elseif op == code.OpDiv then
		result = math.floor(left_value / right_value)
	else
		return string.format("unknown integer operator: %d", op)
	end
	return self:push(object.Integer.new(result))
end

function vm.VM:execute_binary_operation (op: code.Opcode): string
	local right = self:pop()
	local left = self:pop()
	local right_type = right:type()
	local left_type = left:type()
	if left_type == object.INTEGER_OBJ and right_type == object.INTEGER_OBJ then
		return self:execute_binary_integer_operation(op, left, right)
	else
		return string.format("unsupported types for binary operation: %s %s", left_type, right_type)
	end
end

function vm.VM:execute_integer_comparison (op: code.Opcode, left: object.Object, right: object.Object): string
	local left_value = (left as object.Integer).value
	local right_value = (right as object.Integer).value
	if op == code.OpEqual then
		return self:push(native_bool_to_boolean_object(right_value == left_value))
	elseif op == code.OpNotEqual then
		return self:push(native_bool_to_boolean_object(right_value ~= left_value))
	elseif op == code.OpGreaterThan then
		return self:push(native_bool_to_boolean_object(right_value < left_value))
	else
		return string.format("unknown operator: %d", op)
	end
end

function vm.VM:execute_comparison (op: code.Opcode): string
	local right = self:pop()
	local left = self:pop()
	if left:type() == object.INTEGER_OBJ and right:type() == object.INTEGER_OBJ then
		return self:execute_integer_comparison(op, left, right)
	else
		if op == code.OpEqual then
			return self:push(native_bool_to_boolean_object(right == left))
		elseif op == code.OpNotEqual then
			return self:push(native_bool_to_boolean_object(right ~= left))
		else
			return string.format("unknown operator: %s (%s %s)", op, left:type(), right:type())
		end
	end
end

function vm.VM:execute_bang_operator (): string
	local operand = self:pop()
	if operand == True then
		return self:push(False)
	elseif operand == False then
		return self:push(True)
	elseif operand == Null then
		return self:push(True)
	else
		return self:push(False)
	end
end

function vm.VM:execute_minus_operator (): string
	local operand = self:pop()
	if operand:type() ~= object.INTEGER_OBJ then
		return string.format("unsupported type for negation: %s", operand:type())
	end
	local value = (operand as object.Integer).value
	return self:push(object.Integer.new(-value))
end

local function is_truthy (obj: object.Object): boolean
	if obj is object.Boolean then
		return (obj as object.Boolean).value
	elseif obj is object.Null then
		return false
	else
		return true
	end
end

function vm.VM:run(): string
	local ip = 0
	while ip < #self.instructions.bytes do
		local op = self.instructions.bytes[ip+1] as code.Opcode
		if op == code.OpConstant then
			local const_index = code.read_u16(self.instructions.bytes, ip+1+1)
			ip = ip + 2
			local err = self:push(self.constants[const_index+1])
			if err ~= nil then
				return err
			end
		elseif op == code.OpAdd or op == code.OpSub or op == code.OpMul or op == code.OpDiv then
			local err = self:execute_binary_operation(op)
			if err ~= nil then
				return err
			end
		elseif op == code.OpPop then
			self:pop()
		elseif op == code.OpTrue then
			local err = self:push(True)
			if err ~= nil then
				return err
			end
		elseif op == code.OpFalse then
			local err = self:push(False)
			if err ~= nil then
				return err
			end
		elseif op == code.OpEqual or op == code.OpNotEqual or op == code.OpGreaterThan then
			local err = self:execute_comparison(op)
			if err ~= nil then
				return err
			end
		elseif op == code.OpBang then
			local err = self:execute_bang_operator()
			if err ~= nil then
				return err
			end
		elseif op == code.OpMinus then
			local err = self:execute_minus_operator()
			if err ~= nil then
				return err
			end
		elseif op == code.OpJump then
			local pos = code.read_u16(self.instructions.bytes, ip+1+1)
			ip = pos - 1
		elseif op == code.OpJumpNotTruthy then
			local pos = code.read_u16(self.instructions.bytes, ip+1+1)
			ip = ip + 2
			local condition = self:pop()
			if not is_truthy(condition) then
				ip = pos - 1
			end
		elseif op == code.OpNull then
			local err = self:push(Null)
			if err ~= nil then
				return err
			end
		end
		ip = ip + 1
	end
	return nil
end

function vm.VM:push (o: object.Object): string
	if self.sp >= stack_size then
		return "stack overflow"
	end
	self.stack[self.sp+1] = o
	self.sp = self.sp + 1
	return nil
end

function vm.VM:pop (): object.Object
	local o = self.stack[self.sp-1+1]
	self.sp = self.sp - 1
	return o
end

function vm.new (bytecode: compiler.Bytecode): vm.VM
	return setmetatable({
		instructions = bytecode.instructions,
		constants = bytecode.constants,
		stack = {},
		sp = 0,
	}, { __index = vm.VM })
end

return vm
