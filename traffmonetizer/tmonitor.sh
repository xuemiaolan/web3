#!/usr/bin/env bash

CONTAINER="tm"
EXPECTED_PREFIX="Token:"

# 获取最新一行日志（stderr+stdout）
LAST_LINE=$(docker logs --tail 1 "$CONTAINER" 2>/dev/null)


# 判断是否以 Token: 开头
if [[ "$LAST_LINE" != ${EXPECTED_PREFIX}* ]]; then
    echo "[ALERT] Log mismatch, restarting $CONTAINER"
    echo "[LOG] $LAST_LINE"
    docker restart "$CONTAINER"
else
    echo "[OK] Token log detected"
fi

