--[[
    Identifying with Nickserv
]]

Name = "Nickserv identifier"
Hidden = true

-- comment to enable this plugin
disable()

local identified = false
Hook "Think"
{
    function()
        if not identified then
            send{target = "nickserv", message = ("identify %s"):format(CONFIG.nick, CONFIG.nickserv.password)}
            identified = true
        end
    end
}
