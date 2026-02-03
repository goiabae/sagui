
local record T
	errors: { string:{ string:{string} } }
	current_domain: string

	fatal_fail: function(self, string, ...: any)
	error: function(self, string, ...: any)
	new: function (): T
	set_domain: function (self, string)
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
	table.insert(self.errors[self.current_domain]["FAIL"], string.format(str, ...))
	error()
end

function T:error (str: string, ...)
	table.insert(self.errors[self.current_domain]["ERROR"], string.format(str, ...))
end

function T.new (): T
	return setmetatable({ errors = {} }, { __index = T }) as T
end

function T:set_domain (domain: string)
	self.errors[domain] = self.errors[domain] or {
		["ERROR"] = {},
		["FAIL"] = {},
	}
	self.current_domain = domain
end

local testing <const> = {
	T = T,
	Test = Test,
}

return testing
