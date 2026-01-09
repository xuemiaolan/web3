#!/bin/bash

# 容器名称
container_name="tm"

# 获取当前脚本所在目录
log_file="$(pwd)/tm.log"

# 监控容器日志流并获取最后一行
docker logs -f "$container_name" | while true; do
  # 获取容器日志的最后一行
  last_log=$(docker logs "$container_name" | tail -n 1)
  
  # 判断最新一行是否以 "Token:" 开头
  if [[ "$last_log" != Token:* ]]; then
    echo "$(date) - 最新日志不以 'Token:' 开头，正在重启容器 $container_name..." | tee -a "$log_file"
    # 重启容器
    docker restart "$container_name"
  else
    echo "$(date) - 正常日志：$last_log" | tee -a "$log_file"
  fi
  
  # 延时，避免过于频繁地请求日志
  sleep 60
done
