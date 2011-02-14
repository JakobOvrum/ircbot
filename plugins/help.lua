--[[
	Help command
]]

Name = "Command Help"
Hidden = true

-- uncomment to disable this plugin
-- disable()

local helpHeader = "-------- running plugins --------"
local helpFooter = "Use `help <plugin>` to see help for a particular plugin."

local pluginHeader = "-------- %s (%s) --------"

Command "help"
{
	function(modname)
		local response = {method = "notice", target = user.nick}

		if not modname then -- list plugins
			send(response, helpHeader)
			for name, plugin in pairs(self.plugins) do
				if not plugin.Hidden then
					send(response, ("%s - %s"):format(name, plugin.Name))
				end
			end
			send(response, helpFooter)
		else -- list commands
			local plugin = self.plugins[modname] or raise("Plugin \"%s\" not found.", modname)
			if next(plugin.commands) then
				send(response, pluginHeader:format(modname, plugin.Name))
				for name, cmd in pairs(plugin.commands) do
					if not cmd.admin or self:isAdmin(user) then
						send(response, ("%s%s - %s"):format(plugin.CommandPrefix, name, cmd.help))
					end
				end
			else
				send(response, ("Plugin \"%s\" (%s) has no commands."):format(modname, plugin.Name))
			end
		end
	end
}


