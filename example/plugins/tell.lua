--[[
  Tell
]]

PLUGIN.Name = "Tell"
local telldb = false

Command "tell"
{
  expectedArgs = "([%w%p]+) (.+)";

  function (usernick, message)
    telldb[usernick] = telldb[usernick] or {}
    local t = telldb[usernick]
    t[#t+1] = {user.nick, message}
    reply("%s: Ok, got it.", user.nick)
  end
}

local function check(user, channel)
  if telldb[user.nick] then
    local t = telldb[user.nick]
    for n=1,#t do
      send{target = channel, message = ("%s: %s left this message to you: '%s'"):format(user.nick, t[n][1], t[n][2])}
    end
    telldb[user.nick] = nil
  end
end

Hook "OnChat"
{
  function(...)
    return check(...)
  end
}
Hook "OnJoin"
{
  function(...)
    return check(...)
  end
}

Hook "Think"
{
  function()
		if not telldb then
			if data then
				data.tell = data.tell or {}
				telldb = data.tell
			end
		end
	end
}