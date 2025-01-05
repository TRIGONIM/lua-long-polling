<!-- personal notes

-------

-->

# Long Polling Server

A simple [long-polling](https://javascript.info/long-polling) server (and client) written in Lua.

![demo image](https://file.def.pm/wq86G74W.svg)

_source: javascript.info_

## Features:

- Can be used to deliver messages to multiple clients at the same time.
- Tested in a production environment
- docker ready
- Contains Client and Server components. Also contains advanced application example
- You can specify predefined parameters to be added to each update object, which is useful when you want to recognize different services that send updates to the same link.
- Ability to customize the amount of data stored and the storage time (for redis) so that no garbage is stored

## Use cases:

- In environments where it is not possible to create a web server (e.g. in a Garry's Mod game), but getting "webhooks" is necessary
- As a single point of collecting webhooks, for example to get updates from all your Telegram bots with just one request. To do this, make `https://api.telegram.org/bot$TOKEN/setWebhook?url=https://your.app/SomeS3cretP@th?this_key=and_value&will_be=merged_with_updates_sent_by_telegram&botname=some_id`.
- Simple chat-like services implementations

## Project structure

```
 .
├──  lua
│   └──  long-polling
│       ├──  application
│       │   ├──  docker-compose.yml
│       │   ├──  Dockerfile
│       │   ├──  init.lua
│       │   └──  README.MD
│       ├──  client
│       │   ├──  init.lua
│       │   └──  README.MD
│       └──  server
│           ├──  dataproviders
│           │   ├──  localtable.lua
│           │   └──  redis.lua
│           ├──  misc
│           │   ├──  pubsub.lua
│           │   └──  redis-safe.lua
│           ├──  init.lua
│           └──  README.MD
├──  LICENSE
└──  README.MD

```

## Usage:

- 🔥 [application](/lua/long-polling/application)
- [client](/lua/long-polling/client)
- [server](/lua/long-polling/server)

## TODO:

- Move out `redis-safe` into separate repo
- Create the `mysql` dataprovider, using [luasocket-mysql](https://github.com/TRIGONIM/luasocket-mysql) driver
- Also create the `filesystem` dataprovider

