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

module "ircbot"

local bot = _META

local argHandlers = {
	string = function(expected, args)
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

function bot:RegisterCommand(plugin, names, tbl)
	tbl.callback = assert(tbl.callback or tbl[1], "callback not specified")
	local f = tbl.callback

	tbl.admin = not not tbl.admin
	
	assert(type(f) == "function", "callback is not a function")

	if tbl.expectedArgs then
		tbl.ArgParser = assert(argHandlers[type(tbl.expectedArgs)], "\"expectedArgs\" is of unsupported type")
	end
	
	setmetatable(tbl, {__index = plugin})
	setfenv(f, tbl)

	for k,name in ipairs(names) do
		assert(not name:find(" "), "command name can not contain spaces")
		self.commands[name] = tbl
	end
end

function bot:hasCommandSystem()
	return not self.config.no_command_system
end

function bot:flushCommands()
	local cmds = self.commands
	for k,v in ipairs(cmds) do cmds[k] = nil end
end

CommandPrefix = "!"
function commandPrefix(new)
	local cmdPrefix = CommandPrefix
	CommandPrefix = new or cmdPrefix
	return cmdPrefix
end

function bot:initCommandSystem()
	local commands = {}
	local abort_uid = {}
	self.commands = commands

	local config = self.config
	local function report(user, channel, action)
		self:log(("user '%s@%s' tried to %s (in %s)"):format(user.nick, user.host, action, channel))
	end
	
	self:hook("OnChat", "_cmdhandler", function(user, channel, msg)
		local cmdname = msg:match(table.concat{"^", CommandPrefix, "(%S+)"})
		if not cmdname then return end
		
		local cmd = commands[cmdname]
		if not cmd then
			local ignore = self.config.ignore_unknowncommand_warnings
			if not ignore then
				report(user, channel, "run unrecognized command "..cmdname)
			end
			return
		end

		if cmd.admin == true and not self:isAdmin(user) then
			local ignore = config.ignore_lackofadmin_warnings
			if not ignore then
				report(user, channel, "run admin-only command "..cmdname)
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
		cmd.reply = function(fmt, ...)
			if type(fmt) ~= "string" then
				error(("bad argument #1 to 'reply' (expected string, got %s)"):format(type(fmt)), 2)
			end
			if cmd.pm then
				self:sendChat(user.nick, format(fmt, ...))
			else
				self:sendChat(channel, format(fmt, ...))
			end
		end

		
		cmd.raise = function(...)
			reply(...)
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
	end)
end
