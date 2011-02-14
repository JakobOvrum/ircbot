local error = error
local table = table
local type = type
local select = select
local pcall = pcall
local unpack = unpack
local assert = assert
local setmetatable = setmetatable
local setfenv = setfenv
local print = print
local ipairs = ipairs
local format = string.format

require "tableprint"

module "ircbot"

local bot = _META

local argHandlers = {
	string = function(expected, args)
		if not args then
			return nil, "arguments expected"
		end		
		local t = {args:match(expected)}
		if #t == 0 then
			return nil, "invalid argument format"
		end
		return t
	end;

	number = function(expected, args)
		if not args then
			return nil, "arguments expected"
		end
		local t = {}
		args:gsub("(%S+)", function(word) table.insert(t, word) end)

		if expected > -1 and #t < expected then
			return nil, ("got %d arguments, expected %d"):format(#t, expected)
		end
		return t
	end;
}

function bot:registerCommand(plugin, names, tbl, errorlevel)
	local function raise(message)
		error(format("%s (in command \"%s\")", message, table.concat(names, ", ")), errorlevel + 2)
	end

	if type(tbl.callback) ~= "function" then
		raise("callback is not a function")
	end

	tbl.admin = not not tbl.admin
	tbl.help = tbl.help or "No description."

	if tbl.expectedArgs then
		tbl.ArgParser = argHandlers[type(tbl.expectedArgs)] or raise("\"expectedArgs\" is of unsupported type")
	end

	if tbl.blacklist and tbl.whitelist then
		raise("commands can not have both a blacklist and whitelist")
	end

	local list = tbl.blacklist or tbl.whitelist
	if list then
		local newList = {}
		for k, channel in ipairs(list) do
			newList[channel] = true
		end
		tbl[tbl.blacklist and "blacklist" or "whitelist"] = newList
	end
	
	setmetatable(tbl, {__index = plugin})
	setfenv(tbl.callback, tbl)

	for k,name in ipairs(names) do
		if name:find("%s") then
			raise("command name can not contain whitespace")
		end
		plugin.commands[name] = tbl
	end
end

local abort_uid = {}

--- Default command prefix for bots when not overriden by the bots configuration file or the plugin.
CommandPrefix = "!"

function bot:initCommandSystem(plugin)
	local commands = plugin.commands
	local config = self.config

	local function report(user, channel, action)
		self:log(("user '%s@%s' tried to %s (in %s)"):format(user.nick, user.host, action, channel))
	end

	plugin.CommandPrefix = plugin.CommandPrefix or config.CommandPrefix or CommandPrefix
	local commandPattern = table.concat{"^", plugin.CommandPrefix, "(%S+)"}

	self:hook("OnChat", plugin, function(user, channel, msg)
		local cmdname = msg:match(commandPattern)
		if not cmdname then return end
		
		local cmd = commands[cmdname]
		if not cmd then return end

		local blacklist = cmd.blacklist
		if blacklist and blacklist[channel] then return end

		local whitelist = cmd.whitelist
		if whitelist and not whitelist[channel] then return end

		if cmd.admin == true and not self:isAdmin(user) then
			if not config.ignore_lackofadmin_warnings then
				report(user, channel, "run admin-only command " .. cmdname)
			end
			return
		end

		local function raise(err)
			local errorMessage = ("Error in command \"%s\": %s"):format(cmdname, err)
			self:log("[%s] %s", channel, errorMessage)
			local redirect = config.redirect_errors
			if redirect ~= true then
				self:sendChat(type(redirect) == "string" and redirect or channel, errorMessage)
			end
		end
		
		local args = msg:match("^%S+ (.+)$")

		local argParser = cmd.ArgParser
		if argParser then
			local parsed, err = argParser(cmd.expectedArgs, args)
			if not parsed then
				return raise(err)
			end
			args = parsed
		end
		
		cmd.user, cmd.channel = user, channel
		cmd.pm = channel == config.nick
		cmd.reply = function(message, ...)
			if type(message) ~= "string" then
				error(("bad argument #1 to 'reply' (expected string, got %s)"):format(type(message)), 2)
			end
			message = ... and message:format(...) or message
			self:sendChat(cmd.pm and user.nick or channel, message)
			return message
		end

		
		cmd.raise = function(...)
			cmd.reply(...)
			error(abort_uid)
		end

		local succ, err
		if type(args) == "table" then
			succ, err = pcall(cmd.callback, unpack(args))
		else
			succ, err = pcall(cmd.callback, args)
		end
		
		if not succ and err ~= abort_uid then
			return raise(err)
		end

		--signal to LuaIRC that this event was handled
		return true
	end)
end

function bot:shutdownCommandSystem(plugin)
	self:unhook("OnChat", plugin)
end
