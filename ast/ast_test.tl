
local ast = require("ast.ast")
local token = require("token")
local testing = require("testing")

local function test_string (t: testing.T)
	local program = ast.Program.new({
		ast.LetStatement.new(
			{ type = token.LET, literal = "let" },
			ast.Identifier.new(
				{ type = token.IDENT, literal = "myVar" },
				"myVar"
			),
			ast.Identifier.new(
				{ type = token.IDENT, literal = "anotherVar" },
				"anotherVar"
			)
		)
	})
	if program:string() ~= "let myVar = anotherVar;" then
		t:error("program:string() wrong. got='%s'", program:string())
	end
end

return {
	domain = "ast",
	test_cases = {
		{ name = "string", func = test_string },
	}
}
