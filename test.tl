
local testing = require("testing")

local ast_test = require("ast.ast_test")
local lexer_test = require("lexer.lexer_test")
local parser_test = require("parser.parser_test")
local object_test = require("object_test")
local evaluator_test = require("evaluator_test")
local code_test = require("code_test")
local compiler_test = require("compiler_test")
local vm_test = require("vm_test")
local symbol_table_test = require("symbol_table_test")

-- local testing_test = {
-- 	domain = "testing",
-- 	test_cases = {
-- 		{ name = "error", func = function (t: testing.T)
-- 				t:error("hello from error message")
-- 			end
-- 		},
-- 		{ name = "fatal_fail", func = function (t: testing.T)
-- 				t:fatal_fail("hello from fatal message")
-- 			end
-- 		},
-- 	}
-- }

local t = testing.T.new()
local function run_tests (tests: {testing.Test})
	for _, test in ipairs(tests) do
		t:set_domain(test.domain)
		for _, case in ipairs(test.test_cases) do
			case.func(t)
			-- -- FIXME: can't get the error object because teal refuses to typecheck the pcall second return value
			-- local status = pcall(function () case.func(t) end)
			-- if not status then
			-- 	break
			-- end
		end
		local error_count = #t.errors[test.domain]["ERROR"]
		local fail_count = #t.errors[test.domain]["FAIL"]
		if error_count == 0 and fail_count == 0 then
			print(string.format("[%s]: \27[32mOK\27[0m", test.domain))
		else
			print(string.format("[%s]: %d \27[31merrors\27[0m, %d \27[31m\27[1mfails\27[0m\27[22m", test.domain, error_count, fail_count))
			for _, err in ipairs(t.errors[test.domain]["ERROR"]) do
				print("\27[31mERROR\27[0m: " .. err)
			end
			for _, fail in ipairs(t.errors[test.domain]["FAIL"]) do
				print("\27[31m\27[1mFAIL\27[0m\27[22m: " .. fail)
			end
		end
	end
end

run_tests({
	-- testing_test,
	ast_test,
	lexer_test,
	parser_test,
	object_test,
	evaluator_test,
	code_test,
	compiler_test,
	vm_test,
	symbol_table_test,
})
