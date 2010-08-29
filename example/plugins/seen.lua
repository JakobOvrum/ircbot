--[[
	Last seen
]]

PLUGIN.Name = "Last seen"
local time,seendb = os.time,false

Hook "OnChat"
{
	function(user, channel)
		seendb[user.nick] = {"m", channel, time()}
	end
}

Hook "OnJoin"
{
	function(user, channel)
		seendb[user.nick] = {"j", channel, time()}
	end
}

Command "seen"
{
	expectedArgs = 1;

	function(usernick)
		local u = seendb[usernick]
		if not u then
			return reply("I haven't seen "..usernick.." around.")
		end
		reply(("I last saw %s %s %s around %s"):format(usernick, (u[1] == "m" and "say something in") or "join", u[2], os.date("%c", u[3])))
	end
}

Hook "Think"
{
	function()
		if not seendb then
			if data then
				data.seen = data.seen or {}
				seendb = data.seen
			end
		end
	end
}