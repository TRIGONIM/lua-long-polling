-- source: https://github.com/TRIGONIM/lua-long-polling/blob/e28fff8141c7d1a22e030c9d6132ef853032da84/lua/long-polling/client.lua
-- local kupol  = require("long-polling.client")
-- local Client = kupol.new("https://lp.example.com/channel")
-- By default, client use copas and lua-cjson, but you can use your own functions
--   from Garry's Mod for example

local kupol = {}

local MT = {}
MT.__index = MT

function MT:publish_async(tData, callback)
	kupol.thread_new(function()
		local ok, code = self:publish(tData)
		if callback then callback(ok, code) end
	end)
end

function MT:publish(tData)
	local body = kupol.json_encode(tData)
	local res, code = kupol.http_post(self.url, body)
	return code == 201 or res == "OK", code
end

function MT:get(offset, timeout)
	local paramstr = "?ts=" .. (offset or "") .. "&sleep=" .. (timeout or "")

	local body, code_or_err = kupol.http_get(self.url .. paramstr)
	if not body then return false, code_or_err end

	local tData = kupol.json_decode(body)
	return tData, body -- tData may be nil
end

function MT:log(...)
	local prefix = ("Kupol (%s): "):format(self.url)
	print(prefix .. string.format(...))
end

function MT:handle_error(err)
	self:log("🆘 Error\n\t%s", err)
end

function MT:subscribe(fHandler, requested_ts, timeout)
	self.thread = kupol.thread_new(function() repeat
		local tmt = requested_ts and timeout or 0 -- it's better if first request will be fast if requested_ts not provided
		local tData, body = self:get(requested_ts, tmt)
		if tData then
			local ts_diff = tData.ts - (requested_ts or 0)

			local REM = (requested_ts or 0) > tData.ts -- REMOTE FUCKUP. e.g. remote ts 0, local ts 1000
			local LOC = ts_diff > #tData.updates -- LOCAL FUCKUP. e.g. remote ts 100, local ts 0, but 30 updates instead of 100
			if REM or LOC then
				if REM then
					self:log("🚧 ts on server is less than requested (%d < %d)", tData.ts, requested_ts)
				end

				if LOC then
					self:log("🚧 updates lost: %d (got %d, expected %d)", ts_diff - #tData.updates, #tData.updates, ts_diff) -- too long time haven't requested them
				end

				requested_ts = tData.ts -- emerg reset
			else
				requested_ts = requested_ts and (requested_ts + #tData.updates) or tData.ts
				-- requested_ts = tData.ts
			end

			for _, update in ipairs(tData.updates) do
				local pcallok, res = pcall(fHandler, update, tData.ts)
				if not pcallok then
					self:log(debug.traceback("🆘 Kupol Error In The Handler Callback\n\t%s"), res)
				end
			end
		else -- no tData
			self:handle_error(body)
			kupol.thread_pause(10)
		end
	until (not self.thread) end)
end

local IS_GARRYSMOD = (GM or GAMEMODE) and RunString and hook

local copas_ok, copas = pcall(require, "copas") -- should be loaded before http_v2
if copas_ok then
	local http = require("http_v2") -- https://github.com/TRIGONIM/lua-requests-async/blob/main/lua/http_v2.lua
	local async_request = http.copas_request

	function kupol.http_post(url, data)
		local body, code = async_request("POST", url, data, {["content-type"] = "application/json"})
		return body, code
	end

	function kupol.http_get(url)
		local body, code = async_request("GET", url)
		return body, code
	end

	kupol.thread_new   = copas.addthread
	kupol.thread_pause = copas.sleep

elseif IS_GARRYSMOD then
	function kupol.thread_new(f, ...)
		local co = coroutine.create(f)
		local function cont(...)
			local ok, callback = coroutine.resume(co, ...)
			if not ok then error( debug.traceback(co, callback) ) end
			if coroutine.status(co) ~= "dead" then callback(cont) end
		end
		cont(...)
		return co
	end

	function kupol.thread_pause(seconds)
		coroutine.yield(function(cont) timer.Simple(seconds, cont) end)
	end

	function kupol.http_get(url)
		return coroutine.yield(function(cont)
			http.Fetch(url, function(body, _, _, code) cont(body, code) end,
				function(err) cont(false, err) end)
		end)
	end

	function kupol.http_post(url, data)
		return coroutine.yield(function(cont)
			local ok = HTTP({ url = url, method = "POST",
				body = data, type = "application/json",
				success = function(code, body) cont(body, code) end,
				failed = function(err) cont(false, err) end
			})
			if not ok then cont(false, "HTTP() failed") end
		end)
	end

else
	print("Kupol: looks like copas is not installed. So you should provide own kupol.http_* and kupol.thread_* functions")
end

local cjson_ok, cjson = pcall(require, "cjson.safe")
if cjson_ok then
	kupol.json_encode = cjson.encode
	kupol.json_decode = cjson.decode

elseif IS_GARRYSMOD then
	kupol.json_encode = util.TableToJSON
	kupol.json_decode = util.JSONToTable

else
	print("Kupol: looks like lua-cjson is not installed. So you should provide own kupol.json_encode and kupol.json_decode functions")
end

-- url example: https://lp.example.com/channel
function kupol.new(url)
	return setmetatable({url = url}, MT)
end

return kupol
