
local compiler = require("compiler")
local evaluator = require("evaluator")
local lexer = require("lexer.lexer")
local object = require("object")
local parser = require("parser.parser")
local vm = require("vm")
local environment = require("environment")

local engine = { "engine", "vm", "use 'vm' ir 'eval'" }

local input = [[
  let fibonacci = fn(x) {
    if (x == 0) {
      0
    } else {
      if (x == 1) {
        return 1;
      } else {
        fibonacci(x - 1) + fibonacci(x - 2);
      }
    }
  };
  fibonacci(35);
]]

local function main ()
	local l = lexer.new(input)
	local p = parser.new(l)
	local program = p:parse_program()

	do
		local comp = compiler.new()
		local err = comp:compile(program)
		if err ~= nil then
			print(string.format("compiler error: %s", err))
			return
		end
		local machine = vm.new(comp:bytecode())
		local start = os.clock()
		err = machine:run()
		if err ~= nil then
			print(string.format("vm error: %s", err))
			return
		end
		local duration = os.clock() - start
		local result = machine:last_popped_stack_elem()
		print(string.format("engine=vm, result=%s, duration=%.3f\n", result:inspect(), duration))
	end

	do
		local env = environment.new_environment()
		local start = os.clock()
		local result = evaluator.eval(program, env)
		local duration = os.clock() - start
		print(string.format("engine=eval, result=%s, duration=%.3f\n", result:inspect(), duration))
	end
end

main()
