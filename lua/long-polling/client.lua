local kupol = {}

local MT = {}
MT.__index = MT

function MT:publish(tData)
	local body = kupol.json_encode(tData)
	local res, code = kupol.http_post(self.url, body)
	return code == 202 or res == "OK", code
end

function MT:get(last_id, timeout)
	local paramstr = "?ts=" .. (last_id or "") .. "&sleep=" .. (timeout or "")

	local body, code_or_err = kupol.http_get(self.url .. paramstr)
	if not body then return false, code_or_err end

	local tData = kupol.json_decode(body)
	return tData, body -- tData may be nil
end

function MT:log(...)
	print("Kupol: " .. string.format(...))
end

function MT:subscribe(fHandler, last_id, timeout)
	kupol.thread_new(function() while true do
		local to = last_id and timeout or 0 -- it's better if first request will be fast if last_id not provided
		local tData, body = self:get(last_id, to)
		if tData then
			if (last_id or 0) > tData.ts then
				self:log("🚧 ts on server is less than requested (%d < %d)", tData.ts, last_id)
			end

			local updates_should_be = tData.ts - (last_id or 0)
			if updates_should_be > #tData.updates then
				local updates_lost = updates_should_be - #tData.updates
				self:log("🚧 updates lost: %d (got %d, expected %d)", updates_lost, #tData.updates, updates_should_be) -- too long haven't requested them
			end

			-- last_id = last_id and (last_id + #tData.updates) or tData.ts
			last_id = tData.ts
			for _, update in ipairs(tData.updates) do
				local pcallok, res = pcall(fHandler, update, tData.ts)
				if not pcallok then
					self:log(debug.traceback("🆘 Kupol Error In The Handler Callback\n\t%s"), res)
				end
			end
		else -- no tData
			fHandler(false, body)
			kupol.thread_pause(10)
		end
	end end) -- while true, thread
end

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
else
	-- e.g. in Garry's Mod
	print("Kupol: looks like copas is not installed. So you should provide own kupol.http_* and kupol.thread_* functions")
end

local cjson_ok, cjson = pcall(require, "cjson.safe")
if cjson_ok then
	kupol.json_encode = cjson.encode
	kupol.json_decode = cjson.decode
else
	print("Kupol: looks like lua-cjson is not installed. So you should provide own kupol.json_encode and kupol.json_decode functions")
end

-- url example: https://lp.example.com/channel
function kupol.new(url)
	return setmetatable({url = url}, MT)
end

return kupol
