
local lexer = require("lexer.lexer")
local parser = require("parser.parser")
local evaluator = require("evaluator")
local environment = require("environment")
local compiler = require("compiler")
local vm = require("vm")

local PROMPT <const> = ">> "

local MONKEY_FACE <const> = [[
            __,__
   .--.  .-"     "-.  .--.
  / .. \/  .-. .-.  \/ .. \
 | |  '|  /   Y   \  |'  | |
 | \   \  \ 0 | 0 /  /   / |
  \ '- ,\.-"""""""-./, -' /
   ''-' /_   ^ ^   _\ '-''
       |  \._   _./  |
       \   \ '~' /   /
        '._ '-=-' _.'
           '-----'
]]

local function print_parser_errors (output: FILE, errors: {string})
	output:write(MONKEY_FACE)
	output:write("Woops! We ran into some monkey business here!\n")
	output:write(" parser errors:\n")
	for _, msg in ipairs(errors) do
		output:write("\t" .. msg .. "\n")
	end
end

local function start (input: FILE, output: FILE)
	local env = environment.new_environment()
	while true do
		output:write(PROMPT)
		local line = input:read()
		if not line then
			return
		end
		output:write(string.format("\"%s\"\n", line))
		local l = lexer.new(line)
		local p = parser.new(l)
		local program = p:parse_program()
		if #p:get_errors() ~= 0 then
			print_parser_errors(output, p:get_errors())
		else
			output:write("PARSED: " .. program:string() .. "\n")
			local comp = compiler.new()
			local err = comp:compile(program)
			if err ~= nil then
				output:write(string.format("Woops! Compilation failed:\n %s\n", err))
			else
				local machine = vm.new(comp:bytecode())
				local err = machine:run()
				if err ~= nil then
					output:write(string.format("Woops! Executing bytecode failed:\n %s\n", err))
				else
					local last_popped = machine:last_popped_stack_elem()
					output:write(last_popped:inspect() .. "\n")
				end
			end
			-- local evaluated = evaluator.eval(program, env)
			-- if evaluated ~= nil then
			-- 	output:write(evaluated:inspect() .. "\n")
			-- end
		end
	end
end

local repl <const> = {
	start = start,
}

return repl
