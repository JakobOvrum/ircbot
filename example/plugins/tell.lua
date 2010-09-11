--[[
  Tell
]]

PLUGIN.Name = "Tell"
local telldb = {}

function PostLoad()
  if data then
    data.tell = data.tell or {}
    telldb = data.tell
  else
    error("this plugin depends on the data plugin")
  end
end

Command "tell"
{
  expectedArgs = "([^ ]+) (.+)";

  function (usernick, message)
    telldb[usernick:lower()] = telldb[usernick:lower()] or {}
    local t = telldb[usernick:lower()]
    t[#t+1] = {user.nick, message}
    reply("%s: Ok, got it.", user.nick)
  end
}

local function check(user, channel)
  if telldb[user.nick] then
    local t = telldb[user.nick:lower()]
    for n=1,#t do
      send{target = channel, message = ("%s: %s left this message to you: '%s'"):format(user.nick, t[n][1], t[n][2])}
    end
    telldb[user.nick:lower()] = nil
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