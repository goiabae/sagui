
local record objecti
	type ObjectType = string

	interface Object
		type: function (self): ObjectType
		inspect: function (self): string
	end
end

return objecti
