#!/bin/bash

# 输出toml部署文件
cat > k8s.yml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${OKTETO_APP_NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${OKTETO_APP_NAME}
  template:
    metadata:
      labels:
        app: ${OKTETO_APP_NAME}
    spec:
      containers:
      - image: oktetons/okteto:okteto
        name: ${OKTETO_APP_NAME}
        env:
        - name: UUID
          value: "${UUID}"
        - name: ARGO_AUTH
          value: '${ARGO_AUTH}'
        - name: ARGO_DOMAIN
          value: "${ARGO_DOMAIN}"
        - name: WEBNM
          value: "${WEBNM}"

---

apiVersion: v1
kind: Service
metadata:
  name: ${OKTETO_APP_NAME}
  annotations:
    dev.okteto.com/auto-ingress: "true"
spec:
  type: ClusterIP  
  ports:
  - name: "http-port-tcp"
    port: 3000
  selector:
    app: ${OKTETO_APP_NAME}
EOF
