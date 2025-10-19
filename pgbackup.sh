#!/bin/bash

BACKUP_DIR="/backup/pgsql"      # 备份存放目录
DATE=$(date +%F)                     # 当前日期
PGUSER="postgres"                    # 数据库用户
RETENTION_DAYS=7                     # 保留天数

# Telegram 通知配置
BOT_TOKEN=""
CHAT_ID=""
TG_API="https://api.telegram.org/bot${BOT_TOKEN}/sendMessage"

send_telegram() {
  local text="$1"
  curl -s -X POST "$TG_API" \
       --data-urlencode "chat_id=$CHAT_ID" \
       --data-urlencode "text=$text"
}

mkdir -p "$BACKUP_DIR/$DATE"

DB_LIST=$(psql -U "$PGUSER" -h localhost -t -c "
  SELECT datname
  FROM pg_database
  WHERE datistemplate = false
    AND datallowconn = true
    AND datname NOT IN ('postgres');
" | tr -d ' ')

START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
send_telegram "🗄️ PostgreSQL 自动备份开始
📅 时间：$START_TIME"

SUCCESS=true

for DB in $DB_LIST; do
  echo "Backing up $DB..."
  if pg_dump -U "$PGUSER" -h localhost -F c -b "$DB" | gzip > "$BACKUP_DIR/$DATE/${DB}.dump.gz"; then
    echo "$DB ✅"
  else
    echo "$DB ❌"
    SUCCESS=false
  fi
done

# 删除过期备份
find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;

END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
if $SUCCESS; then
  STATUS="✅ 所有数据库备份成功"
else
  STATUS="❌ 部分数据库备份失败，请检查日志"
fi

send_telegram "📦 PostgreSQL 备份任务完成
📅 日期：$DATE
🕓 开始时间：$START_TIME
🏁 结束时间：$END_TIME
📁 路径：$BACKUP_DIR/$DATE
状态：$STATUS"
