# =============================================================================
# Dockerfile для Envoy Proxy как mTLS-прокси перед NGINX
# =============================================================================

FROM envoyproxy/envoy:v1.31-latest

LABEL maintainer="mTLS Demo - Envoy Proxy"
LABEL description="Envoy Proxy с mTLS-терминацией и проксированием на NGINX"

# Устанавливаем openssl для конвертации ключей PKCS#1 → PKCS#8
RUN apt-get update && apt-get install -y --no-install-recommends openssl && rm -rf /var/lib/apt/lists/*

# Копируем конфигурацию
COPY envoy-proxy.yaml /etc/envoy/envoy.yaml

# Копируем entrypoint-скрипт
COPY entrypoint.sh /entrypoint.sh

# Исправляем CRLF → LF (на случай сборки из Windows)
RUN sed -i 's/\r$//' /etc/envoy/envoy.yaml /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Создаём директории
RUN mkdir -p /etc/envoy/certs /tmp/envoy-certs

# Открываем порты: HTTPS (8443) + Admin (9901)
EXPOSE 8443 9901

# Entrypoint: копирует сертификаты в /tmp, конвертирует PKCS#1→PKCS#8, запускает Envoy
ENTRYPOINT ["/entrypoint.sh"]
