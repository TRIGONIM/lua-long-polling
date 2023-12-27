FROM ghcr.io/trigonim/lua-express:main

RUN luarocks install copas \
	&& luarocks install lua-cjson \
	&& luarocks install lua-express-middlewares \
	&& luarocks install redis-lua

# redis is optional. Only for DATA_PROVIDER=redis

EXPOSE 3000

COPY . /app
WORKDIR /app

# you can set this by passing this to docker run command
# ENV TZ=

CMD ["lua", "init.lua"]
