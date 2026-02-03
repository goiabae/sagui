
local record code
	type byte = integer
	type Opcode = byte

	record Definition
		name: string
		operand_widths: {integer}
	end

	record Instructions
		bytes: {byte}
		string: function (self): string
		byte_string: function (self): string
		new: function (?{byte}): Instructions
		skip_bytes: function (self, integer): Instructions
		fmt_instruction: function (self, Definition, {integer}): string
		append_bytes: function (self, {byte})
	end

	OpConstant: Opcode
	OpAdd: Opcode
	OpPop: Opcode
	OpSub: Opcode
	OpMul: Opcode
	OpDiv: Opcode
	OpTrue: Opcode
	OpFalse: Opcode
	OpEqual: Opcode
	OpNotEqual: Opcode
	OpGreaterThan: Opcode
	OpMinus: Opcode
	OpBang: Opcode

	definitions: { Opcode:Definition }
	lookup: function (byte): (Definition, string)
	make: function (Opcode, ...: integer): {byte}
	read_operands: function (Definition, Instructions): ({integer}, integer)
	read_u16: function ({byte}, integer): integer
end

code.OpConstant = 0
code.OpAdd = 1
code.OpPop = 2
code.OpSub = 3
code.OpMul = 4
code.OpDiv = 5
code.OpTrue = 6
code.OpFalse = 7
code.OpEqual = 8
code.OpNotEqual = 9
code.OpGreaterThan = 10
code.OpMinus = 11
code.OpBang = 12
code.definitions = {
	[code.OpConstant] = { name = "OpConstant", operand_widths = {2} },
	[code.OpAdd] = { name = "OpAdd", operand_widths = {} },
	[code.OpPop] = { name = "OpPop", operand_widths = {} },
	[code.OpSub] = { name = "OpSub", operand_widths = {} },
	[code.OpMul] = { name = "OpMul", operand_widths = {} },
	[code.OpDiv] = { name = "OpDiv", operand_widths = {} },
	[code.OpTrue] = { name = "OpTrue", operand_widths = {} },
	[code.OpFalse] = { name = "OpFalse", operand_widths = {} },
	[code.OpEqual] = { name = "OpEqual", operand_widths = {} },
	[code.OpNotEqual] = { name = "OpNotequal", operand_widths = {} },
	[code.OpGreaterThan] = { name = "OpGreaterThan", operand_widths = {} },
	[code.OpMinus] = { name = "OpMinus", operand_widths = {} },
	[code.OpBang] = { name = "OpBang", operand_widths = {} },
}

function code.Instructions:append_bytes (bytes: {code.byte})
	for _, b in ipairs(bytes) do
		table.insert(self.bytes, b)
	end
end

function code.Instructions:byte_string (): string
	local words = {}
	for i = 1, #self.bytes do
		table.insert(words, string.format("%02x", self.bytes[i]))
	end
	return table.concat(words, " ")
	-- local out = ""
	-- for i = 1, #self.bytes do
	-- 	out = out .. string.pack("B", self.bytes[i])
	-- end
	-- return out
end

function code.Instructions:string (): string
	local out = ""
	local i = 0
	while i < #self.bytes do
		local def, err = code.lookup(self.bytes[i+1])
		if err ~= nil then
			out = out .. string.format("ERROR: %s\n", err)
		else
			local operands, read = code.read_operands(def, self:skip_bytes(i+1))
			out = out .. string.format("%04d %s\n", i, self:fmt_instruction(def, operands))
			i = i + 1 + read
		end
	end
	return out
end

function code.Instructions.new (bytes?: {code.byte}): code.Instructions
	return setmetatable({
		bytes = bytes or {},
	}, { __index = code.Instructions })
end

function code.Instructions:skip_bytes (n: integer): code.Instructions
	local new_bytes = {}
	for i = 1+n, #self.bytes do
		table.insert(new_bytes, self.bytes[i])
	end
	return code.Instructions.new(new_bytes)
end

function code.lookup (op: code.byte): (code.Definition, string)
	if code.definitions[op] ~= nil then
		return code.definitions[op], nil
	else
		return nil, string.format("opcode %d undefined", op)
	end
end

local function put_big_endian_binary_u16(bytes: {code.byte}, offset: integer, o: integer)
	local sl = string.pack("H", o)
	bytes[offset] = string.unpack("B", sl:sub(2, 2)) as code.byte
	bytes[offset+1] = string.unpack("B", sl:sub(1, 1)) as code.byte
end

function code.make (op: code.Opcode, ...: integer): {code.byte}
	local operands = { ... }
	if not code.definitions[op] then
		return {}
	end
	local def = code.definitions[op]
	local instruction_len = 1
	for _, w in ipairs(def.operand_widths) do
		instruction_len = instruction_len + w
	end
	local instruction = {}
	instruction[1] = op
	local offset = 2
	for i,o in ipairs(operands) do
		local width = def.operand_widths[i]
		if width == 2 then
			put_big_endian_binary_u16(instruction, offset, o)
		end
		offset = offset + width
	end
	return instruction
end

function code.read_u16 (bytes: {code.byte}, offset: integer): integer
	if bytes[offset] == nil then
		error(string.format("bytes (len %d) with offset %d was nil", #bytes, offset))
	end
	local v, _ = string.unpack("H", string.pack("BB", bytes[offset+1], bytes[offset]))
	return v
end

function code.read_operands (def: code.Definition, ins: code.Instructions): ({integer}, integer)
	local operands = {}
	local offset = 0
	for i, width in ipairs(def.operand_widths) do
		if width == 2 then
			operands[i] = code.read_u16(ins.bytes, offset+1)
		end
		offset = offset + width
	end
	return operands, offset
end

function code.Instructions:fmt_instruction (def: code.Definition, operands: {integer}): string
	local operand_count = #def.operand_widths
	if #operands ~= operand_count then
		return string.format("ERROR: operand len %d does not match defined %d\n", #operands, operand_count)
	end
	if operand_count == 0 then
		return def.name
	elseif operand_count == 1 then
		return string.format("%s %d", def.name, operands[1])
	end
	return string.format("ERROR: unhandled operand_count for %s\n", def.name)
end

return code
