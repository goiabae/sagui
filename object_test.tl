
local testing = require("testing")
local object = require("object")

local function test_string_hash_key (t: testing.T)
	local hello1 = object.String.new("Hello World")
	local hello2 = object.String.new("Hello World")
	local diff1 = object.String.new("My name is johnny")
	local diff2 = object.String.new("My name is johnny")

	if hello1:hash_key() ~= hello2:hash_key() then
		t:error("strings with same content have different hash keys")
	end

	if diff1:hash_key() ~= diff2:hash_key() then
		t:error("strings with same content have different hash keys")
	end

	if hello1:hash_key() == diff1:hash_key() then
		t:error("strings with different content have same hash keys")
	end
end

return {
	domain = "object",
	test_cases = {
		{ name = "string_hash_key", func = test_string_hash_key },
	}
}
