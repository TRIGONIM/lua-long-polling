local polling = require("long-polling.server").new("localtable")

local express = require("express")
local app = express()

local function push_updates(req, res)
	local channel = req.params.channel
	local payload = req.query.data

	polling:publish_new(channel, payload)
	res:send("OK")
end

local function get_updates(req, res)
	local channel = req.params.channel
	local last_id = tonumber(req.query.last_id) or 0
	local timeout = tonumber(req.query.timeout) or 0

	local data, total = polling:get_news(channel, last_id, timeout)
	res:set("X-Total-Messages", total):json(data)
end

app:post("/:channel", push_updates)
app:get("/:channel", get_updates)

app:listen(3000)
