
local code = require("code")
local compiler = require("compiler")
local object = require("object")

local stack_size <const> = 2048
local globals_size <const> = 65536
local max_frames <const> = 1024

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
	record Frame
		fn: object.CompiledFunction
		ip: integer
		base_pointer: integer
		new_frame: function (object.CompiledFunction, integer): Frame
		instructions: function (self): code.Instructions
		ip_add: function (self, integer)
	end
	record VM
		constants: {object.Object}
		stack: {object.Object}
		globals: {object.Object}
		sp: integer
		frames: {Frame}
		frames_index: integer
		current_frame: function (self): Frame
		push_frame: function (self, Frame)
		pop_frame: function (self): Frame
		stack_top: function (self): object.Object
		run: function (self): string
		push: function (self, object.Object): string
		pop: function (self): object.Object
		last_popped_stack_elem: function (self): object.Object
		execute_binary_operation: function (self, code.Opcode): string
		execute_binary_integer_operation: function (self, code.Opcode, object.Object, object.Object): string
	end
	new: function (compiler.Bytecode): VM
	new_with_globals_store: function (compiler.Bytecode, {object.Object}): VM
	Null: object.Null
end

vm.Null = Null

function vm.VM:current_frame (): vm.Frame
	return self.frames[self.frames_index-1+1]
end

function vm.VM:push_frame (f: vm.Frame)
	if self.frames_index > max_frames then
		error("can't push more frames")
	end
	self.frames[self.frames_index+1] = f
	self.frames_index = self.frames_index + 1
end

function vm.VM:pop_frame (): vm.Frame
	self.frames_index = self.frames_index - 1
	return self.frames[self.frames_index + 1]
end

local frame_mt = {
	__index = vm.Frame
}
function vm.Frame.new_frame (fn: object.CompiledFunction, base_pointer: integer): vm.Frame
	return setmetatable({
		fn = fn,
		ip = -1,
		base_pointer = base_pointer,
	} as vm.Frame, frame_mt)
end

function vm.Frame:instructions (): code.Instructions
	return self.fn.instructions
end

function vm.Frame:ip_add (n: integer)
	self.ip = self.ip + n
end

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

function vm.VM:execute_binary_string_operation (op: code.Opcode, left: object.Object, right: object.Object): string
	if op ~= code.OpAdd then
		return string.format("unknown string operator: %s", op)
	end
	local left_value = (left as object.String).value
	local right_value = (right as object.String).value
	return self:push(object.String.new(left_value .. right_value))
end

function vm.VM:execute_binary_operation (op: code.Opcode): string
	local right = self:pop()
	local left = self:pop()
	local right_type = right:type()
	local left_type = left:type()
	if left_type == object.INTEGER_OBJ and right_type == object.INTEGER_OBJ then
		return self:execute_binary_integer_operation(op, left, right)
	elseif left_type == object.STRING_OBJ and right_type == object.STRING_OBJ then
		return self:execute_binary_string_operation(op, left, right)
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

function vm.VM:build_array (start_index: integer, end_index: integer): object.Object
	local elements = {}
	for i = start_index, end_index-1 do
		elements[i-start_index+1] = self.stack[i+1]
	end
	return object.Array.new(elements)
end

function vm.VM:build_hash (start_index: integer, end_index: integer): (object.Object, string)
	local hashed_pairs = {}
	local pair_count = 0
	for i = start_index, end_index-1, 2 do
		local key = self.stack[i+1]
		local value = self.stack[i+1+1]
		local pair_ = { key = key, value = value }
		if (key as object.Hashable).hash_key == nil then
			return nil, string.format("unusable as hash key: %s", key:type())
		end
		local hash_key = key as object.Hashable
		hashed_pairs[hash_key:hash_key().value] = pair_
		pair_count = pair_count + 1
	end
	return object.Hash.new(hashed_pairs, pair_count), nil
end

function vm.VM:execute_array_index (left: object.Array, index: object.Integer): string
	local array_object = left
	local i = index.value
	local max = #array_object.elements - 1
	if i < 0 or i > max then
		return self:push(Null)
	else
		return self:push(array_object.elements[i+1])
	end
end

function vm.VM:execute_hash_index (left: object.Hash, index: object.Object): string
	local hash_object = left
	if (index as object.Hashable).hash_key == nil then
		return string.format("unusable as hash key: %s", index:type())
	end
	local key = index as object.Hashable
	local pair_ = hash_object.pairs[key:hash_key().value]
	if pair_ == nil then
		return self:push(Null)
	else
		return self:push(pair_.value)
	end
end

function vm.VM:execute_index_expression (left: object.Object, index: object.Object): string
	if left:type() == object.ARRAY_OBJ and index:type() == object.INTEGER_OBJ then
		return self:execute_array_index(left as object.Array, index as object.Integer)
	elseif left:type() == object.HASH_OBJ then
		return self:execute_hash_index(left as object.Hash, index)
	else
		return string.format("index operator not supported: %s", left:type())
	end
end

function vm.VM:call_function (num_args: integer): string
	local a = self.stack[self.sp-1-num_args+1]
	if not (a is object.CompiledFunction) then
		return string.format("calling non-function")
	end
	local fn = a as object.CompiledFunction
	if num_args ~= fn.num_parameters then
		return string.format("wrong number of arguments: want=%d, got=%d", fn.num_parameters, num_args)
	end
	local frame = vm.Frame.new_frame(fn, self.sp-num_args)
	self:push_frame(frame)
	self.sp = frame.base_pointer + fn.num_locals
	return nil
end

function vm.VM:run(): string
	local ip = 0
	while self:current_frame().ip < #self:current_frame():instructions().bytes do
		self:current_frame().ip = self:current_frame().ip + 1
		ip = self:current_frame().ip
		local ins = self:current_frame():instructions()
		local op = ins.bytes[ip+1] as code.Opcode

		if op == code.OpConstant then
			local const_index = code.read_u16(ins.bytes, ip+1+1)
			self:current_frame():ip_add(2)
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
			local pos = code.read_u16(ins.bytes, ip+1+1)
			self:current_frame().ip = pos - 1
		elseif op == code.OpJumpNotTruthy then
			local pos = code.read_u16(ins.bytes, ip+1+1)
			self:current_frame():ip_add(2)
			local condition = self:pop()
			if not is_truthy(condition) then
				self:current_frame().ip = pos - 1
			end
		elseif op == code.OpNull then
			local err = self:push(Null)
			if err ~= nil then
				return err
			end
		elseif op == code.OpGetGlobal then
			local global_index = code.read_u16(ins.bytes, ip+1+1)
			self:current_frame():ip_add(2)
			local err = self:push(self.globals[global_index])
			if err ~= nil then
				return err
			end
		elseif op == code.OpSetGlobal then
			local global_index = code.read_u16(ins.bytes, ip+1+1)
			self:current_frame():ip_add(2)
			if global_index > globals_size then
				error("attempted to index outside of fixed size array `globals'")
			end
			self.globals[global_index] = self:pop()
		elseif op == code.OpArray then
			local num_elements = code.read_u16(ins.bytes, ip+1+1)
			self:current_frame():ip_add(2)
			local array = self:build_array(self.sp - num_elements, self.sp)
			self.sp = self.sp - num_elements
			local err = self:push(array)
			if err ~= nil then
				return err
			end
		elseif op == code.OpHash then
			local num_elements = code.read_u16(ins.bytes, ip+1+1)
			self:current_frame():ip_add(2)
			local hash, err = self:build_hash(self.sp - num_elements, self.sp)
			if err ~= nil then
				return err
			end
			self.sp = self.sp - num_elements
			err = self:push(hash)
			if err ~= nil then
				return err
			end
		elseif op == code.OpIndex then
			local index = self:pop()
			local left = self:pop()
			local err = self:execute_index_expression(left, index)
			if err ~= nil then
				return err
			end
		elseif op == code.OpCall then
			local num_args = code.read_u8(ins.bytes, ip+1+1)
			self:current_frame():ip_add(1)
			local err = self:call_function(num_args)
			if err ~= nil then
				return err
			end
		elseif op == code.OpReturnValue then
			local return_value = self:pop()
			local frame = self:pop_frame()
			self.sp = frame.base_pointer - 1
			local err = self:push(return_value)
			if err ~= nil then
				return err
			end
		elseif op == code.OpReturn then
			local frame = self:pop_frame()
			self.sp = frame.base_pointer - 1
			local err = self:push(Null)
			if err ~= nil then
				return err
			end
		elseif op == code.OpSetLocal then
			local local_index = code.read_u8(ins.bytes, ip+1+1)
			self:current_frame():ip_add(1)
			local frame = self:current_frame()
			-- FIXME: off by one?
			self.stack[frame.base_pointer + local_index + 1] = self:pop()
		elseif op == code.OpGetLocal then
			local local_index = code.read_u8(ins.bytes, ip+1+1)
			self:current_frame():ip_add(1)
			local frame = self:current_frame()
			-- FIXME: off by one?
			local err = self:push(self.stack[frame.base_pointer + local_index + 1])
			if err ~= nil then
				return err
			end
		end
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
	local main_fn = object.CompiledFunction.new(bytecode.instructions, 0, 0)
	local main_frame = vm.Frame.new_frame(main_fn, 0)
	local frames: {vm.Frame} = {}
	frames[0+1] = main_frame
	return setmetatable({
		constants = bytecode.constants,
		stack = {},
		sp = 0,
		globals = {},
		frames = frames,
		frames_index = 1,
	}, { __index = vm.VM })
end

function vm.new_with_globals_store (bytecode: compiler.Bytecode, globals: {object.Object}): vm.VM
	local vm_ = vm.new(bytecode)
	vm_.globals = globals
	return vm_
end

return vm
