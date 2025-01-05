FROM ghcr.io/trigonim/lua-express:latest

RUN luarocks install copas \
	&& luarocks install lua-cjson \
	&& luarocks install lua-express-middlewares \
	&& luarocks install lua-long-polling main \
	&& luarocks install redis-lua


# redis is optional. Only for DATA_PROVIDER=redis

EXPOSE 3000

COPY . /app
WORKDIR /app

# you can set this by passing variables to docker run command
# ENV TZ=
# ENV LUA_PATH="/app/lua/?.lua;/app/lua/?/init.lua;${LUA_PATH}"

CMD ["lua", "server.lua"]
