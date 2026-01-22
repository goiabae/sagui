
local record T
	fatal_fail: function(string, ...: any)
	error: function(string, ...: any)
	fail_now: function()
end

local function new (): T
	return {
		fatal_fail = function (str: string, ...)
			print("FATAL: " .. string.format(str, ...))
			error()
		end,
		error = function (str: string, ...)
			print("ERROR: " .. string.format(str, ...))
		end,
		fail_now = function()
			error()
		end,
	}
end

local testing <const> = {
	T = T,
	new = new,
}

return testing
