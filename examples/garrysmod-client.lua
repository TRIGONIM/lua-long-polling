--[[
This example shows how to modify client to use it in a Garry's Mod environment
	where there are no copas or lua-cjson.

When used in pure lua where copas is installed,
	it is not necessary to overwrite the functions kupol.http_* and kupol.thread_*
]]


local kupol = include("path/to/kupol.lua") -- https://github.com/TRIGONIM/lua-long-polling/blob/main/lua/long-polling/client.lua

kupol.json_encode = util.TableToJSON
kupol.json_decode = util.JSONToTable

function kupol.thread_new(f, ...)
	local co = coroutine.create(f)
	local function cont(...)
		local ok, callback = coroutine.resume(co, ...)
		if not ok then error( debug.traceback(co, callback) ) end
		if coroutine.status(co) ~= "dead" then callback(cont) end
	end
	cont(...)
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


local LP = kupol.new("https://poll.def.pm/test") -- personal server for testing. dont use it in production

local i = 1
local publish = function()
	local ok, err = LP:publish({i = i})
	print(i, ok and "published" or "pub failed: " .. tostring(err))
	i = i + 1
end

-- spam publishing
kupol.thread_new(function()
	for _ = 1, 10 do publish() kupol.thread_pause(.05) end
end)

-- one time subscribing for receiving continious updates
LP:subscribe(function(upd, ts)
	print("subscribe callback. upd received. Remote ts, incr:", ts, upd.i)
end, nil, 5) -- 5 seconds timeout
