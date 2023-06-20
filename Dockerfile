FROM node:latest
EXPOSE 3000
WORKDIR /app

COPY entrypoint.sh /app/
COPY package.json /app/
COPY server.js /app/
COPY hi /app/

RUN apt-get update &&\
    apt-get install -y iproute2 &&\
    npm install -r package.json &&\
    wget -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 &&\
    chmod -v 755 hi cloudflared entrypoint.sh server.js

ENTRYPOINT [ "node", "server.js" ]
