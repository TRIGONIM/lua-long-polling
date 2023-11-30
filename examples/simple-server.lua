-- Implementation of the most simple variant of long-polling server.
-- All data is stored in RAM, so it will be lost after server restart.
-- There is no request logging or error handling.
-- If you need most advanced example, see init.lua in the project root.
-- API Example:
-- POST example.com/any_string?data=any_data => 200 OK
-- GET  example.com/any_string?last_id=0&timeout=60 => 200 OK {"any_data"}

local polling = require("long-polling").new("localtable")

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
