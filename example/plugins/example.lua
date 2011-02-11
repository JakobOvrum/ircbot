--[[
	Example Plugin
]]

PLUGIN.Name = "Example"

--Repeats text back at user using printf-style formatting
Command "echo"
{
	function(text)
		reply("%s: %s", user.nick, text)
	end
}

--Greets joining users
--note: hooks do not feature the reply function
Hook "OnJoin"
{
	function(user, channel)
		send{target = channel, message = string.format("Welcome to %s, %s!", channel, user.nick)}
	end
}

--Grabs select information from passed text using patterns
Command "extract"
{
	expectedArgs = "[Oo]nce upon a (%S+) I (%S+) this (%S+)";

	function(a, b, c)
		reply("%s: Once upon a %s you %s this %s", user.nick, a, b, c)
	end
}

--Grab three parameters from passed text
Command "passthree"
{
	expectedArgs = 3; --splits on whitespace

	function(one, two, three)
		reply("You gave me %s, %s and %s.", one, two, three)
	end
}

--Admin-only command with three alias' and an IRC formatted response
Command "secret" "very-secret" "super-secret"
{
	admin = true;

	function()
		reply("%s! This is %s!", color(user.nick, "blue"), bold(underline("top-secret")))
	end
}

--Count all arguments passed to the command
Command "wordcount"
{
	expectedArgs = -1; --accept any number of arguments
	function(...)
		reply("You passed %d arguments", select("#", ...))
	end
}

--Print a line to the bot log
Command "log"
{
	function(line)
		log("Log command: %s", line)
	end
}

--Say "Hi!", wait 3 seconds, say "I'm a bot!", wait 10 seconds, repeat
do
	local spamchannel
	
	--Think hooks are run once every bot:think(), but can be delayed with the "wait" function.
	--The "wait" function does not block the rest of the program.
	Hook "Think"
	{
		enabled = false; --not enabled by default

		function()
			send{target = spamchannel, message = bold("Hi!")}
			wait(3)
			send{target = spamchannel, message = underline("I'm a bot!")}
			wait(10)
		end
	}

	--Enable or disable the previous example
	Command "greeter"
	{
		function(cmd)
			if cmd == "enable" then
				enableThink()
				spamchannel = channel
				reply("Enabled greeter.")
			elseif cmd == "disable" then
				disableThink()
				spamchannel = nil
				reply("Disabled greeter.")
			else
				reply("Argument must be 'enable' or 'disable'.")
			end
		end
	}
end
