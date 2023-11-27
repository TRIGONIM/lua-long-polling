local urldecode = require("express.utils").urldecode
-- local PRINT = require("tlib").PRINT
local json_decode   = require("cjson.safe").decode
local typeofrequest = require("misc.type-is").typeofrequest
local dprint        = require("express.utils").debugPrint

local bodyparser = {}

local function getCharset(req)
	local charset = req:get("content-type")
	if not charset then return end

	charset = charset:match("charset=([^;]+)")
	return charset and charset:lower()
end


-- https://github.com/expressjs/body-parser/blob/ee91374eae1555af679550b1d2fb5697d9924109/lib/types/json.js#L53
function bodyparser.json(opts)
	local typ = opts and opts.type or "application/json" -- "application/*", "*/*", "*/json", "text/*"

	local shouldParse = type(typ) == "function" and typ or function(req)
		return typeofrequest(req, typ)
	end

	return function(req, _, next)
		if req.body then dprint("body already parsed") next() return end

		req.bodydata = req.bodydata or req.pg_req:receiveBody()
		if not req.bodydata then next() return end

		if not shouldParse(req) then
			next()
			return
		end

		-- assert charset
		local charset = getCharset(req) or "utf-8"
		if charset ~= "utf-8" then
			next({
				status = 415,
				message = "Unsupported charset '" .. charset .. "'",
				stack = debug.traceback(),
			})
			return
		end

		local dat = json_decode(req.bodydata)
		if not dat or type(dat) ~= "table" then
			next({
				status = 400,
				message = "Malformed JSON payload",
				stack = debug.traceback(),
				body = req.bodydata,
			})
			return
		end

		req.body = dat -- nil if error above. Maybe 400 Bad Request error?
		next()
	end
end


local function parse_query_string(str)
	local params = {}
	for kv in str:gmatch("[^&]+") do
		if not kv:find("=") then
			params[urldecode(kv)] = ""
		else
			local k, v = kv:match("([^=]*)=(.*)")
			if k then params[urldecode(k)] = urldecode(v) end
		end
	end
	return params
end

function bodyparser.urlencoded(opts)
	local typ = opts and opts.type or "application/x-www-form-urlencoded"

	local shouldParse = type(typ) == "function" and typ or function(req)
		return typeofrequest(req, typ)
	end

	return function(req, _, next)
		if req.body then dprint("body already parsed") next() return end

		req.bodydata = req.bodydata or req.pg_req:receiveBody()
		if not req.bodydata then next() return end -- getExternalIP

		if not shouldParse(req) then
			next()
			return
		end

		-- assert charset
		local charset = getCharset(req) or "utf-8"
		if charset:sub(1, 4) ~= "utf-" then
			next({
				status = 415,
				message = "Unsupported charset '" .. charset .. "'",
				stack = debug.traceback(),
			})
			return
		end

		req.body = parse_query_string(req.bodydata)
		next()
	end
end

return bodyparser
