--[[
	Tell
]]
Name = "Tell"

-- comment to enable this plugin
disable()

function PostLoad()
	if data then
		data.tell = data.tell or {}
	else
		error("this plugin depends on the data plugin")
	end
end

Command "tell"
{
	expectedArgs = "([^ ]+) (.+)",
	help = "Takes a message for another user.",

	function (usernick, message)
		data.tell[usernick:lower()] = data.tell[usernick:lower()] or {}
		table.insert(data.tell[usernick:lower()], {user.nick, message})
		reply("%s: Ok, got it.", user.nick)
	end
}

local function check(user, channel)
	local nick = user.nick:lower()
	if data.tell[nick] then
		local t = data.tell[nick]
		for n = 1, #t do
			send{target = channel, message = ("%s: %s left this message to you: '%s'"):format(user.nick, t[n][1], t[n][2])}
		end
		data.tell[nick] = nil
	end
end

Hook "OnChat" { check }
Hook "OnJoin" { check }
