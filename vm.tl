
local code = require("code")
local compiler = require("compiler")
local object = require("object")

local stack_size <const> = 2048

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
	end
	new: function (compiler.Bytecode): VM
end

function vm.VM:stack_top (): object.Object
	if self.sp == 0 then
		return nil
	end
	return self.stack[self.sp-1+1]
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
		elseif op == code.OpAdd then
			local right = self:pop()
			local left = self:pop()
			local left_value = (left as object.Integer).value
			local right_value = (right as object.Integer).value
			local result = left_value + right_value
			self:push(object.Integer.new(result))
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
