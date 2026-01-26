
local object = require("objecti")

local record environment
	record Environment
		store: { string:object.Object }
		outer: Environment
		get: function (self, string): (object.Object, boolean)
		set: function (self, string, object.Object): object.Object
	end
	new_environment: function (): Environment
	new_enclosed_environment: function (Environment): Environment
end

function environment.Environment:get (name: string): (object.Object, boolean)
	if self.store[name] ~= nil then
		return self.store[name], true
	elseif self.outer ~= nil then
		return self.outer:get(name)
	else
		return nil, false
	end
end

function environment.Environment:set (name: string, val: object.Object): object.Object
	self.store[name] = val
end

function environment.new_environment (): environment.Environment
	return setmetatable({
		store = {},
		outer = nil,
	}, { __index = environment.Environment })
end

function environment.new_enclosed_environment (outer: environment.Environment): environment.Environment
	local env = environment.new_environment()
	env.outer = outer
	return env
end

return environment
