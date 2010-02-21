local error = error
local table = table
local type = type
local select = select
local xpcall = xpcall
local unpack = unpack

local print = print

module(...)

local function assert(a, err)
	if not a then
		error(err, 3)
	end
	return a
end

local commands = {}

function RegisterCommand(name)
	return function(tbl)
		name = name or tbl.Name
		
		local f = tbl[1]
		assert(type(f) == "function", "Callback is not a function")
		local cmd = {
			name = assert(name, "Command name not specified");
			cb = f;
			args = tbl.ExpectedArgs;
			plugin = tbl.Plugin;
		}
		commands[name] = cmd
	end
end

CommandPrefix = "!"

local function errorHandler(err)
	return err
end

--in serious need of cleanup
function OnChat(s, user, channel, msg)
	local cmdname = msg:match(table.concat{"^", CommandPrefix, "(%S+)"})
	if not cmdname then return end

	local cmd = commands[cmdname]
	if not cmd then return end

	local function raise(msg)
		s:sendChat(channel, table.concat{"Error running command \"", cmdname, "\": ", msg})
	end

	local args = msg:match(".- (.+)$")
	local expectedArgs = cmd.args
	
	if type(expectedArgs) == "string" then
		if not args then
			return raise("bad argument format")
		end
		
		local argstbl = {args:match(expectedArgs)}
		if #argstbl == 0 then
			return raise("bad argument format")
		end

		args = argstbl
		
	elseif type(expectedArgs) == "number" then
		if not args then
			return raise("Arguments expected, got none")
		end
		
		local argstbl = {}
		args:gsub("(%S+)", function(a) table.insert(argstbl, a) end)

		local n = #argstbl
		if expectedArgs >= 0 and n < expectedArgs then
			return raise(table.concat{expectedArgs, " arguments expected, got ", n})
		end

		args = argstbl
	end

	function cmd.plugin.reply(msg, ...)
		msg = msg:format(...)
		s:sendChat(channel, msg)
	end

	local env = cmd.plugin.environment
	env.channel = channel
	env.user = user
	
	local f = function()
		if type(args) == "table" then
			cmd.cb(unpack(args))
		else
			cmd.cb(args)
		end
	end
	
	local succ, err = xpcall(f, errorHandler)
	
	if not succ then
		raise(err)
	end
end
