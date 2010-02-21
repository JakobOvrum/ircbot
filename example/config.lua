nick = "LuaIRCBot"
username = "lua"
realname = "Example Service"

server = "irc.gamesurge.net"

channels
{
	"#hellothere";
}

plugindir = "plugins"

function startup(bot)
	bot:sendChat("jA_cOp", "I authed!")
	bot:sendChat("AuthServ", "AUTH replacethis. Maybe that'll work.")
	bot:setmode{ add = "x" }
end

--Uncomment this if you're on a network without account services.
--password = "replaceme"
