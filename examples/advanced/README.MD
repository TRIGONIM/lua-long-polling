# Long Polling Server Application

In this folder you can find the source code of the server and client, which works at `poll.def.pm`.

## Features

- Can be used to deliver messages to multiple clients at the same time.
- Tested in a production environment
- docker ready
- You can specify predefined parameters to be added to each update object, which is useful when you want to recognize different services that send updates to the same link.
- Ability to customize the amount of data stored and the storage time (for redis) so that no garbage is stored


## Run the application

```bash
# git clone this repo
# cd directory_with_this_file/

# run server via docker-compose.yml (will build fresh image)
# 👍 nice for development
docker-compose up --build polling

# alternatively run server via docker run (will use image from registry)
docker run --env-file .env -p 3000:3000 ghcr.io/trigonim/lua-long-polling:latest
```

All available settings are listed in [`.env-example`](.env-example)

## Application REST API:

![api demo](https://file.def.pm/uV3R6f28.gif)

- **GET** `http://your.app/anySecretPath?ts=0&sleep=10`, where `ts` is the last update id you received from polling server. Take it as an offset. The `sleep` parameter is the timeout during which the connection will be kept open until a new update is available. If an update arrives within this timeout, the connection will be immediately closed with the new update in the response in the following format: `{ts = 123, ok = true, updates = {your_update}}`
- **POST** with json data to `http://your.app/anySecretPath?merge=me`. The final update will looks like this: `{"a": "b", "merge": "me"}`.
  Curl example: `curl --verbose -d '{"a": 1}' "http://localhost:3000/SECRET_UID?merge=me"`

No authorization. With API features in mind, you can use your server as a public API, because no one client will be able to get the other's data without knowing its "secret path". It's like in blockchain.

**Pro tip:** If you want to use Traefik as web proxy (nginx is fine without it), you may need to configure `maxIdleConnsPerHost=-1` as Traefik has a limit of active connections and disconnects the excess ones with error 500

**👀 Test server:** poll.def.pm. But please, don't use it in production because I can turn it off at any moment.

## Client Example

> 🇺🇸 English version not ready for now (I am lazy and don't want to translate it). You can use https://www.deepl.com/ to translate text on your own.

Works both in pure Lua and on Garry's Mod server.

On pure Lua requires copas (and luasocket), lua-requests-async (it also requires copas) and cjson.

### Usage

**In gmod** put any file in the path, then get access to the library through `kupol = include("path/to/client.lua")`. Nothing is added to the global space automatically.

In pure Lua you can use `kupol = require("long-polling.client")`.

### Example

```lua
local kupol  = require("long-polling.client") -- also works in Garry's Mod with include()
local Client = kupol.new("https://poll.def.pm/SomeSecretWord")


-- Getting data
Client:subscribe(function(upd, last_id)
	print("LP server received " .. tostring(last_id) .. " updates in all time")
	print("Last update: " .. kupol.json_encode(upd))
end, nil, 30) -- 30 is timeout in seconds.
-- nil – this is the last id, which was received (offset)


-- Sending data
kupol.thread_new(function()
	for i = 1, 10 do
		local ok, err = Client:publish({any = "value", counter = i})
		print(ok and "published" or "pub failed: " .. tostring(err))
		kupol.thread_pause(.05)
	end
end)
```

