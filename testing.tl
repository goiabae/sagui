
local record Error
	test_name: string
	message: string
end

local record T
	errors: { string:{ string:{Error} } }
	current_domain: string
	current_test: string

	fatal_fail: function(self, string, ...: any)
	error: function(self, string, ...: any)
	new: function (): T
	set_domain: function (self, string)
	set_test: function (self, string)
end

local record Test
	record TestCase
		name: string
		func: function (T)
	end
	domain: string
	test_cases: {TestCase}
end

function T:fatal_fail (str: string, ...)
	local err = { test_name = self.current_test, message = string.format(str, ...) }
	table.insert(self.errors[self.current_domain]["FAIL"], err)
	error()
end

function T:error (str: string, ...)
	local err = { test_name = self.current_test, message = string.format(str, ...) }
	table.insert(self.errors[self.current_domain]["ERROR"], err)
end

function T.new (): T
	return setmetatable({
		errors = {},
		current_domain = nil,
		current_test = nil,
	}, { __index = T }) as T
end

function T:set_domain (domain: string)
	self.errors[domain] = self.errors[domain] or {
		["ERROR"] = {},
		["FAIL"] = {},
	}
	self.current_domain = domain
end

function T:set_test (test_name: string)
	self.current_test = test_name
end

local testing <const> = {
	T = T,
	Test = Test,
}

return testing
