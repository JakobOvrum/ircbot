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
		send{target = channel, message = "Welcome!"}
	end
}

--Grabs select information from passed text using patterns
Command "extract"
{
	expectedArgs = "Once upon a (%S+) I walked this (%S+)";

	function(a, b)
		reply("%s: Once upon a %s you walked this %s", user.nick, a, b)
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

--Admin-only command with three alias with an IRC formatted response
Command "secret" "very-secret" "super-secret"
{
	admin = true;

	function()
		reply("%s! This is %s!", color(user.nick, "blue"), bold(underline("top-secret")))
	end
}

