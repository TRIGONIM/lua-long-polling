<!-- personal notes

#todo

Структура репозитория убогая.
Переименовать его в типа "исходник poll.def.pm"? Или хотя бы конкретно "long-polling-server"
Example папку убрать. Пример с нее переместить в ридми?
В lua вот это вот misc/redis-safe.lua и misc/pubsub.lua какого черта оно там?
Есть lua/long-polling/client.lua, а lua/long-polling/server.lua в сраке спрятан.

-------

-->

# Long Polling Server

A simple [long-polling](https://javascript.info/long-polling) server (and client) written in Lua.

![demo image](https://file.def.pm/wq86G74W.svg)

_source: javascript.info_

# Features:

- Can be used to deliver messages to multiple clients at the same time.
- Tested in a production environment
- docker ready
- You can specify predefined parameters to be added to each update object, which is useful when you want to recognize different services that send updates to the same link.
- Ability to customize the amount of data stored and the storage time (for redis) so that no garbage is stored

# Use cases:

- In environments where it is not possible to create a web server (e.g. in a Garry's Mod game), but getting "webhooks" is necessary
- As a single point of collecting webhooks, for example to get updates from all your Telegram bots with just one request. To do this, make `https://api.telegram.org/bot$TOKEN/setWebhook?url=https://your.app/SomeS3cretP@th?this_key=and_value&will_be=merged_with_updates_sent_by_telegram&botname=some_id`.
- Simple chat-like services implementations

# Server API:

![api demo](https://file.def.pm/uV3R6f28.gif)

- **GET** `http://your.app/anySecretPath?ts=0&sleep=10`, where `ts` is the last update id you received from polling server. Take it as an offset. The `sleep` parameter is the timeout during which the connection will be kept open until a new update is available. If an update arrives within this timeout, the connection will be immediately closed with the new update in the response in the following format: `{ts = 123, ok = true, updates = {your_update}}`
- **POST** with json data to `http://your.app/anySecretPath?merge=me`. The final update will looks like this: `{"a": "b", "merge": "me"}`.
  Curl example: `curl --verbose -d '{"a": 1}' "http://localhost:3000/SECRET_UID?merge=me"`

No authorization. With API features in mind, you can use your server as a public API, because no one client will be able to get the other's data without knowing its "secret path". It's like in blockchain.

**Pro tip:** If you want to use Traefik as web proxy (nginx is fine without it), you may need to configure `maxIdleConnsPerHost=-1` as Traefik has a limit of active connections and disconnects the excess ones with error 500

**👀 Test server:** poll.def.pm. But please, don't use it in production because I can turn it off at any moment.

# Usage:

## Client

```lua
local kupol = require("long-polling.client") -- also works in Garry's Mod with include()
local polling = kupol.new("https://poll.def.pm/SomeSecretWord")
polling:subscribe(function(upd, last_id) print(last_id, upd.key) end, nil, 30)
polling:publish({key = "value"})
```

## Server

All available settings vars are listed in [`.env-example`](https://github.com/TRIGONIM/lua-long-polling/blob/main/.env-example)

```bash
# run server via docker-compose.yml (will build fresh image)
docker-compose up --build polling

# alternatively run server via docker run (will use image from registry)
docker run --env-file .env -p 3000:3000 ghcr.io/trigonim/lua-long-polling:latest
```

# TODO:

- Move out `redis-safe` into separate repo
- Create the `mysql` dataprovider, using [luasocket-mysql](https://github.com/TRIGONIM/luasocket-mysql) driver
- Also create the `filesystem` dataprovider

