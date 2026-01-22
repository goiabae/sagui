
local lexer = require("lexer.lexer")
local token = require("token")

local PROMPT <const> = ">> "

local function start (input: FILE, output: FILE)
	while true do
		output:write(PROMPT)
		local line = input:read()
		if not line then
			return
		end
		output:write(string.format("\"%s\"\n", line))
		local l = lexer.new(line)
		local tok = l:next_token()
		while tok and tok.type ~= token.EOF do
			output:write(string.format("{ type = \"%s\", literal = \"%s\" }\n", tok.type, tok.literal))
			tok = l:next_token()
		end
	end
end

local repl <const> = {
	start = start,
}

return repl
