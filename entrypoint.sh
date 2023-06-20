#!/bin/bash

generate_web() {
# 下载并运行 web
  cat > web.sh << EOF
#!/usr/bin/env bash

WEBNM=${WEBNM:-'hi'}
UUID=${UUID:-'de04add9-5b68-8bab-950c-08cd5320df18'}
VMESS=${VMESS:-'vmess'}
VLESS=${VLESS:-'vless'}
TROJAN=${TROJAN:-'trojan'}
SHADOWSOCKS=${SHADOWSOCKS:-'shadowsocks'}

run() {
  chmod +x ${WEBNM} && ./${WEBNM} >/dev/null 2>&1 &
}

run
EOF
}


generate_argo() {
  cat > argo.sh << ABC
#!/usr/bin/env bash

ARGO_AUTH=${ARGO_AUTH}
ARGO_DOMAIN=${ARGO_DOMAIN}

# 下载并运行 Argo
check_file() {
  [ ! -e cloudflared ] && wget -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && chmod +x cloudflared
}

run() {
  if [[ -n "\${ARGO_AUTH}" && -n "\${ARGO_DOMAIN}" ]]; then
    [[ "\$ARGO_AUTH" =~ TunnelSecret ]] && echo "\$ARGO_AUTH" | sed 's@{@{"@g;s@[,:]@"\0"@g;s@}@"}@g' > tunnel.json && echo -e "tunnel: \$(sed "s@.*TunnelID:\(.*\)}@\1@g" <<< "\$ARGO_AUTH")\ncredentials-file: $PWD/tunnel.json" > tunnel.yml && ./cloudflared tunnel --edge-ip-version auto --config tunnel.yml --url http://localhost:8080 run 2>&1 &
    [[ \$ARGO_AUTH =~ ^[A-Z0-9a-z=]{120,250}$ ]] && ./cloudflared tunnel --edge-ip-version auto run --token ${ARGO_AUTH} 2>&1 &
  else
    ./cloudflared tunnel --edge-ip-version auto --no-autoupdate --logfile argo.log --loglevel info --url http://localhost:8080 2>&1 &
    sleep 5
    ARGO_DOMAIN=\$(cat argo.log | grep -o "info.*https://.*trycloudflare.com" | sed "s@.*https://@@g" | tail -n 1)
  fi
}

export_list() {
  VM="{ \"v\": \"2\", \"ps\": \"Argo-Vmess\", \"add\": \"icook.hk\", \"port\": \"443\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\${ARGO_DOMAIN}\", \"path\": \"/${VMESS}?ed=2048\", \"tls\": \"tls\", \"sni\": \"\${ARGO_DOMAIN}\", \"alpn\": \"\" }"
  cat > list << EOF
*******************************************
V2-rayN:
----------------------------
vless://${UUID}@icook.hk:443?encryption=none&security=tls&sni=\${ARGO_DOMAIN}&type=ws&host=\${ARGO_DOMAIN}&path=%2F${VLESS}?ed=2048
----------------------------
vmess://\$(echo \$VM | base64 -w0)
----------------------------
trojan://${UUID}@icook.hk:443?security=tls&sni=\${ARGO_DOMAIN}&type=ws&host=\${ARGO_DOMAIN}&path=%2F${TROJAN}?ed=2048
----------------------------
ss://$(echo "chacha20-ietf-poly1305:${UUID}@icook.hk:443" | base64 -w0)@icook.hk:443#Argo-Shadowsocks
由于该软件导出的链接不全，请自行处理如下: 传输协议: WS ， 伪装域名: \${ARGO_DOMAIN} ，路径: /${shadowsocks}?ed=2048 ， 传输层安全: tls ， sni: \${ARGO_DOMAIN}
*******************************************
EOF
  cat list
}
check_file
run
export_list
ABC
}

generate_web
generate_argo
[ -e web.sh ] && nohup bash web.sh >/dev/null 2>&1 &
[ -e argo.sh ] && nohup bash argo.sh >/dev/null 2>&1 &
