nick = "LuaIRCBot"
username = "lua"
realname = "Example Service"

server = "irc.gamesurge.net"

channels
{
	"#hellothere";
}

plugin_dir = "plugins"

--on_connect callback example for authenticating to services before joining channels
local auth_service = "replaceme" -- "AuthServ@Services.GameSurge.net" for GameSurge
local auth_user = "replaceme"
local auth_pass = "replaceme"

function on_connect(connection)
	--Uncomment this to enable automatic account authentication
	--connection:sendChat(auth_service, table.concat({"AUTH", auth_user, auth_pass}, " "))
end

--Uncomment this if you're on a network without account services.
--password = "replaceme"
