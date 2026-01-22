
local record T
	 fatal_fail: function(string, ...: any)
end

local function new (): T
	return {
		fatal_fail = function (str: string, ...)
			print(string.format(str, ...))
		end
	}
end

local testing <const> = {
	T = T,
	new = new,
}

return testing
