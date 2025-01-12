-- package.path = string.format("%s;%s", "./lua/?.lua", package.path)
-- package.path = string.format("%s;%s", "./lua/?/init.lua", package.path)

io.stdout:setvbuf("no") -- faster stdout without buffering

--------

local APP_VERSION = "v1.5.0" -- #todo automate
print("LP Server Loading. Version " .. APP_VERSION)

local dataprovider = os.getenv("DATA_PROVIDER") or "localtable"
local longpolling = require("long-polling").new(dataprovider)

local json_encode = require("cjson.safe").encode
local json_decode = require("cjson.safe").decode

local return_result = function(res, result)
	result.ok = true
	res:json(result)
end

local return_error = function(res, err_code, err_descr)
	res:status(err_code):json({
		ok = false,
		error_code = err_code,
		error_description = err_descr
	})
end

local express = require("express")
local app = express()

app:set("trust proxy", {"uniquelocal"}) -- correct recognition of req:ip() inside the docker container

-- log requests
app:use(function(req, res, next)
	local kvs = {}
	for k, v in pairs(req.query) do
		kvs[#kvs + 1] = k .. "=" .. v
	end
	local querystring = kvs[1] and ("?" .. table.concat(kvs, "&")) or ""
	print(req.method, req:ip(), req.url .. querystring)
	next()
end)

-- parse body as json
app:use(require("body-parser").json({type = "*/*"})) -- https://github.com/TRIGONIM/lua-express-middlewares

app:use(function(_, res, next)
	res:set("X-Powered-By", "lua-long-polling " .. APP_VERSION)
	next()
end)

local rate_limiter = require("rate-limiter-simple") -- https://github.com/TRIGONIM/lua-express-middlewares
app:use(rate_limiter({
	frame_time   = tonumber(os.getenv("RATE_LIMIT_FRAME")) or 60,
	limit_amount = tonumber(os.getenv("RATE_LIMIT_LIMIT")) or 60,
}))

local function pushUpdates(req, res)
	local channel = req.params.channel
	local updateObj = req.body
	for k, v in pairs(req.query) do -- merge additional params from uri
		updateObj[k] = v
	end

	local update_json = json_encode(updateObj)
	local total = longpolling:publish_new(channel, update_json)

	res:set("X-Total-Updates", total):send("OK")
end

local function getUpdates(req, res)
	local channel = req.params.channel
	local offset = tonumber(req.query.ts) or 0

	-- clamping between 0 and 60
	local timeout = math.min(math.max(tonumber(req.query.sleep) or 0, 0), 60)

	-- locks the thread until update or timeout
	local data, total = longpolling:get_news(channel, offset, timeout)
	for k, v in ipairs(data) do data[k] = json_decode(v) end

	return_result(res, {
		updates = data,
		ts = total,
	})
end

app:all("/", function(_, res)
	res:redirect("https://github.com/TRIGONIM/lua-long-polling")
end)

app:post("/:channel/pushUpdates", pushUpdates) -- backward compatibility
app:post("/:channel", pushUpdates)

app:get("/:channel/getUpdates", getUpdates) -- backward compatibility
app:get("/:channel", getUpdates)

app:use(function(err, _, res, next)
	if type(err) == "table" and err.body then -- bodyparser middleware
		return_error(res, 500, err.message)
		return
	end

	print("polling error: " .. tostring(err))
	print(debug.traceback("trace"))
	if os.getenv("LUA_ENV") == "development" then next(err) end -- full info
	return_error(res, 500, "Internal Server Error")
end)

app:listen(3000)
