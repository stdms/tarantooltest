FROM tarantool/tarantool:2.3

RUN apk update
RUN apk add luarocks unzip git cmake gcc binutils libc-dev make
RUN tarantoolctl rocks install http

RUN mkdir /opt/tarantool/lib
COPY ./lib/*.lua /opt/tarantool/lib/
COPY ./*.lua /opt/tarantool/
EXPOSE 8080
WORKDIR /opt/tarantool

ENV LUA_PATH $LUA_PATH;./lib/?.lua

EXPOSE 8080

CMD ["tarantool", "testapp.lua"]
