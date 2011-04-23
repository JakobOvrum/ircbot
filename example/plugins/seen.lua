--[[
	Last seen
]]

-- Uncomment to enable
disable()

PLUGIN.Name = "Last seen"
local time,seendb = os.time

function PostLoad()
  if data then
    data.seen = data.seen or {}
    seendb = data.seen
  else
    error("this plugin depends on the data plugin")
  end
end

Hook "OnChat"
{
	function(user, channel)
		seendb[user.nick:lower()] = {"m", channel, time()}
	end
}

Hook "OnJoin"
{
	function(user, channel)
		seendb[user.nick:lower()] = {"j", channel, time()}
	end
}

Command "seen"
{
	expectedArgs = 1;

	function(usernick)
		local u = seendb[usernick:lower()]
		if not u then
			return reply("I haven't seen "..usernick.." around.")
		end
		reply("I last saw %s %s %s around %s", usernick, (u[1] == "m" and "say something in") or "join", u[2], os.date("%c", u[3]))
	end
}