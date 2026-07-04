# =============================================================================
# Dockerfile для HAProxy как mTLS-прокси перед NGINX
# =============================================================================

FROM haproxy:2.9-alpine

LABEL maintainer="mTLS Demo - HAProxy"
LABEL description="HAProxy Proxy с mTLS-терминацией и проксированием на NGINX"

# Копируем конфигурацию
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg

# Копируем entrypoint-скрипт
COPY entrypoint.sh /entrypoint.sh

# Всё делаем от root: исправляем CRLF, даём права
USER root
RUN sed -i 's/\r$//' /entrypoint.sh && \
    chmod +x /entrypoint.sh

# НЕ переключаемся обратно на haproxy — entrypoint работает от root,
# HAProxy сам сбросит привилегии через настройки в конфиге
# (для production лучше использовать su-exec/gosu, для демо достаточно)

# Открываем порты: mTLS (9443) + Stats (8404)
EXPOSE 9443 8404

# Entrypoint: собирает PEM-файлы из отдельных cert/key, запускает HAProxy
ENTRYPOINT ["/entrypoint.sh"]
