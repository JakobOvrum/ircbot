local table = table
local string = string
local tonumber = tonumber
local tostring = tostring
local pcall = pcall
local error = error
local setfenv = setfenv
local ipairs = ipairs
local loadfile = loadfile

module(...)

local function tableField(tbl, name)
	tbl[name] = function(t)
		tbl[name] = t
	end
end

function load(path, tableFields)	
	local f, err = loadfile(path)
	if not f then error(err, 2) end

	local config = {table = table, string = string, tonumber = tonumber, tostring = tostring}

	if tableFields then
		for k, field in ipairs(tableFields) do
			tableField(config, field)
		end
	end
	
	setfenv(f, config)

	f, err = pcall(f)
	if not f then error(err, 2) end
	
	return config
end
