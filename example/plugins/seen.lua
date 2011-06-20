--[[
	Last seen
]]
Name = "Last seen"

-- comment to enable this plugin
disable()

local time = os.time

function PostLoad()
	if data then
		data.seen = data.seen or {}
	else
		error("this plugin depends on the data plugin")
	end
end

Hook "OnChat"
{
	function(user, channel)
		data.seen[user.nick:lower()] = {"m", channel, time()}
	end
}

Hook "OnJoin"
{
	function(user, channel)
		data.seen[user.nick:lower()] = {"j", channel, time()}
	end
}

Command "seen"
{
	expectedArgs = 1,
	help = "Checks when the last date the specified user was seen.",

	function(usernick)
		local u = data.seen[usernick:lower()]
		if not u then
			return reply("I haven't seen %s around.", usernick)
		end
		reply("I last saw %s %s %s around %s", usernick, (u[1] == "m" and "say something in") or "join", u[2], os.date("%c", u[3]))
	end
}
