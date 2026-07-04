# =============================================================================
# Dockerfile для NGINX как mTLS-прокси перед другим NGINX
# =============================================================================

FROM nginx:alpine

LABEL maintainer="mTLS Demo - NGINX Proxy"
LABEL description="NGINX Proxy с mTLS-терминацией и проксированием на NGINX-backend"

# Копируем конфигурацию NGINX-proxy
COPY nginx-proxy.conf /etc/nginx/nginx.conf

# Создаём директорию для сертификатов
RUN mkdir -p /etc/nginx/certs

# Открываем HTTPS порт (9443)
EXPOSE 9443

# Запуск NGINX в foreground-режиме
CMD ["nginx", "-g", "daemon off;"]
