# Lua Long Polling Server

> 🇺🇸 English version not ready for now (I am lazy and don't want to translate it). You can use https://www.deepl.com/ to translate text on your own.


This is a simplest realization of long-polling server.

All data is stored in RAM, so it will be lost after server restart.

There is no request logging or error handling features implemented,
	but you can find it in advanced app file located somewhere in this repo 😅

## API:

- `POST` example.com/any_string?data=any_data => 200 OK
- `GET ` example.com/any_string?last_id=0&timeout=60 => 200 OK {"any_data"}

## Example

```lua
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

```
