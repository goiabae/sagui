
local object = require("object")

local record environment

	record Environment
		store: { string:object.Object }
		get: function (self, string): { object.Object, boolean }
		set: function (self, string, object.Object): object.Object
	end

	new_environment: function (): Environment
end

function environment.Environment:get (name: string): { object.Object, boolean }
	return { self.store[name], self.store[name] ~= nil }
end

function environment.Environment:set (name: string, val: object.Object): object.Object
	self.store[name] = val
end

function environment.new_environment (): environment.Environment
	return setmetatable({
		store = {},
	}, { __index = environment.Environment })
end

return environment
