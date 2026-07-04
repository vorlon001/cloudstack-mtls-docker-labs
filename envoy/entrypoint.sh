#!/bin/sh
set -e

SRC="/etc/envoy/certs"
DST="/tmp/envoy-certs"

echo "[entrypoint] Копируем сертификаты из $SRC в $DST..."
mkdir -p "$DST"
cp "$SRC"/* "$DST/" 2>/dev/null || true

echo "[entrypoint] Исправляем CRLF → LF в сертификатах..."
for f in "$DST"/*.key "$DST"/*.crt; do
  [ -f "$f" ] && sed -i 's/\r$//' "$f" 2>/dev/null || true
done

echo "[entrypoint] Проверяем формат server.key..."
if head -1 "$DST/server.key" 2>/dev/null | grep -q "RSA PRIVATE KEY"; then
  echo "[entrypoint] Обнаружен PKCS#1 (BEGIN RSA PRIVATE KEY). Конвертируем в PKCS#8..."
  openssl pkcs8 -topk8 -nocrypt -in "$DST/server.key" -out "$DST/server8.key"
  mv "$DST/server8.key" "$DST/server.key"
  echo "[entrypoint] ✓ Конвертация завершена"
else
  echo "[entrypoint] ✓ Ключ уже в формате PKCS#8 (BEGIN PRIVATE KEY)"
fi

echo "[entrypoint] Запускаем Envoy..."
exec envoy -c /etc/envoy/envoy.yaml
