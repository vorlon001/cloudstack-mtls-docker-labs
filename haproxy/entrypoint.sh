#!/bin/sh
# =============================================================================
# Entrypoint для HAProxy mTLS-прокси
#
# HAProxy требует PEM-файлы (cert + key в одном файле).
# Этот скрипт копирует сертификаты из read-only /etc/haproxy/certs/
# в /tmp/haproxy-certs/, собирает PEM-файлы и запускает HAProxy.
# =============================================================================

set -e

SRC="/etc/haproxy/certs"
DST="/tmp/haproxy-certs"

echo "[entrypoint] Копируем сертификаты из $SRC в $DST..."
mkdir -p "$DST"
cp "$SRC"/* "$DST/" 2>/dev/null || true

echo "[entrypoint] Исправляем CRLF → LF в сертификатах..."
for f in "$DST"/*.key "$DST"/*.crt; do
    [ -f "$f" ] && sed -i 's/\r$//' "$f" 2>/dev/null || true
done

echo "[entrypoint] Собираем server.pem (server.crt + server.key)..."
cat "$DST/server.crt" "$DST/server.key" > "$DST/server.pem"

echo "[entrypoint] Собираем client.pem (client.crt + client.key)..."
cat "$DST/client.crt" "$DST/client.key" > "$DST/client.pem"

echo "[entrypoint] Запускаем HAProxy..."
exec haproxy -f /usr/local/etc/haproxy/haproxy.cfg
