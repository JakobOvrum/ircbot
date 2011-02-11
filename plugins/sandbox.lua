--[[
	Admin only sandbox for testing
]]

--comment out this line to enable
disable()

PLUGIN.Name = "Admin Sandbox"

Command "lua"
{
	admin = true;

	function(code)
		if #code == 0 then
			raise("expected code!")
		end

		if code:match("^=") then
			code = "return " .. code:sub(2)
		end

		local f, err = loadstring(code)
		if not f then
			raise(err)
		end
		
		local results = {pcall(f)}
		if not results[1] then
			raise(results[2])
		end

		local buffer = {}
		for k, result in ipairs(results) do
			table.insert(buffer, tostring(result))
		end

		reply("%s: %s", user.nick, table.concat(buffer, ", "))
	end
}
