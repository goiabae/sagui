local repl = require("repl.repl")

local function main()
	local stdin = io.stdin
	local stdout = io.stdout
	print("Hello, World! This is the Monkey programming language!")
	print("Feel free to type in commands")
	repl.start(stdin, stdout)
end

main()
