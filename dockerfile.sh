#!/usr/bin/env bash

# 默认各参数值，请自行修改.(注意:伪装路径不需要 / 符号开始,为避免不必要的麻烦,请不要使用特殊符号.)
cat >  ./Dockerfile << ABC
FROM node:latest
EXPOSE 3000
WORKDIR /app

COPY entrypoint.sh /app/
COPY package.json /app/
COPY server.js /app/
COPY ${WEBNM} /app/

RUN apt-get update &&\
    apt-get install -y iproute2 &&\
    npm install -r package.json &&\
    wget -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 &&\
    chmod -v 755 ${WEBNM} cloudflared entrypoint.sh server.js

ENTRYPOINT [ "node", "server.js" ]
ABC

