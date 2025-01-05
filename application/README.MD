# Long Polling Application

> 🇺🇸 English version not ready for now (I am lazy and don't want to translate it). You can use https://www.deepl.com/ to translate text on your own.

В папке находится исходный код поллинг сервера, который работает по адресу `poll.def.pm`. Но ниже приведен пример более примитивного приложения, которое тоже использует эту библиотеку.

## Run advanced application

```bash
cd directory_with_this_file/

# run server via docker-compose.yml (will build fresh image)
docker-compose up --build polling

# alternatively run server via docker run (will use image from registry)
docker run --env-file .env -p 3000:3000 ghcr.io/trigonim/lua-long-polling:latest
```

All available settings vars are listed in [`.env-example`](.env-example)

## Application REST API:

![api demo](https://file.def.pm/uV3R6f28.gif)

- **GET** `http://your.app/anySecretPath?ts=0&sleep=10`, where `ts` is the last update id you received from polling server. Take it as an offset. The `sleep` parameter is the timeout during which the connection will be kept open until a new update is available. If an update arrives within this timeout, the connection will be immediately closed with the new update in the response in the following format: `{ts = 123, ok = true, updates = {your_update}}`
- **POST** with json data to `http://your.app/anySecretPath?merge=me`. The final update will looks like this: `{"a": "b", "merge": "me"}`.
  Curl example: `curl --verbose -d '{"a": 1}' "http://localhost:3000/SECRET_UID?merge=me"`

No authorization. With API features in mind, you can use your server as a public API, because no one client will be able to get the other's data without knowing its "secret path". It's like in blockchain.

**Pro tip:** If you want to use Traefik as web proxy (nginx is fine without it), you may need to configure `maxIdleConnsPerHost=-1` as Traefik has a limit of active connections and disconnects the excess ones with error 500

**👀 Test server:** poll.def.pm. But please, don't use it in production because I can turn it off at any moment.



## Another example of simplest application

There is a simplest realization of long-polling server application.

All data is stored in RAM, so it will be lost after server restart.

There is no request logging or error handling features implemented,
	but you can find it in advanced app file located somewhere in this repo 😅

<details>
<summary>Toggle me!</summary>

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

### API:

- `POST` example.com/any_string?data=any_data => 200 OK
- `GET ` example.com/any_string?last_id=0&timeout=60 => 200 OK {"any_data"}

</details>
