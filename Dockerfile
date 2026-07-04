# =============================================================================
# Dockerfile для NGINX с mTLS
# Базируется на лёгком образе nginx:alpine
# =============================================================================

FROM nginx:alpine

# Метаданные
LABEL maintainer="mTLS Demo"
LABEL description="NGINX с поддержкой Mutual TLS (mTLS)"

# Копируем конфигурацию NGINX
COPY conf/nginx.conf /etc/nginx/nginx.conf

# Создаём директорию для сертификатов (сами сертификаты монтируются через volume)
RUN mkdir -p /etc/nginx/certs

# Открываем HTTPS порт
EXPOSE 443

# Запуск NGINX в foreground-режиме (стандартная точка входа nginx:alpine)
CMD ["nginx", "-g", "daemon off;"]
