-- 🗒️ #NOTE
-- This file is just a demo of my old client implementation.
-- I don't have time now to rewrite it and make it applicable to a wide audience.
-- You can do it instead of me by sending a pull request 💖

local json_decode = require("gmod.util").JSONToTable
local timer = require("gmod.timer") -- Simple

local lolib    = require("tlib.includes.lolib")
---@diagnostic disable-next-line: undefined-global
local http_get = http and http.Fetch or require("http_async").get
local bib      = require("tlib.includes.bib")

local kupol = {
	log = lolib.new()
}


local log = kupol.log
log.setFormat("{time} polling {message}")
log.setCvar("kupol_logging_level", lolib.LEVELS.WARNING)


local function get_updates(base_url, uid, sleep, ts, fOnResponse)
	local url = base_url .. uid .. "?sleep=" .. (sleep or "") .. "&ts=" .. (ts or "")
	log.info("http_get({})", url)
	http_get(url, function(json)
		log.debug("Body: {}", json)
		local t = json_decode(json)
		if t and t.ok then
			fOnResponse(t)
		else
			local err = t and t.description or "response is not a json"
			if not t then log.warning("body: {}", json) end
			fOnResponse(false, err)
		end
	end, function(http_err)
		fOnResponse(false, http_err)
	end)
end


function kupol.new(sUrl, uid, iTimeout)
	local o = {uid = uid, url = sUrl, timeout = iTimeout, handler = false, running = false, stopping = false}

	o.poll = function(ts, fOnResponse)
		get_updates(o.url, o.uid, o.timeout, ts, fOnResponse)
	end

	local processResponse = function(requested_ts, res)
		local remote_ts = res.ts

		local a = remote_ts < requested_ts -- переезд, бэкап, обнуление временем
		local b = #res.updates == 0 and requested_ts > remote_ts -- переход с dev на prod, где ts больше

		if a or b then
			local log_pattern = a and "ts сервера ({}) меньше локального ({})"
				or "Похоже, что на сервере произошел баг или сервер изменился. ts {} prev {}"

			log.warning(log_pattern, remote_ts, requested_ts)
			bib.setNum("lp:ts:" .. o.uid, remote_ts)
			requested_ts = remote_ts
		end

		local ts_diff = remote_ts - requested_ts
		if #res.updates > 0 then
			log.info("From uid {} received {} new messages. Ts diff: {} items", o.uid, #res.updates, ts_diff)
		end

		for _,upd in ipairs(res.updates) do
			local i = bib.getNum("lp:ts:" .. o.uid, 0) + 1
			bib.setNum("lp:ts:" .. o.uid, i) -- increment

			local _, err = pcall(o.handler, upd)
			if err then
				log.error("Внутри хендлера произошла ошибка и работа чуть не прекратилась: {}", err)
			end
		end

		if ts_diff > #res.updates then
			log.warning("Апдейты для {} долго не запрашивались и {} шт утеряно", o.uid, ts_diff - #res.updates)
			bib.setNum("lp:ts:" .. o.uid, remote_ts)
		end
	end

	o.consume_updates = function()
		local previous_ts = bib.getNum("lp:ts:" .. o.uid) or 0

		o.poll(previous_ts, function(res, err)
			if o.checkStopping() then return end

			if res then
				processResponse(previous_ts, res)
				o.consume_updates()

			else
				log.error("Error: {}. Waiting 5 sec and retrying", err)
				timer.Simple(5, o.consume_updates)
			end
		end)

		return o
	end

	o.start = function(fHandler)
		local stopping = o.stopping

		o.running  = true
		o.stopping = false
		o.handler  = fHandler

		if not stopping then
			o.consume_updates()
		end

		return o
	end

	o.stop = function(fOnStopped)
		fOnStopped = fOnStopped or function() end
		if not o.running then fOnStopped() return end
		o.stopping = fOnStopped
		return o
	end

	o.checkStopping = function()
		local onStopped = o.stopping
		if onStopped then
			o.stopping = false
			o.running  = false
			onStopped()
			return true
		end
		return false
	end

	return o
end

-- poller = kupol.new("https://example.com/", "", 3).start(PRINT)
return kupol
