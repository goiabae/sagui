
local code = require("code")
local testing = require("testing")

local function test_make (t: testing.T)
	local tests: {{code.Opcode, {integer}, {integer}}} = {
		{ code.OpConstant, {65534}, { code.OpConstant, 255, 254 } },
		{ code.OpAdd, {}, { code.OpAdd } },
	}
	for _, tt in ipairs(tests) do
		local instruction = code.make(tt[1], table.unpack(tt[2]))
		if #instruction ~= #tt[3] then
			t:error("instruction has wrong length. want=%d, got=%d", #tt[3], #instruction)
		end
		for i, b in ipairs(tt[3]) do
			if instruction[i] ~= b then
				t:error("wrong byte at pos %d. want=%d, got=%d", i, b, instruction[i])
			end
		end
	end
end

local function test_instruction_string (t: testing.T)
	local instructions = {
		code.make(code.OpAdd),
		code.make(code.OpConstant, 2),
		code.make(code.OpConstant, 65535),
	}
	local expected =
		"0000 OpAdd\n" ..
		"0001 OpConstant 2\n" ..
		"0004 OpConstant 65535\n"
	local concatted = code.Instructions.new()
	for _, ins in ipairs(instructions) do
		for _, i in ipairs(ins) do
			table.insert(concatted.bytes, i)
		end
	end
	if concatted:string() ~= expected then
		t:error("instructions wrongly formatted.\nwant='%s'\ngot='%s'", expected, concatted:string())
	end
end

local function test_read_operands (t: testing.T)
	local tests = {
		{ op = code.OpConstant, operands = { 65535 }, bytes_read = 2 },
	}
	for _, tt in ipairs(tests) do
		local instruction = code.Instructions.new(code.make(tt.op, table.unpack(tt.operands)))
		local def, err = code.lookup(tt.op)
		if err ~= nil then
			t:fatal_fail("definition not found: '%s'\n", err)
		end
		local operands_read, n = code.read_operands(def, instruction:skip_bytes(1))
		if n ~= tt.bytes_read then
			t:fatal_fail("n wrong. want=%d, got=%d", tt.bytes_read, n)
		end
		for i, want in ipairs(tt.operands) do
			if operands_read[i] ~= want then
				t:error("operand wrong. want=%d, got=%d", want, operands_read[i])
			end
		end
	end
end

return {
	domain = "code",
	test_cases = {
		{ name = "make", func = test_make },
		{ name = "instruction_string", func = test_instruction_string },
		{ name = "read_operands", func = test_read_operands },
	},
}
